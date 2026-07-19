"""Generate deterministic original audio for the Day 3 finale.

All files are 48 kHz PCM WAV. Looping ambience is generated with periodic
components and crossfaded noise so Godot can loop it without a click.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


RATE = 48_000
ROOT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "day3"
RNG = random.Random(330393)


def envelope(t: float, duration: float, attack: float = 0.01, release: float = 0.12) -> float:
    return min(1.0, t / max(attack, 1e-6), (duration - t) / max(release, 1e-6))


def periodic_noise(length: int, scale: float = 1.0) -> list[float]:
    half = max(1, length // 2)
    seed = [RNG.uniform(-scale, scale) for _ in range(half)]
    return seed + seed[: length - half]


def write_wav(name: str, samples: list[float] | list[tuple[float, float]], channels: int = 1) -> None:
    path = ROOT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(channels)
        out.setsampwidth(2)
        out.setframerate(RATE)
        frames = bytearray()
        if channels == 1:
            for value in samples:
                frames.extend(struct.pack("<h", int(max(-1.0, min(1.0, float(value))) * 32767)))
        else:
            for left, right in samples:
                frames.extend(struct.pack("<hh", int(max(-1.0, min(1.0, left)) * 32767), int(max(-1.0, min(1.0, right)) * 32767)))
        out.writeframes(frames)


def room_hvac() -> list[float]:
    duration = 12.0
    count = int(duration * RATE)
    noise = periodic_noise(count, 1.0)
    return [
        0.11 * math.sin(2 * math.pi * 49 * i / RATE)
        + 0.055 * math.sin(2 * math.pi * 98 * i / RATE)
        + 0.025 * noise[i]
        for i in range(count)
    ]


def fluorescent() -> list[float]:
    duration = 8.0
    count = int(duration * RATE)
    noise = periodic_noise(count, 1.0)
    return [0.08 * math.sin(2 * math.pi * 120 * i / RATE) + 0.018 * noise[i] for i in range(count)]


def heartbeat() -> list[float]:
    duration = 4.0
    result = [0.0] * int(duration * RATE)
    for beat in (0.15, 0.43, 1.25, 1.53, 2.35, 2.63, 3.45, 3.73):
        for i in range(int(0.22 * RATE)):
            index = int(beat * RATE) + i
            if index >= len(result):
                break
            t = i / RATE
            result[index] += 0.44 * math.sin(2 * math.pi * (58 - 28 * t) * t) * math.exp(-22 * t)
    return result


def breathing() -> list[float]:
    duration = 5.0
    count = int(duration * RATE)
    noise = periodic_noise(count, 1.0)
    result = []
    for i in range(count):
        t = i / RATE
        breath = max(0.0, math.sin(2 * math.pi * 0.42 * t)) ** 1.7
        result.append(noise[i] * breath * 0.16)
    return result


def impact(duration: float, body_freq: float, peak: float, noise_amount: float) -> list[float]:
    count = int(duration * RATE)
    result = []
    for i in range(count):
        t = i / RATE
        transient = RNG.uniform(-1, 1) * noise_amount * math.exp(-70 * t)
        body = math.sin(2 * math.pi * body_freq * t) * math.exp(-9 * t)
        result.append((transient + body) * peak * envelope(t, duration, 0.002, 0.08))
    return result


def paper() -> list[float]:
    duration = 0.9
    count = int(duration * RATE)
    return [RNG.uniform(-1, 1) * 0.22 * envelope(i / RATE, duration, 0.02, 0.18) * (0.5 + 0.5 * math.sin(2 * math.pi * 7 * i / RATE) ** 2) for i in range(count)]


def radio_click() -> list[float]:
    duration = 0.28
    count = int(duration * RATE)
    return [
        (RNG.uniform(-1, 1) * 0.16 + math.sin(2 * math.pi * 920 * i / RATE) * 0.18)
        * envelope(i / RATE, duration, 0.003, 0.08)
        for i in range(count)
    ]


def crowd_shock() -> list[tuple[float, float]]:
    duration = 6.0
    count = int(duration * RATE)
    left_noise = periodic_noise(count, 1.0)
    right_noise = periodic_noise(count, 1.0)
    result = []
    for i in range(count):
        t = i / RATE
        swell = 0.12 + 0.06 * math.sin(2 * math.pi * 0.23 * t)
        murmur_l = left_noise[i] * swell + 0.03 * math.sin(2 * math.pi * 174 * t)
        murmur_r = right_noise[i] * swell + 0.03 * math.sin(2 * math.pi * 213 * t)
        result.append((murmur_l, murmur_r))
    return result


def helicopter() -> list[tuple[float, float]]:
    duration = 8.0
    count = int(duration * RATE)
    result = []
    for i in range(count):
        t = i / RATE
        rotor = 0.14 * math.sin(2 * math.pi * 17 * t) + 0.08 * math.sin(2 * math.pi * 34 * t)
        pan = math.sin(2 * math.pi * t / duration)
        result.append((rotor * (0.8 - 0.15 * pan), rotor * (0.8 + 0.15 * pan)))
    return result


def siren() -> list[tuple[float, float]]:
    duration = 8.0
    count = int(duration * RATE)
    result = []
    for i in range(count):
        t = i / RATE
        freq = 610 + 130 * math.sin(2 * math.pi * 0.19 * t)
        tone = 0.105 * math.sin(2 * math.pi * freq * t)
        result.append((tone * 0.88, tone))
    return result


def tv_static() -> list[float]:
    duration = 7.0
    count = int(duration * RATE)
    noise = periodic_noise(count, 1.0)
    return [(0.055 * noise[i] + 0.018 * math.sin(2 * math.pi * 60 * i / RATE)) for i in range(count)]


def stinger(minor: bool) -> list[tuple[float, float]]:
    duration = 3.2
    count = int(duration * RATE)
    freqs = (55.0, 65.41, 82.41) if minor else (55.0, 69.30, 82.41)
    result = []
    for i in range(count):
        t = i / RATE
        env = envelope(t, duration, 0.08, 1.8) * math.exp(-0.35 * t)
        left = sum(math.sin(2 * math.pi * f * t) for f in freqs) * 0.065 * env
        right = sum(math.sin(2 * math.pi * (f * 1.003) * t) for f in freqs) * 0.065 * env
        result.append((left, right))
    return result


def main() -> None:
    write_wav("ambience/briefing-hvac.wav", room_hvac())
    write_wav("ambience/fluorescent-hum.wav", fluorescent())
    write_wav("ambience/crowd-shock.wav", crowd_shock(), 2)
    write_wav("ambience/helicopter.wav", helicopter(), 2)
    write_wav("ambience/emergency-siren.wav", siren(), 2)
    write_wav("ambience/tv-static.wav", tv_static())
    write_wav("sfx/heartbeat.wav", heartbeat())
    write_wav("sfx/heavy-breathing.wav", breathing())
    write_wav("sfx/briefcase-latch.wav", impact(0.55, 150, 0.55, 0.55))
    write_wav("sfx/paper-handoff.wav", paper())
    write_wav("sfx/table-contact.wav", impact(0.65, 92, 0.58, 0.4))
    write_wav("sfx/door-latch.wav", impact(0.45, 210, 0.52, 0.45))
    write_wav("sfx/body-fall.wav", impact(1.05, 54, 0.72, 0.42))
    write_wav("sfx/radio-click.wav", radio_click())
    write_wav("music/death-stinger.wav", stinger(True), 2)
    write_wav("music/shoot-stinger.wav", stinger(False), 2)


if __name__ == "__main__":
    main()
