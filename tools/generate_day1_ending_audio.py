"""Generate original, loop-safe Day 1 ending ambience and foley at 48 kHz."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio" / "day1" / "ending"
RATE = 48_000
RNG = random.Random(19072026)


def write_mono(name: str, samples: list[float], target_peak: float = 0.38) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    peak = max(max(abs(value) for value in samples), 1e-6)
    gain = min(target_peak / peak, 6.0)
    pcm = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, value * gain)) * 32767)) for value in samples)
    with wave.open(str(OUT / name), "wb") as target:
        target.setnchannels(1)
        target.setsampwidth(2)
        target.setframerate(RATE)
        target.writeframes(pcm)


def loop_noise(seconds: float, mood: str) -> list[float]:
    count = int(RATE * seconds)
    samples: list[float] = []
    filtered = 0.0
    for index in range(count):
        t = index / RATE
        phase = t / seconds
        seam = math.sin(math.pi * phase) ** 2
        white = RNG.uniform(-1.0, 1.0)
        filtered = filtered * 0.997 + white * 0.003
        wind = filtered * (0.42 + 0.16 * math.sin(math.tau * t / 7.0))
        if mood == "night":
            tone = 0.035 * math.sin(math.tau * 54 * t) + 0.018 * math.sin(math.tau * 91 * t)
            insects = 0.014 * math.sin(math.tau * 3120 * t) * max(0.0, math.sin(math.tau * t / 2.7))
            value = wind * 0.32 + tone + insects
        elif mood == "truth":
            pad = 0.055 * math.sin(math.tau * 110 * t) + 0.04 * math.sin(math.tau * 164.8 * t)
            bell = 0.028 * math.sin(math.tau * 660 * t) * (max(0.0, math.sin(math.tau * t / 5.0)) ** 8)
            value = wind * 0.16 + pad + bell
        elif mood == "propaganda":
            drone = 0.05 * math.sin(math.tau * 72 * t) + 0.024 * math.sin(math.tau * 144 * t)
            radio = RNG.uniform(-0.04, 0.04) if int(t * 7) % 17 in (0, 1) else 0.0
            value = wind * 0.15 + drone + radio
        else:
            pulse = (max(0.0, math.sin(math.tau * 0.82 * t)) ** 16) * math.sin(math.tau * 58 * t)
            value = wind * 0.08 + pulse * 0.11 + 0.025 * math.sin(math.tau * 43 * t)
        samples.append(value * (0.75 + seam * 0.25))
    fade = int(RATE * 0.08)
    for index in range(fade):
        mix = index / fade
        blended = samples[index] * mix + samples[-fade + index] * (1.0 - mix)
        samples[index] = blended
        samples[-fade + index] = blended
    return samples


def door_latch() -> list[float]:
    seconds = 0.72
    count = int(RATE * seconds)
    values: list[float] = []
    for index in range(count):
        t = index / RATE
        click = math.exp(-t * 42) * (0.5 * math.sin(math.tau * 920 * t) + RNG.uniform(-0.3, 0.3))
        thunk_time = max(0.0, t - 0.23)
        thunk = math.exp(-thunk_time * 18) * math.sin(math.tau * 92 * thunk_time) if t >= 0.23 else 0.0
        values.append(click * 0.55 + thunk * 0.62)
    return values


def main() -> None:
    write_mono("night-ambience.wav", loop_noise(12.0, "night"))
    write_mono("truth-memorial.wav", loop_noise(12.0, "truth"))
    write_mono("propaganda-patrol.wav", loop_noise(12.0, "propaganda"))
    write_mono("room-pulse.wav", loop_noise(10.0, "room"))
    write_mono("door-latch.wav", door_latch(), 0.62)


if __name__ == "__main__":
    main()
