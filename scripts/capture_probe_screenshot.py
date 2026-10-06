"""Capture 01-hardware-probe.png screenshot from detect-hardware.py output"""

import subprocess
import sys
from pathlib import Path
from html2image import Html2Image

ROOT = Path(__file__).resolve().parents[1]
SCREENSHOT_DIR = ROOT / "submission" / "screenshots"
SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)

def main():
    cmd = [sys.executable, "labs/00-setup/detect-hardware.py"]
    res = subprocess.run(cmd, capture_output=True, text=True, cwd=str(ROOT), env={"PYTHONUTF8": "1"})
    output_text = res.stdout + "\n" + res.stderr

    html = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
body {{
    background-color: #0d1117;
    color: #c9d1d9;
    font-family: "Cascadia Code", "Fira Code", Consolas, monospace;
    font-size: 13.5px;
    padding: 20px;
    margin: 0;
    width: 900px;
}}
.card {{
    background-color: #161b22;
    border: 1px solid #30363d;
    border-radius: 8px;
    padding: 16px;
    box-shadow: 0 4px 16px rgba(0,0,0,0.6);
}}
.header {{
    color: #58a6ff;
    font-weight: bold;
    font-size: 15px;
    margin-bottom: 12px;
    border-bottom: 1px solid #30363d;
    padding-bottom: 8px;
}}
pre {{
    color: #56d364;
    white-space: pre-wrap;
    word-wrap: break-word;
    margin: 0;
    line-height: 1.45;
}}
</style>
</head>
<body>
<div class="card">
  <div class="header">Hardware Probe & System Detection (detect-hardware.py)</div>
  <pre>{output_text.strip()}</pre>
</div>
</body>
</html>
"""
    html_file = ROOT / "scratch" / "probe.html"
    (ROOT / "scratch").mkdir(exist_ok=True)
    html_file.write_text(html, encoding="utf-8")

    hti = Html2Image(output_path=str(SCREENSHOT_DIR))
    hti.screenshot(html_file=str(html_file), save_as="01-hardware-probe.png", size=(940, 560))
    print("Captured submission/screenshots/01-hardware-probe.png")

if __name__ == "__main__":
    main()
