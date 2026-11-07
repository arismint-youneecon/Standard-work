// =====================================================================
//  Supabase Edge Function: translate-standard
//  컨트롤타워의 "🌐 번역 생성" 버튼이 호출합니다.
//  - 호출자의 로그인(JWT)으로 초안을 읽고(RLS 적용) → Claude API로 번역 → translations 컬럼에 저장
//  - 배포:  supabase functions deploy translate-standard
//  - 비밀키: supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//           (선택) TRANSLATE_MODEL=claude-sonnet-5-5   GLOSSARY="너깃=nugget; 급소=key point"
// =====================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const LANG_NAMES: Record<string, string> = {
  en: "English", zh: "Simplified Chinese", ja: "Japanese", vi: "Vietnamese", uz: "Uzbek (Latin script)",
  ru: "Russian", ne: "Nepali", kk: "Kazakh (Cyrillic)", bn: "Bengali", fr: "French",
};
// 번역하지 않는 키 (파일 경로, 아이콘, 전화번호 등)
const SKIP_KEY = /(^|_)path$|^icon$|^phone$|^url$|^stop_line$/;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...CORS, "Content-Type": "application/json" } });

// 문자열 수집 / 재조립
function collect(obj: unknown, path: string[] = [], out: { path: string[]; text: string }[] = []) {
  if (Array.isArray(obj)) obj.forEach((v, i) => collect(v, [...path, String(i)], out));
  else if (obj && typeof obj === "object") {
    for (const [k, v] of Object.entries(obj as Record<string, unknown>)) {
      if (SKIP_KEY.test(k)) continue;
      collect(v, [...path, k], out);
    }
  } else if (typeof obj === "string" && obj.trim()) out.push({ path, text: obj });
  return out;
}
function setPath(root: Record<string, unknown>, path: string[], value: string) {
  let cur: any = root;
  path.slice(0, -1).forEach((k, i) => {
    const nextIsIndex = /^\d+$/.test(path[i + 1]);
    if (cur[k] === undefined) cur[k] = nextIsIndex ? [] : {};
    cur = cur[k];
  });
  cur[path[path.length - 1]] = value;
}
async function hash(s: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf)).slice(0, 8).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function translateBatch(texts: string[], lang: string): Promise<string[]> {
  const key = Deno.env.get("ANTHROPIC_API_KEY");
  if (!key) throw new Error("ANTHROPIC_API_KEY secret is not set");
  const model = Deno.env.get("TRANSLATE_MODEL") || "claude-sonnet-5-5";
  const glossary = Deno.env.get("GLOSSARY") || "";
  const numbered: Record<string, string> = {};
  texts.forEach((t, i) => (numbered[String(i + 1)] = t));

  const system =
    `You translate factory standard-work instructions (automotive parts plant: welding, pressing, assembly, inspection) from Korean into ${LANG_NAMES[lang] || lang}. ` +
    `Audience: shop-floor workers. Use short, plain, imperative sentences that a worker with basic literacy understands. ` +
    `Keep technical tokens unchanged: equipment codes (e.g. L01-OP30, E-21), numbers, units (mm, ℃, s), "OK"/"NOK", "GO"/"NO-GO", part names in Latin letters. ` +
    `Preserve line breaks (\\n) and numbering inside a string. ` +
    (glossary ? `Glossary (Korean=target term): ${glossary}. ` : "") +
    `Return ONLY a JSON object with exactly the same keys as the input, each value being the translation. No commentary.`;

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json" },
    body: JSON.stringify({
      model, max_tokens: 8000, system,
      messages: [{ role: "user", content: JSON.stringify(numbered) }],
    }),
  });
  if (!res.ok) throw new Error(`Anthropic API ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const data = await res.json();
  let text: string = data.content?.map((c: any) => c.text || "").join("") || "";
  text = text.trim().replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/, "");
  const start = text.indexOf("{"), end = text.lastIndexOf("}");
  const parsed = JSON.parse(text.slice(start, end + 1));
  return texts.map((_, i) => String(parsed[String(i + 1)] ?? ""));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const auth = req.headers.get("Authorization") || "";
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: auth } },
    });
    const { draft_id, langs, mode, items } = await req.json();
    const targets: string[] = (langs && langs.length ? langs : Object.keys(LANG_NAMES)).filter((l: string) => LANG_NAMES[l]);

    // ---- 모드 2: 앱 화면 문구 번역 (admin) → app_texts 에 저장 ----
    if (mode === "texts") {
      const list: { key: string; text: string }[] = (items || []).filter((i: any) => i?.key && i?.text);
      if (!list.length) return json({ ok: false, error: "no_items" }, 400);
      const texts = list.map((i) => i.text);
      const done: string[] = [], failed: Record<string, string> = {};
      for (const lang of targets) {
        try {
          const out = await translateBatch(texts, lang);
          const rows = list.map((it, i) => ({ key: it.key, lang, text: out[i], updated_at: new Date().toISOString() }));
          const { error } = await sb.from("app_texts").upsert(rows);   // RLS: admin 만 성공
          if (error) throw new Error(error.message);
          done.push(lang);
        } catch (e) { failed[lang] = String(e?.message || e); }
      }
      return json({ ok: true, done, failed });
    }

    // RLS: 담당 라인 편집자만 초안을 읽을 수 있음
    const { data: row, error } = await sb.from("standards").select("id,status,content,translations").eq("id", draft_id).single();
    if (error || !row) return json({ ok: false, error: "draft_not_found_or_forbidden" }, 403);
    if (row.status !== "draft") return json({ ok: false, error: "not_a_draft" }, 400);

    const items = collect(row.content);
    if (!items.length) return json({ ok: false, error: "nothing_to_translate" }, 400);
    const texts = items.map((i) => i.text);
    const srcHash = await hash(texts.join("\u0001"));

    const translations: Record<string, unknown> = { ...(row.translations || {}) };
    const done: string[] = [], failed: Record<string, string> = {};
    // 언어별 순차 처리 (한 번에 40개 문자열씩 나눠 보냄)
    for (const lang of targets) {
      try {
        const out: string[] = [];
        for (let i = 0; i < texts.length; i += 40) out.push(...(await translateBatch(texts.slice(i, i + 40), lang)));
        const tr: Record<string, unknown> = {};
        items.forEach((it, i) => setPath(tr, it.path, out[i]));
        translations[lang] = tr; done.push(lang);
      } catch (e) { failed[lang] = String(e?.message || e); }
    }
    translations.__hash = srcHash;
    translations.__at = new Date().toISOString();

    const { error: upErr } = await sb.from("standards").update({ translations }).eq("id", draft_id);
    if (upErr) return json({ ok: false, error: upErr.message }, 500);
    return json({ ok: true, done, failed, strings: texts.length });
  } catch (e) {
    return json({ ok: false, error: String(e?.message || e) }, 500);
  }
});
