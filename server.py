"""
SCALPEL web server — the deterministic engine + a live Socratic examiner.

Division of labour (this is the whole point):
  • The ELO ENGINE grades. Score, rating delta, catastrophic-zeroing, item
    calibration — all deterministic, all in engine.py. The number you can trust.
  • The LLM EXAMINES. It never decides your score. It plays the examiner in the
    viva: given the ground-truth costs/feedback for the point you just played, it
    grills you Socratically on *why* your line was wrong (or why the better line
    is better) — the IM-theoretical layer a model can actually hold.

So the API key is optional: without it the trainer is fully playable (the canned
engine feedback shows). With it, the wrong-line feedback becomes a live viva.

Run:
    pip install -r requirements.txt
    export ANTHROPIC_API_KEY=sk-ant-...        # optional — enables the examiner
    python server.py                            # http://127.0.0.1:5000
"""

from __future__ import annotations

import json
import os
import random

from flask import Flask, Response, jsonify, request, send_from_directory

from engine import Profile, select_point, Option, DecisionPoint

HERE = os.path.dirname(os.path.abspath(__file__))
PROFILE_PATH = os.path.join(HERE, "profile.json")
STATIC_DIR = os.path.join(HERE, "web")
MODEL = "claude-opus-4-8"


# ----------------------------- content loading -----------------------------

def load_bank() -> list[DecisionPoint]:
    """Prefer the markdown bank (content.md); fall back to the dataclass bank."""
    md = os.path.join(HERE, "content.md")
    if os.path.exists(md):
        try:
            from content_authoring import load_markdown
            return load_markdown(md)
        except Exception as e:  # malformed markdown shouldn't take the app down
            print(f"[scalpel] content.md failed to compile ({e}); using content.py")
    from content import BANK
    return BANK


BANK = load_bank()
BY_ID = {p.id: p for p in BANK}
profile = Profile(PROFILE_PATH)

app = Flask(__name__, static_folder=None)


# ----------------------------- serialization -----------------------------

def public_point(dp: DecisionPoint) -> dict:
    """Serve a point WITHOUT leaking the answer: options are shuffled and carry
    only their stable original index + text — no cost, catastrophic flag, or
    feedback crosses the wire until after the player has committed."""
    idx = list(range(len(dp.options)))
    random.shuffle(idx)
    return {
        "id": dp.id,
        "skill": dp.skill,
        "difficulty": round(dp.difficulty),
        "stem": dp.stem,
        "rating": round(profile.rating(dp.skill)),
        "options": [{"i": i, "text": dp.options[i].text} for i in idx],
    }


# ----------------------------- API -----------------------------

@app.get("/api/state")
def state():
    return jsonify({
        "ratings": {k: round(v) for k, v in profile.ratings.items()},
        "skills": sorted({p.skill for p in BANK}),
        "attempts": len(profile.history),
        "examiner_enabled": bool(os.environ.get("ANTHROPIC_API_KEY")),
    })


@app.get("/api/next")
def next_point():
    skill = request.args.get("skill") or None
    pool = [p for p in BANK if skill is None or p.skill == skill]
    if not pool:
        return jsonify({"error": f"no points for skill {skill!r}"}), 404
    dp = select_point(BANK, profile, skill=skill)
    return jsonify(public_point(dp))


@app.post("/api/grade")
def grade():
    body = request.get_json(force=True)
    dp = BY_ID.get(body.get("point_id"))
    if dp is None:
        return jsonify({"error": "unknown point_id"}), 400
    try:
        chosen = dp.options[int(body["option_index"])]
    except (KeyError, ValueError, IndexError):
        return jsonify({"error": "bad option_index"}), 400

    a = profile.grade(dp, chosen)
    profile.save()
    ideal = dp.ideal
    return jsonify({
        "score": a.score,
        "catastrophic": chosen.catastrophic,
        "optimal": a.score == 1.0,
        "chosen": {"text": chosen.text, "feedback": chosen.feedback},
        "ideal": {"text": ideal.text, "feedback": ideal.feedback},
        "rating_before": round(a.rating_before),
        "rating_after": round(a.rating_after),
        "delta": round(a.rating_after - a.rating_before),
        "difficulty": round(dp.difficulty),
    })


# ----------------------------- the Socratic examiner -----------------------------

EXAMINER_SYSTEM = """\
You are a surgical examiner conducting a viva (oral exam). The trainee has just \
played a decision point in a skills trainer and you are grilling them on their \
reasoning — Socratically.

Your job is to make them defend or revise their thinking, not to lecture. Rules:
- Ask one sharp question at a time. Probe the WHY behind their choice.
- Never just hand them the answer. Lead them to see it. If they're stuck after a \
couple of exchanges, give the smallest hint that unblocks them, then ask again.
- Stay grounded in the ground-truth analysis you're given below (the engine's \
costs and the per-option teaching notes are authoritative — do not contradict \
them or invent surgical facts beyond them).
- A catastrophic line (e.g. clamping/cauterising blind, cutting what you can't \
uncut) is non-negotiable — make them articulate exactly which structure they'd \
destroy and why control-before-vision is the rule.
- Be terse, direct, and a little demanding — like a real examiner. 2-4 sentences \
per turn. No preamble, no "great question", no emoji.
- If they've clearly got it, say so plainly and stop."""


def examiner_context(dp: DecisionPoint, chosen: Option) -> str:
    lines = [
        f"SCENARIO ({dp.skill}, difficulty {round(dp.difficulty)}):",
        dp.stem,
        "",
        "OPTIONS (ground truth — authoritative, the trainee has NOT seen costs):",
    ]
    ideal = dp.ideal
    for o in dp.options:
        tags = []
        if o is ideal:
            tags.append("BEST LINE")
        if o.catastrophic:
            tags.append("CATASTROPHIC")
        tag = f" [{', '.join(tags)}]" if tags else ""
        lines.append(f"  • (cost {o.cost:g}){tag} {o.text}")
        lines.append(f"      note: {o.feedback}")
    lines += [
        "",
        f"THE TRAINEE CHOSE: {chosen.text!r}",
        "Open the viva by pressing them on why they made that choice.",
    ]
    return "\n".join(lines)


@app.post("/api/socratic")
def socratic():
    """Stream a live Socratic viva turn (SSE). The engine has already scored the
    attempt; this only generates the examiner's questioning."""
    body = request.get_json(force=True)
    dp = BY_ID.get(body.get("point_id"))
    if dp is None:
        return jsonify({"error": "unknown point_id"}), 400
    try:
        chosen = dp.options[int(body["option_index"])]
    except (KeyError, ValueError, IndexError):
        return jsonify({"error": "bad option_index"}), 400

    if not os.environ.get("ANTHROPIC_API_KEY"):
        return jsonify({"error": "examiner offline: set ANTHROPIC_API_KEY"}), 503

    # Conversation so far (trainee turns + prior examiner turns). The very first
    # call has no history → seed it with the context so the examiner opens.
    history = body.get("messages") or []
    messages = [{"role": "user", "content": examiner_context(dp, chosen)}]
    for m in history:
        role = "assistant" if m.get("role") == "examiner" else "user"
        text = (m.get("content") or "").strip()
        if text:
            messages.append({"role": role, "content": text})

    def sse(event: str, data: dict) -> str:
        return f"event: {event}\ndata: {json.dumps(data)}\n\n"

    def generate():
        import anthropic
        client = anthropic.Anthropic()
        try:
            # Streaming so the viva feels live; adaptive thinking lets the model
            # reason about the trainee's gap before it speaks (text omitted by
            # default — we only stream the spoken question).
            with client.messages.stream(
                model=MODEL,
                max_tokens=1024,
                system=EXAMINER_SYSTEM,
                thinking={"type": "adaptive"},
                output_config={"effort": "low"},
                messages=messages,
            ) as stream:
                for text in stream.text_stream:
                    yield sse("delta", {"text": text})
            yield sse("done", {})
        except anthropic.APIStatusError as e:
            yield sse("error", {"message": f"API error {e.status_code}: {e.message}"})
        except Exception as e:  # network, auth, etc. — surface, don't crash
            yield sse("error", {"message": str(e)})

    return Response(generate(), mimetype="text/event-stream",
                    headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})


# ----------------------------- static frontend -----------------------------

@app.get("/")
def index():
    return send_from_directory(STATIC_DIR, "index.html")


@app.get("/<path:path>")
def static_files(path):
    return send_from_directory(STATIC_DIR, path)


if __name__ == "__main__":
    print(f"[scalpel] {len(BANK)} decision points loaded "
          f"({len({p.skill for p in BANK})} skills)")
    print(f"[scalpel] examiner: "
          f"{'ONLINE' if os.environ.get('ANTHROPIC_API_KEY') else 'offline (no ANTHROPIC_API_KEY)'}")
    app.run(host="127.0.0.1", port=5000, debug=True, threaded=True)
