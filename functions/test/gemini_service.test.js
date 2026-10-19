const test = require("node:test");
const assert = require("node:assert/strict");
const {
  GeminiModelConfig, GeminiService, GeminiServiceException,
  GeminiRateLimitException, GeminiModelUnavailableException, GeminiKeyException,
} = require("../gemini_service");
const { buildGeminiService, parseApiKeys, parseModels, DEFAULT_MODELS, MAX_KEYS } = require("../gemini_service_setup");

const ok = (text = '{"headline":"h","summary":"s"}') => ({ ok: true, status: 200, json: async () => ({ candidates: [{ content: { parts: [{ text }] } }] }) });
const err = (status, message = "") => ({ ok: false, status, json: async () => ({ error: { message } }) });
const ask = (service) => service.generateText({ systemInstruction: "sys", userText: "user" });

// A fake Gemini: behaviour is decided per (key, model).
function fake(rules) {
  const calls = [];
  const fetchImpl = async (url, opts) => {
    const model = /models\/([^:]+):/.exec(url)[1];
    const key = opts.headers["x-goog-api-key"];
    calls.push(`${key}/${model}`);
    const r = rules[`${key}/${model}`];
    return typeof r === "function" ? r() : r || ok();
  };
  return { fetchImpl, calls };
}

test("needs at least one config", () => {
  assert.throws(() => new GeminiService({ configs: [] }), /at least one config/);
});

test("429 on the first model -> the next model is tried", async () => {
  const f = fake({ "A/m1": err(429, "quota") });
  const s = buildGeminiService({ apiKeys: ["A"], models: ["m1", "m2"], fetchImpl: f.fetchImpl });
  const r = await ask(s);
  assert.equal(r.model, "m2");
  assert.equal(r.configIndex, 1);
  assert.deepEqual(f.calls, ["A/m1", "A/m2"]);
});

test("404 (model retired) -> the next model is tried", async () => {
  const f = fake({ "A/m1": err(404, "models/m1 is not found") });
  const r = await ask(buildGeminiService({ apiKeys: ["A"], models: ["m1", "m2"], fetchImpl: f.fetchImpl }));
  assert.equal(r.model, "m2");
});

test("rejected key (403, or 400 'API key not valid') -> the next KEY is tried", async () => {
  const f = fake({ "A/m1": err(403, "denied"), "A/m2": err(400, "API key not valid. Please pass a valid API key."), "B/m1": ok() });
  const r = await ask(buildGeminiService({ apiKeys: ["A", "B"], models: ["m1", "m2"], fetchImpl: f.fetchImpl }));
  assert.equal(r.model, "m1");
  assert.equal(r.configIndex, 2);
});

test("a plain 400 (bad request) is NOT retried on other configs", async () => {
  const f = fake({ "A/m1": err(400, "Invalid JSON payload") });
  await assert.rejects(ask(buildGeminiService({ apiKeys: ["A", "B"], models: ["m1", "m2"], fetchImpl: f.fetchImpl })), (e) => e instanceof GeminiServiceException && e.status === 400);
  assert.deepEqual(f.calls, ["A/m1"]);
});

test("5xx is thrown immediately, no fallback", async () => {
  const f = fake({ "A/m1": err(503, "overloaded") });
  await assert.rejects(ask(buildGeminiService({ apiKeys: ["A"], models: ["m1", "m2"], fetchImpl: f.fetchImpl })), (e) => e.status === 503);
  assert.deepEqual(f.calls, ["A/m1"]);
});

test("every config rate-limited -> the last rate-limit error is thrown", async () => {
  const f = fake({ "A/m1": err(429), "A/m2": err(429), "B/m1": err(429), "B/m2": err(429, "last") });
  await assert.rejects(ask(buildGeminiService({ apiKeys: ["A", "B"], models: ["m1", "m2"], fetchImpl: f.fetchImpl })), (e) => e instanceof GeminiRateLimitException && /last/.test(e.message));
  assert.equal(f.calls.length, 4);
});

test("errors have the right classes", async () => {
  const one = (status) => ask(buildGeminiService({ apiKeys: ["A"], models: ["m1"], fetchImpl: async () => err(status, "d") })).catch((e) => e);
  assert.ok((await one(429)) instanceof GeminiRateLimitException);
  assert.ok((await one(404)) instanceof GeminiModelUnavailableException);
  assert.ok((await one(401)) instanceof GeminiKeyException);
  assert.ok((await one(500)) instanceof GeminiServiceException);
});

test("request: key goes in the header, never the URL; JSON mode and system instruction are sent", async () => {
  let seen;
  const fetchImpl = async (url, opts) => { seen = { url, opts }; return ok(); };
  await ask(buildGeminiService({ apiKeys: ["SECRET"], models: ["gemini-x"], fetchImpl }));
  assert.ok(seen.url.includes("models/gemini-x:generateContent"));
  assert.ok(!seen.url.includes("SECRET"));
  assert.equal(seen.opts.headers["x-goog-api-key"], "SECRET");
  const body = JSON.parse(seen.opts.body);
  assert.equal(body.generationConfig.responseMimeType, "application/json");
  assert.equal(body.systemInstruction.parts[0].text, "sys");
});

test("no error message ever contains an API key", async () => {
  for (const status of [400, 401, 403, 404, 429, 500]) {
    const e = await ask(buildGeminiService({ apiKeys: ["SECRETKEY"], models: ["m1"], fetchImpl: async () => err(status, "API key not valid") })).catch((x) => x);
    assert.ok(!String(e.message).includes("SECRETKEY"), "status " + status);
  }
  const e = await ask(buildGeminiService({ apiKeys: ["SECRETKEY"], models: ["m1"], fetchImpl: async () => { throw new Error("connect ECONNREFUSED using SECRETKEY"); } })).catch((x) => x);
  assert.ok(!String(e.message).includes("SECRETKEY"));
});

test("blocked prompt and empty answer are thrown, not retried", async () => {
  const blocked = buildGeminiService({ apiKeys: ["A", "B"], models: ["m1"], fetchImpl: async () => ({ ok: true, json: async () => ({ promptFeedback: { blockReason: "SAFETY" } }) }) });
  await assert.rejects(ask(blocked), /blocked/);
  const empty = buildGeminiService({ apiKeys: ["A", "B"], models: ["m1"], fetchImpl: async () => ({ ok: true, json: async () => ({ candidates: [{ finishReason: "MAX_TOKENS", content: { parts: [] } }] }) }) });
  await assert.rejects(ask(empty), /no text/);
});

test("logger receives one line per skipped config and never a key", async () => {
  const lines = [];
  const f = fake({ "SECRETKEY/m1": err(429) });
  const s = buildGeminiService({ apiKeys: ["SECRETKEY"], models: ["m1", "m2"], fetchImpl: f.fetchImpl, logger: { warn: (l) => lines.push(l) } });
  await ask(s);
  assert.equal(lines.length, 1);
  assert.match(lines[0], /#1 \(m1\) skipped: GeminiRateLimitException/);
  assert.ok(!lines[0].includes("SECRETKEY"));
});

test("buildGeminiService: keys x models, each key's models grouped together (like the Dart setup)", () => {
  const order = [];
  const fetchImpl = async (url, opts) => { order.push(opts.headers["x-goog-api-key"] + "/" + /models\/([^:]+):/.exec(url)[1]); return err(429); };
  const s = buildGeminiService({ apiKeys: ["A", "B"], models: ["m1", "m2", "m3"], fetchImpl });
  assert.equal(s.configCount, 6);
  return ask(s).catch(() => assert.deepEqual(order, ["A/m1", "A/m2", "A/m3", "B/m1", "B/m2", "B/m3"]));
});

test("buildGeminiService: default chain is 5 models; no key is an error", () => {
  assert.equal(DEFAULT_MODELS.length, 5);
  assert.equal(buildGeminiService({ apiKeys: ["A"] }).configCount, 5);
  assert.throws(() => buildGeminiService({ apiKeys: [] }), /No Gemini API key/);
  assert.throws(() => buildGeminiService({}), /No Gemini API key/);
});

test("parseApiKeys: trims, de-duplicates, accepts commas/spaces/newlines, caps at 6", () => {
  assert.deepEqual(parseApiKeys(" a, b ,a\nc "), ["a", "b", "c"]);
  assert.deepEqual(parseApiKeys(""), []);
  assert.deepEqual(parseApiKeys(undefined), []);
  assert.equal(parseApiKeys("1,2,3,4,5,6,7,8").length, MAX_KEYS);
});

test("parseModels: empty -> defaults, otherwise the given list", () => {
  assert.deepEqual(parseModels(""), DEFAULT_MODELS);
  assert.deepEqual(parseModels("x, y"), ["x", "y"]);
});

test("GeminiModelConfig holds key and model", () => {
  const c = new GeminiModelConfig({ apiKey: "k", model: "m" });
  assert.equal(c.apiKey, "k");
  assert.equal(c.model, "m");
});
