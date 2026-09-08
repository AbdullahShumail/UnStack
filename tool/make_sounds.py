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


def swoosh(duration=0.42, seed=7):
    """Arrow leaving the board.

    A tuned downward sweep rather than a noise burst. The earlier version was
    filtered noise, which came out hissy and abrasive over a phone speaker; a
    pitched body with only a breath of air behind it reads as movement and
    stays pleasant when it fires hundreds of times a session.
    """
    rng = random.Random(seed)
    n = int(RATE * duration)
    out = []
    lp = 0.0
    phase = 0.0
    for i in range(n):
        t = i / n
        # Soft attack so it never clicks, long gentle tail.
        env = (1 - math.exp(-t * 45.0)) * math.exp(-t * 4.2)
        # Sweep down through the vocal range: high enough to cut through,
        # low enough not to be shrill.
        freq = 1150.0 * math.exp(-t * 1.5) + 240.0
        phase += 2 * math.pi * freq / RATE
        body = math.sin(phase) * 0.62 + math.sin(phase * 2.0) * 0.12
        # A little filtered air, well under the tone.
        lp += 0.28 * (rng.uniform(-1.0, 1.0) - lp)
        out.append((body + lp * 0.16) * env)
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


def error(duration=0.26):
    """Blocked arrow: a soft two-note descending beep.

    Deliberately gentle. A blocked tap is how the game teaches its own rule,
    so it should read as a correction, not a punishment.
    """
    n = int(RATE * duration)
    out = [0.0] * n
    for k, (freq, start) in enumerate(((620.0, 0.0), (466.0, 0.42))):
        s0 = int(n * start)
        for i in range(s0, n):
            t = (i - s0) / n
            env = (1 - math.exp(-t * 90.0)) * math.exp(-t * 11.0)
            out[i] += math.sin(2 * math.pi * freq * ((i - s0) / RATE)) * env * 0.5
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
    write("error.wav", error())
    write("clear.wav", chime())
