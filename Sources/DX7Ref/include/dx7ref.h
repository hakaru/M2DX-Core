// dx7ref.h — DEXED msfa reference functions for comparison testing
// Ported from DEXED (https://github.com/asb2m10/dexed) under Apache 2.0 license.
// Test-only target: not included in production builds.

#ifndef DX7REF_H
#define DX7REF_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// --- Constants ---

#define DX7REF_LG_N 6
#define DX7REF_N (1 << DX7REF_LG_N)  // 64 samples per block
#define DX7REF_FEEDBACK_BITDEPTH 8

// --- Scaling Functions ---

/// DEXED ScaleRate: keyboard rate scaling
/// midinote: 0-127, sensitivity: 0-7
/// Returns qrate delta (added to qrate, not raw rate)
int dx7ref_scale_rate(int midinote, int sensitivity);

/// DEXED ScaleVelocity: velocity to level offset
/// velocity: 0-127 (7-bit), sensitivity: 0-8
/// Returns signed offset in microsteps
int dx7ref_scale_velocity(int velocity, int sensitivity);

/// DEXED ScaleLevel (Keyboard Level Scaling)
/// midinote: 0-127, break_point: 0-99 (DX7 format, add 21 for MIDI note)
/// left_depth, right_depth: 0-99
/// left_curve, right_curve: 0-3 (0=neg_lin, 1=neg_exp, 2=pos_exp, 3=pos_lin)
/// Returns signed level offset
int dx7ref_scale_level(int midinote, int break_point,
                       int left_depth, int right_depth,
                       int left_curve, int right_curve);

/// DEXED scaleoutlevel: DX7 output level (0-99) to internal level (0-127)
int dx7ref_scale_outlevel(int outlevel);

// --- Exp2 Lookup ---

/// DEXED Exp2::lookup: Q24 log-domain to Q24 linear amplitude
/// Input: x in Q24 log domain
/// Returns: amplitude in Q24
int32_t dx7ref_exp2_lookup(int32_t x);

// --- Sin Lookup ---

/// DEXED Sin::lookup: Q24 phase to Q24 amplitude
/// Input: phase in Q24 (full cycle = 2^24)
/// Returns: sine value in Q24 (range ±2^24)
int32_t dx7ref_sin_lookup(int32_t phase);

// --- Frequency Lookup ---

/// Initialize the frequency LUT for the given sample rate.
/// Must be called before dx7ref_freq_lookup().
void dx7ref_freq_init(double sample_rate);

/// DEXED Freqlut::lookup: log-frequency to Q24 phase increment.
/// Input: logfreq in Q24 (as computed by dx7ref_osc_freq)
/// Returns: phase increment per sample in Q24
int32_t dx7ref_freq_lookup(int32_t logfreq);

// --- Oscillator Frequency ---

/// Compute log-frequency for a DX7 operator.
/// midinote: 0-127, mode: 0=ratio, 1=fixed
/// coarse: 0-31, fine: 0-99, detune: 0-14 (7=center)
/// Returns: logfreq in Q24 format (same as DEXED osc_freq)
int32_t dx7ref_osc_freq(int midinote, int mode, int coarse, int fine, int detune);

// --- EG (Envelope Generator) ---

/// EG state for reference testing
typedef struct {
    int32_t level;
    int32_t target_level;
    int32_t inc;
    int      ix;          // stage: -1=idle, 0-3
    int      rising;      // 1=attack, 0=decay
    int      down;        // 1=key pressed, 0=released
    int      rates[4];    // R1-R4 (0-99)
    int      levels[4];   // L1-L4 (0-99)
    int      outlevel;    // scaleoutlevel(OL) << 5
    int      rate_scaling; // from dx7ref_scale_rate()
} dx7ref_eg_t;

/// Initialize EG with parameters
void dx7ref_eg_init(dx7ref_eg_t *eg,
                    const int rates[4], const int levels[4],
                    int outlevel_raw, int rate_scaling);

/// Trigger note-on (starts from level 0, stage 0)
void dx7ref_eg_note_on(dx7ref_eg_t *eg);

/// Trigger note-off (jump to stage 3)
void dx7ref_eg_note_off(dx7ref_eg_t *eg);

/// Process one block (N=64 samples) — returns level (Q16-ish)
int32_t dx7ref_eg_getsample(dx7ref_eg_t *eg);

/// Compute raw inc for given rate and rate_scaling (for unit testing)
/// Returns the rawInc value before SR correction
int dx7ref_eg_compute_inc(int rate, int rate_scaling);

// --- Algorithm Flags ---

/// Get algorithm flags for algorithm number (1-32)
/// flags[6]: operator order [0]=OP6, [1]=OP5, ..., [5]=OP1
/// Returns 0 on success, -1 if algorithm number is out of range
int dx7ref_get_algorithm_flags(int algorithm, uint8_t flags[6]);

// --- Voice-Level Rendering ---

/// Per-operator parameters (matches DEXED FmOpParams)
typedef struct {
    int32_t phase;      // Q24 phase accumulator
    int32_t freq;       // Q24 per-sample phase increment
    int32_t gain_out;   // previous block's gain (for interpolation)
    int32_t level_in;   // EG level (input to exp2)
} dx7ref_op_params_t;

/// Complete voice state for reference rendering
typedef struct {
    dx7ref_eg_t      eg[6];           // envelope generators
    dx7ref_op_params_t params[6];     // operator parameters (phase, freq, gain, level)
    int32_t          basepitch[6];    // log-frequency for each operator
    int32_t          fb_buf[2];       // feedback delay line
    int              algorithm;       // 0-31
    int              fb_shift;        // feedback shift (16=disabled, 1=max)
    int              op_mode[6];      // 0=ratio, 1=fixed
} dx7ref_voice_t;

/// Initialize a voice from a 156-byte DX7 patch + note/velocity.
/// patch: 156-byte unpacked voice data (6 ops × 21 bytes + 34 global bytes)
/// midinote: 0-127, velocity: 0-127 (7-bit)
/// sample_rate: audio sample rate (e.g. 44100.0)
/// Call dx7ref_freq_init() before this if sample_rate differs from previous call.
void dx7ref_voice_init(dx7ref_voice_t *v, const uint8_t patch[156],
                       int midinote, int velocity, double sample_rate);

/// Render N=64 samples from a voice into an Int32 output buffer.
/// Output is raw Q24 voice output (sum of carrier operators).
/// buf must be zeroed by caller before first call.
void dx7ref_voice_render(dx7ref_voice_t *v, int32_t *buf);

/// Trigger note-off for a voice.
void dx7ref_voice_noteoff(dx7ref_voice_t *v);

#ifdef __cplusplus
}
#endif

#endif // DX7REF_H
