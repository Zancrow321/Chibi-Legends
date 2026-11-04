"""Animiert ein Standbild mit animate-with-text-v3. Aufruf: gen_anim.py still.png outdir name frames "action" [seed]"""
import json, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from PIL import Image
import pl2

still, out, name, frames, action = sys.argv[1:6]
seed = int(sys.argv[6]) if len(sys.argv) > 6 else 0
out = pathlib.Path(out); out.mkdir(parents=True, exist_ok=True)
before = pl2.balance()
r = pl2.post("/animate-with-text-v3", {"first_frame": pl2.b64(Image.open(still).convert("RGBA")),
             "action": action, "frame_count": int(frames), "seed": seed, "no_background": True})
job = r.get("background_job_id") or r.get("job_id")
j = pl2.wait_job(job) if job else r
if j.get("status") == "failed":
    raise SystemExit(json.dumps(j)[:800])
res = j.get("last_response") or j.get("result") or j
imgs = res.get("images") or res.get("frames") or []
for i, im in enumerate(imgs):
    pl2.to_img(im).save(out / f"{name}_{i}.png")
print(name, len(imgs), "frames, usage", res.get("usage"), "spent", before - pl2.balance())
if not imgs:
    print(json.dumps(j)[:1500])
