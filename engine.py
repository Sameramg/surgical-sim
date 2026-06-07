"""
SCALPEL — a skill error-grading engine.
Full Code, but the unit of practice is a *decision point* in a surgical skill,
not a clinical timeline. The engine is content-agnostic: feed it any skill graph.

Core model: player-vs-item Elo (the chess-tactics-trainer / IRT formulation).
- The PLAYER has one rating per skill domain.
- Each DECISION POINT has its own difficulty rating.
- You don't pass/fail a point. Every option has a `cost` (deviation from optimal).
  Your "score" on the point in [0,1] = how close to optimal you played.
- Rating update compares score-achieved vs score-expected-given-difficulty.
  Nail a hard point -> big gain. Fumble an easy one -> big loss. Just like chess.
"""

from __future__ import annotations
from dataclasses import dataclass, field
import json, math, random, time, os


# ----------------------------- domain model -----------------------------

@dataclass
class Option:
    text: str
    cost: float          # 0.0 = optimal line. higher = worse. unbounded; we normalize.
    feedback: str        # WHY this is wrong/right — the teaching, like an engine eval
    catastrophic: bool = False  # e.g. cut the structure you can't uncut


@dataclass
class DecisionPoint:
    id: str
    skill: str           # which rating bucket this trains
    difficulty: float    # Elo-scale difficulty (e.g. 1200 = routine, 1800 = nasty)
    stem: str            # the scenario presented
    options: list[Option]

    @property
    def ideal(self) -> Option:
        return min(self.options, key=lambda o: o.cost)

    def score_for(self, chosen: Option) -> float:
        """Map cost -> [0,1] quality. Optimal option = 1.0, worst = 0.0."""
        costs = [o.cost for o in self.options]
        lo, hi = min(costs), max(costs)
        if hi == lo:
            return 1.0
        return 1.0 - (chosen.cost - lo) / (hi - lo)


# ----------------------------- the engine -----------------------------

K_PLAYER = 32          # how fast your rating moves
K_ITEM   = 12          # items drift slower — they're a calibrating population
START    = 1200.0


def expected(r_player: float, r_item: float) -> float:
    """Standard Elo expectancy: P(player 'beats' item)."""
    return 1.0 / (1.0 + 10 ** ((r_item - r_player) / 400.0))


@dataclass
class Attempt:
    point_id: str
    skill: str
    chosen: str
    score: float
    rating_before: float
    rating_after: float
    ts: float = field(default_factory=time.time)


class Profile:
    """Persisted player state. One rating per skill; full attempt log for replay."""

    def __init__(self, path: str):
        self.path = path
        self.ratings: dict[str, float] = {}
        self.history: list[dict] = []
        self._load()

    def _load(self):
        if os.path.exists(self.path):
            d = json.load(open(self.path))
            self.ratings = d.get("ratings", {})
            self.history = d.get("history", [])

    def save(self):
        json.dump({"ratings": self.ratings, "history": self.history},
                  open(self.path, "w"), indent=2)

    def rating(self, skill: str) -> float:
        return self.ratings.setdefault(skill, START)

    def grade(self, dp: DecisionPoint, chosen: Option) -> Attempt:
        rp = self.rating(dp.skill)
        score = dp.score_for(chosen)
        exp = expected(rp, dp.difficulty)
        # catastrophic errors are graded as a 0 regardless of relative cost —
        # transecting the CBD is not "a slightly worse line"
        if chosen.catastrophic:
            score = 0.0
        new_rp = rp + K_PLAYER * (score - exp)
        # symmetric item update keeps the difficulty population calibrated
        dp.difficulty += K_ITEM * (exp - score)
        self.ratings[dp.skill] = new_rp
        a = Attempt(dp.id, dp.skill, chosen.text, score, rp, new_rp)
        self.history.append(a.__dict__)
        return a


# ----------------------------- adaptive selection -----------------------------

def select_point(bank: list[DecisionPoint], profile: Profile,
                 skill: str | None = None) -> DecisionPoint:
    """
    Serve the point that teaches most: difficulty near the player's rating
    (target ~ where expected score is ~0.5 -> maximal information, like CAT/IRT).
    """
    pool = [p for p in bank if skill is None or p.skill == skill]
    def info(p: DecisionPoint) -> float:
        e = expected(profile.rating(p.skill), p.difficulty)
        return -abs(e - 0.5)          # closer to 0.5 = more informative
    top = sorted(pool, key=info, reverse=True)[:max(1, len(pool)//3)]
    return random.choice(top)
