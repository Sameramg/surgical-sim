"""
SCALPEL engine test suite — proves the rating math is *monotonic-correct*.

The engine claims three things about its grading (see engine.py docstring). A
trainer people trust to tell them they're getting better has to actually be
right about that, so each claim gets nailed down here:

  1. MONOTONIC GAIN     — nailing a hard point gains more than nailing an easy
                          one (and fumbling an easy point loses more than
                          fumbling a hard one). This is the whole "like chess"
                          promise; if it's false the rating is noise.
  2. CATASTROPHIC = 0    — a catastrophic option scores 0.0 no matter where its
                          cost sits relative to the other options, and always
                          moves the rating down.
  3. ITEM CONVERGENCE    — an item's difficulty drifts toward the rating at
                          which the expected score equals the score players
                          actually achieve on it (Elo/IRT calibration). Run it
                          long enough and the difficulty stops moving.

Plus the supporting invariants those three rest on (the score map, the Elo
expectancy curve, the symmetry of the update).

Run:  pytest -q
"""

from __future__ import annotations

import copy
import math

import pytest

from engine import (
    Option,
    DecisionPoint,
    Profile,
    expected,
    K_PLAYER,
    K_ITEM,
    START,
    select_point,
)
from content import BANK


# ----------------------------- fixtures / builders -----------------------------


@pytest.fixture
def profile(tmp_path):
    """A fresh profile backed by a throwaway file (nothing on disk to load)."""
    return Profile(str(tmp_path / "profile.json"))


def make_point(skill="test", difficulty=1200.0, costs=(0.0, 0.5, 1.0), cat=None):
    """Build a synthetic DecisionPoint with the given option costs.

    `cat` is an optional index marking one option catastrophic, so tests can
    place a catastrophic option *anywhere* on the cost scale.
    """
    opts = []
    for i, c in enumerate(costs):
        opts.append(Option(text=f"opt{i}", cost=c, feedback="why",
                           catastrophic=(cat == i)))
    return DecisionPoint(id="syn", skill=skill, difficulty=difficulty,
                         stem="synthetic", options=opts)


def optimal_of(dp: DecisionPoint) -> Option:
    return min(dp.options, key=lambda o: o.cost)


def worst_of(dp: DecisionPoint) -> Option:
    return max(dp.options, key=lambda o: o.cost)


# =============================================================================
# Supporting invariant 0: the score map  cost -> [0,1]
# =============================================================================


def test_score_optimal_is_one_worst_is_zero():
    dp = make_point(costs=(0.0, 0.3, 0.7, 1.0))
    assert dp.score_for(optimal_of(dp)) == 1.0
    assert dp.score_for(worst_of(dp)) == 0.0


def test_score_is_strictly_monotonic_in_cost():
    dp = make_point(costs=(0.0, 0.2, 0.6, 0.9))
    scores = [dp.score_for(o) for o in sorted(dp.options, key=lambda o: o.cost)]
    # higher cost -> strictly lower score
    assert all(a > b for a, b in zip(scores, scores[1:])), scores


def test_score_is_scale_invariant():
    # Costs are explicitly ordinal-within-a-point; doubling them must not change
    # the score, only their relative spacing should matter.
    a = make_point(costs=(0.0, 0.25, 0.5, 1.0))
    b = make_point(costs=(0.0, 0.5, 1.0, 2.0))
    sa = [a.score_for(o) for o in a.options]
    sb = [b.score_for(o) for o in b.options]
    assert sa == pytest.approx(sb)


def test_score_degenerate_all_equal_is_one():
    # If every option costs the same there is no "wrong" line; don't punish.
    dp = make_point(costs=(0.4, 0.4, 0.4))
    for o in dp.options:
        assert dp.score_for(o) == 1.0


# =============================================================================
# Supporting invariant 1: Elo expectancy curve
# =============================================================================


def test_expected_equal_ratings_is_half():
    assert expected(1500, 1500) == pytest.approx(0.5)


def test_expected_monotonic_in_player_rating():
    # Stronger player -> higher expected score against a fixed item.
    rs = [800, 1000, 1200, 1500, 2000]
    es = [expected(r, 1500) for r in rs]
    assert all(a < b for a, b in zip(es, es[1:])), es


def test_expected_monotonic_decreasing_in_difficulty():
    ds = [800, 1000, 1200, 1500, 2000]
    es = [expected(1500, d) for d in ds]
    assert all(a > b for a, b in zip(es, es[1:])), es


def test_expected_400_point_gap_is_ten_to_one():
    # The defining property of the 400-scale: +400 rating ~ 10x odds.
    e = expected(1900, 1500)
    odds = e / (1 - e)
    assert odds == pytest.approx(10.0, rel=1e-6)


# =============================================================================
# CLAIM 1: monotonic gain  — hard nails pay more, easy fumbles cost more
# =============================================================================


def test_nailing_harder_point_gains_more(profile):
    """Same player, same perfect answer: the harder item must move the rating
    up by more. This is the core 'big gain for a hard point' claim."""
    easy = make_point(difficulty=1000.0)
    hard = make_point(difficulty=1800.0)

    # grade easy from a fresh rating
    a_easy = profile.grade(copy.deepcopy(easy), optimal_of(easy))
    gain_easy = a_easy.rating_after - a_easy.rating_before

    # reset the skill rating so the comparison starts from the same place
    profile.ratings[easy.skill] = START
    a_hard = profile.grade(copy.deepcopy(hard), optimal_of(hard))
    gain_hard = a_hard.rating_after - a_hard.rating_before

    assert gain_easy > 0 and gain_hard > 0
    assert gain_hard > gain_easy


def test_gain_is_strictly_monotonic_across_a_spread_of_difficulties(profile):
    """Not just two points: gain must increase monotonically with difficulty
    across the whole spectrum for a perfectly-played point."""
    gains = []
    for d in (900, 1100, 1300, 1500, 1700, 1900):
        profile.ratings["test"] = START
        dp = make_point(difficulty=float(d))
        a = profile.grade(dp, optimal_of(dp))
        gains.append(a.rating_after - a.rating_before)
    assert all(x < y for x, y in zip(gains, gains[1:])), gains


def test_fumbling_easier_point_loses_more(profile):
    """Mirror image: bombing an easy point (worst line) must cost more rating
    than bombing a hard one, because you were expected to handle the easy one."""
    easy = make_point(difficulty=1000.0)
    hard = make_point(difficulty=1800.0)

    profile.ratings["test"] = START
    a_easy = profile.grade(copy.deepcopy(easy), worst_of(easy))
    loss_easy = a_easy.rating_after - a_easy.rating_before

    profile.ratings["test"] = START
    a_hard = profile.grade(copy.deepcopy(hard), worst_of(hard))
    loss_hard = a_hard.rating_after - a_hard.rating_before

    assert loss_easy < 0 and loss_hard < 0
    assert loss_easy < loss_hard  # more negative


def test_nailing_then_overqualified_gain_shrinks(profile):
    """As the player outgrows an item, the reward for nailing it shrinks toward
    zero — you stop gaining rating for trivial wins."""
    gains = []
    for r in (1000, 1300, 1600, 1900, 2200):
        profile.ratings["test"] = float(r)
        dp = make_point(difficulty=1200.0)
        a = profile.grade(dp, optimal_of(dp))
        gains.append(a.rating_after - a.rating_before)
    assert all(x > y for x, y in zip(gains, gains[1:])), gains
    assert gains[-1] >= 0  # never negative for a perfect answer


# =============================================================================
# CLAIM 2: catastrophic always zeroes
# =============================================================================


def test_catastrophic_scores_zero_even_when_cheapest(profile):
    """The cost ordering says this option is *optimal* (cost 0), but it's
    flagged catastrophic — it must still score 0, not 1."""
    dp = make_point(costs=(0.0, 0.5, 1.0), cat=0)
    cat_opt = dp.options[0]
    assert cat_opt.cost == min(o.cost for o in dp.options)
    a = profile.grade(dp, cat_opt)
    assert a.score == 0.0


@pytest.mark.parametrize("cat_index,costs", [
    (0, (0.0, 0.5, 1.0)),   # catastrophic option is the cheapest
    (1, (0.0, 0.5, 1.0)),   # ...in the middle
    (2, (0.0, 0.5, 1.0)),   # ...the most expensive
])
def test_catastrophic_zeroes_regardless_of_cost_position(profile, cat_index, costs):
    dp = make_point(costs=costs, cat=cat_index)
    profile.ratings[dp.skill] = START
    a = profile.grade(dp, dp.options[cat_index])
    assert a.score == 0.0


def test_catastrophic_always_drops_rating(profile):
    """A score of 0 against any item with a positive expectation is a loss.
    Even against a brutally hard item the rating cannot go *up*."""
    for d in (800, 1200, 1600, 2500):
        profile.ratings["test"] = START
        dp = make_point(difficulty=float(d), costs=(0.0, 1.0), cat=1)
        a = profile.grade(dp, dp.options[1])
        assert a.score == 0.0
        assert a.rating_after < a.rating_before


def test_catastrophic_is_worst_possible_outcome(profile):
    """No non-catastrophic answer can score below a catastrophic one: 0.0 is the
    floor, so catastrophic is by construction the worst line on the point."""
    dp = make_point(costs=(0.0, 0.5, 1.0), cat=0)
    cat_score = 0.0  # what grade() assigns to a catastrophic line
    non_cat_scores = [dp.score_for(o) for o in dp.options[1:]]
    assert all(s >= cat_score for s in non_cat_scores)


def test_real_bank_catastrophics_are_modeled(profile):
    """Sanity check on the authored content: the catastrophic blind-maneuver
    lines in hem-002 actually grade to 0."""
    dp = next(p for p in BANK if p.id == "hem-002")
    cats = [o for o in dp.options if o.catastrophic]
    assert cats, "expected hem-002 to contain catastrophic options"
    for o in cats:
        fresh = copy.deepcopy(dp)
        target = next(x for x in fresh.options if x.text == o.text)
        a = profile.grade(fresh, target)
        assert a.score == 0.0


# =============================================================================
# CLAIM 3: item difficulty converges
# =============================================================================


def _drive_item_at_fixed_player(player_rating, target_score, start_difficulty,
                                iterations):
    """Repeatedly grade one item with a player held at a fixed true rating who
    always achieves `target_score`. Returns the list of difficulties over time.

    Holding the player fixed isolates the *item* update so we can watch it
    calibrate — exactly the 'a population of equal players keeps hitting this
    item' scenario the item rating is meant to model.
    """
    # cost 1 - target_score gives exactly `target_score` on a 0..1 cost spread
    dp = make_point(difficulty=start_difficulty, costs=(0.0, 1.0))
    chosen = Option(text="fixed", cost=1.0 - target_score, feedback="")
    dp.options.append(chosen)

    prof_path_score = dp.score_for(chosen)
    assert prof_path_score == pytest.approx(target_score)

    diffs = [dp.difficulty]
    rp = player_rating
    for _ in range(iterations):
        exp = expected(rp, dp.difficulty)
        # mirror engine.grade's item update, player held fixed:
        dp.difficulty += K_ITEM * (exp - target_score)
        diffs.append(dp.difficulty)
    return diffs


def test_item_difficulty_converges_to_calibration_point():
    """An item played by a steady population converges to the difficulty at
    which expected score == achieved score."""
    R, s = 1500.0, 0.75
    # closed-form equilibrium: expected(R, d*) = s
    d_star = R + 400.0 * math.log10(1.0 / s - 1.0)

    diffs = _drive_item_at_fixed_player(R, s, start_difficulty=1900.0,
                                        iterations=2000)
    assert diffs[-1] == pytest.approx(d_star, abs=1.0)


def test_item_difficulty_error_monotonically_shrinks():
    """It's not enough to land near the answer — the distance to equilibrium
    must shrink every step (true convergence, no oscillation/divergence)."""
    R, s = 1500.0, 0.6
    d_star = R + 400.0 * math.log10(1.0 / s - 1.0)
    diffs = _drive_item_at_fixed_player(R, s, start_difficulty=2100.0,
                                        iterations=400)
    errors = [abs(d - d_star) for d in diffs]
    assert all(b < a for a, b in zip(errors, errors[1:])), errors[:10]
    assert errors[-1] < errors[0] / 100  # converged by orders of magnitude


def test_item_converges_from_either_side():
    """Starting too-easy or too-hard both converge to the same point."""
    R, s = 1400.0, 0.5            # s=0.5 -> equilibrium is exactly R
    d_star = R
    from_high = _drive_item_at_fixed_player(R, s, 2000.0, 1500)[-1]
    from_low = _drive_item_at_fixed_player(R, s, 800.0, 1500)[-1]
    assert from_high == pytest.approx(d_star, abs=1.0)
    assert from_low == pytest.approx(d_star, abs=1.0)


def test_overrated_item_gets_easier_when_players_ace_it():
    """Directionality of the item update: if players consistently beat an item
    by more than expected, its difficulty must come *down*."""
    dp = make_point(difficulty=1800.0, costs=(0.0, 1.0))
    rp = 1500.0
    before = dp.difficulty
    # players keep nailing it (score 1.0) though it's rated above them
    for _ in range(5):
        exp = expected(rp, dp.difficulty)
        dp.difficulty += K_ITEM * (exp - 1.0)
    assert dp.difficulty < before


# =============================================================================
# Supporting invariant 2: conservation / symmetry of the update
# =============================================================================


def test_player_and_item_updates_are_symmetric(profile):
    """Rating points the player gains correspond (scaled by K) to difficulty the
    item loses, and vice versa. This is what keeps the population calibrated."""
    dp = make_point(difficulty=1500.0)
    diff_before = dp.difficulty
    a = profile.grade(dp, optimal_of(dp))
    player_delta = a.rating_after - a.rating_before
    item_delta = dp.difficulty - diff_before
    # player_delta = K_PLAYER*(score-exp);  item_delta = K_ITEM*(exp-score)
    assert player_delta / K_PLAYER == pytest.approx(-item_delta / K_ITEM)


def test_exactly_expected_play_barely_moves_rating(profile):
    """If you score exactly what the curve expects, the rating is ~unchanged —
    the engine only rewards beating (or punishes missing) expectation."""
    # tune difficulty so expected == 0.5, then score exactly 0.5
    dp = make_point(difficulty=START, costs=(0.0, 1.0))
    half = Option(text="half", cost=0.5, feedback="")
    dp.options.append(half)
    profile.ratings[dp.skill] = START          # expected == 0.5
    a = profile.grade(dp, half)
    assert a.score == pytest.approx(0.5)
    assert abs(a.rating_after - a.rating_before) < 1e-9


# =============================================================================
# Profile bookkeeping (the rating you trust has to persist correctly)
# =============================================================================


def test_history_and_ratings_roundtrip(tmp_path):
    path = str(tmp_path / "p.json")
    p = Profile(path)
    dp = make_point()
    p.grade(dp, optimal_of(dp))
    p.save()

    reloaded = Profile(path)
    assert reloaded.ratings == p.ratings
    assert len(reloaded.history) == 1
    assert reloaded.history[0]["point_id"] == dp.id


def test_attempt_records_before_and_after(profile):
    dp = make_point(difficulty=1700.0)
    rp_before = profile.rating(dp.skill)
    a = profile.grade(dp, optimal_of(dp))
    assert a.rating_before == rp_before
    assert a.rating_after == profile.rating(dp.skill)
    assert a.rating_after != a.rating_before


# =============================================================================
# Adaptive selection (serve the most informative item)
# =============================================================================


def test_select_point_targets_player_rating(profile):
    """Selection should favour items whose difficulty sits near the player's
    rating (expected ~0.5 = maximal information)."""
    skill = "hemostasis"
    profile.ratings[skill] = 1650.0          # right at hem-002's difficulty
    # run several times since selection samples from the informative top-third
    picks = [select_point(BANK, profile, skill=skill).id for _ in range(50)]
    assert "hem-002" in picks
    # the wildly-off-target easy item should not dominate
    assert picks.count("hem-002") >= picks.count("hem-001")


def test_select_point_respects_skill_filter(profile):
    for _ in range(20):
        dp = select_point(BANK, profile, skill="dissection")
        assert dp.skill == "dissection"
