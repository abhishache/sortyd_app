// Keep the existing free-tier model, with an explicit native response contract.
const MODEL = "@cf/meta/llama-3.1-8b-instruct-fast";
const MAX_BODY_BYTES = 96_000;
const MAX_MESSAGE_CHARS = 80_000;
const MAX_MESSAGES = 2;
const MAX_OUTPUT_TOKENS = 8_000;

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" }
  });
}

function extractJSON(value) {
  if (typeof value !== "string") return value;

  const direct = value.trim();
  try {
    return JSON.parse(direct);
  } catch {}

  // Smaller models occasionally add a sentence or a Markdown fence despite
  // the prompt. Only return a parsed JSON value to native clients, never the
  // surrounding prose that would make their Decodable parsing fail.
  const fenced = /```(?:json)?\s*([\s\S]*?)```/gi;
  for (const match of direct.matchAll(fenced)) {
    try {
      return JSON.parse(match[1].trim());
    } catch {}
  }

  for (let start = 0; start < direct.length; start += 1) {
    const first = direct[start];
    if (first !== "{" && first !== "[") continue;

    const stack = [];
    let inString = false;
    let escaping = false;
    for (let index = start; index < direct.length; index += 1) {
      const character = direct[index];
      if (inString) {
        if (escaping) escaping = false;
        else if (character === "\\") escaping = true;
        else if (character === '"') inString = false;
        continue;
      }
      if (character === '"') {
        inString = true;
      } else if (character === "{" || character === "[") {
        stack.push(character);
      } else if (character === "}" || character === "]") {
        const opener = stack.pop();
        if ((character === "}" && opener !== "{") || (character === "]" && opener !== "[")) break;
        if (stack.length === 0) {
          try {
            return JSON.parse(direct.slice(start, index + 1));
          } catch {
            break;
          }
        }
      }
    }
  }
  return null;
}

// Batch results are wrapped for JSON Mode, then unwrapped for existing app versions.
const string = { type: "string" };
const strings = { type: "array", items: string };
const integer = { type: "integer" };
function object(properties) {
  return { type: "object", properties, required: Object.keys(properties), additionalProperties: false };
}
const pillar = object({ id: string, name: string, emoji: string, score: { type: "integer", minimum: 0, maximum: 100 }, status: string, insight: string, tasks: strings, advice: string });
const recap = { headline: string, summary: string, highlight: string, nudge: string, grade: string, gradeReason: string };
const flag = object({ id: string, taskTitle: string, daysSkipped: integer, suggestion: string, actionLabel: string });
function contract(prompt, batch) {
  let item;
  if (prompt.includes('"pillars"')) item = object({ ...(batch ? { listId: string } : {}), pillars: { type: "array", items: pillar, minItems: 1 }, overallInsight: string, criticalPillar: string });
  else if (prompt.includes('"gradeReason"')) item = object({ ...(batch ? { listId: string } : {}), ...recap });
  else if (prompt.includes('"flags"')) item = object({ listId: string, flags: { type: "array", items: flag } });
  else if (prompt.includes('"listName"')) item = object({ emoji: string, listName: string, tasks: { ...strings, minItems: 4, maxItems: 6 } });
  else if (prompt.includes('"hasReminder"')) item = object({ title: string, hasReminder: { type: "boolean" }, reminderHour: { type: ["integer", "null"] }, reminderMinute: { type: ["integer", "null"] } });
  else if (prompt.includes('"tips"')) item = object({ score: integer, label: string, insight: string, tips: strings });
  if (!item) return null;
  return batch ? object({ results: { type: "array", items: item, minItems: 1 } }) : item;
}
function conforms(value, schema) {
  if (Array.isArray(schema.type)) return schema.type.some(type => conforms(value, { ...schema, type }));
  if (schema.type === "null") return value === null;
  if (schema.type === "string") return typeof value === "string";
  if (schema.type === "boolean") return typeof value === "boolean";
  if (schema.type === "integer") return Number.isInteger(value) && (schema.minimum === undefined || value >= schema.minimum) && (schema.maximum === undefined || value <= schema.maximum);
  if (schema.type === "array") return Array.isArray(value) && value.length >= (schema.minItems ?? 0) && value.length <= (schema.maxItems ?? Infinity) && value.every(item => conforms(item, schema.items));
  return value !== null && typeof value === "object" && !Array.isArray(value) && schema.required.every(key => Object.hasOwn(value, key) && conforms(value[key], schema.properties[key]));
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/api/ai") {
      return json({ error: "Not found" }, 404);
    }

    const contentLength = Number(request.headers.get("content-length") || 0);
    if (contentLength > MAX_BODY_BYTES) {
      return json({ error: "Request too large" }, 413);
    }

    // Native apps do not need CORS. Rate-limit by Cloudflare's connecting IP
    // before parsing or invoking Workers AI, which protects the free allocation.
    const clientKey = request.headers.get("cf-connecting-ip") || "unknown";
    const { success } = await env.AI_RATE_LIMITER.limit({ key: clientKey });
    if (!success) return json({ error: "Too many requests. Try again shortly." }, 429);

    const body = await request.text();
    if (new TextEncoder().encode(body).byteLength > MAX_BODY_BYTES) {
      return json({ error: "Request too large" }, 413);
    }

    let input;
    try {
      input = JSON.parse(body);
    } catch {
      return json({ error: "Invalid JSON" }, 400);
    }

    if (!input || typeof input !== "object" || !Array.isArray(input.messages) || input.messages.length !== 1) {
      return json({ error: "messages is required" }, 400);
    }
    const [message] = input.messages;
    if (
      !message || message.role !== "user" || typeof message.content !== "string" ||
      message.content.length === 0 || message.content.length > MAX_MESSAGE_CHARS
    ) return json({ error: "Invalid message" }, 400);

    try {
      const expectsArray = /valid JSON array|JSON array|Respond ONLY with a valid JSON array/i.test(message.content);
      const schema = contract(message.content, expectsArray);
      const result = await env.AI.run(MODEL, {
        messages: [
          {
            role: "system",
            content: "Return only JSON matching the supplied schema. Use the requested language. Base every statement on supplied data. Never copy illustrative example statistics. " + (expectsArray ? 'Return an object with a results array containing one result per list. Preserve every listId exactly.' : 'Follow only the actual user goal; exclude unrelated tasks.')
          },
          { role: "user", content: message.content }
        ],
        max_tokens: Math.max(1, Math.min(Number.isFinite(Number(input.max_tokens)) ? Number(input.max_tokens) || 800 : 800, MAX_OUTPUT_TOKENS)),
        temperature: Math.max(0, Math.min(Number(input.temperature) || 0.35, 0.7)),
        ...(schema ? { response_format: { type: "json_schema", json_schema: schema } } : (!expectsArray ? { response_format: { type: "json_object" } } : {}))
      });
      const raw = typeof result === "string" ? result : (result.response ?? result.text ?? result);
      const parsed = extractJSON(raw);
      if (parsed === null || (schema && !conforms(parsed, schema))) {
        console.error("Workers AI returned non-JSON content");
        return json({ error: { message: "AI returned an invalid response", code: "invalid_ai_response" } }, 502);
      }
      const content = JSON.stringify(expectsArray && schema ? parsed.results : parsed);
      return json({
        choices: [{
          index: 0,
          message: { role: "assistant", content },
          finish_reason: "stop"
        }]
      });
    } catch (error) {
      console.error("Workers AI failed", error);
      return json({ error: { message: "Workers AI request failed", code: "workers_ai_error" } }, 502);
    }
  }
};
