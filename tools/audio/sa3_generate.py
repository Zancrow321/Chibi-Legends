"""Generate raw sound effects with Stable Audio 3 through a local ComfyUI.

    python tools/audio/sa3_generate.py                      # all events from sa3_prompts.json
    python tools/audio/sa3_generate.py hit_heavy glut_super # only these
    python tools/audio/sa3_generate.py --server http://127.0.0.1:8188 --variants 8 dash

Needs ComfyUI with stable_audio_3_medium.safetensors (checkpoints) and
t5gemma_b_b_ul2.safetensors (text_encoders). Only uses the standard library.
Raw FLAC files land in ComfyUI's output folder under chibi-sfx/<event>/;
the list of files with prompt and seed is written to chibi-sfx/manifest.json.
Afterwards: tools/audio/sa3_finish.py picks and converts them for the game.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).parent


def workflow(prompt: str, seconds: float, seed: int, prefix: str) -> dict:
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "stable_audio_3_medium.safetensors"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "t5gemma_b_b_ul2.safetensors", "type": "stable_audio", "device": "default"}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["2", 0]}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["2", 0]}},
        "5": {"class_type": "EmptyLatentAudio", "inputs": {"seconds": max(1.0, seconds), "batch_size": 1}},
        "6": {"class_type": "KSampler", "inputs": {"seed": seed, "steps": 8, "cfg": 1.0, "sampler_name": "lcm", "scheduler": "simple",
                                                    "denoise": 1.0, "model": ["1", 0], "positive": ["3", 0], "negative": ["4", 0], "latent_image": ["5", 0]}},
        "7": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["6", 0], "vae": ["1", 2]}},
        "8": {"class_type": "SaveAudio", "inputs": {"audio": ["7", 0], "filename_prefix": prefix}},
    }


def call(server: str, path: str, data: dict | None = None) -> dict:
    req = urllib.request.Request(server + path, data=json.dumps(data).encode() if data else None,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("events", nargs="*")
    ap.add_argument("--server", default="http://127.0.0.1:8188")
    ap.add_argument("--output-dir", default=r"G:\Comfy-Desktop\ComfyUI-Shared\output", help="ComfyUI output folder")
    ap.add_argument("--variants", type=int, default=0, help="override variants per event")
    args = ap.parse_args()

    cfg = json.loads((HERE / "sa3_prompts.json").read_text(encoding="utf-8"))
    events = {k: v for k, v in cfg["events"].items() if not args.events or k in args.events}
    manifest_path = Path(args.output_dir) / "chibi-sfx" / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}

    jobs = []
    for name, ev in events.items():
        prompt = f"{ev['prompt']}, {cfg['style']}. Length: {ev['seconds']:g} seconds"
        for i in range(args.variants or ev["variants"]):
            seed = random.randrange(1, 2**48)
            res = call(args.server, "/prompt", {"prompt": workflow(prompt, ev["seconds"], seed, f"chibi-sfx/{name}/{name}_s{seed}")})
            jobs.append((name, prompt, seed, res["prompt_id"]))
    print(f"{len(jobs)} Auftraege in der Warteschlange")

    pending = list(jobs)
    while pending:
        time.sleep(1.0)
        rest = []
        for name, prompt, seed, pid in pending:
            h = call(args.server, f"/history/{pid}").get(pid)
            if not h or not h.get("status", {}).get("completed"):
                if h and h.get("status", {}).get("status_str") == "error":
                    print(f"Fehler: {name} seed {seed}")
                    continue
                rest.append((name, prompt, seed, pid))
                continue
            for out in h["outputs"].values():
                for a in out.get("audio", []):
                    rel = f"{a['subfolder']}/{a['filename']}".replace("\\", "/")
                    manifest.setdefault(name, []).append({"file": rel, "prompt": prompt, "seed": seed})
        if len(rest) != len(pending):
            print(f"  noch {len(rest)}")
        pending = rest

    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False), encoding="utf-8")
    print(f"Manifest: {manifest_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
