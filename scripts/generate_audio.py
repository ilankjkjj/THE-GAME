"""Create the project's original, deterministic sound-effects source pack.

Standard-library synthesis only: no recordings, samples, external APIs or voices.
Run from any directory. Generated WAV files are intended for Roblox audio import.
"""
from pathlib import Path
import array
import json
import math
import random
import sys
import wave

RATE = 22050
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "audio"
TAU = math.tau


def synthesize(name, seconds, seed):
    rng = random.Random(seed)
    samples = []
    slow_noise = 0.0
    for i in range(round(seconds * RATE)):
        t = i / RATE
        x = t / seconds
        noise = rng.uniform(-1, 1)
        slow_noise = slow_noise * 0.93 + noise * 0.07
        edge = min(1, t / 0.012, (seconds - t) / 0.08)
        if name == "eruption":
            pulse = math.sin(TAU * (43 * t - 7 * t * t))
            value = (0.7 * slow_noise + 0.19 * pulse + 0.17 * noise * math.exp(-t * 6)) * math.exp(-t * 1.9)
        elif name == "impact":
            value = (0.65 * math.sin(TAU * (95 * t - 30 * t * t)) + 0.35 * noise) * math.exp(-t * 8)
        elif name == "storm":
            value = (slow_noise * 1.7 + 0.06 * math.sin(TAU * 37 * t)) * math.sin(math.pi * x) ** 0.7
        elif name == "scifi":
            phase = 310 * t + 125 * t * t
            value = (math.sin(TAU * phase + 2 * math.sin(TAU * 11 * t)) * 0.3 + math.sin(TAU * (phase * 1.505)) * 0.17) * math.sin(math.pi * x) ** 0.5
        elif name == "warning":
            gate = 1 if int(t * 5) % 2 == 0 else 0
            value = gate * (math.sin(TAU * 660 * t) * 0.24 + math.sin(TAU * 880 * t) * 0.11)
        elif name == "whoosh":
            value = (noise * 0.2 + slow_noise * 0.65 + math.sin(TAU * (80 * t + 850 * t * t)) * 0.055) * math.sin(math.pi * x) ** 1.3
        elif name in ("reward", "victory", "obby", "checkpoint", "purchase"):
            value = 0
            chord = ((0, 523.25), (0.13, 659.25), (0.26, 783.99), (0.39, 1046.5))
            if name == "victory": chord += ((0.58, 1318.5), (0.78, 1568), (0.98, 2093))
            if name == "checkpoint": chord = ((0, 880), (0.08, 1320))
            if name == "purchase": chord = ((0, 660), (0.10, 990))
            for start, frequency in chord:
                age = t - start
                if age >= 0:
                    value += (math.sin(TAU * frequency * age) + 0.22 * math.sin(TAU * frequency * 2 * age)) * 0.19 * math.exp(-age * 6)
        elif name == "gunshot":
            value = (noise * 0.75 + math.sin(TAU * (155*t - 100*t*t)) * 0.3) * math.exp(-t*27)
        elif name == "sword":
            value = (noise * 0.27 + slow_noise * 0.6) * math.sin(math.pi*x)**1.8 + math.sin(TAU*2400*t)*0.05*math.exp(-t*12)
        elif name == "role":
            value = (math.sin(TAU*220*t) + 0.3*math.sin(TAU*330*t))*0.25*(1 if int(t*7)%2==0 else 0)
        elif name == "supply":
            value = math.sin(TAU*(430*t+390*t*t))*0.2*math.sin(math.pi*x) + slow_noise*0.2
        elif name == "knockout":
            value = math.sin(TAU*(520*t-340*t*t))*0.27*math.exp(-t*5) + noise*0.12*math.exp(-t*15)
        else:  # button: compact mechanical click with a small resonant body
            value = (noise * 0.24 + math.sin(TAU * 145 * t) * 0.25) * math.exp(-t * 34)
        samples.append(value * max(0, edge))
    peak = max(abs(value) for value in samples)
    gain = 0.78 / max(peak, 0.001)
    pcm = array.array("h", (round(max(-1, min(1, value * gain)) * 32767) for value in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    rms = math.sqrt(sum((value * gain) ** 2 for value in samples) / len(samples))
    return {"file": f"{name}.wav", "duration": seconds, "sample_rate": RATE,
            "channels": 1, "peak": round(peak * gain, 4), "rms": round(rms, 4)}


if __name__ == "__main__":
    sounds = [("button", 0.18), ("warning", 0.8), ("impact", 0.65), ("eruption", 1.8),
              ("storm", 1.8), ("scifi", 1.2), ("whoosh", 0.7), ("reward", 1.05),
              ("gunshot", 0.28), ("sword", 0.42), ("role", 0.9), ("supply", 0.7),
              ("checkpoint", 0.35), ("obby", 1.1), ("purchase", 0.35), ("knockout", 0.7), ("victory", 1.6)]
    manifest = [synthesize(name, duration, index + 713) for index, (name, duration) in enumerate(sounds)]
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(manifest)} original sound effects in assets/audio; no clipping.")
