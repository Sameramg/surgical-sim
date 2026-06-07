"""
SCALPEL CLI — the playable loop. Run: python play.py
Your rating moves every turn. After each point you see the ideal line and the
cost of yours — the chess 'this was the better move' moment.
"""

import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from engine import Profile, select_point
from content import BANK

PROFILE = os.path.join(os.path.dirname(__file__), "profile.json")


def bar(r):  # tiny visual for the rating
    return f"{r:6.0f}  " + "█" * int(max(0, (r - 800) / 40))


def play():
    p = Profile(PROFILE)
    print("\n=== SCALPEL — surgical decision trainer ===")
    print("Pick the number. Ctrl-C to quit. Your rating is per-skill.\n")
    try:
        while True:
            dp = select_point(BANK, p)
            print(f"\n[{dp.skill}]  your rating: {bar(p.rating(dp.skill))}")
            print(f"point difficulty: {dp.difficulty:.0f}")
            print("\n" + dp.stem + "\n")
            opts = list(dp.options)
            import random; random.shuffle(opts)   # don't let position leak the answer
            for i, o in enumerate(opts, 1):
                print(f"  {i}. {o.text}")
            raw = input("\n> ").strip()
            if not raw.isdigit() or not (1 <= int(raw) <= len(opts)):
                print("pick a listed number."); continue
            chosen = opts[int(raw) - 1]
            a = p.grade(dp, chosen)

            verdict = ("OPTIMAL" if a.score == 1.0
                       else "CATASTROPHIC" if chosen.catastrophic
                       else f"score {a.score:.0%}")
            print(f"\n  -> {verdict}")
            print(f"     {chosen.feedback}")
            if a.score < 1.0:
                ideal = dp.ideal
                print(f"\n  best line: {ideal.text}")
                print(f"     {ideal.feedback}")
            delta = a.rating_after - a.rating_before
            print(f"\n     rating {a.rating_before:.0f} -> {a.rating_after:.0f} "
                  f"({'+' if delta>=0 else ''}{delta:.0f})")
            p.save()
    except (KeyboardInterrupt, EOFError):
        print("\n\n--- session over ---")
        for skill, r in p.ratings.items():
            print(f"  {skill:14s} {r:.0f}  ({len(p.history)} total attempts logged)")
        print(f"\nfull replay log: {PROFILE}\n")


if __name__ == "__main__":
    play()
