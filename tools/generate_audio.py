#!/usr/bin/env python3
"""Procedural, original audio for VARKON (SuperEssence Studio).

Every sound and music loop in assets/audio is synthesised by this script, so the
studio owns them outright (no third-party samples). Re-run it to regenerate:

    python3 tools/generate_audio.py

Requires numpy. Music is converted to OGG Vorbis with ffmpeg when available.
"""
import os
import subprocess
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(1337)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env_adsr(n, a=0.01, d=0.1, s=0.6, r=0.2):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(0, n - a_n - d_n - r_n)
    e = np.concatenate([
        np.linspace(0, 1, max(a_n, 1)),
        np.linspace(1, s, max(d_n, 1)),
        np.full(s_n, s),
        np.linspace(s, 0, max(r_n, 1)),
    ])
    return e[:n] if len(e) >= n else np.pad(e, (0, n - len(e)))


def exp_decay(n, k):
    return np.exp(-np.arange(n) / SR * k)


def noise(n):
    return rng.uniform(-1, 1, n)


def lowpass(x, alpha):
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc)
        y[i] = acc
    return y


def sine(f, t):
    return np.sin(2 * np.pi * f * t)


def saw(f, t):
    return 2 * ((f * t) % 1.0) - 1


def square(f, t, duty=0.5):
    return np.where((f * t) % 1.0 < duty, 1.0, -1.0)


def tri(f, t):
    return 2 * np.abs(saw(f, t)) - 1


def sweep(f0, f1, t):
    f = np.linspace(f0, f1, len(t))
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def write_wav(name, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    return path


# ---------------------------------------------------------------- SFX
def sfx():
    out = {}
    t = t_axis(0.08)
    out["ui_click"] = norm(sine(880, t) * exp_decay(len(t), 60) + 0.3 * sine(1760, t) * exp_decay(len(t), 90), 0.6)
    t = t_axis(0.25)
    out["ui_confirm"] = norm((sine(660, t) * (t < 0.1) + sine(990, t) * (t >= 0.1)) * exp_decay(len(t), 12), 0.6)
    t = t_axis(0.3)
    out["ui_error"] = norm(square(140, t, 0.3) * exp_decay(len(t), 8) * 0.5, 0.5)
    t = t_axis(0.35)
    out["ui_open"] = norm(sweep(300, 700, t) * env_adsr(len(t), 0.01, 0.1, 0.4, 0.2), 0.5)

    t = t_axis(1.2)
    creak = lowpass(noise(len(t)), 0.05) * sweep(80, 160, t)
    sparkle = sum(sine(f, t) * exp_decay(len(t), 3) * (t > 0.5) for f in (1318, 1568, 2093))
    out["chest_open"] = norm(creak * 2 * (t < 0.6) + sparkle * 0.4)
    t = t_axis(1.0)
    out["chest_rare"] = norm(sum(sine(f, t) * np.clip((t - i * 0.12) * 20, 0, 1) * exp_decay(len(t), 2)
                                 for i, f in enumerate((523, 659, 784, 1046, 1318))))
    t = t_axis(0.9)
    hammer = sum(lowpass(noise(len(t)), 0.3) * exp_decay(len(t), 30) * (np.abs(t - k) < 0.12) for k in (0.0, 0.3, 0.6))
    out["craft"] = norm(hammer + 0.3 * sine(1200, t) * exp_decay(len(t), 6))
    t = t_axis(0.7)
    out["upgrade"] = norm(sweep(400, 1600, t) * env_adsr(len(t), 0.01, 0.2, 0.5, 0.3) + 0.3 * sine(2093, t) * (t > 0.4))
    t = t_axis(0.25)
    out["coin"] = norm(sine(1975, t) * exp_decay(len(t), 15) + sine(2637, t) * exp_decay(len(t), 20) * (t > 0.06), 0.5)

    t = t_axis(0.18)
    out["hit"] = norm(lowpass(noise(len(t)), 0.4) * exp_decay(len(t), 25) + 0.4 * sine(120, t) * exp_decay(len(t), 20), 0.7)
    t = t_axis(0.35)
    out["hit_heavy"] = norm(lowpass(noise(len(t)), 0.2) * exp_decay(len(t), 12) + sweep(120, 40, t) * exp_decay(len(t), 8))
    t = t_axis(0.22)
    out["swing"] = norm(lowpass(noise(len(t)), 0.15) * np.sin(np.pi * t / t[-1]), 0.5)
    t = t_axis(0.9)
    out["explosion"] = norm(lowpass(noise(len(t)), 0.08) * exp_decay(len(t), 4) + sweep(90, 30, t) * exp_decay(len(t), 5))
    t = t_axis(0.6)
    out["fire"] = norm(lowpass(noise(len(t)), 0.25) * env_adsr(len(t), 0.05, 0.1, 0.7, 0.3) * (1 + 0.5 * sine(9, t)), 0.6)
    t = t_axis(0.5)
    out["ice"] = norm(sum(sine(f, t) * exp_decay(len(t), 10) for f in (2349, 3136, 3520)) + 0.3 * noise(len(t)) * exp_decay(len(t), 25), 0.5)
    t = t_axis(0.6)
    out["poison"] = norm(lowpass(noise(len(t)), 0.1) * (0.5 + 0.5 * sine(14, t)) * env_adsr(len(t), 0.05, 0.1, 0.6, 0.3), 0.5)
    t = t_axis(0.7)
    out["magic"] = norm(sum(sine(f * (1 + 0.01 * sine(6, t)), t) for f in (440, 660, 880)) * env_adsr(len(t), 0.05, 0.2, 0.5, 0.3), 0.5)
    t = t_axis(0.3)
    out["zap"] = norm(square(60, t) * noise(len(t)) * exp_decay(len(t), 10) + sweep(2000, 200, t) * 0.3, 0.5)
    t = t_axis(0.6)
    out["heal"] = norm(sum(sine(f, t) * np.clip((t - i * 0.08) * 30, 0, 1) for i, f in enumerate((523, 784, 1046))) * exp_decay(len(t), 4), 0.5)
    t = t_axis(0.3)
    out["deploy"] = norm(sweep(200, 90, t) * exp_decay(len(t), 10) + lowpass(noise(len(t)), 0.3) * exp_decay(len(t), 30) * 0.5, 0.7)
    t = t_axis(1.4)
    out["tower_destroyed"] = norm(lowpass(noise(len(t)), 0.05) * exp_decay(len(t), 2.5) + sweep(70, 25, t) * exp_decay(len(t), 3))
    t = t_axis(0.8)
    out["telegraph"] = norm(square(330, t, 0.25) * (np.floor(t * 8) % 2) * 0.4, 0.4)
    t = t_axis(0.5)
    out["build"] = norm(lowpass(noise(len(t)), 0.3) * exp_decay(len(t), 14) + sine(220, t) * exp_decay(len(t), 10) * 0.6, 0.6)

    # Victory / defeat jingles
    notes = [(523, 0.15), (659, 0.15), (784, 0.15), (1046, 0.5)]
    out["victory"] = norm(np.concatenate([(saw(f, t_axis(d)) * 0.3 + sine(f, t_axis(d))) * env_adsr(int(SR * d), 0.01, 0.05, 0.7, 0.05) for f, d in notes]))
    notes = [(392, 0.25), (370, 0.25), (349, 0.25), (262, 0.7)]
    out["defeat"] = norm(np.concatenate([tri(f, t_axis(d)) * env_adsr(int(SR * d), 0.01, 0.1, 0.6, 0.1) for f, d in notes]), 0.6)

    # Goblin voices: formant-ish buzz through an amplitude-modulated pitch contour
    def voice(f0, f1, dur, rough=0.4, laugh=False):
        t = t_axis(dur)
        f = np.linspace(f0, f1, len(t))
        if laugh:
            f = f * (1 + 0.15 * np.sign(sine(7, t)))
        ph = np.cumsum(f) / SR
        buzz = saw(1, ph) + rough * noise(len(t))
        formant = sine(900, t) * 0.4 + sine(1400, t) * 0.25 + 1
        amp = env_adsr(len(t), 0.02, 0.1, 0.8, 0.1)
        if laugh:
            amp = amp * (0.5 + 0.5 * (sine(7, t) > 0))
        return norm(lowpass(buzz * formant, 0.35) * amp, 0.7)

    out["goblin_grunt"] = voice(160, 110, 0.35)
    out["goblin_laugh"] = voice(240, 200, 1.0, 0.3, laugh=True)
    out["king_roar"] = voice(110, 70, 0.9, 0.8)
    out["goblin_hurt"] = voice(300, 180, 0.25, 0.5)
    return out


# ---------------------------------------------------------------- MUSIC
def note_freq(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def render_track(bpm, bars, chords, melody, bass_pat, drums, lead="saw", dark=0.0):
    beat = 60.0 / bpm
    total = bars * 4 * beat
    n = int(total * SR)
    mix = np.zeros(n)

    def place(sig, start):
        s = int(start * SR)
        e = min(n, s + len(sig))
        mix[s:e] += sig[: e - s]

    for bar in range(bars):
        chord = chords[bar % len(chords)]
        # Pads
        t = t_axis(4 * beat)
        pad = sum(saw(note_freq(c), t) * 0.5 + sine(note_freq(c) / 2, t) for c in chord)
        pad = lowpass(pad, 0.04 + 0.03 * (1 - dark)) * env_adsr(len(t), 0.3, 0.5, 0.7, 0.6) * 0.18
        place(pad, bar * 4 * beat)
        # Bass
        for i, step in enumerate(bass_pat):
            if step is None:
                continue
            t = t_axis(beat / 2)
            f = note_freq(chord[0] - 12 + step)
            b = (square(f, t, 0.4) * 0.4 + sine(f, t)) * env_adsr(len(t), 0.005, 0.05, 0.6, 0.05) * 0.35
            place(lowpass(b, 0.2), bar * 4 * beat + i * beat / 2)
        # Drums
        for i, hit in enumerate(drums):
            st = bar * 4 * beat + i * beat / 2
            if "k" in hit:
                t = t_axis(0.25)
                place(sweep(110, 40, t) * exp_decay(len(t), 14) * 0.9, st)
            if "s" in hit:
                t = t_axis(0.2)
                place(lowpass(noise(len(t)), 0.5) * exp_decay(len(t), 20) * 0.35, st)
            if "h" in hit:
                t = t_axis(0.05)
                place(noise(len(t)) * exp_decay(len(t), 80) * 0.12, st)
            if "t" in hit:
                t = t_axis(0.4)
                place(sweep(180, 90, t) * exp_decay(len(t), 9) * 0.5, st)
    # Melody
    pos = 0.0
    for midi, length in melody * max(1, int(bars * 4 / max(1, sum(l for _, l in melody)))):
        if pos >= bars * 4:
            break
        d = length * beat
        if midi is not None:
            t = t_axis(d)
            f = note_freq(midi)
            vib = 1 + 0.004 * sine(5.5, t)
            ph = np.cumsum(np.full(len(t), f) * vib) / SR
            if lead == "saw":
                s = saw(1, ph) * 0.5 + tri(1, ph) * 0.5
            elif lead == "square":
                s = square(1, ph, 0.3)
            else:
                s = sine(1, ph) + 0.3 * sine(2, ph)
            s = lowpass(s, 0.25) * env_adsr(len(t), 0.02, 0.1, 0.7, min(0.15, d / 3)) * 0.22
            place(s, pos * beat)
        pos += length
    # Simple feedback echo for depth
    delay = int(beat * 0.75 * SR)
    echo = np.zeros(n)
    echo[delay:] = mix[:-delay] * 0.25
    mix = mix + echo
    return norm(mix, 0.85)


def music():
    tracks = {}
    # Minor-key fantasy march for the fortress menu (D minor)
    chords = [[62, 65, 69], [58, 62, 65], [60, 64, 67], [57, 61, 64]]
    mel = [(74, 1), (77, 0.5), (76, 0.5), (74, 1), (69, 1), (70, 1.5), (69, 0.5), (67, 2),
           (72, 1), (74, 0.5), (72, 0.5), (70, 1), (69, 1), (67, 1), (69, 1), (65, 2)]
    tracks["music_menu"] = render_track(92, 8, chords, mel, [0, None, 7, None, 0, None, 7, 12],
                                        ["k", "h", "s", "h", "k", "h", "s", "h"], lead="sine", dark=0.3)
    # Driving battle loop (E minor)
    chords = [[64, 67, 71], [60, 64, 67], [62, 66, 69], [59, 62, 66]]
    mel = [(76, 0.5), (79, 0.5), (81, 1), (79, 0.5), (76, 0.5), (74, 1), (76, 0.5), (71, 0.5), (74, 1), (76, 2),
           (83, 0.5), (81, 0.5), (79, 1), (76, 1), (78, 1), (79, 2)]
    tracks["music_battle"] = render_track(136, 16, chords, mel, [0, 0, 12, 0, 0, 7, 12, 7],
                                          ["kh", "h", "sh", "h", "kh", "kh", "sh", "h"], lead="saw")
    # Heavy boss theme (C minor, slower, toms)
    chords = [[60, 63, 67], [56, 60, 63], [55, 59, 62], [60, 63, 66]]
    mel = [(72, 1.5), (71, 0.5), (72, 1), (75, 1), (74, 2), (67, 2), (68, 1), (67, 1), (65, 1), (63, 1), (62, 4)]
    tracks["music_boss"] = render_track(118, 12, chords, mel, [0, 0, 0, 1, 0, 0, 6, 7],
                                        ["kt", "h", "s", "t", "kt", "k", "s", "th"], lead="square", dark=0.8)
    # Fortress ambience: wind + distant forge
    dur = 20.0
    t = t_axis(dur)
    wind = lowpass(noise(len(t)), 0.01) * (0.6 + 0.4 * sine(0.15, t)) * 3
    forge = np.zeros(len(t))
    for k in np.arange(1.0, dur, 2.3):
        s = int(k * SR)
        h = t_axis(0.4)
        clang = (sine(820, h) + sine(1230, h) * 0.6) * exp_decay(len(h), 9) * 0.15
        forge[s:s + len(h)] += clang[: len(forge) - s]
    fire = lowpass(noise(len(t)), 0.2) * 0.08 * (1 + 0.5 * noise(len(t)))
    tracks["ambience_fortress"] = norm(wind + forge + fire, 0.6)
    return tracks


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, x in sfx().items():
        write_wav(name, x)
        print("sfx", name)
    have_ffmpeg = subprocess.call(["which", "ffmpeg"], stdout=subprocess.DEVNULL) == 0
    for name, x in music().items():
        path = write_wav(name, x)
        if have_ffmpeg:
            ogg = path[:-4] + ".ogg"
            rc = subprocess.call(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "4", ogg])
            if rc == 0:
                os.remove(path)
        print("music", name)


if __name__ == "__main__":
    main()
