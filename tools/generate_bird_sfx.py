"""Generate original pigeon coos and wing-flap effects as 48 kHz mono WAVs."""

from __future__ import annotations

import math
from pathlib import Path
import wave

import numpy as np


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = PROJECT_ROOT / "assets/audio/sfx/birds"
SAMPLE_RATE = 48_000


def _smooth_noise(rng: np.random.Generator, count: int, width: int) -> np.ndarray:
    noise = rng.normal(0.0, 1.0, count + width - 1)
    kernel = np.hanning(width)
    kernel /= kernel.sum()
    return np.convolve(noise, kernel, mode="valid")


def _soft_envelope(local_time: np.ndarray, duration: float, attack: float = 0.08) -> np.ndarray:
    attack_curve = np.clip(local_time / attack, 0.0, 1.0)
    release_curve = np.clip((duration - local_time) / (duration * 0.45), 0.0, 1.0)
    return np.sin(attack_curve * math.pi * 0.5) * np.sin(release_curve * math.pi * 0.5)


def make_flap(seed: int, spacing: float, weight: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    duration = 0.9
    count = int(duration * SAMPLE_RATE)
    time = np.arange(count) / SAMPLE_RATE
    sound = np.zeros(count)

    for index, onset in enumerate([0.04, 0.04 + spacing, 0.04 + spacing * 2.0, 0.04 + spacing * 3.0]):
        local = time - onset
        valid = (local >= 0.0) & (local < 0.16)
        phase = local[valid]
        envelope = np.exp(-phase * (24.0 + index * 2.0)) * np.sin(np.clip(phase / 0.018, 0.0, 1.0) * math.pi * 0.5)
        noise = _smooth_noise(rng, valid.sum(), 42 - index * 5)
        body = np.sin(2.0 * math.pi * (78.0 + index * 9.0) * phase) * np.exp(-phase * 18.0)
        sound[valid] += (noise * 0.75 + body * weight) * envelope * (1.0 - index * 0.08)

    air = _smooth_noise(rng, count, 180)
    sound += air * np.exp(-time * 3.2) * 0.055
    return sound


def make_coo(seed: int, notes: list[tuple[float, float, float, float]]) -> np.ndarray:
    rng = np.random.default_rng(seed)
    duration = max(start + length for start, length, _frequency, _fall in notes) + 0.18
    count = int(duration * SAMPLE_RATE)
    time = np.arange(count) / SAMPLE_RATE
    sound = np.zeros(count)

    for start, length, frequency, fall in notes:
        local = time - start
        valid = (local >= 0.0) & (local < length)
        phase_time = local[valid]
        envelope = _soft_envelope(phase_time, length)
        vibrato = 1.0 + 0.015 * np.sin(2.0 * math.pi * 5.1 * phase_time)
        instantaneous = (frequency - fall * phase_time / length) * vibrato
        phase = 2.0 * math.pi * np.cumsum(instantaneous) / SAMPLE_RATE
        voice = (
            np.sin(phase)
            + 0.38 * np.sin(phase * 2.0 + 0.3)
            + 0.16 * np.sin(phase * 3.0 + 0.8)
        )
        breath = _smooth_noise(rng, valid.sum(), 96) * 0.055
        sound[valid] += (voice * 0.62 + breath) * envelope

    return sound


def write_wav(name: str, samples: np.ndarray) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    fade_count = min(480, samples.size // 4)
    samples[:fade_count] *= np.linspace(0.0, 1.0, fade_count)
    samples[-fade_count:] *= np.linspace(1.0, 0.0, fade_count)
    peak = max(float(np.max(np.abs(samples))), 1e-6)
    pcm = np.int16(np.clip(samples / peak * 0.78, -1.0, 1.0) * 32767)

    with wave.open(str(OUTPUT_DIR / name), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def main() -> None:
    write_wav("pigeon_flap_a.wav", make_flap(1201, 0.19, 0.42))
    write_wav("pigeon_flap_b.wav", make_flap(1202, 0.16, 0.34))
    write_wav("pigeon_coo_a.wav", make_coo(2201, [(0.04, 0.48, 142.0, 22.0), (0.56, 0.42, 128.0, 16.0)]))
    write_wav("pigeon_coo_b.wav", make_coo(2202, [(0.04, 0.38, 132.0, 12.0), (0.44, 0.5, 154.0, 28.0)]))
    write_wav("pigeon_coo_c.wav", make_coo(2203, [(0.04, 0.34, 148.0, 20.0), (0.41, 0.34, 136.0, 14.0), (0.8, 0.42, 120.0, 18.0)]))
    print(f"Generated 5 bird SFX in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
