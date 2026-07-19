"""Prepare Day 1 camera-cutscene illustrations and 48 kHz mono audio."""

from __future__ import annotations

from pathlib import Path
import shutil

import numpy as np
from PIL import Image
from scipy.io import wavfile
from scipy.signal import butter, lfilter, resample_poly


ROOT = Path(__file__).resolve().parents[1]
ART_DIR = ROOT / "assets/art/Day1 Scene 1/camera-cutscene"
AUDIO_DIR = ROOT / "assets/audio/day1/cutscene"
SOURCE_DIR = AUDIO_DIR / "source"
FRAME_1 = Path(r"C:\Users\alfar\Pictures\Scene01\broadcast v2\1.png")
FRAME_2 = Path(r"C:\Users\alfar\Pictures\Scene01\broadcast v2\2.png")
THWACK_DIR = SOURCE_DIR / "thwack-files/PCM"
RATE = 48_000
RNG = np.random.default_rng(1701)


def normalize(signal: np.ndarray, peak: float = 0.88) -> np.ndarray:
    maximum = float(np.max(np.abs(signal))) if signal.size else 0.0
    return signal if maximum <= 1e-8 else signal * (peak / maximum)


def write(name: str, signal: np.ndarray, peak: float = 0.88) -> None:
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    pcm = np.int16(np.clip(normalize(signal, peak), -1.0, 1.0) * 32767)
    wavfile.write(AUDIO_DIR / name, RATE, pcm)
    print(f"Wrote {name}: {len(signal) / RATE:.2f}s")


def read_mono(path: Path) -> np.ndarray:
    rate, data = wavfile.read(path)
    signal = data.astype(np.float32)
    if data.dtype.kind in "iu":
        signal /= float(np.iinfo(data.dtype).max)
    if signal.ndim > 1:
        signal = signal.mean(axis=1)
    if rate != RATE:
        signal = resample_poly(signal, RATE, rate)
    return normalize(signal, 0.8)


def filtered_noise(seconds: float, low: float, high: float) -> np.ndarray:
    samples = int(seconds * RATE)
    noise = RNG.normal(0.0, 1.0, samples)
    b, a = butter(3, [low / (RATE * 0.5), high / (RATE * 0.5)], btype="band")
    return lfilter(b, a, noise)


def envelope(seconds: float, attack: float, release: float) -> np.ndarray:
    samples = int(seconds * RATE)
    env = np.ones(samples)
    attack_samples = max(1, int(attack * RATE))
    release_samples = max(1, int(release * RATE))
    env[:attack_samples] = np.linspace(0.0, 1.0, attack_samples)
    env[-release_samples:] = np.linspace(1.0, 0.0, release_samples)
    return env


def place(destination: np.ndarray, source: np.ndarray, seconds: float, gain: float = 1.0) -> None:
    start = int(seconds * RATE)
    count = min(len(source), len(destination) - start)
    if count > 0:
        destination[start : start + count] += source[:count] * gain


def prepare_frames() -> None:
    ART_DIR.mkdir(parents=True, exist_ok=True)
    for source, name in [(FRAME_1, "frame-1-soldier-hit.png"), (FRAME_2, "frame-2-civilian-shove.png")]:
        if not source.exists():
            raise FileNotFoundError(source)
        image = Image.open(source).convert("RGB")
        image.save(ART_DIR / name, optimize=True)
        print(f"Wrote {name}: {image.size}")


def prepare_audio() -> None:
    hit = read_mono(THWACK_DIR / "thwack-08.wav")
    shove_source = read_mono(THWACK_DIR / "thwack-04.wav")
    write("impact-hit-cc0.wav", hit)

    scuffle = filtered_noise(2.4, 120.0, 2800.0) * 0.14
    for time, source, gain in [(0.05, hit, 0.7), (0.48, shove_source, 0.6), (0.92, hit, 0.42), (1.42, shove_source, 0.48), (1.9, hit, 0.35)]:
        place(scuffle, source, time, gain)
    write("scuffle-cc0.wav", scuffle, 0.76)

    shove = filtered_noise(0.48, 75.0, 900.0) * envelope(0.48, 0.005, 0.42)
    place(shove, shove_source, 0.0, 0.9)
    write("shove.wav", shove)

    click = np.zeros(int(0.22 * RATE))
    for time, frequency, gain in [(0.0, 2200.0, 0.8), (0.055, 1450.0, 0.55), (0.115, 800.0, 0.32)]:
        start = int(time * RATE)
        length = int(0.028 * RATE)
        t = np.arange(length) / RATE
        pulse = np.sin(2.0 * np.pi * frequency * t) * np.exp(-t * 95.0) * gain
        click[start : start + length] += pulse
    write("camera-click.wav", click, 0.72)

    gunshot = np.zeros(int(1.35 * RATE))
    blast = filtered_noise(0.16, 80.0, 9000.0) * envelope(0.16, 0.001, 0.15)
    place(gunshot, blast, 0.0, 1.0)
    t = np.arange(len(gunshot)) / RATE
    gunshot += np.sin(2.0 * np.pi * 54.0 * t) * np.exp(-t * 5.2) * 0.65
    gunshot += filtered_noise(1.35, 40.0, 1200.0) * np.exp(-t * 3.7) * 0.25
    write("gunshot.wav", gunshot, 0.95)

    blip_seconds = 0.075
    t = np.arange(int(blip_seconds * RATE)) / RATE
    blip = (np.sign(np.sin(2.0 * np.pi * 118.0 * t)) * 0.62 + RNG.normal(0.0, 0.2, len(t)))
    blip *= np.exp(-t * 39.0)
    write("tense-dialogue-blip.wav", blip, 0.45)

    running = np.zeros(int(3.0 * RATE))
    step = filtered_noise(0.15, 65.0, 1250.0) * envelope(0.15, 0.002, 0.14)
    for index, time in enumerate(np.arange(0.0, 2.85, 0.27)):
        place(running, step, float(time), 0.8 if index % 2 else 1.0)
    write("running-away.wav", running, 0.72)

    breathing = np.zeros(int(8.0 * RATE))
    breath_noise = filtered_noise(0.82, 180.0, 1900.0)
    breath_noise *= np.sin(np.linspace(0.0, np.pi, len(breath_noise))) ** 1.7
    for index, time in enumerate(np.arange(0.15, 7.7, 0.95)):
        place(breathing, breath_noise, float(time), 0.55 + 0.08 * (index % 2))
    write("mc-heavy-breathing.wav", breathing, 0.56)

    crowd = filtered_noise(8.0, 150.0, 2200.0) * 0.24
    t = np.arange(len(crowd)) / RATE
    crowd *= 0.72 + 0.28 * np.sin(2.0 * np.pi * 0.37 * t)
    for time, freq in [(0.3, 420.0), (1.1, 510.0), (2.0, 360.0), (3.4, 560.0), (5.0, 440.0), (6.2, 620.0)]:
        length = int(0.7 * RATE)
        vt = np.arange(length) / RATE
        cry = np.sin(2 * np.pi * (freq + 90 * vt) * vt) * np.sin(np.pi * vt / 0.7) * 0.22
        place(crowd, cry, time)
    write("crowd-panic.wav", crowd, 0.62)

    ambience_seconds = 14.0
    t = np.arange(int(ambience_seconds * RATE)) / RATE
    ambience = (
        np.sin(2 * np.pi * 43.0 * t) * 0.34
        + np.sin(2 * np.pi * 64.5 * t + 0.7) * 0.18
        + np.sin(2 * np.pi * 86.0 * t + 1.8) * 0.09
    )
    ambience *= 0.76 + 0.24 * np.sin(2 * np.pi * 0.0714 * t)
    ambience += filtered_noise(ambience_seconds, 90.0, 700.0) * 0.06
    fade = int(0.4 * RATE)
    ambience[:fade] *= np.linspace(0.0, 1.0, fade)
    ambience[-fade:] *= np.linspace(1.0, 0.0, fade)
    write("tense-ambience.wav", ambience, 0.48)


def main() -> None:
    prepare_frames()
    prepare_audio()
    source_copy = SOURCE_DIR / "thwack-1.0-license.txt"
    shutil.copy2(SOURCE_DIR / "thwack-files/LICENSE.txt", source_copy)


if __name__ == "__main__":
    main()
