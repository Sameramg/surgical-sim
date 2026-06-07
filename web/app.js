// SCALPEL frontend — buildless React (ESM via esm.sh + htm, no npm step).
// The engine grades; the examiner (Anthropic) runs the live Socratic viva.

import React, { useState, useEffect, useRef, useCallback } from "https://esm.sh/react@18.3.1";
import { createRoot } from "https://esm.sh/react-dom@18.3.1/client";
import htm from "https://esm.sh/htm@3.1.1";

const html = htm.bind(React.createElement);
const api = (p, opts) => fetch(p, opts).then((r) => r.json());

function ratingBar(r) {
  const blocks = Math.max(0, Math.round((r - 800) / 40));
  return "█".repeat(Math.min(blocks, 40));
}

function App() {
  const [state, setState] = useState(null);
  const [skill, setSkill] = useState(null);
  const [point, setPoint] = useState(null);
  const [result, setResult] = useState(null);   // grade response
  const [picked, setPicked] = useState(null);    // chosen original index
  const [loading, setLoading] = useState(false);

  const loadState = useCallback(async () => setState(await api("/api/state")), []);

  const nextPoint = useCallback(async (sk = skill) => {
    setResult(null); setPicked(null);
    const q = sk ? `?skill=${encodeURIComponent(sk)}` : "";
    setPoint(await api(`/api/next${q}`));
  }, [skill]);

  useEffect(() => { loadState(); }, [loadState]);
  useEffect(() => { if (state) nextPoint(); /* first point */ }, [state ? true : false]);

  async function choose(i) {
    if (result) return;
    setPicked(i); setLoading(true);
    const r = await api("/api/grade", {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ point_id: point.id, option_index: i }),
    });
    setResult(r); setLoading(false); loadState();
  }

  function pickSkill(sk) {
    const next = sk === skill ? null : sk;
    setSkill(next); nextPoint(next);
  }

  if (!state) return html`<div class="wrap"><p class="note">loading…</p></div>`;

  return html`
    <div class="wrap">
      <div class="bar">
        <div>
          <h1>SCALPEL</h1>
          <div class="sub">surgical decision trainer · the engine grades, the examiner grills</div>
        </div>
        <div class="note">${state.attempts} attempts</div>
      </div>

      <div class="skills">
        ${state.skills.map((s) => html`
          <span class=${"chip" + (s === skill ? " on" : "")} onClick=${() => pickSkill(s)}>
            ${s} · ${state.ratings[s] ?? 1200}
          </span>`)}
        <span class=${"chip" + (skill === null ? " on" : "")} onClick=${() => pickSkill(skill)}>
          all skills
        </span>
      </div>

      ${point && html`<${Card} point=${point} picked=${picked} result=${result}
                              loading=${loading} onChoose=${choose} />`}

      ${result && html`
        <div class="row">
          <button class="act" onClick=${() => nextPoint()}>next point →</button>
          <span class=${"note " + (result.delta >= 0 ? "delta-pos" : "delta-neg")}>
            rating ${result.rating_before} → ${result.rating_after}
            (${result.delta >= 0 ? "+" : ""}${result.delta})
          </span>
        </div>`}

      ${result && !result.optimal && html`
        <${Viva} point=${point} optionIndex=${picked} enabled=${state.examiner_enabled} />`}
    </div>`;
}

function Card({ point, picked, result, loading, onChoose }) {
  const klass = (o) => {
    if (!result) return "opt" + (picked === o.i ? " picked" : "");
    if (result.ideal && o.text === result.ideal.text) return "opt best";
    if (picked === o.i) return "opt picked " + (result.catastrophic || result.score < 0.5 ? "bad" : "");
    return "opt";
  };
  return html`
    <div class="card">
      <div class="meta">
        <span>${point.skill}</span>
        <span class="rating">you ${point.rating} ${ratingBar(point.rating)} · point ${point.difficulty}</span>
      </div>
      <div class="stem">${point.stem}</div>
      ${point.options.map((o) => html`
        <button class=${klass(o)} disabled=${!!result || loading} onClick=${() => onChoose(o.i)}>
          ${o.text}
        </button>`)}

      ${result && html`
        <div style="margin-top:14px">
          <div class=${"verdict " + (result.optimal ? "v-optimal" : result.catastrophic || result.score < 0.5 ? "v-bad" : "v-mid")}>
            ${result.optimal ? "OPTIMAL" : result.catastrophic ? "CATASTROPHIC" : `score ${Math.round(result.score * 100)}%`}
          </div>
          <p class="fb">${result.chosen.feedback}</p>
          ${!result.optimal && html`
            <p class="fb"><strong style="color:var(--good)">best line:</strong> ${result.ideal.text}<br/>${result.ideal.feedback}</p>`}
        </div>`}
    </div>`;
}

// The live Socratic viva — streams examiner turns from the Anthropic-backed endpoint.
function Viva({ point, optionIndex, enabled }) {
  const [messages, setMessages] = useState([]); // {role:'examiner'|'you', content}
  const [streaming, setStreaming] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [input, setInput] = useState("");
  const started = useRef(false);

  const ask = useCallback(async (history) => {
    setBusy(true); setError(null); setStreaming("");
    let acc = "";
    try {
      const resp = await fetch("/api/socratic", {
        method: "POST", headers: { "content-type": "application/json" },
        body: JSON.stringify({ point_id: point.id, option_index: optionIndex, messages: history }),
      });
      if (!resp.ok) { setError((await resp.json()).error || "examiner error"); setBusy(false); return; }
      const reader = resp.body.getReader();
      const dec = new TextDecoder();
      let buf = "";
      for (;;) {
        const { value, done } = await reader.read();
        if (done) break;
        buf += dec.decode(value, { stream: true });
        const frames = buf.split("\n\n"); buf = frames.pop();
        for (const f of frames) {
          const ev = (f.match(/event: (.*)/) || [])[1];
          const dataLine = (f.match(/data: (.*)/) || [])[1];
          if (!dataLine) continue;
          const data = JSON.parse(dataLine);
          if (ev === "delta") { acc += data.text; setStreaming(acc); }
          else if (ev === "error") setError(data.message);
        }
      }
    } catch (e) {
      setError(String(e));
    }
    if (acc) setMessages((m) => [...m, { role: "examiner", content: acc }]);
    setStreaming(""); setBusy(false);
  }, [point, optionIndex]);

  // Auto-open the viva once, when this wrong-line result first appears.
  useEffect(() => {
    if (enabled && !started.current) { started.current = true; ask([]); }
  }, [enabled, ask]);

  function send() {
    const text = input.trim();
    if (!text || busy) return;
    const history = [...messages, { role: "you", content: text }];
    setMessages(history); setInput("");
    ask(history);
  }

  if (!enabled) return html`
    <div class="viva">
      <div class="viva-h">examiner</div>
      <p class="note">Live Socratic viva is offline. Start the server with
        <code>ANTHROPIC_API_KEY</code> set and the examiner will grill you on
        <em>why</em> this line was wrong.</p>
    </div>`;

  return html`
    <div class="viva">
      <div class="viva-h">examiner — defend your reasoning</div>
      ${messages.map((m) => html`
        <div class=${"msg " + (m.role === "examiner" ? "m-examiner" : "m-you")}>
          <div class="m-role">${m.role === "examiner" ? "examiner" : "you"}</div>${m.content}
        </div>`)}
      ${streaming && html`<div class="msg m-examiner"><div class="m-role">examiner</div><span class="cursor">${streaming}</span></div>`}
      ${busy && !streaming && html`<p class="note cursor"></p>`}
      ${error && html`<p class="err">${error}</p>`}
      <div class="ask">
        <textarea placeholder="answer the examiner…" value=${input}
          onInput=${(e) => setInput(e.target.value)}
          onKeyDown=${(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(); } }} />
        <button class="ghost" onClick=${send} disabled=${busy}>reply</button>
      </div>
    </div>`;
}

createRoot(document.getElementById("root")).render(html`<${App} />`);
