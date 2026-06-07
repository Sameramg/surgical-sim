"""
Tests for the markdown -> DecisionPoint compiler.

The headline test is the round-trip: `content.md` must compile to a bank that is
structurally identical to the hand-written `content.py` BANK — proving the
authoring path is a faithful, lossless replacement for writing dataclasses.
The rest pin down the parser's contract and its error reporting (authors need
loud, line-numbered failures, not silent broken content).
"""

from __future__ import annotations

import os

import pytest

from content_authoring import compile_markdown, load_markdown, emit_python, ContentError
from content import BANK


HERE = os.path.dirname(__file__)


def _key(points):
    """A comparable, order-stable view of a bank for equality assertions."""
    return [
        (
            p.id, p.skill, p.difficulty, p.stem,
            tuple((o.text, o.cost, o.feedback, o.catastrophic) for o in p.options),
        )
        for p in points
    ]


# ----------------------------- the round-trip -----------------------------


def test_content_md_matches_handwritten_bank():
    compiled = load_markdown(os.path.join(HERE, "content.md"))
    assert _key(compiled) == _key(BANK)


def test_emit_python_round_trips():
    """Compile md -> emit dataclass source -> exec it -> identical bank."""
    compiled = load_markdown(os.path.join(HERE, "content.md"))
    src = emit_python(compiled)
    ns: dict = {}
    exec(src, ns)
    assert _key(ns["BANK"]) == _key(compiled)


# ----------------------------- basics -----------------------------

SAMPLE = """\
# hemostasis

## hem-x @1400
Bleeding. What now?

- [0.0] Control it
  > Because control first.
- [!] Clamp blind
  > CATASTROPHIC.
"""


def test_basic_compile():
    pts = compile_markdown(SAMPLE)
    assert len(pts) == 1
    p = pts[0]
    assert p.id == "hem-x"
    assert p.skill == "hemostasis"
    assert p.difficulty == 1400
    assert p.stem == "Bleeding. What now?"
    assert [o.text for o in p.options] == ["Control it", "Clamp blind"]


def test_bang_tag_is_catastrophic_with_default_cost():
    p = compile_markdown(SAMPLE)[0]
    clamp = p.options[1]
    assert clamp.catastrophic is True
    assert clamp.cost == 1.0


def test_bang_tag_with_explicit_cost():
    md = SAMPLE.replace("- [!] Clamp blind", "- [!0.85] Clamp blind")
    p = compile_markdown(md)[0]
    assert p.options[1].catastrophic is True
    assert p.options[1].cost == 0.85


def test_default_difficulty_when_omitted():
    md = SAMPLE.replace("## hem-x @1400", "## hem-x")
    p = compile_markdown(md)[0]
    assert p.difficulty == 1200.0  # engine.START


def test_skill_carries_across_multiple_points():
    md = SAMPLE + """\

## hem-y @1500
More bleeding. Now?

- [0.0] Pressure
  > Buys time.
- [0.5] Wait
  > Slower.
"""
    pts = compile_markdown(md)
    assert [p.skill for p in pts] == ["hemostasis", "hemostasis"]


def test_multi_paragraph_stem():
    md = """\
# s
## p @1200
First paragraph of the stem
spanning two source lines.

Second paragraph.

- [0.0] a
  > fa
- [1.0] b
  > fb
"""
    p = compile_markdown(md)[0]
    assert p.stem == "First paragraph of the stem spanning two source lines.\n\nSecond paragraph."


def test_multiline_feedback_joins():
    p = compile_markdown(SAMPLE)[0]
    assert p.options[0].feedback == "Because control first."


def test_optimal_is_lowest_cost():
    p = compile_markdown(SAMPLE)[0]
    assert p.ideal.text == "Control it"


def test_comments_are_ignored():
    md = """\
# s
<!-- author note: revisit difficulty -->
## p @1200
Stem here.

- [0.0] a
  > fa
- [1.0] b
  > fb
"""
    p = compile_markdown(md)[0]
    assert p.stem == "Stem here."
    assert len(p.options) == 2


# ----------------------------- error reporting -----------------------------


def _err(md):
    with pytest.raises(ContentError) as ei:
        compile_markdown(md)
    return ei.value


def test_error_point_before_skill():
    e = _err("## p @1200\nstem\n\n- [0.0] a\n  > f\n- [1.0] b\n  > f\n")
    assert "before any `# skill`" in str(e)
    assert e.line_no == 1


def test_error_option_without_feedback():
    md = "# s\n## p @1200\nstem\n\n- [0.0] a\n- [1.0] b\n  > f\n"
    e = _err(md)
    assert "no `> feedback`" in str(e)


def test_error_too_few_options():
    md = "# s\n## p @1200\nstem\n\n- [0.0] only one\n  > f\n"
    e = _err(md)
    assert "at least 2" in str(e)


def test_error_all_same_cost():
    md = "# s\n## p @1200\nstem\n\n- [0.5] a\n  > f\n- [0.5] b\n  > f\n"
    e = _err(md)
    assert "no better/worse line" in str(e)


def test_error_missing_stem():
    md = "# s\n## p @1200\n- [0.0] a\n  > f\n- [1.0] b\n  > f\n"
    e = _err(md)
    assert "no stem" in str(e)


def test_error_bad_cost_tag():
    md = "# s\n## p @1200\nstem\n\n- [oops] a\n  > f\n- [1.0] b\n  > f\n"
    e = _err(md)
    assert "not a number or `!`" in str(e)


def test_error_duplicate_id():
    md = (SAMPLE + "\n## hem-x @1500\nstem\n\n- [0.0] a\n  > f\n- [1.0] b\n  > f\n")
    e = _err(md)
    assert "duplicate point id" in str(e)


def test_error_feedback_without_option():
    md = "# s\n## p @1200\nstem\n  > orphan feedback\n"
    e = _err(md)
    assert "no option above it" in str(e)


def test_error_prose_after_option():
    md = "# s\n## p @1200\nstem\n\n- [0.0] a\n  > f\nstray prose\n- [1.0] b\n  > f\n"
    e = _err(md)
    assert "prose after an option" in str(e)


def test_error_empty_document():
    e = _err("\n\n  \n")
    assert "no decision points" in str(e)
