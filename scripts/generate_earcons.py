"""
Generate 4 audio earcon WAV files for the Cuisinée app.
  chime_open.wav  — rising 4-note chord (C4 E4 G4 C5)
  chime_close.wav — descending notes (C5 G4 E4 C4)
  timer_tick.wav  — soft tick (one cycle of 800 Hz, 50 ms)
  timer_done.wav  — pleasant 3-note ascending ding (E4 G4 B4)
"""

import math
import os
import struct
import wave

SAMPLE_RATE = 44100
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'frontend', 'assets', 'audio')

os.makedirs(OUTPUT_DIR, exist_ok=True)


def lerp(a, b, t):
    return a + (b - a) * t


def generate_frames(freq: float, duration: float, amplitude: float = 0.45,
                    fade_in: float = 0.015, fade_out: float = 0.08) -> bytes:
    """Return raw 16-bit PCM bytes for a sine tone with linear fade-in / fade-out."""
    n = int(SAMPLE_RATE * duration)
    buf = bytearray(n * 2)
    for i in range(n):
        t = i / SAMPLE_RATE
        # Amplitude envelope
        fade = 1.0
        if t < fade_in:
            fade = t / fade_in
        elif t > duration - fade_out:
            fade = (duration - t) / fade_out
        val = int(amplitude * 32767 * fade * math.sin(2 * math.pi * freq * t))
        struct.pack_into('<h', buf, i * 2, max(-32767, min(32767, val)))
    return bytes(buf)


def write_wav(filename: str, raw_pcm: bytes) -> None:
    path = os.path.join(OUTPUT_DIR, filename)
    with wave.open(path, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(raw_pcm)
    print(f'  Wrote {path}  ({len(raw_pcm) // 2} samples)')


# ── Note frequencies ──────────────────────────────────────────────────────────
C4  = 261.63
E4  = 329.63
G4  = 392.00
B4  = 493.88
C5  = 523.25

# ── chime_open.wav  (C4 → E4 → G4 → C5, each 140 ms, 20 ms silence gap) ─────
open_segments = []
for freq, dur in [(C4, 0.14), (E4, 0.14), (G4, 0.14), (C5, 0.22)]:
    open_segments.append(generate_frames(freq, dur, amplitude=0.38, fade_out=0.04))
    # tiny 18 ms silence between notes
    open_segments.append(bytes(int(SAMPLE_RATE * 0.018) * 2))
write_wav('chime_open.wav', b''.join(open_segments))

# ── chime_close.wav  (C5 → G4 → E4 → C4, each 130 ms) ───────────────────────
close_segments = []
for freq, dur in [(C5, 0.13), (G4, 0.13), (E4, 0.13), (C4, 0.20)]:
    close_segments.append(generate_frames(freq, dur, amplitude=0.35, fade_out=0.05))
    close_segments.append(bytes(int(SAMPLE_RATE * 0.018) * 2))
write_wav('chime_close.wav', b''.join(close_segments))

# ── timer_tick.wav  (short soft 800 Hz click, 55 ms) ─────────────────────────
write_wav('timer_tick.wav', generate_frames(800, 0.055, amplitude=0.25, fade_in=0.003, fade_out=0.025))

# ── timer_done.wav  (E4 → G4 → B4, each 160 ms with a bit of reverb decay) ──
done_segments = []
for freq, dur in [(E4, 0.16), (G4, 0.16), (B4, 0.28)]:
    done_segments.append(generate_frames(freq, dur, amplitude=0.42, fade_out=0.08))
    done_segments.append(bytes(int(SAMPLE_RATE * 0.015) * 2))
write_wav('timer_done.wav', b''.join(done_segments))

print('All earcons generated successfully.')
