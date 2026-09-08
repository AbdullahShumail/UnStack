"""Synthesises the game's sound effects.

Run with:  python tool/make_sounds.py

The clips are generated rather than sourced so they are reproducible, tiny,
and free of licensing questions. Everything is mono 22.05 kHz 16-bit PCM,
which is plenty for short UI sounds and keeps the APK small.
"""

import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    peak = max(1e-9, max(abs(s) for s in samples))
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s / peak * 0.86)) * 32767))
        for s in samples
    )
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(frames)
    print("%-14s %6d bytes" % (name, os.path.getsize(path)))


def swoosh(duration=0.34, seed=7):
    """Arrow leaving the board: filtered noise with a rising then falling
    cutoff, so it reads as something accelerating past the ear."""
    rng = random.Random(seed)
    n = int(RATE * duration)
    out = []
    lp = 0.0
    bp = 0.0
    for i in range(n):
        t = i / n
        # Envelope: quick swell, long tail.
        env = (t / 0.16) if t < 0.16 else math.exp(-(t - 0.16) * 6.5)
        # Cutoff sweeps up then back down — the "whoosh" shape.
        sweep = math.sin(math.pi * t)
        cutoff = 0.06 + 0.55 * sweep
        noise = rng.uniform(-1.0, 1.0)
        lp += cutoff * (noise - lp)
        # Subtracting a slower follower leaves a band, which sounds like air
        # rather than static.
        bp += 0.10 * (lp - bp)
        out.append((lp - bp) * env)
    return out


def tick(duration=0.045, pitch=1650.0):
    """Clock tick: a short pitched click with a hard transient."""
    n = int(RATE * duration)
    out = []
    for i in range(n):
        t = i / n
        env = math.exp(-t * 34)
        body = math.sin(2 * math.pi * pitch * (i / RATE))
        click = math.exp(-t * 160) * 0.9
        out.append((body * 0.55 + click) * env)
    return out


def thud(duration=0.16):
    """Blocked arrow: a low, damped knock."""
    n = int(RATE * duration)
    out = []
    for i in range(n):
        t = i / n
        env = math.exp(-t * 16)
        # Pitch drops slightly, which is what makes it read as a knock.
        freq = 190.0 * (1.0 - 0.35 * t)
        out.append(math.sin(2 * math.pi * freq * (i / RATE)) * env)
    return out


def chime(duration=0.7):
    """Level cleared: a small three-note major arpeggio."""
    n = int(RATE * duration)
    out = [0.0] * n
    for k, freq in enumerate((660.0, 880.0, 1320.0)):
        start = int(n * k * 0.13)
        for i in range(start, n):
            t = (i - start) / n
            env = math.exp(-t * 5.0)
            out[i] += math.sin(2 * math.pi * freq * ((i - start) / RATE)) * env * 0.5
    return out


if __name__ == "__main__":
    write("swoosh.wav", swoosh())
    write("tick.wav", tick())
    write("tick_urgent.wav", tick(duration=0.06, pitch=2100.0))
    write("thud.wav", thud())
    write("clear.wav", chime())
