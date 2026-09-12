const MAX_REQUEST_BYTES = 1_024;
const MAX_ITEM_LENGTH = 64;
const JSON_HEADERS = { "content-type": "application/json; charset=utf-8" };

type CombineRequest = { left?: unknown; right?: unknown };
type Combination = { name: string; emoji: string };
type OpenAIResponse = { output_text?: unknown; output?: unknown };

const combinationSchema = {
  type: "object",
  additionalProperties: false,
  required: ["name", "emoji"],
  properties: {
    name: { type: "string", minLength: 1, maxLength: 48 },
    emoji: { type: "string", minLength: 1, maxLength: 16 },
  },
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

function normalizeItem(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim().normalize("NFC");
  if (!normalized || normalized.length > MAX_ITEM_LENGTH || /[\u0000-\u001F\u007F]/.test(normalized)) {
    return null;
  }
  return normalized;
}

async function readSmallJSON(request: Request): Promise<CombineRequest | null> {
  const contentLength = request.headers.get("content-length");
  if (contentLength && Number(contentLength) > MAX_REQUEST_BYTES) return null;
  if (!request.body) return null;

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > MAX_REQUEST_BYTES) {
        await reader.cancel();
        return null;
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  try {
    return JSON.parse(new TextDecoder().decode(concatenate(chunks, total))) as CombineRequest;
  } catch {
    return null;
  }
}

function concatenate(chunks: Uint8Array[], total: number): Uint8Array {
  const output = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    output.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return output;
}

function isCombination(value: unknown): value is Combination {
  if (!value || typeof value !== "object") return false;
  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.name === "string" &&
    candidate.name.trim().length > 0 &&
    candidate.name.length <= 48 &&
    typeof candidate.emoji === "string" &&
    candidate.emoji.trim().length > 0 &&
    candidate.emoji.length <= 16
  );
}

function outputText(payload: OpenAIResponse): string | null {
  if (typeof payload.output_text === "string") return payload.output_text;
  if (!Array.isArray(payload.output)) return null;

  for (const item of payload.output) {
    if (!item || typeof item !== "object") continue;
    const content = (item as { content?: unknown }).content;
    if (!Array.isArray(content)) continue;
    for (const part of content) {
      if (!part || typeof part !== "object") continue;
      const candidate = part as { type?: unknown; text?: unknown };
      if (candidate.type === "output_text" && typeof candidate.text === "string") {
        return candidate.text;
      }
    }
  }
  return null;
}

type GenerationOutcome = {
  combination: Combination | null;
  upstreamStatus: number | null;
};

async function generateCombination(left: string, right: string, apiKey: string): Promise<GenerationOutcome> {
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      authorization: `Bearer ${apiKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-5.6-luna",
      store: false,
      reasoning: { effort: "none" },
      max_output_tokens: 60,
      tool_choice: "none",
      instructions:
        "You name one concise, familiar, game-friendly thing created by combining two items. " +
        "Return a single neutral noun or short noun phrase with one fitting emoji. " +
        "Do not explain your answer, mention the inputs, invent trademarks, or include punctuation in the name.",
      input: `Combine these two items: ${JSON.stringify(left)} + ${JSON.stringify(right)}`,
      text: {
        format: {
          type: "json_schema",
          name: "combination",
          strict: true,
          schema: combinationSchema,
        },
      },
    }),
    signal: AbortSignal.timeout(8_000),
  });

  if (!response.ok) {
    console.error(JSON.stringify({ message: "OpenAI request failed", status: response.status }));
    return { combination: null, upstreamStatus: response.status };
  }

  const payload = (await response.json()) as OpenAIResponse;
  const text = outputText(payload);
  if (!text) {
    return { combination: null, upstreamStatus: response.status };
  }

  try {
    const result = JSON.parse(text) as unknown;
    return {
      combination: isCombination(result)
        ? { name: result.name.trim(), emoji: result.emoji.trim() }
        : null,
      upstreamStatus: response.status,
    };
  } catch {
    return { combination: null, upstreamStatus: response.status };
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      return json({ ok: true });
    }
    if (request.method !== "POST" || url.pathname !== "/v1/combine") {
      return json({ error: "Not found" }, 404);
    }
    if (!request.headers.get("content-type")?.toLowerCase().includes("application/json")) {
      return json({ error: "Content-Type must be application/json" }, 415);
    }

    const body = await readSmallJSON(request);
    const left = normalizeItem(body?.left);
    const right = normalizeItem(body?.right);
    if (!left || !right) {
      return json({ error: "left and right must be short, non-empty item names" }, 400);
    }

    const generated = await generateCombination(left, right, env.OPENAI_API_KEY);
    if (!generated.combination) {
      return json({ error: "Combination generation is unavailable", upstreamStatus: generated.upstreamStatus }, 502);
    }

    console.log(JSON.stringify({ message: "Combination generated" }));
    return json({ ...generated.combination, source: "ai" });
  },
} satisfies ExportedHandler<Env>;
