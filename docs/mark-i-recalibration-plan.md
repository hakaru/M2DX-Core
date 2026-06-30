# Mark I OPS recalibration — plan & A/B (markI-ops-dac findings 1–3)

Status: **DECIDED 2026-06-30 — finding 2 closed (÷5 maintained); findings 1 & 3 deferred.** This doc frames the Mark I forward-modulation
("darkness") recalibration raised by the DX7 fidelity audit, with A/B render data, so the
final divisor can be chosen by ear against a real DX7 / Dexed reference. No code that ships
is changed yet. **Clean-room:** the project deliberately does not consult Dexed's GPL
`EngineMkI.cpp`; nothing here does either — the reference is your own ears + the audit's
reasoning + public DX7 OPS docs.

Parent: `dx7-fidelity-audit-2026-06-30.md` (`markI-ops-dac` dimension, findings 1–3).
A/B harness: `Tests/M2DXCoreTests/MarkIDivisorABTests.swift` → `M2DX_MARKI_AB=1 swift test --filter renderMarkIDivisorAB` (env-gated: it mutates the process-global divisor, so it is a no-op in a normal `swift test`).

## Decision (2026-06-30)

**Finding 2 (forward-mod divisor) — CLOSED, ÷5 maintained.** An A/B by ear (BASS 1 + E.PIANO 1,
peak-normalized) found ÷4 / ÷5 / ÷6 / ÷8 **nearly indistinguishable**, matching the data (BASS 1
spans only ~12%, E.PIANO 1 is divisor-insensitive at sustain). The divisor's "darkness" is a
low-impact calibration, so the shipping default stays **÷5** — changing it is not worth a
recalibration of the default engine. `MarkICalibrationTests.darkerSustain` is weakened from the
(pre-KLS-fix, over-bright-Modern) `÷0.6` threshold to assert only the surviving true property
**`Mark I < Modern`**; `MarkIDivisorABTests` is kept as the living A/B record.

**Findings 1 (4× / 12 dB hot output) & 3 (4× feedback) — DEFERRED.** These are the genuinely
audible Mark I issues (the A/B normalized loudness away, so they were not evaluated): the 12 dB
engine-switch level jump / clip-and-Maximizer reliance, and over-hot feedback. They are separate,
more structural, and tracked in the audit (`markI-ops-dac` findings 1 & 3) for a future, measured pass.

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

- **Divisor:** **÷5 maintained** (see the Decision at the top) — the A/B found ÷4…÷8 nearly
  indistinguishable by ear, so the brightness knob is a low-impact calibration not worth changing
  the shipping default. The bracketing data + WAVs remain for any future re-evaluation.
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

## finding 1 & 3 characterization + decision (2026-06-30, M2DX #95)

Before implementing the coordinated fix, a measurement-first pass (`Tests/M2DXCoreTests/MarkICalibrationCharacterizationTests.swift`, env-gated `M2DX_MARKI_CHAR=1`) rendered the carrier and feedback paths through the full `SynthEngine` for Modern vs Mark I. **The audit's finding 1 and finding 3 do NOT manifest as rendered behaviour — both are closed as no-ops.**

### finding 1 (carrier "4× / 12 dB hot") — CLOSED, no change

Pure single carrier (alg 32, op0 only, no modulation), output-level sweep, Mark I (÷5) vs Modern peak ratio:

| level | 0.10 | 0.20 | 0.35 | 0.50 | 0.70 | 0.85 | 1.00 |
|---|---|---|---|---|---|---|---|
| ratio (markI/modern) | 1.000 | 1.000 | 1.000 | 0.999 | 1.000 | 1.000 | 1.000 |

The carrier is **already level-matched to Modern at every level** (the slight per-sample differences confirm independent code paths converging to the same level). The audit's theoretical `2²⁶ vs 2²⁴ = 4×` is fully absorbed by the level/attenuation→output mapping and never reaches the rendered carrier. A constant `<<13→<<11` would make typical patches **~4× too quiet** (a regression), so it is **rejected**. This also matches the original A/B raw-peak data (BASS 1 0.0824 vs 0.0871; E.PIANO 0.0957 vs 0.0993).

### finding 3 (feedback "4× too strong") — CLOSED, no action

Feedback sweep on a Mark-I-deepened feedback stack (DX7 alg 6, `algIndex 5`; the Mark I feedback deepening at `DX7Voice.swift:417` is gated to `algIndex {3,5,31}` = DX7 alg 4/6/32 only — 3 of 32), attack window 0..2400:

| fb | peakRatio (markI/modern) | centroidRatio |
|---|---|---|
| 0 | 1.146 | 0.658 |
| 4 | 1.145 | 0.660 |
| 7 | 1.145 | 0.660 |

The Mark I/Modern divergence (~15% hotter, ~34% darker) is **invariant to the feedback amount** — it is the forward-mod **divisor** (finding 2, already CLOSED at ÷5: the intended OPS warmth), not feedback-specific. The alg-4/6/32 `+2` feedback band-aids already compensate the feedback strength **and are required for `dx7refmki` Swift==C parity**; removing them needs the (rejected) `<<11`. So **no action**. (Caveat: not stress-tested on a feedback-dominant patch; the decision rests primarily on the structural argument — band-aids required for parity, finding-1 moot — corroborated by the fb-invariant measurement.)

### Net decision

The coordinated recalibration (audit findings 1 + 2 + 3) is **not warranted** — Mark I is already level-matched to Modern, and its modest darker/warmer FM character is the intended, ear-accepted ÷5 calibration. M2DX **#95 is re-scoped to the one real, structural issue: the 12-bit DAC (#75) degenerates to a fixed quantizer** at the post-normalization tiny scale and must move to per-voice on the ~full-scale signal. That is the sole remaining work and is tracked as #95 Stage 1.

## Stage 1 outcome (2026-06-30) — DAC moved per-voice, full-scale R = 2²⁵

The companding was relocated from the post-normalization summed mix to per-voice on the raw OPS
sample (`SynthEngine.swift`, `dac12bitCompand(Float(blockBuf[s]) / kMarkIDACFullScale) * kMarkIDACFullScale`);
the DAC-off path is byte-exact and `dx7refmki` parity is unaffected (DAC gated off there). The
full-scale reference `kMarkIDACFullScale` was chosen by **ear A/B over an R sweep**: at R = 2²⁶
(the OPS single-op full scale) ~80% of samples stayed at exponent 8 (the finest grid) → inaudible;
**R = 2²⁵ is the shipped value** (exp 2/4 engaged = audible-but-not-crushed vintage character;
2²⁴/2²³ over-crush). `kMarkIDACFullScale` is a runtime-settable `nonisolated(unsafe) var` (same
RT-safe pattern as `markIModScaleQ12`), default 2²⁵. Tests: 262 green incl. parity + calibration +
`VintageDACTests`. Note: per-voice companding runs at the oversampled rate; downsampling removes
only ~3 dB of the quantization noise, so per-voice-at-native (Option B) was not needed.
