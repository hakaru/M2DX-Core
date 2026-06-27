// dx7refmki.h — "Mark I" (OPS log-sin + exp) reference for comparison testing.
//
// Clean-room twin of M2DX-Core's Swift Mark I path (DX7MarkI.swift,
// DX7Voice.renderBlockMarkI, MarkISinTables.swift), built ONLY from our own
// Apache code + the public OPS formulas in DX7MarkI_PROVENANCE.md.
// It does NOT copy Dexed's GPL-3.0 EngineMkI.cpp.
//
// This reference reuses the dx7ref voice scaffolding (EG, frequency LUT,
// algorithm flag table, 156-byte patch layout, N=64 block render). Only the
// per-sample operator (log-sin + exp), the gain→log-attenuation mapping, and
// the fused Alg 4/6 feedback chains differ — and those mirror the Swift Mark I
// EXACTLY so Task 10 can compare sample-for-sample.
//
// Test-only target: not included in production builds.

#ifndef DX7REFMKI_H
#define DX7REFMKI_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// --- Constants (mirror DX7MarkI.swift / Algorithm.swift) ---

#define DX7REFMKI_LG_N 6
#define DX7REFMKI_N (1 << DX7REFMKI_LG_N)   // 64 samples per block
#define DX7REFMKI_FEEDBACK_BITDEPTH 8

#define DX7REFMKI_ENV_MAX (1 << 14)         // kMarkIEnvMax = 16384
// kMarkILevelThresh = ENV_MAX - 100 (attenuation >= this == inaudible)
#define DX7REFMKI_LEVEL_THRESH (DX7REFMKI_ENV_MAX - 100)

// --- Table / lookup primitives (mirror MarkISinTables.swift + mkiSin) ---

/// Materialize the log-sine + exp LUTs. Idempotent; called by voice_init.
void dx7refmki_tables_init(void);

/// OPS operator: C twin of Swift `mkiSin`.
/// phase: Q24 phase; atten: log-domain attenuation (UInt16). Returns Q24-ish.
int32_t dx7refmki_sin(int32_t phase, uint16_t atten);

/// EG level (Q24, the same value Modern feeds to exp2) → Mark I log attenuation.
/// C twin of Swift `markIAtten`. Larger result = MORE attenuation = quieter.
uint16_t dx7refmki_atten(int32_t level_in);

// --- Frequency LUT (shared math with dx7ref) ---

/// Initialize the frequency LUT for the given sample rate.
void dx7refmki_freq_init(double sample_rate);

/// log-frequency (Q24) → Q24 phase increment per sample.
int32_t dx7refmki_freq_lookup(int32_t logfreq);

/// Compute log-frequency for a DX7 operator (same as dx7ref_osc_freq).
int32_t dx7refmki_osc_freq(int midinote, int mode, int coarse, int fine, int detune);

// --- EG (Envelope Generator) — identical to dx7ref EG ---

typedef struct {
    int32_t level;
    int32_t target_level;
    int32_t inc;
    int      ix;            // stage: -1=idle, 0-3
    int      rising;        // 1=attack, 0=decay
    int      down;          // 1=key pressed, 0=released
    int      rates[4];      // R1-R4 (0-99)
    int      levels[4];     // L1-L4 (0-99)
    int      outlevel;      // scaleoutlevel(OL) << 5 (+ KLS/vel folded in voice_init)
    int      rate_scaling;  // from scale_rate()
} dx7refmki_eg_t;

void dx7refmki_eg_note_on(dx7refmki_eg_t *eg);
void dx7refmki_eg_note_off(dx7refmki_eg_t *eg);
int32_t dx7refmki_eg_getsample(dx7refmki_eg_t *eg);

// --- Voice-Level Rendering ---

/// Per-operator parameters. `mki_atten_out` carries the PREVIOUS block's
/// attenuation for the ramp (twin of DX7Operator.markIGainOut). Initialized to
/// ENV_MAX (silent) at note-on, mirroring kMarkIEnvMax default.
typedef struct {
    int32_t  phase;          // Q24 phase accumulator
    int32_t  freq;           // Q24 per-sample phase increment
    int32_t  level_in;       // EG level (input to atten mapping)
    uint16_t mki_atten_out;  // previous block's attenuation (for interpolation ramp)
} dx7refmki_op_params_t;

typedef struct {
    dx7refmki_eg_t        eg[6];        // envelope generators
    dx7refmki_op_params_t params[6];    // operator parameters
    int32_t          basepitch[6];      // log-frequency per operator
    int32_t          fb_buf[2];         // feedback delay line (op0)
    int              algorithm;         // 0-31
    int              fb_shift;          // feedback shift (16=disabled, 1=max)
    int              op_mode[6];        // 0=ratio, 1=fixed
} dx7refmki_voice_t;

/// Initialize a voice from a 156-byte DX7 patch (SAME layout as dx7ref).
void dx7refmki_voice_init(dx7refmki_voice_t *v, const uint8_t patch[156],
                          int midinote, int velocity, double sample_rate);

/// Render N=64 samples (Mark I path) into an Int32 output buffer.
/// buf must be zeroed by the caller before the first call.
void dx7refmki_voice_render(dx7refmki_voice_t *v, int32_t *buf);

/// Trigger note-off for a voice.
void dx7refmki_voice_noteoff(dx7refmki_voice_t *v);

#ifdef __cplusplus
}
#endif

#endif // DX7REFMKI_H
