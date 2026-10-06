"""Fast model downloader using curl.exe for Hugging Face GGUF models"""

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "lib"))
import labkit

MODELS_DIR = ROOT / "models"
MODELS_DIR.mkdir(exist_ok=True)

def main():
    key = os.environ.get("LAB_MODEL", "qwen35-0.8b")
    spec = labkit.model_spec(key)

    primary_name = spec["primary"][1]
    compare_name = spec["compare"][1]

    files = [
        (primary_name, f"https://huggingface.co/{spec['repo']}/resolve/main/{primary_name}"),
        (compare_name, f"https://huggingface.co/{spec['repo']}/resolve/main/{compare_name}"),
    ]

    print(f"==> Fast downloading {spec['label']} GGUF model files using curl.exe...")
    for filename, url in files:
        target_path = MODELS_DIR / filename
        if target_path.exists() and target_path.stat().st_size > 10_000_000:
            print(f"    already downloaded: {filename} ({target_path.stat().st_size / 1e6:.1f} MB)")
            continue

        print(f"\n==> Downloading {filename} to {target_path}...")
        cmd = ["curl.exe", "-L", "-C", "-", "-o", str(target_path), url]
        res = subprocess.run(cmd)
        if res.returncode != 0:
            print(f"Error downloading {filename}: exit code {res.returncode}")
            return res.returncode
        print(f"    Downloaded {filename} ({target_path.stat().st_size / 1e6:.1f} MB)")

    print("\n==> Writing active.json manifest...")
    os.environ["LAB_MODEL"] = key
    manifest_cmd = [sys.executable, str(ROOT / "labs" / "00-setup" / "download-model.py"), "--skip-download"]
    res = subprocess.run(manifest_cmd, env={**os.environ, "PYTHONUTF8": "1", "LAB_MODEL": key})
    return res.returncode

if __name__ == "__main__":
    sys.exit(main())
