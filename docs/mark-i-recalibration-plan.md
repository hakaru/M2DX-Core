# Mark I OPS recalibration — plan & A/B (markI-ops-dac findings 1–3)

Status: **decision pending (by ear).** This doc frames the Mark I forward-modulation
("darkness") recalibration raised by the DX7 fidelity audit, with A/B render data, so the
final divisor can be chosen by ear against a real DX7 / Dexed reference. No code that ships
is changed yet. **Clean-room:** the project deliberately does not consult Dexed's GPL
`EngineMkI.cpp`; nothing here does either — the reference is your own ears + the audit's
reasoning + public DX7 OPS docs.

Parent: `dx7-fidelity-audit-2026-06-30.md` (`markI-ops-dac` dimension, findings 1–3).
A/B harness: `Tests/M2DXCoreTests/MarkIDivisorABTests.swift` → `swift test --filter renderMarkIDivisorAB`.

## Why this is open

The audit found three **shared Swift+C, parity-invisible** issues in the Mark I (OPS) path,
all about *calibration*, not structure (the OPS pipeline is bit-exact to the `dx7refmki` twin):

1. **(finding 1, HIGH)** Mark I carrier output is `result << 13` ≈ 2²⁶ — **4× (12 dB) hotter**
   than Modern's 2²⁴ through the same `/2²⁸` normalization.
2. **(finding 2, HIGH)** The forward-mod divisor (`markIModScaleQ12`, default ÷8 = parity;
   app default ÷5) makes Mark I **darker than a real DX7** — the audit argues the faithful
   value is **÷4** (mod index = Modern ≈ 2π, since DEXED level-matches its two engines).
3. **(finding 3, MEDIUM)** Feedback re-injects the 4×-hot signal through the same shift as
   Modern → **4× too strong** for every feedback algorithm except the +2-compensated 4/6/32.

These three are **entangled**: the divisor (2) sets brightness, but the `<<13` output scale (1)
sets loudness *and* the feedback strength (3). Changing the divisor alone leaves the 12 dB
loudness step and the hot feedback. So this is a **coordinated recalibration**, not a one-liner.

It also entangles with the **KLS fidelity fix (v1.16.0)**: that fix corrected an inverted/under-
scaled keyboard level scaling that had been over-driving a BASS 1 modulator, so Modern BASS 1 is
now **correctly darker** (sustain centroid 685 → 180 Hz). The old `MarkICalibrationTests`
`darkerSustain` assertion (`Mark I < Modern × 0.6`) was tuned to the *old over-bright* Modern and
no longer holds; it is currently `withKnownIssue`, to be resolved **together with** this decision.

## Current state (code)

| Knob | Where | Value |
|---|---|---|
| `markIModScaleQ12` | `DX7MarkI.swift:68` | **512 = ÷8** (bit-parity default; matches `dx7refmki`) |
| app `markIDivisor` | `M2DXAudioEngine.swift` (`setMarkIModDivisor`) | **÷5** default, range **2–16**, Pro "Mark I Depth" slider |
| carrier output | `DX7MarkI.swift` `mkiSin` | `result << 13` (≈2²⁶, 4× Modern) — *unchanged so far* |
| feedback | `DX7MarkI.swift` / `DX7Voice` | unscaled `(y0+y)>>(fbShift+1)`, +2 only on alg 4/6/32 — *unchanged* |
| default engine | `M2DXAudioEngine.swift:143` | **`.markI`** (every user hears this) |

## A/B render data

`note 60, vel 100, peak-normalized to −3 dBFS so you compare TIMBRE not loudness.` Sustain-window
spectral centroid (lower = darker); raw peak is the un-normalized loudness (finding-1 axis).

| patch | Modern | ÷4 | ÷5 (app) | ÷6 | ÷8 (parity) |
|---|---|---|---|---|---|
| **BASS 1** (alg 15) centroid | 180 Hz | **160** | 152 | 148 | **142** |
| BASS 1 raw peak | 0.0871 | 0.0848 | 0.0824 | 0.0802 | 0.0773 |
| **E.PIANO 1** (alg 4) centroid | 280 Hz | 280 | 280 | 280 | 280 |
| E.PIANO 1 raw peak | 0.0993 | 0.0957 | 0.0957 | 0.0957 | 0.0957 |

WAVs: `/tmp/m2dx-marki-ab/{bass1,epiano1}_{modern,mki_div4,mki_div5,mki_div6,mki_div8}.wav`.

**What the data says**
- The divisor's brightness effect is **patch- and time-dependent.** On BASS 1 (modulation sustains)
  it spans 142→160 Hz across ÷8→÷4 — a real but **compressed ~12%** range. On E.PIANO 1 the
  modulators have decayed by the sustain window, so the divisor barely moves the *sustain* centroid
  (its effect is in the **attack** transient instead) — **judge E.PIANO by ear over the whole note.**
- Even at the audit-"faithful" ÷4, BASS 1 Mark I (160 Hz) stays **darker than Modern** (180 Hz).
  So ÷4 does **not** make Mark I identical to Modern — the OPS log-sin/exp quantization is inherently
  a touch darker. The audit's "mod index = Modern" is approximate, not exact, in practice.
- The raw-peak column shows the divisor barely changes loudness (0.085→0.077). The 4×-hot **12 dB**
  step (finding 1) is the `<<13` output scale vs Modern, a **separate** axis the A/B normalizes away.

## Decisions to make

1. **Forward-mod divisor** (the brightness knob): **÷4** (audit-faithful, brightest, closest to
   Modern) · **÷5** (today's app default) · **÷6** · keep **÷8** (parity, darkest). The audible
   spread is modest; pick by ear from the WAVs / on device.
2. **Finding 1 (4× hot output):** fix `mkiSin` `<<13 → <<11` (→2²⁴, level-matched to Modern) and
   re-derive the divisor accordingly? This removes the 12 dB engine-switch jump and clipping/Maximizer
   reliance, but **changes Mark I loudness** and must be done *with* the divisor (the A/B already
   isolates timbre, so the chosen ÷ stays valid after a pure output re-scale).
3. **Finding 3 (4× hot feedback):** scale the feedback term like Modern and drop the alg-4/6/32 +2
   band-aid? Best done after (1) so one shift law serves both engines.
4. **`darkerSustain` test:** with corrected KLS + any of the above, "Mark I markedly darker than
   Modern (÷0.6)" is the wrong assertion. Options: (a) re-tune to the chosen ÷'s measured ratio,
   (b) weaken to "Mark I ≤ Modern" (still true at every ÷ for BASS 1), or (c) retire it and keep the
   A/B harness as the calibration record. Decide once ÷ is fixed.

## Recommendation

- **Divisor:** lean **÷4** (or ÷5 if you prefer the current voicing) — Mark I is the *shipping default
  engine*, so matching a real DX7's modulation index matters for everyone, and ÷4 is still audibly
  "OPS-dark" vs Modern. But this is your ear's call against a real DX7/Dexed; the WAVs are there for it.
- **Do the coordinated fix, not just the divisor:** also `<<13→<<11` (finding 1) + feedback scaling
  (finding 3), so loudness, brightness, and feedback are all faithful and the engine-switch level jump
  goes away. Treat as one reviewed, RT-careful change with a fresh on-device A/B.
- **Test:** weaken `darkerSustain` to "Mark I ≤ Modern" (b) and keep `MarkIDivisorABTests` as the
  living calibration record.

## Implementation plan (once ÷ + scope are chosen)

1. `DX7MarkI.swift`: set `markIModScaleQ12` default to the chosen value (÷4 → 1024); if doing finding 1,
   change `mkiSin` `<<13 → <<11` and re-derive the divisor; mirror both in `dx7refmki.c`. Keep the app's
   `setMarkIModDivisor` range/UI (recenter on the new default).
2. Finding 3: scale the feedback term (`DX7MarkI.swift` `computeFb*MkI`) consistently; remove the
   alg-4/6/32 +2 special-case if (1) makes it unnecessary.
3. Tests: re-baseline `MarkICalibrationTests` (`darkerSustain` per the chosen option; `headroom` peak
   threshold if loudness changed); the `dx7refmki` parity tests must stay green (Swift == C twin).
4. App: bump `M2DXAudioEngine` default divisor + UI range; new M2DX-Core release + pin bump; on-device A/B.

Until then: v1.16.0 ships the KLS fix with Mark I unchanged (÷5), `darkerSustain` `withKnownIssue`.
