#!/bin/bash
# ENT Interview Master — file-saving launcher (macOS).
# Serves ent_interview_master.html locally and auto-saves every edit straight
# into ent_answers.json on disk. Double-click to run.

cd "$(dirname "$0")" || exit 1

HTML_FILE="ent_interview_master.html"
DATA_FILE="ent_answers.json"

if [ ! -f "$HTML_FILE" ]; then
  echo "Can't find $HTML_FILE next to this launcher. Keep them in the same folder."
  read -n 1 -s -r -p "Press any key to close..."; exit 1
fi

# No Node.js? Fall back to the standalone (browser-saved) version so it still opens.
if ! command -v node >/dev/null 2>&1; then
  echo "Node.js is not installed, so file-based saving isn't available."
  echo "Opening the standalone version instead — your edits will save in the browser."
  echo "To get file saving, install Node.js from https://nodejs.org and run this again."
  open "$HTML_FILE" 2>/dev/null || xdg-open "$HTML_FILE" 2>/dev/null
  read -n 1 -s -r -p "Press any key to close..."; exit 0
fi

# Free the port if a previous run is still holding it.
lsof -ti :3005 | xargs kill -9 2>/dev/null; sleep 0.3

DATA_FILE="$DATA_FILE" HTML_FILE="$HTML_FILE" node - <<'NODE_EOF'
const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const DATA_FILE = path.join(process.cwd(), process.env.DATA_FILE || 'ent_answers.json');
const HTML_FILE = path.join(process.cwd(), process.env.HTML_FILE || 'ent_interview_master.html');

function loadData() {
  try { return JSON.parse(fs.readFileSync(DATA_FILE, 'utf8')); }
  catch (e) { return { answers: {}, checked: {}, wrong: {} }; }
}
function saveData(obj) {
  // Write to a temp file then rename, so a crash mid-write can't corrupt your answers.
  const tmp = DATA_FILE + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(obj, null, 2), 'utf8');
  fs.renameSync(tmp, DATA_FILE);
}

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/data') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(loadData()));
    return;
  }
  if (req.method === 'POST' && req.url === '/save') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try { saveData(JSON.parse(body)); res.writeHead(200); res.end('ok'); }
      catch (e) { res.writeHead(400); res.end('bad json'); }
    });
    return;
  }
  // Everything else serves the single app file from disk.
  fs.readFile(HTML_FILE, (err, buf) => {
    if (err) { res.writeHead(500); res.end('cannot read ' + HTML_FILE); return; }
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(buf);
  });
});

server.listen(3005, () => {
  console.log('ENT Interview Master running at http://localhost:3005');
  console.log('Auto-saving every edit to ' + DATA_FILE);
  console.log('Leave this window open while you study. Close it to stop the app.');
  setTimeout(() => exec('open http://localhost:3005'), 300);
});
NODE_EOF
