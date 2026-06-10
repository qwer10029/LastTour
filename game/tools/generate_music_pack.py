#!/usr/bin/env python3
"""Generate the first-pass End Journey music pack.

The pack is intentionally synthetic and small: cold pads, sparse bells,
mechanical pulses, and shared motifs that can be replaced or polished later.
It uses only the Python standard library so it runs on the course machines.
"""

from __future__ import annotations

import array
import json
import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 22_050
CHANNELS = 2
PPQ = 480
TAU = math.tau

PROJECT_ROOT = Path(__file__).resolve().parents[1]
MUSIC_DIR = PROJECT_ROOT / "assets" / "music"
SOURCE_DIR = MUSIC_DIR / "source"

CUES = [
    {"id": "menu_main", "seconds": 32.0, "bpm": 72, "loop": True, "profile": "menu_main"},
    {"id": "menu_select", "seconds": 24.0, "bpm": 78, "loop": True, "profile": "menu_select"},
    {"id": "opening_prologue", "seconds": 32.0, "bpm": 70, "loop": True, "profile": "opening"},
    {"id": "day_exploration", "seconds": 36.0, "bpm": 66, "loop": True, "profile": "day"},
    {"id": "evening_warning", "seconds": 7.0, "bpm": 90, "loop": False, "profile": "evening"},
    {"id": "night_setup", "seconds": 28.0, "bpm": 86, "loop": True, "profile": "night_setup"},
    {"id": "night_combat", "seconds": 32.0, "bpm": 96, "loop": True, "profile": "night_combat"},
    {"id": "terminal", "seconds": 28.0, "bpm": 72, "loop": True, "profile": "terminal"},
    {"id": "truth_reveal", "seconds": 34.0, "bpm": 68, "loop": True, "profile": "truth"},
    {"id": "final_choice", "seconds": 32.0, "bpm": 64, "loop": True, "profile": "final_choice"},
    {"id": "run_reset", "seconds": 6.5, "bpm": 82, "loop": False, "profile": "run_reset"},
]

KUNLUN_MOTIF = [50, 52, 57, 53]  # D, E, A, F: cold, slightly unfinished.
TRAVELER_MOTIF = [50, 53, 57, 60]
REVERSE_MOTIF = [57, 53, 52, 50]
RESET_MOTIF = [62, 57, 53, 50, 38]


def midi_to_hz(note: int) -> float:
    return 440.0 * (2.0 ** ((note - 69) / 12.0))


def clamp(value: float, low: float = -1.0, high: float = 1.0) -> float:
    return max(low, min(high, value))


def env_adsr(t: float, dur: float, attack: float, release: float) -> float:
    if dur <= 0.0:
        return 0.0
    if t < attack:
        return t / max(attack, 0.0001)
    if t > dur - release:
        return max((dur - t) / max(release, 0.0001), 0.0)
    return 1.0


def pan_gains(pan: float) -> tuple[float, float]:
    pan = clamp(pan, -1.0, 1.0)
    return math.sqrt((1.0 - pan) * 0.5), math.sqrt((1.0 + pan) * 0.5)


def waveform(kind: str, phase: float) -> float:
    s = math.sin(phase)
    if kind == "triangle":
        return (2.0 / math.pi) * math.asin(s)
    if kind == "soft_saw":
        return 0.70 * s + 0.20 * math.sin(phase * 2.0) + 0.10 * math.sin(phase * 3.0)
    if kind == "bell":
        return s + 0.42 * math.sin(phase * 2.72) + 0.18 * math.sin(phase * 5.18)
    if kind == "metal":
        return 0.65 * s + 0.35 * math.sin(phase * 3.97)
    return s


class Synth:
    def __init__(self, cue_id: str, seconds: float, seed: int) -> None:
        self.cue_id = cue_id
        self.seconds = seconds
        self.frames = int(seconds * SAMPLE_RATE)
        self.left = [0.0] * self.frames
        self.right = [0.0] * self.frames
        self.rng = random.Random(seed)
        self.midi_notes: list[tuple[float, float, int, int]] = []

    def add_note(
        self,
        note: int,
        start: float,
        dur: float,
        amp: float,
        wave_kind: str = "sine",
        pan: float = 0.0,
        attack: float = 0.025,
        release: float = 0.18,
        detune: float = 0.0,
        midi_velocity: int = 72,
    ) -> None:
        start_i = max(0, int(start * SAMPLE_RATE))
        end_i = min(self.frames, int((start + dur) * SAMPLE_RATE))
        if end_i <= start_i:
            return
        freq = midi_to_hz(note) * (1.0 + detune)
        phase = self.rng.random() * TAU
        inc = TAU * freq / SAMPLE_RATE
        lg, rg = pan_gains(pan)
        for i in range(start_i, end_i):
            t = (i - start_i) / SAMPLE_RATE
            env = env_adsr(t, dur, attack, release)
            value = waveform(wave_kind, phase) * amp * env
            self.left[i] += value * lg
            self.right[i] += value * rg
            phase += inc
        self.midi_notes.append((start, dur, note, midi_velocity))

    def add_chord_pad(
        self,
        notes: list[int],
        start: float,
        dur: float,
        amp: float,
        wave_kind: str = "soft_saw",
    ) -> None:
        spread = [-0.45, -0.15, 0.15, 0.45, 0.0]
        for idx, note in enumerate(notes):
            self.add_note(
                note,
                start,
                dur,
                amp / max(len(notes), 1),
                wave_kind,
                spread[idx % len(spread)],
                attack=1.2,
                release=1.2,
                detune=(idx - len(notes) * 0.5) * 0.0015,
                midi_velocity=48,
            )

    def add_pulse(
        self,
        note: int,
        start: float,
        dur: float,
        amp: float,
        pan: float = 0.0,
        wave_kind: str = "soft_saw",
    ) -> None:
        self.add_note(note, start, dur, amp, wave_kind, pan, attack=0.004, release=dur * 0.85, midi_velocity=82)

    def add_wind(self, amp: float, color: float = 0.985) -> None:
        l_state = 0.0
        r_state = 0.0
        for i in range(self.frames):
            l_state = l_state * color + self.rng.uniform(-1.0, 1.0) * (1.0 - color)
            r_state = r_state * color + self.rng.uniform(-1.0, 1.0) * (1.0 - color)
            drift = math.sin((i / SAMPLE_RATE) * TAU / max(self.seconds, 1.0))
            self.left[i] += l_state * amp * (0.8 + 0.2 * drift)
            self.right[i] += r_state * amp * (0.8 - 0.2 * drift)

    def add_static_bursts(self, count: int, amp: float) -> None:
        for _ in range(count):
            start = self.rng.uniform(0.5, max(self.seconds - 0.5, 0.6))
            dur = self.rng.uniform(0.035, 0.16)
            freq_note = self.rng.choice([74, 76, 79, 81, 86])
            self.add_note(freq_note, start, dur, amp, "metal", self.rng.uniform(-0.8, 0.8), 0.002, dur)

    def edge_fade(self, fade_sec: float = 0.08) -> None:
        fade_frames = max(1, int(fade_sec * SAMPLE_RATE))
        for i in range(min(fade_frames, self.frames)):
            gain = i / fade_frames
            self.left[i] *= gain
            self.right[i] *= gain
            j = self.frames - i - 1
            self.left[j] *= gain
            self.right[j] *= gain

    def normalize(self, target_peak: float = 0.88) -> None:
        peak = 0.0
        for l, r in zip(self.left, self.right):
            peak = max(peak, abs(l), abs(r))
        if peak <= 0.0:
            return
        scale = target_peak / peak if peak > target_peak else 1.0
        for i in range(self.frames):
            self.left[i] = math.tanh(self.left[i] * scale * 1.05) / math.tanh(1.05)
            self.right[i] = math.tanh(self.right[i] * scale * 1.05) / math.tanh(1.05)


def beat_to_sec(beat: float, bpm: float) -> float:
    return beat * 60.0 / bpm


def add_motif(
    synth: Synth,
    notes: list[int],
    bpm: float,
    beat_start: float,
    repeat_beats: float,
    repeats: int,
    amp: float,
    wave_kind: str,
    octave: int = 0,
    note_beats: float = 0.85,
) -> None:
    offsets = [0.0, 1.5, 3.0, 5.5]
    for rep in range(repeats):
        base = beat_start + rep * repeat_beats
        for idx, note in enumerate(notes):
            start = beat_to_sec(base + offsets[idx % len(offsets)], bpm)
            dur = beat_to_sec(note_beats, bpm)
            pan = [-0.35, 0.15, 0.42, -0.1][idx % 4]
            synth.add_note(note + octave, start, dur, amp, wave_kind, pan, attack=0.02, release=0.45)


def add_clock_pulses(synth: Synth, bpm: float, every_beats: float, note: int, amp: float, dur_beats: float) -> None:
    total_beats = synth.seconds * bpm / 60.0
    beat = 0.0
    while beat < total_beats:
        pan = -0.25 if int(beat / every_beats) % 2 == 0 else 0.25
        synth.add_pulse(note, beat_to_sec(beat, bpm), beat_to_sec(dur_beats, bpm), amp, pan, "soft_saw")
        beat += every_beats


def render_profile(cue: dict) -> Synth:
    cue_id = cue["id"]
    bpm = float(cue["bpm"])
    profile = cue["profile"]
    synth = Synth(cue_id, float(cue["seconds"]), seed=sum(ord(c) for c in cue_id))
    total_beats = synth.seconds * bpm / 60.0
    repeats8 = max(1, int(total_beats // 8))

    if profile == "menu_main":
        synth.add_wind(0.012)
        synth.add_chord_pad([38, 45, 50, 53], 0, synth.seconds, 0.20)
        add_motif(synth, KUNLUN_MOTIF, bpm, 0, 8, repeats8, 0.075, "bell", octave=12)
        add_clock_pulses(synth, bpm, 4.0, 26, 0.040, 0.55)
        synth.add_static_bursts(10, 0.020)
    elif profile == "menu_select":
        synth.add_wind(0.008)
        synth.add_chord_pad([38, 45, 50], 0, synth.seconds, 0.13)
        add_clock_pulses(synth, bpm, 2.0, 38, 0.040, 0.28)
        add_motif(synth, KUNLUN_MOTIF[:3], bpm, 1, 8, repeats8, 0.052, "bell", octave=12, note_beats=0.5)
    elif profile == "opening":
        synth.add_wind(0.010)
        synth.add_chord_pad([38, 45, 50, 57], 0, synth.seconds, 0.22)
        synth.add_chord_pad([41, 48, 53, 60], synth.seconds * 0.5, synth.seconds * 0.5, 0.12)
        add_motif(synth, TRAVELER_MOTIF, bpm, 0, 8, repeats8, 0.070, "bell", octave=12, note_beats=1.2)
    elif profile == "day":
        synth.add_wind(0.020)
        synth.add_chord_pad([26, 38, 45, 50], 0, synth.seconds, 0.15)
        add_motif(synth, TRAVELER_MOTIF, bpm, 3, 12, max(1, int(total_beats // 12)), 0.046, "triangle", octave=12, note_beats=0.8)
        add_clock_pulses(synth, bpm, 8.0, 26, 0.025, 0.75)
        synth.add_static_bursts(7, 0.014)
    elif profile == "evening":
        synth.add_wind(0.014)
        add_clock_pulses(synth, bpm, 0.75, 38, 0.055, 0.22)
        for idx, note in enumerate([50, 52, 55, 57, 62]):
            synth.add_note(note + 12, 0.55 + idx * 0.58, 0.36, 0.090, "metal", 0.0, 0.006, 0.2, midi_velocity=90)
        synth.add_note(38, 4.2, 1.4, 0.14, "soft_saw", 0.0, 0.01, 1.2, midi_velocity=84)
    elif profile == "night_setup":
        synth.add_wind(0.010)
        synth.add_chord_pad([26, 38, 41, 45], 0, synth.seconds, 0.15, "soft_saw")
        add_clock_pulses(synth, bpm, 1.0, 26, 0.050, 0.28)
        add_motif(synth, REVERSE_MOTIF, bpm, 2, 8, repeats8, 0.045, "metal", octave=12, note_beats=0.42)
        synth.add_static_bursts(14, 0.020)
    elif profile == "night_combat":
        synth.add_wind(0.009)
        synth.add_chord_pad([26, 31, 38, 45], 0, synth.seconds, 0.13, "soft_saw")
        add_clock_pulses(synth, bpm, 0.5, 26, 0.060, 0.18)
        add_clock_pulses(synth, bpm, 2.0, 38, 0.045, 0.22)
        add_motif(synth, REVERSE_MOTIF, bpm, 0, 8, repeats8, 0.050, "metal", octave=12, note_beats=0.32)
        synth.add_static_bursts(22, 0.026)
    elif profile == "terminal":
        synth.add_wind(0.006, color=0.993)
        synth.add_chord_pad([26, 38, 49], 0, synth.seconds, 0.12)
        add_clock_pulses(synth, bpm, 1.0, 50, 0.025, 0.12)
        add_motif(synth, REVERSE_MOTIF, bpm, 1, 8, repeats8, 0.035, "sine", octave=24, note_beats=0.22)
        synth.add_static_bursts(18, 0.018)
    elif profile == "truth":
        synth.add_wind(0.012)
        synth.add_chord_pad([26, 38, 45, 50], 0, synth.seconds, 0.18)
        synth.add_chord_pad([29, 41, 48, 53], synth.seconds * 0.45, synth.seconds * 0.55, 0.12)
        add_motif(synth, KUNLUN_MOTIF, bpm, 0, 8, repeats8, 0.060, "bell", octave=12, note_beats=1.35)
        add_motif(synth, REVERSE_MOTIF, bpm, 4, 16, max(1, int(total_beats // 16)), 0.040, "triangle", octave=0, note_beats=1.8)
    elif profile == "final_choice":
        synth.add_wind(0.010)
        synth.add_chord_pad([26, 38, 41, 50], 0, synth.seconds, 0.18)
        add_clock_pulses(synth, bpm, 4.0, 26, 0.045, 0.9)
        add_motif(synth, [50, 53, 57, 56], bpm, 2, 12, max(1, int(total_beats // 12)), 0.060, "bell", octave=12, note_beats=1.2)
    elif profile == "run_reset":
        synth.add_wind(0.010)
        for idx, note in enumerate(RESET_MOTIF):
            synth.add_note(note, 0.25 + idx * 0.48, 0.42, 0.110, "metal", 0.0, 0.004, 0.28, midi_velocity=96)
        synth.add_note(26, 3.2, 2.2, 0.16, "soft_saw", 0.0, 0.01, 1.8, midi_velocity=86)

    synth.edge_fade(0.08)
    synth.normalize(0.86)
    return synth


def write_wav(path: Path, synth: Synth) -> None:
    pcm = array.array("h")
    for left, right in zip(synth.left, synth.right):
        pcm.append(int(clamp(left) * 32767))
        pcm.append(int(clamp(right) * 32767))
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(CHANNELS)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(pcm.tobytes())


def vlq(value: int) -> bytes:
    chunks = [value & 0x7F]
    value >>= 7
    while value:
        chunks.insert(0, (value & 0x7F) | 0x80)
        value >>= 7
    return bytes(chunks)


def write_midi(path: Path, cue: dict, notes: list[tuple[float, float, int, int]]) -> None:
    bpm = int(cue["bpm"])
    tempo = int(60_000_000 / bpm)
    events: list[tuple[int, int, bytes]] = []
    name = cue["id"].encode("ascii")
    events.append((0, 0, b"\xff\x03" + vlq(len(name)) + name))
    events.append((0, 1, b"\xff\x51\x03" + tempo.to_bytes(3, "big")))
    for start, dur, note, velocity in notes:
        start_tick = int(start * bpm / 60.0 * PPQ)
        end_tick = int((start + dur) * bpm / 60.0 * PPQ)
        events.append((start_tick, 2, bytes([0x90, note, velocity])))
        events.append((end_tick, 0, bytes([0x80, note, 0])))
    events.sort(key=lambda item: (item[0], item[1]))
    track = bytearray()
    current_tick = 0
    for tick, _order, payload in events:
        track.extend(vlq(max(tick - current_tick, 0)))
        track.extend(payload)
        current_tick = tick
    track.extend(vlq(0))
    track.extend(b"\xff\x2f\x00")
    with path.open("wb") as handle:
        handle.write(b"MThd")
        handle.write(struct.pack(">LHHH", 6, 0, 1, PPQ))
        handle.write(b"MTrk")
        handle.write(struct.pack(">L", len(track)))
        handle.write(track)


def main() -> None:
    MUSIC_DIR.mkdir(parents=True, exist_ok=True)
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    manifest = {
        "sample_rate": SAMPLE_RATE,
        "channels": CHANNELS,
        "runtime_format": "wav",
        "note": "Generated prototype music. OGG export should replace WAV runtime assets when an encoder is available.",
        "cues": [],
    }
    for cue in CUES:
        print(f"rendering {cue['id']}...")
        synth = render_profile(cue)
        wav_path = MUSIC_DIR / f"{cue['id']}.wav"
        source_wav_path = SOURCE_DIR / f"{cue['id']}.wav"
        midi_path = SOURCE_DIR / f"{cue['id']}.mid"
        write_wav(wav_path, synth)
        write_wav(source_wav_path, synth)
        write_midi(midi_path, cue, synth.midi_notes)
        manifest["cues"].append({
            "id": cue["id"],
            "seconds": cue["seconds"],
            "bpm": cue["bpm"],
            "loop": cue["loop"],
            "runtime": f"res://assets/music/{cue['id']}.wav",
            "source_wav": f"res://assets/music/source/{cue['id']}.wav",
            "source_midi": f"res://assets/music/source/{cue['id']}.mid",
        })
    (SOURCE_DIR / "music_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(CUES)} cues to {MUSIC_DIR}")


if __name__ == "__main__":
    main()
