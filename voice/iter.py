#!/usr/bin/env python3
"""
Round 3: fix the three things from Adam's last verdict.
1. Mid-word pauses — tune length/repetition penalty, disable text splitting
2. Can-on-a-string — output at XTTS native 24 kHz, skip the 22050 downsample
3. Reference under-use — bump gpt_cond_len from default ~6s to 20s

Stays on the nix-dry sentence (Adam's pick) so we can hear param effects
on a known reference, plus one short and one long variation.
"""
import os
import subprocess
from pathlib import Path

OUT = Path("/tmp/nix-voice-iter")
OUT.mkdir(exist_ok=True)
for old in OUT.glob("*.wav"):
    old.unlink()

os.environ["COQUI_TOS_AGREED"] = "1"
print("loading XTTS v2...")
from TTS.api import TTS
tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2", progress_bar=False)

ROOT = Path.home() / ".nix" / "voice"
ref = ROOT / "refs" / "cate-v2.wav"

# Reach into the model to set conditioning length (not exposed in tts_to_file)
xtts_model = tts.synthesizer.tts_model
print("default gpt_cond_len:", getattr(xtts_model.config, "gpt_cond_len", "?"))

# Common high-quality params for round 3
common_kwargs = dict(
    temperature=0.75,
    length_penalty=1.0,
    repetition_penalty=2.0,
    top_k=50,
    top_p=0.85,
    enable_text_splitting=False,
    gpt_cond_len=20,
    gpt_cond_chunk_len=8,
    speed=1.0,
)

NIX_DRY = "I told you the cursor would come back. Reboots are not supposed to be a personality event."

trials = [
    ("01-baseline-fixed",
     NIX_DRY,
     dict(common_kwargs)),
    ("02-slower",
     NIX_DRY,
     dict(common_kwargs, speed=0.92)),
    ("03-lower-temp",
     NIX_DRY,
     dict(common_kwargs, temperature=0.65)),
    ("04-low-rep-penalty",
     NIX_DRY,
     dict(common_kwargs, repetition_penalty=1.5)),
    ("05-real-nix-line",
     "Plymouth quit retain-splash didn't take. We're getting a black flash on the handoff. I'll dig into it.",
     dict(common_kwargs)),
]

for label, text, kwargs in trials:
    out_path = OUT / f"{label}.wav"
    print(f"  [{label}] '{text[:60]}{'...' if len(text)>60 else ''}'")
    try:
        tts.tts_to_file(
            text=text,
            speaker_wav=str(ref),
            language="en",
            file_path=str(out_path),
            **kwargs,
        )
    except Exception as e:
        print(f"    FAIL: {e}")
        continue
    # Keep XTTS native 24 kHz for evaluation. Convert to mono only.
    final = OUT / f"{label}.mono.wav"
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", str(out_path),
        "-ac", "1", "-sample_fmt", "s16",
        str(final),
    ], check=True)
    out_path.unlink()
    final.rename(out_path)

print("done. files in", OUT)
for f in sorted(OUT.glob("*.wav")):
    print(" ", f.name)
