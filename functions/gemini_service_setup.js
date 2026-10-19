// Builds the fallback chain across several API keys, each tried against every model in
// order before moving to the next key (same idea as gemini_service_setup.dart).
//
// Gemini rate limits are tracked per Google Cloud PROJECT, not per key or per person, so
// keys from separate projects/accounts give independent daily quotas. Keeping each key's
// models grouped together means a key is fully used up before the next one is touched.
//
// Order matters: GeminiService tries configs top to bottom and moves to the next only on a
// 429 (rate limit), a 404 (model unavailable) or a rejected key.
//
// The keys are NOT in this file. They live in ONE Firebase secret:
//
//     firebase functions:secrets:set GEMINI_API_KEYS
//     (paste the keys separated by commas, up to 6:   key1,key2,key3 )
//
// For local tools: GEMINI_API_KEYS="key1,key2"  (a single GEMINI_API_KEY also works).

"use strict";

const { GeminiModelConfig, GeminiService } = require("./gemini_service");

const MAX_KEYS = 6;

// Same models as the Steadfast chain, most capable first.
// Names change over time: run  node tools/check_gemini.js  to see which ones your keys can use,
// and override the list at deploy time with GEMINI_MODELS=name1,name2,...
const DEFAULT_MODELS = [
  "gemini-3.6-flash", // Primary
  "gemini-3.5-flash", // Fallback
  "gemini-3.5-flash-lite", // Fast/cheap fallback
  "gemini-3-flash-preview", // Optional preview fallback
  "gemini-3.1-flash-lite", // Legacy compatibility
];

const splitList = (s) =>
  String(s || "")
    .split(/[,\s]+/)
    .map((x) => x.trim())
    .filter(Boolean);

/** "key1, key2,key1" -> ["key1", "key2"] (trimmed, de-duplicated, at most MAX_KEYS). */
function parseApiKeys(text) {
  return [...new Set(splitList(text))].slice(0, MAX_KEYS);
}

/** "a,b" -> ["a","b"]; empty -> DEFAULT_MODELS. */
function parseModels(text) {
  const list = splitList(text);
  return list.length ? list : DEFAULT_MODELS;
}

/**
 * @param {object} o
 * @param {string[]} o.apiKeys
 * @param {string[]} [o.models]
 * @param {Function} [o.fetchImpl]
 * @param {{warn: Function}} [o.logger]
 */
function buildGeminiService({ apiKeys, models = DEFAULT_MODELS, fetchImpl, logger } = {}) {
  const keys = (apiKeys || []).filter(Boolean);
  if (keys.length === 0) throw new Error("No Gemini API key configured. Set the GEMINI_API_KEYS secret (see docs/ai-insights.md).");
  const configs = [];
  for (const apiKey of keys) {
    for (const model of models) configs.push(new GeminiModelConfig({ apiKey, model }));
  }
  return new GeminiService({ configs, fetchImpl, logger });
}

module.exports = { buildGeminiService, parseApiKeys, parseModels, DEFAULT_MODELS, MAX_KEYS };
