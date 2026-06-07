# SCALPEL — a surgical decision trainer

A player-vs-item Elo engine for surgical *decision points*. You don't pass/fail a
point — every option has a `cost` (deviation from the optimal line), and your
score is how close to optimal you played. Nail a hard point, gain big; fumble an
easy one, lose big. Just like a chess tactics trainer.

The engine is **content-agnostic** (`engine.py` knows nothing about surgery) and
**deterministic** (the rating is math you can trust). On top of it sits a live
**Socratic examiner** (Anthropic) that grills you on *why* a line was wrong —
the engine grades, the LLM examines.

```
engine.py              the Elo/IRT grading engine (generic)
content.py             hand-written content bank (dataclasses)
content.md             the same bank, authored in markdown
content_authoring.py   markdown → DecisionPoints compiler
play.py                the terminal trainer (no dependencies)
server.py + web/       the local React UI with the live Socratic examiner
test_engine.py         proves the rating math is monotonic-correct
test_content_authoring.py   proves the markdown compiler is lossless
```

## 1. The terminal trainer (zero dependencies)

```bash
python play.py
```

## 2. The test suite — proving the math

`test_engine.py` nails down the three properties a trustworthy rating must have:

- **Monotonic gain** — nailing a *harder* point gains more rating than an easy
  one; fumbling an *easy* point loses more than a hard one (across a whole
  difficulty spread, not just two points).
- **Catastrophic always zeroes** — a catastrophic option scores `0.0` no matter
  where its cost sits among the other options, and always moves the rating down.
- **Item difficulty converges** — an item played by a steady population drifts to
  the difficulty where expected score == achieved score, and the error shrinks
  monotonically (true convergence, from either side).

Plus the supporting invariants (score map, Elo expectancy, update symmetry) and
the adaptive item selection.

```bash
pip install pytest
pytest -q          # 50 passing
```

## 3. Authoring content in markdown

The bottleneck for this product is content volume — so write decision points in
plain markdown and compile them:

```markdown
# hemostasis

## hem-001 @1200
Steady ooze from a 2mm vessel. Field is dry. First move?

- [0.0] Precise bipolar to the vessel, then confirm dry
  > Targeted, minimal collateral spread. The default for small vessels.
- [0.6] Blind monopolar buzz at the area
  > Sloppy — collateral injury and char that obscures the field.
- [!] Blindly clamp into the pool of blood
  > CATASTROPHIC. Never clamp what you can't see.
```

`# skill` sets the skill bucket. `## id @difficulty` starts a point (difficulty
defaults to 1200). Option tags: `[0.6]` is a cost, `[!]` is catastrophic
(cost 1.0), `[!0.9]` is catastrophic with an explicit cost. The lowest-cost
option is the optimal line. Every option needs a `> feedback` line.

```bash
python content_authoring.py content.md             # validate + summarize (line-numbered errors)
python content_authoring.py content.md --emit-py   # freeze markdown back to dataclass source
```

`content.md` round-trips exactly to the hand-written `content.py` bank — see
`test_content_authoring.py`.

## 4. The local React UI with the live Socratic examiner

```bash
pip install -r requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...     # optional — enables the examiner
python server.py                         # → http://127.0.0.1:5000
```

- **Flask backend** (`server.py`) serves the bank, grades every attempt through
  the same deterministic `engine.py`, and never leaks which option is correct
  until you commit. The LLM never touches your score.
- **React frontend** (`web/`, buildless — React 18 via ESM, no `npm install`):
  pick the number, see the verdict and the better line.
- **The examiner** — on any non-optimal line, a viva opens: the model
  (`claude-opus-4-8`, streamed over SSE) plays an examiner grilling you
  Socratically on *why*, grounded in the engine's ground-truth costs and
  teaching notes. You reply, it presses harder. Without an API key the trainer
  is still fully playable — the examiner panel just shows how to enable it.
