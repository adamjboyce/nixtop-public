#!/usr/bin/env python3
"""
Nix voice cache baker.

Reads ~/.nix/voice/manifest.json, synthesizes any phrase whose `wav` is null
(or where --rebake is passed) using XTTS v2 with the configured reference
clip, post-processes with silence trim and optional carrier-extraction, and
writes the cleaned wav to ~/.nix/voice/cache/<mood>/<key>.wav.

Phrase fields honored:
    text     — what to say (or what to extract from the carrier output)
    carrier  — optional; if present, bake this sentence and extract `text`
               from it via whisper word-level timestamps. Use for short
               phrases (<=4 syllables) where XTTS struggles for context.
    source   — if present and `text` is null, this entry is non-synthesized
               (e.g. harvested) and bake.py will skip it.

Usage:
    bake.py                    # bake everything still null
    bake.py --rebake           # rebake everything (skips harvested entries)
    bake.py --only your-move   # bake just one key
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path.home() / ".nix" / "voice"
MANIFEST = ROOT / "manifest.json"
CACHE = ROOT / "cache"
REFS = ROOT / "refs"

# Round 3 winning params (validated against Adam's ear 2026-04-12).
XTTS_KWARGS = dict(
    temperature=0.75,
    length_penalty=1.0,
    repetition_penalty=2.0,
    top_k=50,
    top_p=0.85,
    enable_text_splitting=False,
)


def load_manifest():
    return json.loads(MANIFEST.read_text())


def save_manifest(m):
    MANIFEST.write_text(json.dumps(m, indent=2) + "\n")


def trim_silence(in_path, out_path, threshold_db=-30, min_silence=0.1):
    """Trim leading + trailing silence, preserve internal pauses."""
    f = (
        f"silenceremove=start_periods=1:start_silence={min_silence}:start_threshold={threshold_db}dB,"
        f"areverse,"
        f"silenceremove=start_periods=1:start_silence={min_silence}:start_threshold={threshold_db}dB,"
        f"areverse"
    )
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", str(in_path),
        "-af", f,
        str(out_path),
    ], check=True)


def to_target_format(in_path, out_path, fmt):
    sr = fmt["sample_rate"]
    ch = fmt["channels"]
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", str(in_path),
        "-ac", str(ch),
        "-ar", str(sr),
        "-sample_fmt", "s16",
        str(out_path),
    ], check=True)


def extract_target_via_whisper(carrier_wav_path, target_text, whisper_model):
    """Use whisper word-level timestamps to find target_text in carrier audio.
    Returns (start_seconds, end_seconds) of the target span, or None on miss."""
    target_words = target_text.lower().strip().rstrip(".,!?").split()
    segs, _ = whisper_model.transcribe(
        str(carrier_wav_path),
        beam_size=1,
        word_timestamps=True,
        vad_filter=False,
    )
    all_words = []
    for s in segs:
        if s.words:
            all_words.extend(s.words)
    norm = lambda w: w.word.lower().strip().strip(".,!?")
    n = len(target_words)
    for i in range(len(all_words) - n + 1):
        if [norm(w) for w in all_words[i:i + n]] == target_words:
            return (all_words[i].start, all_words[i + n - 1].end)
    print(f"    WARN: target '{target_text}' not found in carrier transcription")
    print(f"    transcribed words: {[norm(w) for w in all_words]}")
    return None


def synth_one(tts, phrase, ref_wav, target_format, whisper_model):
    """Synthesize one phrase, post-process, write to cache, return relative path."""
    key = phrase["key"]
    mood = phrase["mood"]
    text = phrase["text"]
    carrier = phrase.get("carrier")

    if text is None:
        # Non-synthesized (harvested) entry — leave existing wav alone.
        print(f"  [{key}] skipping (harvested entry, source={phrase.get('source','?')[:40]}...)")
        return phrase.get("wav")

    out_dir = CACHE / mood
    out_dir.mkdir(parents=True, exist_ok=True)
    raw_path = out_dir / f"{key}.raw.wav"
    cut_path = out_dir / f"{key}.cut.wav"
    trim_path = out_dir / f"{key}.trim.wav"
    final_path = out_dir / f"{key}.wav"

    bake_text = carrier if carrier else text
    print(f"  [{key}] '{bake_text}'" + (f" -> extract '{text}'" if carrier else ""))

    tts.tts_to_file(
        text=bake_text,
        speaker_wav=str(ref_wav),
        language="en",
        file_path=str(raw_path),
        **XTTS_KWARGS,
    )

    # If carrier mode, find target words in raw and cut to that span first.
    work_path = raw_path
    if carrier:
        span = extract_target_via_whisper(raw_path, text, whisper_model)
        if span:
            start, end = span
            pad = 0.05
            subprocess.run([
                "ffmpeg", "-y", "-loglevel", "error",
                "-ss", str(max(0, start - pad)),
                "-to", str(end + pad),
                "-i", str(raw_path),
                str(cut_path),
            ], check=True)
            work_path = cut_path

    # Trim leading + trailing silence (preserve internal pauses).
    trim_silence(work_path, trim_path)

    # Resample to manifest target format.
    to_target_format(trim_path, final_path, target_format)

    # Cleanup intermediates.
    for p in (raw_path, cut_path, trim_path):
        if p.exists():
            p.unlink()

    return str(final_path.relative_to(ROOT))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="bake only this key (test mode)")
    ap.add_argument("--rebake", action="store_true", help="rebake even if wav exists")
    args = ap.parse_args()

    m = load_manifest()
    ref_clip = m["voice"].get("reference_clip") or "refs/cate-v1.wav"
    ref_path = ROOT / ref_clip
    if not ref_path.exists():
        sys.exit(f"reference clip missing: {ref_path}")

    target_format = m["voice"]["format"]

    todo = []
    for p in m["phrases"]:
        if args.only and p["key"] != args.only:
            continue
        if p["text"] is None:
            continue  # harvested entries never get baked
        if p["wav"] and not args.rebake:
            continue
        todo.append(p)

    if not todo:
        print("nothing to bake.")
        return

    print(f"reference: {ref_clip}")
    print(f"phrases to bake: {len(todo)}")

    needs_whisper = any(p.get("carrier") for p in todo)
    whisper_model = None
    if needs_whisper:
        print("loading faster-whisper (base, int8) for carrier extraction...")
        from faster_whisper import WhisperModel
        whisper_model = WhisperModel("base", device="cpu", compute_type="int8")

    print("loading XTTS v2...")
    os.environ["COQUI_TOS_AGREED"] = "1"
    from TTS.api import TTS
    tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2", progress_bar=False)

    for p in todo:
        rel = synth_one(tts, p, ref_path, target_format, whisper_model)
        for entry in m["phrases"]:
            if entry["key"] == p["key"]:
                entry["wav"] = rel
                break

    m["voice"]["reference_clip"] = ref_clip
    m["voice"]["engine_version"] = "coqui-tts xtts_v2 (round-3 params)"
    save_manifest(m)
    print("done.")


if __name__ == "__main__":
    main()
