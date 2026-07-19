"""Generate original 48 kHz mono dialogue blips used by world encounters."""

from __future__ import annotations

import math
from pathlib import Path
import wave

import numpy as np


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = PROJECT_ROOT / "assets/audio/ui"
DAY1_BROADCAST_DIR = PROJECT_ROOT / "assets/audio/day1/broadcast"
SAMPLE_RATE = 48_000


def make_coarse_blip() -> np.ndarray:
    rng = np.random.default_rng(7319)
    duration = 0.075
    count = int(duration * SAMPLE_RATE)
    time = np.arange(count) / SAMPLE_RATE
    frequency = 118.0 - 24.0 * (time / duration)
    phase = 2.0 * math.pi * np.cumsum(frequency) / SAMPLE_RATE
    pulse = np.where(np.sin(phase) >= 0.0, 1.0, -1.0)
    saw = 2.0 * ((phase / (2.0 * math.pi)) % 1.0) - 1.0
    grit = rng.normal(0.0, 1.0, count)
    grit = np.convolve(grit, np.ones(7) / 7.0, mode="same")
    attack = np.clip(time / 0.004, 0.0, 1.0)
    release = np.exp(-time * 42.0)
    envelope = attack * release
    return (pulse * 0.52 + saw * 0.24 + grit * 0.2) * envelope


def make_phone_ring() -> np.ndarray:
    duration = 1.15
    count = int(duration * SAMPLE_RATE)
    time = np.arange(count) / SAMPLE_RATE
    carrier = 0.62 * np.sin(2.0 * math.pi * 440.0 * time)
    carrier += 0.32 * np.sin(2.0 * math.pi * 480.0 * time)
    tremolo = 0.58 + 0.42 * np.sin(2.0 * math.pi * 18.0 * time) ** 2
    gate = ((time < 0.42) | ((time > 0.58) & (time < 1.0))).astype(float)
    edge = np.minimum(np.clip((time % 0.58) / 0.012, 0.0, 1.0), 1.0)
    return carrier * tremolo * gate * edge


def make_call_disconnect() -> np.ndarray:
    duration = 0.32
    count = int(duration * SAMPLE_RATE)
    time = np.arange(count) / SAMPLE_RATE
    tone = np.sin(2.0 * math.pi * 310.0 * time) + 0.35 * np.sin(2.0 * math.pi * 620.0 * time)
    click = np.random.default_rng(912).normal(0.0, 0.7, count) * np.exp(-time * 90.0)
    envelope = np.exp(-time * 10.5)
    return tone * envelope * 0.46 + click


def write_wav(name: str, samples: np.ndarray, output_dir: Path = OUTPUT_DIR) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    samples[-240:] *= np.linspace(1.0, 0.0, 240)
    peak = max(float(np.max(np.abs(samples))), 1e-6)
    pcm = np.int16(np.clip(samples / peak * 0.72, -1.0, 1.0) * 32767)
    with wave.open(str(output_dir / name), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def main() -> None:
    write_wav("coarse-civilian-blip.wav", make_coarse_blip())
    write_wav("phone-ring.wav", make_phone_ring(), DAY1_BROADCAST_DIR)
    write_wav("call-disconnect.wav", make_call_disconnect(), DAY1_BROADCAST_DIR)
    print(f"Generated dialogue SFX in {OUTPUT_DIR} and {DAY1_BROADCAST_DIR}")


if __name__ == "__main__":
    main()
