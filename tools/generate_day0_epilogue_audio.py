"""Generate original, loop-safe Day Zero curtain ambience, music, and impact SFX."""

from __future__ import annotations

import math
from pathlib import Path
import wave

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/audio/epilogue"
RATE = 48_000


def _seam(samples: np.ndarray, seconds: float = 0.12) -> np.ndarray:
    width = int(seconds * RATE)
    start = samples[:width].copy()
    fade = np.linspace(0.0, 1.0, width, endpoint=False)
    if samples.ndim == 2:
        fade = fade[:, None]
    samples[-width:] = samples[-width:] * (1.0 - fade) + start * fade
    return samples


def ambience() -> np.ndarray:
    duration = 10.0
    count = int(duration * RATE)
    t = np.arange(count) / RATE
    rng = np.random.default_rng(701)
    noise = rng.normal(0.0, 1.0, count)
    noise = np.convolve(noise, np.ones(1600) / 1600.0, mode="same")
    wind = 0.14 * np.sin(2.0 * math.pi * 0.2 * t)
    wind += 0.08 * np.sin(2.0 * math.pi * 0.5 * t + 1.1)
    room = 0.08 * np.sin(2.0 * math.pi * 47.0 * t)
    return _seam((noise * 2.7 + wind + room) * 0.52)


def music() -> np.ndarray:
    duration = 12.0
    count = int(duration * RATE)
    t = np.arange(count) / RATE
    # Frequencies complete whole cycles over twelve seconds, keeping the drone loop clean.
    frequencies = [55.0, 65.4166667, 82.5, 110.0]
    chord = sum(np.sin(2.0 * math.pi * frequency * t + index * 0.7) / (index + 1.0) for index, frequency in enumerate(frequencies))
    pulse = 0.72 + 0.18 * np.sin(2.0 * math.pi * 0.1666667 * t)
    shimmer = 0.06 * np.sin(2.0 * math.pi * 220.0 * t) * (0.5 + 0.5 * np.sin(2.0 * math.pi * 0.0833333 * t))
    left = (chord * pulse + shimmer) * 0.32
    right = (chord * (0.70 + 0.16 * np.sin(2.0 * math.pi * 0.1666667 * t + 0.8)) - shimmer) * 0.32
    return _seam(np.column_stack((left, right)))


def curtain_impact() -> np.ndarray:
    duration = 0.85
    count = int(duration * RATE)
    t = np.arange(count) / RATE
    rng = np.random.default_rng(409)
    thump = np.sin(2.0 * math.pi * (68.0 - 24.0 * t) * t) * np.exp(-t * 7.2)
    cloth = rng.normal(0.0, 1.0, count)
    cloth = np.convolve(cloth, np.ones(16) / 16.0, mode="same") * np.exp(-t * 5.0)
    tail = np.sin(2.0 * math.pi * 34.0 * t) * np.exp(-t * 4.8)
    return thump * 0.65 + cloth * 0.42 + tail * 0.24


def write(name: str, samples: np.ndarray, peak: float) -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    maximum = max(float(np.max(np.abs(samples))), 1e-6)
    pcm = np.int16(np.clip(samples / maximum * peak, -1.0, 1.0) * 32767)
    channels = 1 if samples.ndim == 1 else samples.shape[1]
    with wave.open(str(OUTPUT / name), "wb") as stream:
        stream.setnchannels(channels)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())


def main() -> None:
    write("day0-curtain-ambience.wav", ambience(), 0.38)
    write("day0-curtain-music.wav", music(), 0.44)
    write("curtain-impact.wav", curtain_impact(), 0.72)
    print(f"Generated Day Zero epilogue audio in {OUTPUT}")


if __name__ == "__main__":
    main()
