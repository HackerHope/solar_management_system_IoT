#!/usr/bin/env node
// Is the Gemini setup working? Run this FIRST, before deploying anything.
//
//   GEMINI_API_KEYS="key1,key2,key3" node tools/check_gemini.js      (a single GEMINI_API_KEY also works)
//   (optional) GEMINI_MODELS="gemini-3.6-flash,gemini-3.5-flash"     (default: the chain in functions/gemini_service_setup.js)
//
// It uses the SAME chain as the Cloud Function (every key x every model, in order) and checks:
//   1. at least one key is set
//   2. which of your keys Google accepts, and which chain models each key can use
//   3. one real call in JSON mode through the fallback chain, and WHICH key/model answered
// Exit code 0 = the advisor can get an answer. Any other code = read the message.

const { buildGeminiService, parseApiKeys, parseModels } = require("../functions/gemini_service_setup");

const BASE = "https://generativelanguage.googleapis.com/v1beta";
const keys = parseApiKeys(process.env.GEMINI_API_KEYS || process.env.GEMINI_API_KEY);
const models = parseModels(process.env.GEMINI_MODELS);
const mark = (s) => console.log("  " + s);
const fail = (m, code) => { console.error("  FAIL  " + m); process.exit(code); };

async function listModels(key) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), 30000);
  try {
    const res = await fetch(BASE + "/models?pageSize=200", { headers: { "x-goog-api-key": key }, signal: ctrl.signal });
    return res;
  } catch (e) {
    return null;
  } finally { clearTimeout(t); }
}

(async () => {
  console.log("Gemini check: " + keys.length + " key(s) x " + models.length + " model(s) = " + keys.length * models.length + " configs in the chain");
  if (keys.length === 0) fail("No key set. Create keys at https://aistudio.google.com/apikey and run:  GEMINI_API_KEYS=\"key1,key2\" node tools/check_gemini.js", 1);

  let accepted = 0;
  let chainOk = 0;
  let network = true;
  for (let i = 0; i < keys.length; i++) {
    const label = "key #" + (i + 1) + " (" + keys[i].slice(0, 4) + "..., " + keys[i].length + " chars)";
    const res = await listModels(keys[i]);
    if (!res) { network = false; mark("FAIL  " + label + ": cannot reach generativelanguage.googleapis.com (network/firewall)"); continue; }
    if (res.status === 400 || res.status === 401 || res.status === 403) { mark("FAIL  " + label + ": rejected by Google (HTTP " + res.status + ") - create a new key"); continue; }
    if (res.status === 429) { mark("WARN  " + label + ": rate limited right now (HTTP 429)"); accepted++; continue; }
    if (!res.ok) { mark("FAIL  " + label + ": HTTP " + res.status); continue; }
    accepted++;
    const names = ((await res.json()).models || []).filter((m) => (m.supportedGenerationMethods || []).includes("generateContent")).map((m) => m.name.replace(/^models\//, ""));
    const have = models.filter((m) => names.includes(m));
    const missing = models.filter((m) => !names.includes(m));
    chainOk += have.length;
    mark("PASS  " + label + ": accepted; " + have.length + "/" + models.length + " chain models available");
    if (missing.length) mark("      not available to this key: " + missing.join(", "));
    if (have.length === 0) {
      const flash = names.filter((n) => /flash/.test(n) && !/(image|tts|live|embedding)/.test(n)).slice(0, 10);
      mark("      models this key CAN use: " + flash.join(", "));
    }
  }
  if (!network && accepted === 0) fail("Cannot reach Gemini. Check your internet / firewall.", 3);
  if (accepted === 0) fail("No key was accepted.", 2);
  if (chainOk === 0) fail("None of the models in the chain exist for your keys. Set GEMINI_MODELS=<names listed above> here and when you deploy (firebase deploy asks for GEMINI_MODELS).", 4);

  // one real call through the chain
  const warnings = [];
  const service = buildGeminiService({ apiKeys: keys, models, logger: { warn: (l) => warnings.push(l) } });
  const t0 = Date.now();
  let r;
  try {
    r = await service.generateText({
      systemInstruction: "You answer with JSON only.",
      userText: 'Reply with exactly this JSON and nothing else: {"ok": true, "word": "solar"}',
      maxOutputTokens: 256,
      temperature: 0,
    });
  } catch (e) {
    warnings.forEach((w) => mark("skipped: " + w));
    fail("The fallback chain failed: " + e.message, 5);
  }
  warnings.forEach((w) => mark("skipped: " + w));
  let parsed;
  try { parsed = JSON.parse(r.text); } catch (_) { fail("Gemini answered, but not with valid JSON: " + r.text.slice(0, 120), 6); }
  if (parsed.ok !== true) fail("Unexpected JSON answer: " + r.text.slice(0, 120), 6);
  const keyNo = Math.floor(r.configIndex / models.length) + 1;
  mark("PASS  real call in JSON mode worked in " + (Date.now() - t0) + " ms, answered by key #" + keyNo + " / model " + r.model + " (config #" + (r.configIndex + 1) + " of " + service.configCount + ")");
  console.log("\nAll checks passed. The advisor can get an AI answer with this setup.");
})();
