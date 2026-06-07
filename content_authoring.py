"""
content_authoring — write decision points in plain Markdown, compile to
DecisionPoints.

The bottleneck for this product is *content volume*. Hand-writing dataclasses is
slow and noisy; a surgeon-author should be able to dump 200 decision points into
a `.md` file and have them become a content bank.

------------------------------------------------------------------------------
THE FORMAT
------------------------------------------------------------------------------

    # hemostasis                         <- H1 sets the skill bucket for the
                                            points that follow

    ## hem-001  @1200                    <- H2 starts a point: `id` then an
    Steady ooze from a 2mm vessel in        optional `@difficulty` (default 1200)
    subcutaneous fat. Field is dry.      <- prose before the first option is the
    What's your first move?                 stem (blank-line-separated paragraphs)

    - [0.0] Precise bipolar, then confirm dry
      > Targeted, minimal collateral spread. The default for small vessels.
    - [0.6] Blind monopolar buzz at the area
      > Works but sloppy — collateral injury and char that obscures the field.
    - [!] Blindly clamp into the pool of blood
      > CATASTROPHIC. Clamping what you can't see destroys named structures.

Option syntax:  `- [<tag>] <text>`  followed by one or more `> feedback` lines.

    [0.0]      cost 0.0  (lowest cost in a point = the optimal line)
    [0.6]      cost 0.6
    [!]        catastrophic; cost defaults to 1.0
    [!0.95]    catastrophic with an explicit cost

Costs are ordinal *within a point* (see content.py): the engine only cares about
their relative ordering and spacing, so use whatever scale reads naturally.

------------------------------------------------------------------------------
USAGE
------------------------------------------------------------------------------

    from content_authoring import compile_markdown, load_markdown
    bank = load_markdown("content.md")          # -> list[DecisionPoint]

CLI:
    python content_authoring.py content.md            # validate + summarize
    python content_authoring.py content.md --emit-py  # print dataclass source
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass

from engine import DecisionPoint, Option, START


# ----------------------------- errors -----------------------------


class ContentError(ValueError):
    """A human-fixable problem in the markdown, reported with a line number."""

    def __init__(self, line_no: int, msg: str, line: str = ""):
        self.line_no = line_no
        snippet = f"\n    {line_no:>4} | {line}" if line else ""
        super().__init__(f"line {line_no}: {msg}{snippet}")


# ----------------------------- patterns -----------------------------

_H1 = re.compile(r"^#\s+(?P<skill>.+?)\s*$")
_H2 = re.compile(r"^##\s+(?P<id>\S+)\s*(?:@(?P<difficulty>-?\d+(?:\.\d+)?))?\s*$")
_OPT = re.compile(r"^[-*]\s+\[(?P<tag>[^\]]*)\]\s*(?P<text>.+?)\s*$")
_FEEDBACK = re.compile(r"^\s*>\s?(?P<text>.*?)\s*$")
_COMMENT = re.compile(r"^\s*<!--.*-->\s*$")


# ----------------------------- builder scaffolding -----------------------------


@dataclass
class _OptDraft:
    cost: float
    text: str
    catastrophic: bool
    feedback_lines: list[str]
    line_no: int

    def finish(self) -> Option:
        # feedback is prose wrapped across `> ` lines; join and collapse to a
        # single normalized string (blank `>` lines separate paragraphs)
        paras = "\n".join(self.feedback_lines).split("\n\n")
        fb = "\n\n".join(" ".join(p.split()) for p in paras if p.strip()).strip()
        if not fb:
            raise ContentError(
                self.line_no,
                f"option {self.text!r} has no `> feedback` — feedback is the "
                "teaching, every option needs it",
            )
        return Option(text=self.text, cost=self.cost, feedback=fb,
                      catastrophic=self.catastrophic)


@dataclass
class _PointDraft:
    id: str
    skill: str
    difficulty: float
    line_no: int
    stem_lines: list[str]
    options: list[_OptDraft]

    def finish(self) -> DecisionPoint:
        stem = "\n\n".join(
            " ".join(p.split())
            for p in "\n".join(self.stem_lines).split("\n\n")
            if p.strip()
        ).strip()
        if not stem:
            raise ContentError(self.line_no, f"point {self.id!r} has no stem")
        if len(self.options) < 2:
            raise ContentError(
                self.line_no,
                f"point {self.id!r} has {len(self.options)} option(s); a "
                "decision needs at least 2",
            )
        opts = [o.finish() for o in self.options]
        if len({o.cost for o in opts}) == 1:
            raise ContentError(
                self.line_no,
                f"point {self.id!r}: all options share cost {opts[0].cost} — "
                "there is no better/worse line to grade",
            )
        return DecisionPoint(id=self.id, skill=self.skill,
                             difficulty=self.difficulty, stem=stem, options=opts)


def _parse_tag(tag: str, line_no: int, line: str) -> tuple[float, bool]:
    """`[0.6]` -> (0.6, False);  `[!]` -> (1.0, True);  `[!0.9]` -> (0.9, True)."""
    tag = tag.strip()
    catastrophic = False
    if tag.startswith("!"):
        catastrophic = True
        tag = tag[1:].strip()
        if not tag:
            return 1.0, True            # bare `[!]` -> worst-case cost
    if not tag:
        raise ContentError(line_no, "empty option tag `[]` — need a cost or `!`",
                           line)
    try:
        return float(tag), catastrophic
    except ValueError:
        raise ContentError(
            line_no, f"option tag {tag!r} is not a number or `!`", line)


# ----------------------------- the compiler -----------------------------


def compile_markdown(text: str) -> list[DecisionPoint]:
    """Compile markdown content into a list of DecisionPoints.

    Raises ContentError (with a line number) on anything malformed, so authoring
    mistakes surface loudly instead of silently producing a broken bank.
    """
    skill: str | None = None
    point: _PointDraft | None = None
    option: _OptDraft | None = None
    points: list[_PointDraft] = []
    seen_ids: dict[str, int] = {}

    def flush_point():
        nonlocal point, option
        if point is not None:
            points.append(point)
        point, option = None, None

    for i, raw in enumerate(text.splitlines(), start=1):
        line = raw.rstrip()

        if not line.strip() or _COMMENT.match(line):
            # a blank line ends a feedback block and separates stem paragraphs
            if option is not None and option.feedback_lines:
                option = None
            elif point is not None and option is None and point.stem_lines:
                point.stem_lines.append("")   # paragraph break in the stem
            continue

        m = _H1.match(line)
        if m:
            flush_point()
            skill = m.group("skill").strip()
            continue

        m = _H2.match(line)
        if m:
            flush_point()
            if skill is None:
                raise ContentError(
                    i, "decision point before any `# skill` heading", line)
            pid = m.group("id")
            if pid in seen_ids:
                raise ContentError(
                    i, f"duplicate point id {pid!r} (first seen on line "
                    f"{seen_ids[pid]})", line)
            seen_ids[pid] = i
            diff = m.group("difficulty")
            point = _PointDraft(
                id=pid, skill=skill,
                difficulty=float(diff) if diff is not None else float(START),
                line_no=i, stem_lines=[], options=[])
            continue

        m = _OPT.match(line)
        if m:
            if point is None:
                raise ContentError(i, "option outside of any decision point",
                                   line)
            cost, cat = _parse_tag(m.group("tag"), i, line)
            option = _OptDraft(cost=cost, text=m.group("text").strip(),
                               catastrophic=cat, feedback_lines=[], line_no=i)
            point.options.append(option)
            continue

        m = _FEEDBACK.match(line)
        if m:
            if option is None:
                raise ContentError(
                    i, "`> feedback` with no option above it", line)
            option.feedback_lines.append(m.group("text"))
            continue

        # plain prose: stem text (only valid before the first option of a point)
        if point is None:
            raise ContentError(
                i, "text outside of a decision point (missing a `## id` "
                "header?)", line)
        if option is not None:
            raise ContentError(
                i, "prose after an option — did you mean `> feedback`? "
                "(stem text must come before the options)", line)
        point.stem_lines.append(line.strip())

    flush_point()
    if not points:
        raise ContentError(0, "no decision points found")
    return [p.finish() for p in points]


def load_markdown(path: str) -> list[DecisionPoint]:
    """Read and compile a markdown content file into DecisionPoints."""
    with open(path, encoding="utf-8") as f:
        return compile_markdown(f.read())


# ----------------------------- emit dataclass source -----------------------------


def emit_python(points: list[DecisionPoint]) -> str:
    """Render compiled points back as engine dataclass source — handy for
    freezing markdown into a static `content.py` if you ever want to."""
    def q(s: str) -> str:
        return repr(s)

    out = ["from engine import DecisionPoint, Option", "", "BANK = ["]
    for p in points:
        out.append(f"    DecisionPoint(")
        out.append(f"        id={q(p.id)}, skill={q(p.skill)}, "
                   f"difficulty={p.difficulty:g},")
        out.append(f"        stem={q(p.stem)},")
        out.append(f"        options=[")
        for o in p.options:
            cat = ", True" if o.catastrophic else ""
            out.append(f"            Option({q(o.text)}, {o.cost:g}, "
                       f"{q(o.feedback)}{cat}),")
        out.append(f"        ]),")
    out.append("]")
    return "\n".join(out) + "\n"


# ----------------------------- CLI -----------------------------


def _main(argv: list[str]) -> int:
    args = [a for a in argv if not a.startswith("--")]
    flags = {a for a in argv if a.startswith("--")}
    if not args:
        print(__doc__)
        return 0
    path = args[0]
    try:
        points = load_markdown(path)
    except ContentError as e:
        print(f"content error in {path}:\n  {e}", file=sys.stderr)
        return 1

    if "--emit-py" in flags:
        print(emit_python(points))
        return 0

    # default: validate + summarize
    by_skill: dict[str, int] = {}
    for p in points:
        by_skill[p.skill] = by_skill.get(p.skill, 0) + 1
    print(f"OK — compiled {len(points)} decision point(s) from {path}")
    for skill, n in sorted(by_skill.items()):
        print(f"  {skill:16s} {n} point(s)")
    cats = sum(1 for p in points for o in p.options if o.catastrophic)
    print(f"  {'(catastrophic lines)':16s} {cats}")
    return 0


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
