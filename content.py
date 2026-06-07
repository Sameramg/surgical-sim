"""
Content bank. THIS is the only file that's domain-specific — proof the engine
is generic. Add skills by adding DecisionPoints. Difficulty is your first guess;
the engine recalibrates it from real attempts.

Costs are ordinal within a point: 0.0 = the line you'd defend to an examiner.
Feedback is the 'engine eval' — it must teach, not just judge.
"""

from engine import DecisionPoint, Option

BANK = [
    DecisionPoint(
        id="hem-001", skill="hemostasis", difficulty=1200,
        stem=("Steady ooze from a 2mm vessel in subcutaneous fat during an open "
              "case. Field is otherwise dry. What's your first move?"),
        options=[
            Option("Precise bipolar to the vessel, then confirm dry", 0.0,
                   "Targeted, minimal collateral thermal spread. Default for "
                   "small vessels in a controlled field."),
            Option("Blind monopolar buzz at the general area", 0.6,
                   "Works but sloppy — collateral injury to fat/skin edge, "
                   "char that obscures the field. You'd lose marks for this."),
            Option("Pack and apply pressure, reassess in 5 min", 0.4,
                   "Not wrong, not efficient. Fine for diffuse ooze; overkill "
                   "for a single identifiable bleeder you can just control."),
            Option("Ignore it, it'll stop", 0.9,
                   "Small now, but you've lost the bloodless field that makes "
                   "everything downstream safer. Bad habit."),
        ]),
    DecisionPoint(
        id="hem-002", skill="hemostasis", difficulty=1650,
        stem=("Brisk pulsatile bleeding suddenly fills the field during "
              "dissection near a named artery. You cannot see the source. "
              "First move?"),
        options=[
            Option("Direct pressure with a finger/swab, call for help & suction", 0.0,
                   "Control first, see second. Pressure buys time, restores the "
                   "field, lets you get suction + an extra pair of hands. This is "
                   "the answer that keeps the patient alive."),
            Option("Blindly clamp into the pool of blood", 1.0,
                   "CATASTROPHIC. Clamping what you can't see is how named "
                   "arteries, nerves and ducts get destroyed. Never clamp blind.",
                   catastrophic=True),
            Option("Blind cautery into the field", 0.95,
                   "CATASTROPHIC. Same sin as blind clamping plus thermal injury. "
                   "You cannot coagulate a high-flow arterial bleed you can't see.",
                   catastrophic=True),
            Option("Increase suction and keep dissecting to find it", 0.7,
                   "You'll lose the race — arterial flow outpaces suction. "
                   "Control the flow before you go looking."),
        ]),
    DecisionPoint(
        id="dis-001", skill="dissection", difficulty=1300,
        stem=("You're separating two tissue layers. The plane is areolar and "
              "'wants' to come apart with gentle spreading. You should:"),
        options=[
            Option("Spread along the natural plane, stay in the loose tissue", 0.0,
                   "The avascular areolar plane is a gift — follow it. Bloodless, "
                   "preserves structures. 'The plane knows the way.'"),
            Option("Sharp-cut straight through to save time", 0.7,
                   "You'll cross out of the safe plane into vessels/structures. "
                   "Speed here costs you bleeding and orientation."),
            Option("Blunt-tear with force to open it fast", 0.6,
                   "Tearing doesn't respect planes — it follows the weakest tissue, "
                   "not the right one. Avulsion injury and bleeding."),
            Option("Stop and cauterize the whole plane pre-emptively", 0.8,
                   "Unnecessary thermal injury to an avascular plane. You're "
                   "creating the problem you're trying to prevent."),
        ]),
]
