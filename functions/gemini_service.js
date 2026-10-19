// Gemini service for the Energy Advisor.
// Same format as the Steadfast gemini_service.dart: a list of model + API key configs is
// tried in order. If a config hits a rate limit (HTTP 429) or its model is unavailable
// (HTTP 404), the next config is tried automatically. Any other error (bad response,
// 5xx, blocked prompt, empty answer) is thrown immediately, because switching model or key
// will not fix it.
//
// One small extension compared with the Dart version: a rejected key (HTTP 401/403, or a
// 400 "API key not valid") is also fallback-worthy, because the NEXT KEY may well work.
//
// The API key is sent in the x-goog-api-key header, never in the URL, so it cannot end up
// in request logs. Error messages never contain the key.

"use strict";

/** A single model + API key combination to try when calling Gemini. */
class GeminiModelConfig {
  constructor({ apiKey, model }) {
    this.apiKey = apiKey;
    this.model = model;
  }
}

class GeminiServiceException extends Error {
  constructor(message, status) {
    super(message);
    this.name = this.constructor.name;
    this.status = status;
  }
}

/** HTTP 429 (rate limit or quota exhausted): safe to try the next config. */
class GeminiRateLimitException extends GeminiServiceException {}

/** HTTP 404: the model string is wrong, retired, or not supported for generateContent. */
class GeminiModelUnavailableException extends GeminiServiceException {}

/** HTTP 401/403 or "API key not valid": this key is bad, the next key may be fine. */
class GeminiKeyException extends GeminiServiceException {}

const FALLBACK_WORTHY = [GeminiRateLimitException, GeminiModelUnavailableException, GeminiKeyException];

class GeminiService {
  /**
   * @param {object} o
   * @param {GeminiModelConfig[]} o.configs  tried top to bottom
   * @param {Function} [o.fetchImpl]         for tests
   * @param {number}   [o.timeoutMs]         per request
   * @param {{warn: Function}} [o.logger]    receives one line per fallback, never a key
   */
  constructor({ configs, fetchImpl = globalThis.fetch, timeoutMs = 30000, logger = null }) {
    if (!Array.isArray(configs) || configs.length === 0) throw new Error("GeminiService needs at least one config");
    this._configs = configs;
    this._fetch = fetchImpl;
    this._timeoutMs = timeoutMs;
    this._logger = logger;
  }

  get configCount() { return this._configs.length; }

  /**
   * Asks Gemini for a JSON answer. Returns { text, model, configIndex } (configIndex is 0-based
   * and tells you which model/key answered; the key itself is never returned).
   */
  async generateText({ systemInstruction, userText, maxOutputTokens = 2048, temperature = 0.3 }) {
    let lastError = null;
    for (let i = 0; i < this._configs.length; i++) {
      const config = this._configs[i];
      try {
        const text = await this._callModel(config, { systemInstruction, userText, maxOutputTokens, temperature });
        return { text, model: config.model, configIndex: i };
      } catch (e) {
        if (FALLBACK_WORTHY.some((C) => e instanceof C)) {
          lastError = e;
          if (this._logger) this._logger.warn(`gemini config #${i + 1} (${config.model}) skipped: ${e.name}`);
          continue;
        }
        throw e; // parse failure, 5xx, blocked prompt ...: a fallback will not fix it
      }
    }
    // Every configured model/key was rate-limited, unavailable or rejected.
    throw lastError || new GeminiServiceException("No Gemini models configured");
  }

  async _callModel(config, { systemInstruction, userText, maxOutputTokens, temperature }) {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(config.model)}:generateContent`;
    const body = {
      systemInstruction: { parts: [{ text: systemInstruction }] },
      contents: [{ role: "user", parts: [{ text: userText }] }],
      generationConfig: { temperature, maxOutputTokens, responseMimeType: "application/json" },
    };
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), this._timeoutMs);
    let res;
    try {
      res = await this._fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": config.apiKey },
        body: JSON.stringify(body),
        signal: ctrl.signal,
      });
    } catch (err) {
      throw new GeminiServiceException(`${config.model} request ${err && err.name === "AbortError" ? "timed out" : "failed (network)"}`);
    } finally {
      clearTimeout(timer);
    }

    if (!res.ok) {
      let detail = "";
      try { detail = ((await res.json())?.error?.message || "").slice(0, 200); } catch (_) { /* ignore */ }
      const msg = (suffix) => `${config.model} ${suffix} (${res.status})${detail ? ": " + detail : ""}`;
      if (res.status === 429) throw new GeminiRateLimitException(msg("rate limit hit"), 429);
      if (res.status === 404) throw new GeminiModelUnavailableException(msg("not found/unsupported"), 404);
      if (res.status === 401 || res.status === 403 || (res.status === 400 && /api key/i.test(detail))) {
        throw new GeminiKeyException(msg("key rejected"), res.status);
      }
      throw new GeminiServiceException(msg("request failed"), res.status);
    }

    const data = await res.json();
    if (data?.promptFeedback?.blockReason) {
      throw new GeminiServiceException(`${config.model} blocked the prompt (${data.promptFeedback.blockReason})`);
    }
    const candidate = data?.candidates?.[0];
    const text = (candidate?.content?.parts || []).map((p) => p.text || "").join("").trim();
    if (!text) {
      throw new GeminiServiceException(`${config.model} returned no text${candidate?.finishReason ? " (" + candidate.finishReason + ")" : ""}`);
    }
    return text;
  }
}

module.exports = {
  GeminiModelConfig,
  GeminiService,
  GeminiServiceException,
  GeminiRateLimitException,
  GeminiModelUnavailableException,
  GeminiKeyException,
};
