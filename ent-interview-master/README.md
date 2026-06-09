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

## Optional: the original server route (file-based saving)

If you specifically want answers written back to `ent_answers.json` on disk
(instead of browser storage), the fixed launcher still works **on macOS with
Node.js installed**:

```bash
chmod +x entinterviewmaster.command   # already set in this repo
./entinterviewmaster.command          # or double-click it
```

Keep `entinterviewmaster.command` and `ent_answers.json` in the same folder.
The standalone HTML also detects this server automatically and will use it when
present, falling back to browser storage otherwise.

## Files

| File | Purpose |
|------|---------|
| `ent_interview_master.html` | Standalone app — **double-click this**. |
| `ent_answers.json` | Your saved answers (also embedded in the HTML). |
| `entinterviewmaster.command` | Original Node launcher, kept for file-based saving. |
