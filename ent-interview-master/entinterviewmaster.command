#!/bin/bash
cd "$(dirname "$0")"
lsof -ti :3005 | xargs kill -9 2>/dev/null; sleep 0.3

node - <<'NODE_EOF'
const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const DATA_FILE = path.join(process.cwd(), 'ent_answers.json');

function loadData() {
  try { return JSON.parse(fs.readFileSync(DATA_FILE, 'utf8')); }
  catch(e) { return { answers: {}, checked: {}, wrong: {} }; }
}
function saveData(obj) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(obj, null, 2), 'utf8');
}

const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>ENT Interview Master</title>
<script src="https://unpkg.com/react@18/umd/react.development.js"></script>
<script src="https://unpkg.com/react-dom@18/umd/react-dom.development.js"></script>
<script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; background: #faf9f6; color: #2a2a28; font-size: 15px; line-height: 1.5; }
  #root { max-width: 880px; margin: 0 auto; padding: 24px 16px 80px; }
  textarea { font-family: inherit; resize: vertical; font-size: 13px; line-height: 1.6; }
  input[type="checkbox"] { width: 17px; height: 17px; cursor: pointer; accent-color: #1D9E75; flex-shrink: 0; margin-top: 2px; }
  button { font-family: inherit; }
  .fade { animation: fade 0.35s ease; }
  @keyframes fade { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: none; } }
</style>
</head>
<body>
<div id="root"></div>
<script type="text/babel">

const data = {
  categories: [
    { name: "Situational & Behavioral", count: 90, pct: 38, color: "#534AB7", bg: "#EEEDFE", subgroups: [
      { name: "On-call scenarios", count: 23, examples: ["Cover colleague's on-call during wedding?", "Case in ER you don't know — what do you do?", "Critical case, senior not answering, what do you do?", "Traveling Thursday, on-call Friday, flight delayed?"] },
      { name: "Family vs Work balance", count: 18, examples: ["Are you married? When will you get married?", "Wife calls — child is sick during clinic", "Husband says leave the program, what do you do?", "Where will you leave your child during on-call?"] },
      { name: "Strengths & Why choose you", count: 13, examples: ["Why should we rank you #1?", "What are your strengths?", "How do you compare with other candidates?"] },
      { name: "Conflict resolution", count: 10, examples: ["Conflict with senior — how did you solve it?", "Argument with colleague, what do you do?", "Senior shouts at you in front of patient?"] },
      { name: "Role model / References", count: 7, examples: ["If we called your reference, what would they say?", "Who is your role model?", "What is your reference in reading?"] },
      { name: "Stress & Burnout", count: 5, examples: ["How do you deal with stress and burnout?", "Tell me about a time under pressure"] },
      { name: "Internship learnings", count: 4, examples: ["What did you learn from being an intern?", "Tell us about an interesting case"] },
      { name: "Leadership", count: 3, examples: ["Tell us about your leadership skills", "What is the quality of a good leader?"] },
      { name: "Weakness", count: 3, examples: ["What is your weakness?", "What makes you angry about patients?"] },
      { name: "Angry / Difficult patient", count: 4, examples: ["Angry patient in clinic, what do you do?", "Difficult patient you met?"] },
    ]},
    { name: "Program-Specific & Vision", count: 66, pct: 28, color: "#1D9E75", bg: "#E1F5EE", subgroups: [
      { name: "Goals / 5-10 year vision", count: 12, examples: ["Where do you see yourself in 5 years?", "Where do you see yourself in 10 years?", "What are your goals in life?"] },
      { name: "Elective & Rotation history", count: 10, examples: ["Where did you take your ENT electives?", "Why didn't you take rotation in our hospital?", "Did you take clinical attachment with us?"] },
      { name: "Fellowship / Subspecialty", count: 10, examples: ["What fellowship are you planning?", "Which subspecialty interests you most?", "What sub-speciality within ENT?"] },
      { name: "Why this center / program", count: 8, examples: ["Why our center?", "What do you know about our program?", "Why did you choose this hospital?"] },
      { name: "Ranking & Commitment", count: 6, examples: ["Are we your #1?", "How will you rank the hospitals?", "If accepted elsewhere, would you still choose us?"] },
      { name: "If not accepted", count: 6, examples: ["What if we didn't accept you this year?", "Will you change specialty if not matched?"] },
      { name: "Questions for them", count: 6, examples: ["Do you have any questions for us?"] },
      { name: "Unpaid / Contract", count: 4, examples: ["Would you accept unpaid?", "If I gave you the contract now, would you sign?"] },
      { name: "Contribution to program", count: 4, examples: ["What will you contribute?", "How can you add to the field?"] },
    ]},
    { name: "Motivation & Identity", count: 26, pct: 11, color: "#D85A30", bg: "#FAECE7", subgroups: [
      { name: "Why ENT / specialty", count: 9, examples: ["Why did you choose ENT?", "Why are you sure this specialty is right?", "What drew you to ENT?"] },
      { name: "Hobbies / Free time", count: 8, examples: ["What are your hobbies?", "What do you do in your free time?", "Last non-medical book you read?"] },
      { name: "Introduce yourself", count: 5, examples: ["Tell us about yourself", "Introduce yourself in 1 minute", "Summarize your CV"] },
      { name: "Describe in word(s)", count: 4, examples: ["Describe yourself in 1 word?", "Describe yourself in 3 words?"] },
    ]},
    { name: "Clinical Reasoning", count: 24, pct: 10, color: "#378ADD", bg: "#E6F1FB", subgroups: [
      { name: "Surgery experience", count: 8, examples: ["What operations did you attend?", "What cases did you see in OR?", "What cases did you encounter on-call?"] },
      { name: "Otology / Hearing", count: 5, examples: ["Approach to deafness in 3yo", "Progressive hearing loss in 20yo female (otosclerosis)", "Interpret audiogram: SNHL", "Rinne & Weber interpretation"] },
      { name: "Tonsils / Adenoids", count: 5, examples: ["Post-tonsillectomy bleeding management", "Peritonsillar abscess approach", "Consent parents for tonsillectomy", "Primary vs secondary bleeding"] },
      { name: "Airway / Emergency", count: 4, examples: ["Button battery in nose — ER approach", "Foreign body in pediatric airway", "First emergency case — your role?"] },
      { name: "Nose / Sinus", count: 1, examples: ["Choanal atresia in newborn", "CT sinus interpretation (fungal)", "Allergic rhinitis management"] },
      { name: "Other ENT", count: 1, examples: ["Epistaxis full workup", "Tongue ulcer DDx", "Post-thyroidectomy hematoma", "Vocal cord lesion found incidentally"] },
    ]},
    { name: "Ethics & Professionalism", count: 15, pct: 6, color: "#D4537E", bg: "#FBEAF0", subgroups: [
      { name: "Doctor disrespecting patient", count: 6, examples: ["You see a doctor mistreating a patient", "Consultant practicing poor patient care"] },
      { name: "Senior's medical mistake", count: 4, examples: ["Senior made mistake in ER, you noticed", "Consultant prescribes harmful medication", "Wrong dose — chain of command"] },
      { name: "Your own mistake", count: 2, examples: ["What if you made a medical mistake?", "You arrived late to clinic — patients angry"] },
      { name: "Extra on-calls / Unfair", count: 2, examples: ["Chief gives you 9 on-calls vs 6 for others", "Junior keeps calling in sick — you're chief"] },
      { name: "Asked to lie / hide", count: 1, examples: ["Consultant says don't document OR complication", "Consultant asks you to lie"] },
    ]},
    { name: "Research & Academic", count: 14, pct: 6, color: "#639922", bg: "#EAF3DE", subgroups: [
      { name: "Talk about your research", count: 8, examples: ["How many researches do you have?", "Talk about one research and your role", "Have you published?", "Choose one you're proud of"] },
      { name: "Research concepts", count: 6, examples: ["What is impact factor?", "Levels of evidence?", "P-value?", "Study designs?"] },
    ]},
  ],
  centers: [
    { name: "KAUH", questionCount: 9, style: "3 stations: Dept Head → RTP → Residents", panel: "Talal Al-Khatib (paeds, ex-RTP), Mazen Merdad (onc), Faisal Zawawi (otology/CI), Almoaidbellah Ramma (current RTP), Nujoom (H&N). Chief: Motasem (R5).", emphasis: ["Role model among references", "One-hand tie + suture types", "Differences between hospitals you rotated at", "Pharmacology (cefdinir dosing)"], unique: "Academic-heavy panel — Merdad/Marzouki publish prolifically with residents. Research must be sharp. You met Ramma + Nujoom in clinic (warm but thin).", you: "Warm-thin: face known, no working relationship. Lead with research identity + craft. Mention the clinic with Ramma once, don't oversell." },
    { name: "KSAUHS / National Guard", questionCount: 6, style: "Standard general + ethical", panel: "Haya Alsubaie (current RTP), Hadi Al-Hakami (ex-RTP, assoc prof), Mohammad Algarni, Mohammad Alshareef (H&N recon, McGill). Chief: Ali Alzahrani (R4).", emphasis: ["General behavioral + ethics", "Strengths / weakness", "Research pedigree"], unique: "Values academic pedigree + cross-institutional research ties. You did an elective here — they know your face, residents still in contact.", you: "TIER 1 — home turf. Use 'during my elective with your team...' + specific detail. Residents text you about symposiums. Play offense." },
    { name: "KFAFH (Armed Forces)", questionCount: 4, style: "Brief, standard general questions", panel: "Nawaf Alsolami (RTP, otologist), Suzan Alzaidi (deputy RTP, laryngology), Mohammed Al-Bar (chairman). Chief: Ahmed Mogharbel (R4).", emphasis: ["Surgeries attended", "Elective locations", "If not accepted"], unique: "Shortest interview. Mogharbel (chief) worked with Ramma at KAU — possible shared connection. Otology-led panel.", you: "TIER 3 — cold. Clinical answers + research do all the work. If otology comes up, Alsolami is an otologist — be ready." },
    { name: "Second Cluster — KAMC", questionCount: 24, style: "Mostly Arabic, conversational, soft-skill heavy", panel: "Sumiyah Bokhari (RTP, facio-plastic, Seoul-trained), Norah Alsharif (deputy RTP), Ahmad Sayed (sleep), Aisha Shamsalddin (otology).", emphasis: ["Which center will you rank first?", "Why Jeddah if not from here?", "Will you change specialty?", "Family/work balance"], unique: "Both RTPs in same panel. Direct pressure on ranking. Personal-life probing. You did an elective here — left strong impression.", you: "TIER 1 — home turf. They know your face. Bokhari = facio-plastic/Seoul. Reference a specific case or teaching moment from the elective." },
    { name: "Second Cluster — KFGH", questionCount: 24, style: "Conversational, soft-skill + some clinical", panel: "Mahmoud Joharji (RTP, rhinology/skull base), Abeer Malebari (deputy RTP, paeds), Jad Moni (SORL guidelines), Saleh.", emphasis: ["Ranking & commitment", "Elective history", "Clinical basics"], unique: "Joharji = rhinology/skull base — your rhinology course (Andejani) + rhinoplasty interest is a real bridge here. You did an elective here.", you: "TIER 1 — home turf. Joharji's rhinology focus aligns with your stated pull toward rhinoplasty/the delicate craft. Use it." },
    { name: "Fakeeh", questionCount: 28, style: "Heavy clinical + ethical scenarios", panel: "Hossam Amoodi (RTP + dept chairman, otologist), Jamal Jawad (rhinology/skull base, Irish fellow), Ibrahim Issa (laryngology).", emphasis: ["Epistaxis cases + audiogram", "Post-tonsillectomy bleeding + CT sinus", "Button battery / airway", "Ethics: drug screening"], unique: "HIGHEST clinical load. CT/audiogram interpretation. Post-thyroidectomy haematoma scenario. Amoodi (otologist) explains the heavy otology questions.", you: "TIER 3 — cold + clinical gauntlet. Refresh otology/audiograms hard. Jawad is an Irish fellow — you trained in Ireland (Trinity), possible rapport." },
  ]
};

// ── Portfolio data (from excavation) ──────────────────────────
const SPINE = {
  line: "I explored seriously, chose deliberately, and the choice held up under scrutiny.",
  steps: [
    { step: "01 · explored", label: "Neurology", killed: true, why: "Gripped me intellectually — dug deep on my own time. But it was the theory I loved, not the clinical reality." },
    { step: "02 · tested", label: "Neurosurgery", killed: true, why: "The 40-year-old, one eye blown, first-assist, ICU, dead in 2 days, cause unknown. Prognosis made real." },
    { step: "03 · loved, then capped", label: "EM", killed: true, why: "SimWars made me love medicine. But EM has a ceiling — no craft, no continuity, shift-work life." },
    { step: "04 · ruled out", label: "Anaesthesia", killed: true, why: "Repetitive. 'You can put your touch but who cares — the patient won't.' No visible reward." },
    { step: "05 · survived", label: "ENT", chosen: true, why: "Kept the emergency rush, added the craft, the anatomy, visible outcomes, and a life I can build." },
  ],
  whyENT: [
    { h: "The pull", items: ["The only OR I never wanted to leave halfway", "Spatially complex, immediately visible, technically demanding", "Margin of error is tiny — ear, septum, neck — so mastery matters"] },
    { h: "The fit", items: ["Operating > emergencies > clinic, honestly", "Airway emergencies keep the SimWars rush alive", "Tight community where excellence is actually noticed"] },
    { h: "The life", items: ["Family-oriented; want a life I can structure", "Achievable in ENT, not in EM shift-work or pure academia", "Room to grow — subspecialty, research, teaching"] },
  ]
};

const BUCKETS = [
  { tag: "Bucket 1", name: "Who are you?", framework: "CAMP · motivation + identity + fit", color: "#D85A30", bg: "#FAECE7", ev: [
    ["Elimination story", "Neuro → neurosurg → EM → anaes → ENT. Tested, not defaulted."],
    ["The 40-year-old case", "Neurosurg prognosis felt, not just argued. Your real patient case."],
    ["The OR I didn't leave", "Branchial cleft + methylene blue, parotids, rhinoplasty, nasal trauma."],
    ["Craft identity", "Drawn to spatial, delicate work with immediate, improvable outcomes."],
    ["H&N anatomy distinction", "Recognised by continuous assessment — not chased. Fresh-cadaver work."],
    ["Vesal 1/2/3 + rhinology course", "Investment made after committing. Knows the community."],
    ["NGHA + MOH electives", "Pushed to be treated as a junior resident. Residents still in contact."],
  ]},
  { tag: "Bucket 2", name: "Can we trust you?", framework: "SPIES (ethics) · STAR (behavioural)", color: "#1D9E75", bg: "#E1F5EE", ev: [
    ["The scissors incident", "Failed something basic in front of the chief. Sat with it. Came back better."],
    ["On-call coverage", "Team-first, but patient safety is the boundary. Escalate when unsafe."],
    ["Family vs work", "'Not 50/50 daily.' Balance is over years. The anchor: showing up."],
    ["TLE leadership failure", "Diagnosed own management breakdown. Joined other projects to learn."],
    ["Student rep + S2S mentor", "Mediated a lecturer conflict. Saw how life stressors hit performance."],
    ["SimWars under pressure", "Calm when randomised into any role. Immediate-feedback growth loop."],
    ["TEAMS / ALERT / TIPS", "From blanking in emergencies to safe, coherent escalation."],
    ["The diabetic 6-year-old", "Kid braver than you framed him. Humility moment that stuck."],
  ]},
  { tag: "Bucket 3", name: "Will you add value?", framework: "Evidence sandwich · trait → proof → trait", color: "#534AB7", bg: "#EEEDFE", ev: [
    ["RSI meta-analysis", "First author + PI. Ketamine vs etomidate. Clinical framing is solid."],
    ["TLE systematic review", "Caught a 44% inclusion error via your own audit. Rigour instinct."],
    ["Research identity", "You initiate and lead — not just participate. Sought the PIs yourself."],
    ["Paeds + psych abstracts", "First author on both. Breadth before the surgical focus."],
    ["Rhinology insight", "'Even consultants are still learning.' Mastery as a lifelong path."],
    ["4 rec letters, 3 specialties", "EM + anaes + ENT vouch for you. Proof the elimination was real."],
    ["Self-built learning tools", "Operative guides, ENT curriculum, spaced-rep OS. Builds what he needs."],
  ]},
];

const STRATEGY = {
  warn: ["Don't lead with the anatomy distinction — invites a question you may flub 4 years on", "Don't say 'mix of clinic and surgery' — RTPs are bored of it", "Don't over-explain the late ENT decision — own it as elimination, not default", "Don't ramble — panel format is ~90 seconds per answer"],
  edge: ["SimWars A-team push — you fought your way in from the B squad", "TLE audit catch — you found your own 44% error", "Scissors story + what came next — rare maturity evidence", "4 letters across 3 specialties — no one else has this", "You build your own tools, unprompted"],
  gap: ["A felt ENT moment, not just the logical case", "One specific thing learned at each elective centre", "Tighten the 40-year-old case into a clean 45-second telling", "Refresh H&N anatomy before the clinical station"],
  frameworks: [
    ["CAMP", "Who are you", "Clinical · Academic · Management · Personal", "For 'tell me about yourself', 'why ENT', 'why us', goals, ranking."],
    ["SPIES / STAR", "Can we trust you", "Seek · Safety · Initiative · Escalate · Support", "SPIES for ethics. STAR for behavioural. Name patient safety early."],
    ["SANDWICH", "Will you add value", "Trait → proof → trait", "Never state a trait without a story; never tell a story without a trait."],
  ]
};

const allQuestions = [];
data.categories.forEach(function(cat, ci) {
  cat.subgroups.forEach(function(sg, si) {
    sg.examples.forEach(function(q, qi) {
      allQuestions.push({ id: ci+'_'+si+'_'+qi, question: q, catIdx: ci, sgIdx: si, catName: cat.name, catColor: cat.color, catBg: cat.bg, sgName: sg.name });
    });
  });
});

// Old answers belong to a different CV (Yahya). Flag them.
var YAHYA_KEYS = ["0_0_0","0_0_1","0_0_2","0_0_3","0_1_0","0_1_1","0_1_2","0_1_3","0_2_0","0_2_1","0_2_2","0_3_0","0_3_1","0_3_2","0_4_1","0_4_2","0_9_0","0_9_1","0_6_0","0_6_1","2_0_0","2_0_1","2_0_2","2_1_0","2_1_1","2_1_2","2_2_0","2_2_1","2_3_0","2_3_1","4_0_0","4_0_1","4_1_0","4_1_1","4_1_2","4_2_0","4_2_1","4_3_0","4_3_1","4_4_0","4_4_1"];
function isYahya(id, answerVal) {
  if (!answerVal) return false;
  return YAHYA_KEYS.indexOf(id) !== -1;
}

function getCenterQuestions(center) {
  var emphWords = center.emphasis.join(' ').toLowerCase().split(/\W+/).filter(function(w){ return w.length > 3; });
  var scored = allQuestions.map(function(q) {
    var haystack = (q.sgName + ' ' + q.catName + ' ' + q.question).toLowerCase();
    var score = emphWords.filter(function(w){ return haystack.includes(w); }).length;
    return Object.assign({}, q, { score: score });
  });
  scored.sort(function(a,b){ return b.score - a.score || Math.random() - 0.5; });
  return scored.slice(0, 4);
}

function useFileData() {
  var [answers, setAnswers] = React.useState({});
  var [checked, setChecked] = React.useState({});
  var [wrong, setWrong] = React.useState({});
  var saveTimer = React.useRef(null);
  var stateRef = React.useRef({ answers: {}, checked: {}, wrong: {} });

  React.useEffect(function() {
    fetch('/data').then(function(r){ return r.json(); }).then(function(d) {
      var a = d.answers || {}, c = d.checked || {}, w = d.wrong || {};
      stateRef.current = { answers: a, checked: c, wrong: w };
      setAnswers(a); setChecked(c); setWrong(w);
    }).catch(function() {});
  }, []);

  function scheduleSave() {
    clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(function() {
      fetch('/save', { method: 'POST', body: JSON.stringify(stateRef.current) });
    }, 800);
  }
  function updateAnswers(fn) { setAnswers(function(prev){ var next = fn(prev); stateRef.current = Object.assign({}, stateRef.current, { answers: next }); scheduleSave(); return next; }); }
  function updateChecked(fn) { setChecked(function(prev){ var next = fn(prev); stateRef.current = Object.assign({}, stateRef.current, { checked: next }); scheduleSave(); return next; }); }
  function updateWrong(fn)   { setWrong(function(prev){   var next = fn(prev); stateRef.current = Object.assign({}, stateRef.current, { wrong: next });   scheduleSave(); return next; }); }
  return { answers, checked, wrong, updateAnswers, updateChecked, updateWrong };
}

// ── RichTextEditor ────────────────────────────────────────────
function RichTextEditor({ value, onChange, placeholder }) {
  var ref = React.useRef(null);
  var isOwn = React.useRef(false);
  var savedSel = React.useRef(null);
  var lastHigh = React.useRef('#FFE99B');
  var [showColors, setShowColors] = React.useState(false);
  var [showHigh, setShowHigh] = React.useState(false);

  React.useEffect(function() {
    if (ref.current && !isOwn.current && document.activeElement !== ref.current) {
      ref.current.innerHTML = value || '';
    }
  }, [value]);

  function saveSel() { var s = window.getSelection(); if (s && s.rangeCount > 0) savedSel.current = s.getRangeAt(0).cloneRange(); }
  function restSel() { if (!savedSel.current || !ref.current) return; ref.current.focus(); var s = window.getSelection(); if (s) { s.removeAllRanges(); s.addRange(savedSel.current); } }
  function handleInput() { isOwn.current = true; if (ref.current) onChange(ref.current.innerHTML); setTimeout(function(){ isOwn.current = false; }, 0); }
  function cmd(c, v) { restSel(); document.execCommand(c, false, v || null); setTimeout(handleInput, 0); }
  function closeAll() { setShowColors(false); setShowHigh(false); }

  function clearFontSizes(node) { if (node.nodeType === 1 && node.style && node.style.fontSize) node.style.fontSize = ''; for (var c = 0; c < node.childNodes.length; c++) clearFontSizes(node.childNodes[c]); }
  function applyFontPx(px) {
    var sel = window.getSelection();
    if (!sel || sel.rangeCount === 0 || sel.isCollapsed) return;
    var range = sel.getRangeAt(0);
    var frag = range.extractContents();
    clearFontSizes(frag);
    var span = document.createElement('span');
    span.style.fontSize = px + 'px';
    span.appendChild(frag);
    range.insertNode(span);
    var nr = document.createRange(); nr.selectNodeContents(span);
    sel.removeAllRanges(); sel.addRange(nr);
    setTimeout(handleInput, 0);
  }
  function stepFont(dir) {
    var SIZES = [10,12,14,16,18,20,24,28,32,36,42,48,64];
    var sel = window.getSelection();
    if (!sel || sel.rangeCount === 0 || sel.isCollapsed) return;
    var node = sel.anchorNode; if (node && node.nodeType === 3) node = node.parentElement;
    var currentPx = 14;
    while (node && node !== ref.current) { var fs = node.style && node.style.fontSize; if (fs) { currentPx = parseInt(fs); break; } node = node.parentElement; }
    var idx = 2;
    for (var i = 0; i < SIZES.length; i++) { if (Math.abs(SIZES[i] - currentPx) < Math.abs(SIZES[idx] - currentPx)) idx = i; }
    applyFontPx(SIZES[Math.max(0, Math.min(SIZES.length - 1, idx + dir))]);
  }
  function resetFont() { applyFontPx(14); }
  function applyHighlight(c) {
    if (c !== 'transparent') lastHigh.current = c;
    if (c === 'transparent') { document.execCommand('removeFormat', false, null); }
    else { var ok = document.execCommand('hiliteColor', false, c); if (!ok) document.execCommand('backColor', false, c); }
    handleInput(); closeAll();
  }
  function handleKeyDown(e) {
    var mod = e.metaKey || e.ctrlKey;
    if (mod && (e.key === 'b' || e.key === 'B')) { e.preventDefault(); cmd('bold'); return; }
    if (mod && (e.key === 'i' || e.key === 'I')) { e.preventDefault(); cmd('italic'); return; }
    if (mod && (e.key === 'u' || e.key === 'U')) { e.preventDefault(); cmd('underline'); return; }
    if (e.altKey && (e.code === 'Equal' || e.code === 'NumpadAdd')) { e.preventDefault(); stepFont(1); return; }
    if (e.altKey && (e.code === 'Minus' || e.code === 'NumpadSubtract')) { e.preventDefault(); stepFont(-1); return; }
    if (e.altKey && (e.code === 'Digit0' || e.code === 'Numpad0')) { e.preventDefault(); resetFont(); return; }
    if (e.altKey && e.code === 'KeyH') { e.preventDefault(); applyHighlight(lastHigh.current); }
  }
  var COLORS = ['#000000','#D85A30','#D4537E','#534AB7','#1D9E75','#378ADD','#C88A00','#639922','#888888'];
  var HIGHS  = ['#FFE99B','#FFD700','#B5F5B5','#ADD8E6','#FFB6C1','#DDD8F8','transparent'];
  var btn = {fontSize:12,padding:'3px 6px',borderRadius:5,border:'1px solid #e0ddd5',background:'#fff',cursor:'pointer',fontFamily:'inherit',lineHeight:'1.4',minWidth:24,textAlign:'center'};

  return (
    <div style={{ border:'1.5px solid #e6e3da', borderRadius:7, background:'#fff', marginTop:8, position:'relative' }}>
      <div style={{ display:'flex', flexWrap:'wrap', gap:3, padding:'5px 8px', borderBottom:'1px solid #efece4', background:'#f6f4ee', alignItems:'center', borderRadius:'5px 5px 0 0' }}>
        <button onMouseDown={function(e){e.preventDefault();saveSel();cmd('bold');}} style={Object.assign({},btn,{fontWeight:800})} title="Bold (⌘B)">B</button>
        <button onMouseDown={function(e){e.preventDefault();saveSel();cmd('italic');}} style={Object.assign({},btn,{fontStyle:'italic'})} title="Italic (⌘I)">I</button>
        <button onMouseDown={function(e){e.preventDefault();saveSel();cmd('underline');}} style={Object.assign({},btn,{textDecoration:'underline'})} title="Underline (⌘U)">U</button>
        <div style={{width:1,height:18,background:'#ddd',margin:'0 2px'}} />
        <button onMouseDown={function(e){e.preventDefault();stepFont(1);}} style={btn} title="Bigger (⌥=)">A+</button>
        <button onMouseDown={function(e){e.preventDefault();stepFont(-1);}} style={btn} title="Smaller (⌥-)">A−</button>
        <div style={{width:1,height:18,background:'#ddd',margin:'0 2px'}} />
        <div style={{position:'relative'}}>
          <button onMouseDown={function(e){e.preventDefault();saveSel();setShowColors(function(v){return !v;});setShowHigh(false);}} style={btn} title="Text color"><span style={{fontWeight:800,color:'#D85A30'}}>A</span></button>
          {showColors && (
            <div style={{position:'absolute',top:'110%',left:0,zIndex:300,background:'#fff',border:'1px solid #e6e3da',borderRadius:8,padding:8,display:'flex',flexWrap:'wrap',gap:4,width:120,boxShadow:'0 4px 16px rgba(0,0,0,0.12)'}}>
              {COLORS.map(function(c){ return (<div key={c} onMouseDown={function(e){e.preventDefault();restSel();document.execCommand('foreColor',false,c);handleInput();closeAll();}} style={{width:22,height:22,background:c,borderRadius:4,cursor:'pointer',border:'1.5px solid transparent'}} />); })}
            </div>
          )}
        </div>
        <div style={{position:'relative'}}>
          <button onMouseDown={function(e){e.preventDefault();saveSel();setShowHigh(function(v){return !v;});setShowColors(false);}} style={btn} title="Highlight (⌥H)"><span style={{background:'#FFD700',padding:'0 3px',fontWeight:700,fontSize:11}}>H</span></button>
          {showHigh && (
            <div style={{position:'absolute',top:'110%',left:0,zIndex:300,background:'#fff',border:'1px solid #e6e3da',borderRadius:8,padding:8,display:'flex',flexWrap:'wrap',gap:4,width:120,boxShadow:'0 4px 16px rgba(0,0,0,0.12)'}}>
              {HIGHS.map(function(c){ return (<div key={c} onMouseDown={function(e){e.preventDefault();restSel();applyHighlight(c);}} style={{width:22,height:22,background:c==='transparent'?'repeating-linear-gradient(45deg,#ccc,#ccc 3px,#fff 3px,#fff 6px)':c,borderRadius:4,cursor:'pointer',border:'1.5px solid #e6e3da'}} />); })}
            </div>
          )}
        </div>
      </div>
      <div ref={ref} contentEditable={true} suppressContentEditableWarning={true} onInput={handleInput} onKeyDown={handleKeyDown} onBlur={saveSel}
        style={{minHeight:80,padding:'10px 12px',outline:'none',fontSize:14,lineHeight:1.7,color:'#333',background:'#fff',borderRadius:'0 0 5px 5px'}} />
      {(!value || value === '') && <div style={{position:'absolute',bottom:10,left:12,color:'#bbb',fontSize:13,pointerEvents:'none',fontStyle:'italic'}}>{placeholder||'Write your answer here...'}</div>}
    </div>
  );
}

// ── QuestionCard ──────────────────────────────────────────────
function QuestionCard({ qObj, checked, onCheck, answer, onAnswer, wrongCount }) {
  var [showAns, setShowAns] = React.useState(false);
  var done = !!checked[qObj.id];
  var missed = (wrongCount || 0) > 0;
  var flagged = isYahya(qObj.id, answer);
  return (
    <div style={{ background: done ? '#f4fbf7' : '#fff', border: '1.5px solid ' + (done ? '#b8e6cc' : missed ? '#f9c8b8' : '#ebe8e0'), borderRadius: 10, marginBottom: 8, overflow: 'hidden' }}>
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10, padding: '11px 14px' }}>
        <input type="checkbox" checked={done} onChange={function(){ onCheck(qObj.id); }} />
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 8 }}>
            <span style={{ fontSize: 13.5, color: done ? '#2a7a50' : '#1a1a1a', textDecoration: done ? 'line-through' : 'none', opacity: done ? 0.7 : 1 }}>{qObj.question}</span>
            <div style={{ display: 'flex', alignItems: 'center', gap: 5, flexShrink: 0 }}>
              {flagged && <span title="Old answer written for a different CV (Yahya). Rewrite in your voice." style={{ background: '#fdeccf', color: '#9a6a16', borderRadius: 99, fontSize: 10, fontWeight: 700, padding: '1px 6px' }}>⚠ old</span>}
              {missed && <span style={{ background: '#fcd3c0', color: '#b03a1a', borderRadius: 99, fontSize: 10, fontWeight: 700, padding: '1px 6px' }}>✗ {wrongCount}</span>}
              <button onClick={function(){ setShowAns(function(a){ return !a; }); }} style={{ fontSize: 11, padding: '3px 8px', borderRadius: 6, border: '1px solid #e0ddd5', background: showAns ? '#f0eee7' : '#fff', cursor: 'pointer', color: '#555', fontWeight: 600 }}>
                {showAns ? 'Hide' : (answer ? 'Answer •' : 'Answer')}
              </button>
            </div>
          </div>
          {showAns && flagged && (
            <div style={{ marginTop: 8, padding: '8px 11px', background: '#fdf6e9', border: '1px solid #f0dcb4', borderRadius: 7, fontSize: 12.5, color: '#8a6516' }}>
              ⚠ This saved answer was written for a different candidate's CV. Use it only as a structure reference — rewrite it in your own voice and story.
            </div>
          )}
          {showAns && <RichTextEditor value={answer || ''} onChange={function(val){ onAnswer(qObj.id, val); }} placeholder="Write your answer here..." />}
        </div>
      </div>
    </div>
  );
}

// ── SubgroupSection ───────────────────────────────────────────
function SubgroupSection({ cat, catIdx, sg, sgIdx, filter, checked, onCheck, answers, onAnswer, wrongCounts }) {
  var [open, setOpen] = React.useState(false);
  var questions = allQuestions.filter(function(q){ return q.catIdx === catIdx && q.sgIdx === sgIdx; });
  var visible = questions;
  if (filter === 'incomplete') visible = questions.filter(function(q){ return !checked[q.id]; });
  if (filter === 'review') visible = questions.filter(function(q){ return (wrongCounts[q.id] || 0) > 0; });
  var done = questions.filter(function(q){ return checked[q.id]; }).length;
  var total = questions.length;
  var pct = total > 0 ? Math.round(done/total*100) : 0;
  if (filter !== 'all' && visible.length === 0) return null;
  return (
    <div style={{ marginBottom: 6 }}>
      <div onClick={function(){ setOpen(function(o){ return !o; }); }} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '9px 12px', borderRadius: open ? '8px 8px 0 0' : 8, background: '#f6f4ee', cursor: 'pointer', userSelect: 'none', border: '1px solid ' + (open ? cat.color : '#ebe8e0') }}>
        <span style={{ flex: 1, fontSize: 13.5, fontWeight: 600, color: '#2a2a2a' }}>{sg.name}</span>
        <span style={{ fontSize: 12, color: pct === 100 ? '#1D9E75' : '#999', fontWeight: 600, minWidth: 36, textAlign: 'right' }}>{done}/{total}</span>
        <div style={{ width: 52, height: 5, background: '#e6e3da', borderRadius: 99, overflow: 'hidden', flexShrink: 0 }}>
          <div style={{ width: pct+'%', height: '100%', background: pct === 100 ? '#1D9E75' : cat.color, borderRadius: 99 }} />
        </div>
        <span style={{ fontSize: 14, color: '#bbb', transform: open ? 'rotate(90deg)' : 'none', transition: 'transform 0.15s' }}>›</span>
      </div>
      {open && (
        <div style={{ border: '1px solid ' + cat.color, borderTop: 'none', borderRadius: '0 0 8px 8px', padding: '10px', background: '#fff' }}>
          {visible.length === 0 ? <div style={{ padding: '12px', color: '#999', fontSize: 13, textAlign: 'center' }}>No questions match this filter.</div>
            : visible.map(function(q) { return <QuestionCard key={q.id} qObj={q} checked={checked} onCheck={onCheck} answer={answers[q.id]} onAnswer={onAnswer} wrongCount={wrongCounts[q.id] || 0} />; })}
        </div>
      )}
    </div>
  );
}

// ── CategorySection ───────────────────────────────────────────
function CategorySection({ cat, catIdx, filter, checked, onCheck, answers, onAnswer, wrongCounts }) {
  var [open, setOpen] = React.useState(false);
  var catQs = allQuestions.filter(function(q){ return q.catIdx === catIdx; });
  var done = catQs.filter(function(q){ return checked[q.id]; }).length;
  var total = catQs.length;
  var pct = total > 0 ? Math.round(done/total*100) : 0;
  var hasVisible = filter === 'all' || (filter === 'incomplete' && catQs.some(function(q){ return !checked[q.id]; })) || (filter === 'review' && catQs.some(function(q){ return (wrongCounts[q.id] || 0) > 0; }));
  if (!hasVisible) return null;
  return (
    <div style={{ marginBottom: 10 }}>
      <div onClick={function(){ setOpen(function(o){ return !o; }); }} style={{ cursor: 'pointer', borderRadius: open ? '10px 10px 0 0' : 10, border: '1.5px solid ' + (open ? cat.color : '#ebe8e0'), background: open ? cat.bg : '#fbfaf7', padding: '13px 16px', display: 'flex', alignItems: 'center', gap: 12, userSelect: 'none' }}>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
            <span style={{ fontWeight: 700, fontSize: 14, color: open ? cat.color : '#1a1a1a' }}>{cat.name}</span>
            <span style={{ fontSize: 13, fontWeight: 700, color: cat.color }}>{done}/{total} <span style={{ fontWeight: 400, color: '#999', fontSize: 12 }}>({pct}%)</span></span>
          </div>
          <div style={{ height: 6, background: '#e6e3da', borderRadius: 99, overflow: 'hidden' }}>
            <div style={{ width: pct+'%', height: '100%', background: cat.color, borderRadius: 99, transition: 'width 0.4s' }} />
          </div>
        </div>
        <span style={{ fontSize: 18, color: cat.color, transform: open ? 'rotate(90deg)' : 'none', transition: 'transform 0.2s', lineHeight: 1 }}>›</span>
      </div>
      {open && (
        <div style={{ border: '1.5px solid ' + cat.color, borderTop: 'none', borderRadius: '0 0 10px 10px', background: '#fff', padding: '12px' }}>
          {cat.subgroups.map(function(sg, si) { return <SubgroupSection key={si} cat={cat} catIdx={catIdx} sg={sg} sgIdx={si} filter={filter} checked={checked} onCheck={onCheck} answers={answers} onAnswer={onAnswer} wrongCounts={wrongCounts} />; })}
        </div>
      )}
    </div>
  );
}

// ── StudyView ─────────────────────────────────────────────────
function StudyView({ filter, setFilter, checked, onCheck, answers, onAnswer, wrongCounts }) {
  var total = allQuestions.length;
  var done = allQuestions.filter(function(q){ return checked[q.id]; }).length;
  var pct = total > 0 ? Math.round(done/total*100) : 0;
  var reviewCount = allQuestions.filter(function(q){ return (wrongCounts[q.id] || 0) > 0; }).length;
  return (
    <div className="fade">
      <div style={{ background: '#fff', borderRadius: 12, padding: '16px 18px', marginBottom: 20, border: '1.5px solid #ebe8e0' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
          <span style={{ fontWeight: 700, fontSize: 15 }}>Overall progress</span>
          <span style={{ fontWeight: 800, fontSize: 20, color: '#534AB7' }}>{pct}%</span>
        </div>
        <div style={{ height: 10, background: '#e6e3da', borderRadius: 99, overflow: 'hidden', marginBottom: 8 }}>
          <div style={{ width: pct+'%', height: '100%', background: pct === 100 ? '#1D9E75' : '#534AB7', borderRadius: 99, transition: 'width 0.5s' }} />
        </div>
        <div style={{ display: 'flex', gap: 16, fontSize: 13, color: '#666' }}>
          <span><b style={{ color: '#1D9E75' }}>{done}</b> done</span>
          <span><b style={{ color: '#999' }}>{total - done}</b> remaining</span>
          {reviewCount > 0 && <span><b style={{ color: '#D85A30' }}>{reviewCount}</b> need review</span>}
        </div>
      </div>
      <div style={{ display: 'flex', gap: 6, marginBottom: 16, flexWrap: 'wrap' }}>
        {[['all','All Questions'],['incomplete','Incomplete'],['review','Needs Review']].map(function(pair) {
          var f = pair[0], l = pair[1];
          return (<button key={f} onClick={function(){ setFilter(f); }} style={{ padding: '7px 14px', borderRadius: 8, border: '1.5px solid ' + (filter === f ? '#534AB7' : '#e0ddd5'), background: filter === f ? '#534AB7' : '#fff', color: filter === f ? '#fff' : '#555', fontWeight: 600, fontSize: 13, cursor: 'pointer' }}>{l}{f === 'review' && reviewCount > 0 ? ' (' + reviewCount + ')' : ''}</button>);
        })}
      </div>
      {data.categories.map(function(cat, ci) { return <CategorySection key={ci} cat={cat} catIdx={ci} filter={filter} checked={checked} onCheck={onCheck} answers={answers} onAnswer={onAnswer} wrongCounts={wrongCounts} />; })}
    </div>
  );
}

// ── SpineView ─────────────────────────────────────────────────
function SpineView() {
  return (
    <div className="fade">
      <div style={{ background: '#fff', border: '1.5px solid #ebe8e0', borderLeft: '3px solid #D8A23A', borderRadius: 10, padding: '16px 20px', marginBottom: 24 }}>
        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 0.6, textTransform: 'uppercase', color: '#b58a2e', marginBottom: 6 }}>The spine</div>
        <div style={{ fontSize: 18, fontStyle: 'italic', color: '#3a3a38', lineHeight: 1.4 }}>"{SPINE.line}"</div>
      </div>
      <h3 style={{ fontSize: 17, fontWeight: 800, marginBottom: 4 }}>The elimination arc</h3>
      <p style={{ fontSize: 13, color: '#888', marginBottom: 16 }}>Every "why ENT" answer hangs off this. Not a late default — a process where each option was tested and ENT survived.</p>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 28 }}>
        {SPINE.steps.map(function(s, i) {
          return (
            <div key={i} style={{ flex: '1 1 150px', minWidth: 150, background: s.chosen ? '#FBF3E2' : '#fff', border: '1.5px solid ' + (s.chosen ? '#D8A23A' : '#ebe8e0'), borderRadius: 10, padding: '13px 15px' }}>
              <div style={{ fontSize: 10.5, fontFamily: 'monospace', color: '#aaa' }}>{s.step}</div>
              <div style={{ fontWeight: 700, fontSize: 15, marginTop: 3, textDecoration: s.killed ? 'line-through' : 'none', textDecorationColor: '#e08a7a', color: s.chosen ? '#9a6a16' : '#2a2a28' }}>{s.label}</div>
              <div style={{ fontSize: 12, color: '#777', marginTop: 5, lineHeight: 1.45 }}>{s.why}</div>
            </div>
          );
        })}
      </div>
      <h3 style={{ fontSize: 17, fontWeight: 800, marginBottom: 4 }}>Why ENT — the real version</h3>
      <p style={{ fontSize: 13, color: '#888', marginBottom: 16 }}>Drop the "mix of clinic and surgery" line. Use the craft framing.</p>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 12 }}>
        {SPINE.whyENT.map(function(col, i) {
          return (
            <div key={i} style={{ background: '#f3f8f5', border: '1px solid #d4e8dd', borderRadius: 11, padding: '16px 18px' }}>
              <div style={{ fontSize: 12, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, color: '#1D9E75', marginBottom: 10 }}>{col.h}</div>
              {col.items.map(function(it, j){ return <div key={j} style={{ fontSize: 13, color: '#555', padding: '4px 0 4px 14px', position: 'relative', lineHeight: 1.45 }}><span style={{ position: 'absolute', left: 0, color: '#aaa' }}>—</span>{it}</div>; })}
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ── PortfolioView ─────────────────────────────────────────────
function PortfolioView() {
  return (
    <div className="fade">
      <h3 style={{ fontSize: 17, fontWeight: 800, marginBottom: 4 }}>Portfolio map</h3>
      <p style={{ fontSize: 13, color: '#888', marginBottom: 20 }}>Every piece of evidence sorted into the three buckets a panel scores you on. The framework under each is how you structure an answer from it.</p>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: 16 }}>
        {BUCKETS.map(function(b, i) {
          return (
            <div key={i} style={{ border: '1px solid #ebe8e0', borderRadius: 14, overflow: 'hidden', background: '#fff' }}>
              <div style={{ padding: '18px 18px 14px', background: b.bg, borderBottom: '1px solid rgba(0,0,0,0.05)' }}>
                <div style={{ fontSize: 11, fontFamily: 'monospace', letterSpacing: 0.5, textTransform: 'uppercase', color: b.color }}>{b.tag}</div>
                <div style={{ fontSize: 19, fontWeight: 800, margin: '5px 0 3px', color: '#2a2a28' }}>{b.name}</div>
                <div style={{ fontSize: 11.5, fontFamily: 'monospace', color: '#888' }}>{b.framework}</div>
              </div>
              <div style={{ padding: '12px 12px 16px' }}>
                {b.ev.map(function(e, j){
                  return (<div key={j} style={{ borderRadius: 9, padding: '11px 13px', marginBottom: 7, background: '#fbfaf7', border: '1px solid #f0ede5' }}>
                    <div style={{ fontWeight: 600, fontSize: 13.5, marginBottom: 2 }}>{e[0]}</div>
                    <div style={{ fontSize: 12, color: '#888', lineHeight: 1.45 }}>{e[1]}</div>
                  </div>);
                })}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ── StrategyView ──────────────────────────────────────────────
function StrategyView() {
  var cards = [
    { h: 'Traps to avoid', color: '#C88A00', bg: '#FBF3E2', items: STRATEGY.warn },
    { h: 'Your edge', color: '#1D9E75', bg: '#E1F5EE', items: STRATEGY.edge },
    { h: 'Still to forge', color: '#534AB7', bg: '#EEEDFE', items: STRATEGY.gap },
  ];
  return (
    <div className="fade">
      <h3 style={{ fontSize: 17, fontWeight: 800, marginBottom: 4 }}>Strategy notes</h3>
      <p style={{ fontSize: 13, color: '#888', marginBottom: 20 }}>The meta-layer — how to run the room, not just answer the questions.</p>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 14, marginBottom: 28 }}>
        {cards.map(function(c, i) {
          return (
            <div key={i} style={{ background: c.bg, border: '1px solid rgba(0,0,0,0.06)', borderRadius: 12, padding: '16px 18px' }}>
              <div style={{ fontSize: 12, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, color: c.color, marginBottom: 10 }}>{c.h}</div>
              {c.items.map(function(it, j){ return <div key={j} style={{ fontSize: 13, color: '#555', padding: '5px 0 5px 14px', position: 'relative', lineHeight: 1.45 }}><span style={{ position: 'absolute', left: 0, color: '#999' }}>—</span>{it}</div>; })}
            </div>
          );
        })}
      </div>
      <h3 style={{ fontSize: 17, fontWeight: 800, marginBottom: 4 }}>Three frameworks, three buckets</h3>
      <p style={{ fontSize: 13, color: '#888', marginBottom: 16 }}>Identify the bucket in one second, deploy the framework, fill it with real material.</p>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 14 }}>
        {STRATEGY.frameworks.map(function(f, i) {
          var colors = ['#D85A30','#1D9E75','#534AB7']; var bgs = ['#FAECE7','#E1F5EE','#EEEDFE'];
          return (
            <div key={i} style={{ border: '1px solid #ebe8e0', borderRadius: 12, overflow: 'hidden', background: '#fff' }}>
              <div style={{ padding: '14px 16px', background: bgs[i] }}>
                <div style={{ fontSize: 11, fontFamily: 'monospace', letterSpacing: 0.5, color: colors[i] }}>{f[0]}</div>
                <div style={{ fontSize: 16, fontWeight: 800, margin: '4px 0 2px' }}>{f[1]}</div>
                <div style={{ fontSize: 11, fontFamily: 'monospace', color: '#999' }}>{f[2]}</div>
              </div>
              <div style={{ padding: '12px 16px', fontSize: 12.5, color: '#777', lineHeight: 1.5 }}>{f[3]}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ── CenterView ────────────────────────────────────────────────
function CenterView({ onStartCenterQuiz }) {
  var [openIdx, setOpenIdx] = React.useState(null);
  var tierColor = { '1': '#1D9E75', '3': '#D85A30' };
  return (
    <div className="fade">
      <p style={{ fontSize: 13, color: '#888', marginBottom: 16 }}>Click a center for its panel, signals, and your tier. Use "Quiz this center" to drill 4 representative questions.</p>
      <div style={{ display: 'grid', gap: 12, gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))' }}>
        {data.centers.map(function(c, i) {
          var isOpen = openIdx === i;
          var tier = c.you.indexOf('TIER 1') !== -1 ? '1' : (c.you.indexOf('TIER 3') !== -1 ? '3' : '2');
          var sizeColor = c.questionCount >= 20 ? '#D85A30' : c.questionCount >= 8 ? '#C88A00' : '#639922';
          return (
            <div key={i} style={{ borderRadius: 12, border: '1.5px solid ' + (isOpen ? '#534AB7' : '#ebe8e0'), overflow: 'hidden', background: '#fff' }}>
              <div onClick={function(){ setOpenIdx(isOpen ? null : i); }} style={{ padding: '14px 16px', background: isOpen ? '#EEEDFE' : '#fbfaf7', display: 'flex', alignItems: 'center', justifyContent: 'space-between', cursor: 'pointer' }}>
                <div style={{ flex: 1 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ fontWeight: 700, fontSize: 15, color: isOpen ? '#534AB7' : '#1a1a1a' }}>{c.name}</span>
                    {tier !== '2' && <span style={{ background: tierColor[tier], color: '#fff', borderRadius: 5, fontSize: 10, fontWeight: 700, padding: '1px 7px' }}>TIER {tier}</span>}
                  </div>
                  <div style={{ fontSize: 12, color: '#888', marginTop: 2 }}>{c.style}</div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ background: sizeColor, color: '#fff', borderRadius: 99, fontSize: 12, fontWeight: 700, padding: '3px 10px' }}>{c.questionCount}q</span>
                  <span style={{ fontSize: 16, color: '#bbb', transform: isOpen ? 'rotate(90deg)' : 'none', transition: 'transform 0.2s' }}>›</span>
                </div>
              </div>
              {isOpen && (
                <div style={{ padding: '14px 16px', background: '#fff', borderTop: '1px solid #ebe8e0' }}>
                  <div style={{ marginBottom: 12 }}>
                    <div style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, color: '#888', marginBottom: 5 }}>Likely panel</div>
                    <div style={{ fontSize: 12.5, color: '#555', lineHeight: 1.5 }}>{c.panel}</div>
                  </div>
                  <div style={{ marginBottom: 12 }}>
                    <div style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, color: '#888', marginBottom: 6 }}>Focus areas</div>
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                      {c.emphasis.map(function(e, j){ return <span key={j} style={{ background: '#f3f1ea', borderRadius: 6, fontSize: 12, padding: '4px 9px', color: '#555' }}>{e}</span>; })}
                    </div>
                  </div>
                  <div style={{ background: '#FBF3E2', borderRadius: 8, padding: '10px 12px', borderLeft: '3px solid #C88A00', marginBottom: 10 }}>
                    <div style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, color: '#b58a2e', marginBottom: 4 }}>Unique signal</div>
                    <div style={{ fontSize: 12.5, color: '#6a5a32', lineHeight: 1.5 }}>{c.unique}</div>
                  </div>
                  <div style={{ background: '#EEF6F1', borderRadius: 8, padding: '10px 12px', borderLeft: '3px solid #1D9E75', marginBottom: 12 }}>
                    <div style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, color: '#1D9E75', marginBottom: 4 }}>Your play</div>
                    <div style={{ fontSize: 12.5, color: '#2a6a4c', lineHeight: 1.5 }}>{c.you}</div>
                  </div>
                  <button onClick={function(){ onStartCenterQuiz(c); }} style={{ width: '100%', padding: '10px', borderRadius: 8, border: 'none', background: '#534AB7', color: '#fff', fontWeight: 700, fontSize: 14, cursor: 'pointer' }}>Quiz this center (4 questions) →</button>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ── QuizSession ───────────────────────────────────────────────
function QuizSession({ queue, centerName, answers, setWrongCounts }) {
  var [idx, setIdx] = React.useState(0);
  var [revealed, setRevealed] = React.useState(false);
  var [results, setResults] = React.useState([]);
  var [sessionDone, setSessionDone] = React.useState(false);
  var isCenter = !!centerName;
  var currentQ = isCenter ? queue[idx] : queue[idx % queue.length];
  if (!currentQ) return <div style={{ textAlign: 'center', padding: 40, color: '#888' }}>No questions available.</div>;

  function handleResult(correct) {
    if (!correct) { setWrongCounts(function(prev) { var next = Object.assign({}, prev); next[currentQ.id] = (prev[currentQ.id] || 0) + 1; return next; }); }
    var newResults = results.concat([{ id: currentQ.id, question: currentQ.question, correct: correct }]);
    setResults(newResults);
    if (isCenter && idx + 1 >= 4) { setSessionDone(true); return; }
    setIdx(function(i){ return i + 1; }); setRevealed(false);
  }
  if (sessionDone) {
    var correctCount = results.filter(function(r){ return r.correct; }).length;
    return (
      <div style={{ textAlign: 'center', padding: '32px 16px' }}>
        <div style={{ fontSize: 38, marginBottom: 10 }}>{correctCount >= 3 ? '🎉' : correctCount >= 2 ? '👍' : '💪'}</div>
        <div style={{ fontSize: 26, fontWeight: 800, marginBottom: 6 }}>{correctCount}/4 Correct</div>
        <div style={{ fontSize: 14, color: '#666', marginBottom: 24 }}>{centerName} session complete.</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 7, maxWidth: 460, margin: '0 auto 24px', textAlign: 'left' }}>
          {results.map(function(r, i) { return (<div key={i} style={{ display: 'flex', alignItems: 'flex-start', gap: 9, padding: '9px 12px', borderRadius: 8, background: r.correct ? '#f0faf5' : '#fff5f3', border: '1px solid ' + (r.correct ? '#b8e6cc' : '#f9c0aa') }}><span style={{ fontSize: 15, flexShrink: 0, marginTop: 1 }}>{r.correct ? '✓' : '✗'}</span><span style={{ fontSize: 13, color: '#333' }}>{r.question}</span></div>); })}
        </div>
      </div>
    );
  }
  var savedAnswer = answers[currentQ.id];
  var flagged = isYahya(currentQ.id, savedAnswer);
  var qLabel = isCenter ? (idx + 1) + ' / 4' : 'Q' + (idx + 1);
  return (
    <div style={{ maxWidth: 580, margin: '0 auto' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14, flexWrap: 'wrap' }}>
        {centerName && <span style={{ background: '#EEEDFE', color: '#534AB7', borderRadius: 7, fontSize: 12, fontWeight: 700, padding: '3px 10px' }}>{centerName}</span>}
        <span style={{ fontSize: 13, color: '#888' }}>Question {qLabel}</span>
        <span style={{ marginLeft: 'auto', background: currentQ.catBg, color: currentQ.catColor, borderRadius: 6, fontSize: 11, padding: '2px 8px', fontWeight: 600 }}>{currentQ.sgName}</span>
      </div>
      <div style={{ background: '#fff', borderRadius: 14, border: '1.5px solid #ebe8e0', padding: '26px 22px', marginBottom: 16, minHeight: 110, display: 'flex', alignItems: 'center' }}>
        <p style={{ fontSize: 18, fontWeight: 600, lineHeight: 1.5, color: '#1a1a1a' }}>{currentQ.question}</p>
      </div>
      {!revealed ? (
        <button onClick={function(){ setRevealed(true); }} style={{ width: '100%', padding: '13px', borderRadius: 10, border: 'none', background: '#534AB7', color: '#fff', fontWeight: 700, fontSize: 15, cursor: 'pointer' }}>Reveal My Answer</button>
      ) : (
        <div>
          <div style={{ background: '#faf9f4', borderRadius: 12, border: '1.5px solid #e6e3da', padding: '16px 18px', marginBottom: 12 }}>
            <div style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, color: '#534AB7', marginBottom: 8 }}>Your answer {flagged && <span style={{ color: '#9a6a16' }}>⚠ old / not your CV</span>}</div>
            {savedAnswer ? <div style={{ fontSize: 14, color: '#333', lineHeight: 1.75 }} dangerouslySetInnerHTML={{ __html: savedAnswer }} /> : <p style={{ fontSize: 13, color: '#bbb', fontStyle: 'italic' }}>No answer saved yet — add one in the Study tab.</p>}
          </div>
          <div style={{ display: 'flex', gap: 10, marginBottom: 8 }}>
            <button onClick={function(){ handleResult(false); }} style={{ flex: 1, padding: '12px', borderRadius: 10, border: '2px solid #f9c0aa', background: '#fff5f3', color: '#b03a20', fontWeight: 700, fontSize: 14, cursor: 'pointer' }}>✗  Missed it</button>
            <button onClick={function(){ handleResult(true); }} style={{ flex: 1, padding: '12px', borderRadius: 10, border: '2px solid #9ddfc0', background: '#f0faf5', color: '#1a7a50', fontWeight: 700, fontSize: 14, cursor: 'pointer' }}>✓  Got it</button>
          </div>
          {!isCenter && <button onClick={function(){ setIdx(function(i){ return i+1; }); setRevealed(false); }} style={{ width: '100%', padding: '9px', borderRadius: 10, border: '1.5px solid #e0ddd5', background: '#fff', color: '#888', fontWeight: 600, fontSize: 13, cursor: 'pointer' }}>Skip →</button>}
        </div>
      )}
    </div>
  );
}

// ── QuizView ──────────────────────────────────────────────────
function QuizView({ answers, wrongCounts, setWrongCounts, initialCenter }) {
  var [mode, setMode] = React.useState(initialCenter ? 'center' : null);
  var [centerName, setCenterName] = React.useState(initialCenter ? initialCenter.name : null);
  var [queue, setQueue] = React.useState(function(){ return initialCenter ? getCenterQuestions(initialCenter) : []; });
  var [sessionKey, setSessionKey] = React.useState(0);
  function startRandom() { var shuffled = allQuestions.slice().sort(function(){ return Math.random() - 0.5; }); setQueue(shuffled); setMode('random'); setCenterName(null); setSessionKey(function(k){ return k+1; }); }
  function startCenter(c) { setQueue(getCenterQuestions(c)); setMode('center'); setCenterName(c.name); setSessionKey(function(k){ return k+1; }); }
  function reset() { setMode(null); setCenterName(null); setQueue([]); }
  if (!mode) {
    return (
      <div className="fade">
        <h3 style={{ fontSize: 17, fontWeight: 800, marginBottom: 6 }}>Quiz mode</h3>
        <p style={{ color: '#666', fontSize: 14, marginBottom: 22 }}>Think through your answer out loud, then reveal your saved template and grade yourself.</p>
        <div onClick={startRandom} style={{ borderRadius: 14, border: '1.5px solid #ebe8e0', background: '#fbfaf7', padding: '20px', cursor: 'pointer', maxWidth: 340, marginBottom: 24 }}>
          <div style={{ fontSize: 30, marginBottom: 8 }}>🔀</div>
          <div style={{ fontWeight: 700, fontSize: 15, marginBottom: 4 }}>Random — never ending</div>
          <div style={{ fontSize: 13, color: '#888' }}>All categories shuffled, infinite stream. Mark correct / wrong as you go.</div>
        </div>
        <div style={{ fontSize: 12, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, color: '#888', marginBottom: 10 }}>Drill a specific center (4 questions)</div>
        <div style={{ display: 'grid', gap: 10, gridTemplateColumns: 'repeat(auto-fill, minmax(210px, 1fr))' }}>
          {data.centers.map(function(c, i) { return (<div key={i} onClick={function(){ startCenter(c); }} style={{ borderRadius: 10, border: '1.5px solid #ebe8e0', background: '#fbfaf7', padding: '13px 15px', cursor: 'pointer' }}><div style={{ fontWeight: 700, fontSize: 14, marginBottom: 3 }}>{c.name}</div><div style={{ fontSize: 12, color: '#888' }}>{c.style}</div></div>); })}
        </div>
      </div>
    );
  }
  return (
    <div className="fade">
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 22 }}>
        <button onClick={reset} style={{ padding: '6px 12px', borderRadius: 8, border: '1.5px solid #e0ddd5', background: '#fff', cursor: 'pointer', fontSize: 13, color: '#555', fontWeight: 600 }}>← Back</button>
        <span style={{ fontSize: 14, fontWeight: 600, color: '#333' }}>{mode === 'center' ? centerName + ' — 4 questions' : 'Random Mode'}</span>
        {mode === 'random' && <button onClick={startRandom} style={{ marginLeft: 'auto', padding: '6px 12px', borderRadius: 8, border: '1.5px solid #e0ddd5', background: '#fff', cursor: 'pointer', fontSize: 12, color: '#666', fontWeight: 600 }}>Reshuffle</button>}
      </div>
      <QuizSession key={sessionKey} queue={queue} centerName={mode === 'center' ? centerName : null} answers={answers} setWrongCounts={setWrongCounts} />
    </div>
  );
}

// ── App ───────────────────────────────────────────────────────
function App() {
  var [tab, setTab] = React.useState('spine');
  var [filter, setFilter] = React.useState('all');
  var [quizCenter, setQuizCenter] = React.useState(null);
  var { answers, checked, wrong: wrongCounts, updateAnswers, updateChecked, updateWrong } = useFileData();
  function onCheck(id) { updateChecked(function(prev){ var n=Object.assign({},prev); n[id]=!prev[id]; return n; }); }
  function onAnswer(id, val) { updateAnswers(function(prev){ var n=Object.assign({},prev); n[id]=val; return n; }); }
  function setWrongCounts(fn) { updateWrong(fn); }
  function handleStartCenterQuiz(center) { setQuizCenter(center); setTab('quiz'); }
  React.useEffect(function(){ if (tab !== 'quiz') setQuizCenter(null); }, [tab]);

  var tabs = [['spine','🧭 Spine'],['portfolio','🗺 Portfolio'],['study','📚 Study'],['centers','🏥 Centers'],['quiz','🧠 Quiz'],['strategy','♟ Strategy']];
  function tabStyle(t) { return { padding: '8px 15px', borderRadius: 8, border: 'none', cursor: 'pointer', fontWeight: 600, fontSize: 13.5, background: tab===t ? '#534AB7' : 'transparent', color: tab===t ? '#fff' : '#666', transition: 'all 0.15s', whiteSpace: 'nowrap' }; }
  var showShortcuts = (tab === 'study');

  return (
    <div>
      <div style={{ marginBottom: 18 }}>
        <h1 style={{ fontSize: 23, fontWeight: 800, letterSpacing: -0.5, marginBottom: 4 }}>ENT Interview Master</h1>
        <p style={{ color: '#888', fontSize: 14 }}>SCFHS · Jeddah · {allQuestions.length} questions · answers saved to file · anchors not scripts · keep it under 90 seconds</p>
      </div>
      <div style={{ display: 'flex', gap: 4, background: '#f1efe8', borderRadius: 10, padding: 4, marginBottom: 14, width: 'fit-content', flexWrap: 'wrap' }}>
        {tabs.map(function(pair){ return <button key={pair[0]} style={tabStyle(pair[0])} onClick={function(){ setTab(pair[0]); }}>{pair[1]}</button>; })}
      </div>
      {showShortcuts && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 20, padding: '8px 12px', background: '#f6f4ee', border: '1px solid #ebe8e0', borderRadius: 9 }}>
          <span style={{ fontSize: 11, fontWeight: 700, color: '#888', textTransform: 'uppercase', letterSpacing: 0.5, alignSelf: 'center', marginRight: 4 }}>Answer shortcuts</span>
          {[['⌘B','Bold'],['⌘I','Italic'],['⌘U','Underline'],['⌥+','Font +'],['⌥−','Font −'],['⌥0','Reset'],['⌥H','Highlight']].map(function(p){ return (<span key={p[0]} style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 12, color: '#444' }}><kbd style={{ background: '#fff', border: '1px solid #d8d4c8', borderRadius: 4, padding: '1px 6px', fontSize: 11, fontFamily: 'inherit', fontWeight: 700, color: '#534AB7' }}>{p[0]}</kbd><span style={{ color: '#888' }}>{p[1]}</span></span>); })}
        </div>
      )}
      {tab === 'spine' && <SpineView />}
      {tab === 'portfolio' && <PortfolioView />}
      {tab === 'study' && <StudyView filter={filter} setFilter={setFilter} checked={checked} onCheck={onCheck} answers={answers} onAnswer={onAnswer} wrongCounts={wrongCounts} />}
      {tab === 'centers' && <CenterView onStartCenterQuiz={handleStartCenterQuiz} />}
      {tab === 'quiz' && <QuizView key={quizCenter ? quizCenter.name : '__picker__'} answers={answers} wrongCounts={wrongCounts} setWrongCounts={setWrongCounts} initialCenter={quizCenter} />}
      {tab === 'strategy' && <StrategyView />}
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
</script>
</body>
</html>`;

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/data') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(loadData()));
    return;
  }
  if (req.method === 'POST' && req.url === '/save') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => { try { saveData(JSON.parse(body)); res.writeHead(200); res.end('ok'); } catch(e) { res.writeHead(400); res.end('bad json'); } });
    return;
  }
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(html);
});

server.listen(3005, () => {
  console.log('ENT Interview Master running at http://localhost:3005');
  setTimeout(() => exec('open http://localhost:3005'), 300);
});
NODE_EOF
