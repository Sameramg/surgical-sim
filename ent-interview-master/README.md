# ENT Interview Master

A self-contained interview-prep app: spine/portfolio/study/centers/quiz/strategy
tabs, a rich-text answer editor, per-center quizzes, and progress tracking.

## Just open it (recommended)

**Double-click `ent_interview_master.html`.** It opens in your browser — no
install, no terminal, no server. Your 41 saved answers are baked into the file,
and any edits you make are saved automatically in that browser.

> First load needs an internet connection (React is pulled from a CDN, same as
> the original). After that the content is local.

### Moving your edits between machines

An open web page can't rewrite the file it was launched from, so live edits are
auto-saved in **that browser** (localStorage). To carry edits elsewhere, use the
buttons in the top-right:

- **⬇ Export .json** — downloads your current answers as `ent_answers.json`.
- **⬆ Import** — loads an `ent_answers.json` back in (on any machine/browser).
- **⬇ Portable .html** — downloads a *fresh copy of the whole app* with your
  current edits baked into the file. That new HTML carries the content with it,
  so opening it on another computer shows your edits immediately — this is how
  an HTML file "retains" content across machines.

## Why the original `.command` "wouldn't open"

The thing you were handed was a launcher, not a document. It failed for several
reasons:

1. **No execute permission** — double-clicking a non-executable `.command`
   just opens it in a text editor (or macOS Gatekeeper blocks it).
2. **It needs Node.js installed** — it boots a local web server on port 3005;
   with no Node, nothing happens.
3. **Filename mismatch** — it loads `ent_answers.json`, but the data file was
   named `ent_answers_1.json` (a download-dedup suffix), so your answers never
   loaded.

The standalone HTML above sidesteps all three.

## Auto-save to a file (the `.command` route)

If you'd rather have every edit written straight to `ent_answers.json` on disk —
no Export button, no browser storage — use the launcher. **On macOS with
[Node.js](https://nodejs.org) installed**, just double-click
`entinterviewmaster.command` (or run `./entinterviewmaster.command`).

It opens the app in your browser and **auto-saves every change to
`ent_answers.json`** (debounced, written atomically so a crash can't corrupt the
file). Leave the terminal window open while you study; close it to stop the app.

It serves the very same `ent_interview_master.html`, so you get all the same
features — it just swaps browser storage for file storage. Keep all three files
in the same folder. If Node.js isn't installed, the launcher falls back to
opening the standalone (browser-saved) version so it still works.

## Files

| File | Purpose |
|------|---------|
| `ent_interview_master.html` | The app — **double-click this** for the no-setup version. |
| `ent_answers.json` | Your saved answers (also embedded in the HTML). |
| `entinterviewmaster.command` | macOS launcher that serves the app and auto-saves to the file. |
