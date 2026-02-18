// dx7ref.c — DEXED msfa reference functions for comparison testing
// Ported from DEXED (https://github.com/asb2m10/dexed) under Apache 2.0 license.
// Original copyright: Copyright 2012 Google Inc. / Pascal Gauthier
// SPDX-License-Identifier: Apache-2.0
//
// This is a test-only target. Functions are ported as faithfully as possible
// from the DEXED C++ codebase to serve as ground truth for M2DX engine testing.

#include "dx7ref.h"
#include <math.h>
#include <string.h>

// ============================================================================
// Constants
// ============================================================================

#define LG_N DX7REF_LG_N
#define N DX7REF_N

// ============================================================================
// Velocity Data Table (from DEXED pitchenv.cc / fm_op_kernel.cc)
// ============================================================================

static const uint8_t velocity_data[64] = {
    0, 70, 86, 97, 106, 114, 121, 126,
    132, 138, 142, 148, 152, 156, 160, 163,
    166, 170, 173, 174, 178, 181, 184, 186,
    189, 190, 194, 196, 198, 200, 202, 205,
    206, 209, 211, 214, 216, 218, 220, 222,
    224, 225, 227, 229, 230, 232, 233, 235,
    237, 238, 240, 241, 242, 243, 244, 246,
    246, 248, 249, 250, 251, 252, 253, 254
};

// ============================================================================
// NLS Table for Keyboard Level Scaling (exponential curve)
// ============================================================================

static const int nls_table[32] = {
    0,  0,  0,  1,  2,  4,  6,  9,
    13, 17, 22, 28, 34, 41, 49, 58,
    68, 79, 90, 103, 116, 131, 146, 163,
    181, 200, 220, 241, 264, 288, 313, 339
};

// ============================================================================
// Level Lookup for Output Level < 20
// ============================================================================

static const int level_lut[20] = {
    0, 5, 9, 13, 17, 20, 23, 25, 27, 29,
    31, 33, 35, 37, 39, 41, 42, 43, 45, 46
};

// ============================================================================
// Coarse frequency multiplier table (from DEXED dx7note.cc)
// ============================================================================

static const int32_t coarsemul[32] = {
    -16777216, 0, 16777216, 26591258, 33554432, 38955489, 43368474, 47099600,
    50331648, 53182516, 55732705, 58039632, 60145690, 62083076, 63876816,
    65546747, 67108864, 68576247, 69959732, 71268397, 72509921, 73690858,
    74816848, 75892776, 76922906, 77910978, 78860292, 79773775, 80654032,
    81503396, 82323963, 83117622
};

// ============================================================================
// Algorithm flags from DEXED fm_core.cc
// Operator order: [0]=OP6, [1]=OP5, ..., [5]=OP1
// ============================================================================

static const uint8_t algorithms[32][6] = {
    { 0xc1, 0x11, 0x11, 0x14, 0x01, 0x14 },  // Alg 1
    { 0x01, 0x11, 0x11, 0x14, 0xc1, 0x14 },  // Alg 2
    { 0xc1, 0x11, 0x14, 0x01, 0x11, 0x14 },  // Alg 3
    { 0xc1, 0x11, 0x94, 0x01, 0x11, 0x14 },  // Alg 4
    { 0xc1, 0x14, 0x01, 0x14, 0x01, 0x14 },  // Alg 5
    { 0xc1, 0x94, 0x01, 0x14, 0x01, 0x14 },  // Alg 6
    { 0xc1, 0x11, 0x05, 0x14, 0x01, 0x14 },  // Alg 7
    { 0x01, 0x11, 0xc5, 0x14, 0x01, 0x14 },  // Alg 8
    { 0x01, 0x11, 0x05, 0x14, 0xc1, 0x14 },  // Alg 9
    { 0x01, 0x05, 0x14, 0xc1, 0x11, 0x14 },  // Alg 10
    { 0xc1, 0x05, 0x14, 0x01, 0x11, 0x14 },  // Alg 11
    { 0x01, 0x05, 0x05, 0x14, 0xc1, 0x14 },  // Alg 12
    { 0xc1, 0x05, 0x05, 0x14, 0x01, 0x14 },  // Alg 13
    { 0xc1, 0x05, 0x11, 0x14, 0x01, 0x14 },  // Alg 14
    { 0x01, 0x05, 0x11, 0x14, 0xc1, 0x14 },  // Alg 15
    { 0xc1, 0x11, 0x02, 0x25, 0x05, 0x14 },  // Alg 16
    { 0x01, 0x11, 0x02, 0x25, 0xc5, 0x14 },  // Alg 17
    { 0x01, 0x11, 0x11, 0xc5, 0x05, 0x14 },  // Alg 18
    { 0xc1, 0x14, 0x14, 0x01, 0x11, 0x14 },  // Alg 19
    { 0x01, 0x05, 0x14, 0xc1, 0x14, 0x14 },  // Alg 20
    { 0x01, 0x14, 0x14, 0xc1, 0x14, 0x14 },  // Alg 21
    { 0xc1, 0x14, 0x14, 0x14, 0x01, 0x14 },  // Alg 22
    { 0xc1, 0x14, 0x14, 0x01, 0x14, 0x04 },  // Alg 23
    { 0xc1, 0x14, 0x14, 0x14, 0x04, 0x04 },  // Alg 24
    { 0xc1, 0x14, 0x14, 0x04, 0x04, 0x04 },  // Alg 25
    { 0xc1, 0x05, 0x14, 0x01, 0x14, 0x04 },  // Alg 26
    { 0x01, 0x05, 0x14, 0xc1, 0x14, 0x04 },  // Alg 27
    { 0x04, 0xc1, 0x11, 0x14, 0x01, 0x14 },  // Alg 28
    { 0xc1, 0x14, 0x01, 0x14, 0x04, 0x04 },  // Alg 29
    { 0x04, 0xc1, 0x11, 0x14, 0x04, 0x04 },  // Alg 30
    { 0xc1, 0x14, 0x04, 0x04, 0x04, 0x04 },  // Alg 31
    { 0xc4, 0x04, 0x04, 0x04, 0x04, 0x04 },  // Alg 32
};

// ============================================================================
// Exp2 Table (generated at init, matches DEXED exp2.cc)
// ============================================================================

static int32_t exp2_tab[2048];  // 1024 * 2 (delta + value interleaved)
static int exp2_initialized = 0;

static void init_exp2_tab(void) {
    if (exp2_initialized) return;
    double inc = exp2(1.0 / 1024.0);
    double y = (double)(1 << 30);
    for (int i = 0; i < 1024; i++) {
        exp2_tab[(i << 1) + 1] = (int32_t)floor(y + 0.5);
        y *= inc;
    }
    for (int i = 0; i < 1023; i++) {
        exp2_tab[i << 1] = exp2_tab[(i << 1) + 3] - exp2_tab[(i << 1) + 1];
    }
    exp2_tab[2046] = (int32_t)((uint32_t)(1u << 31) - (uint32_t)exp2_tab[2047]);
    exp2_initialized = 1;
}

// ============================================================================
// Sin Table (matches DEXED sin.cc with SIN_DELTA)
// ============================================================================

#define SIN_LG_N_SAMPLES 10
#define SIN_N_SAMPLES (1 << SIN_LG_N_SAMPLES)

static int32_t sintab[SIN_N_SAMPLES << 1];  // delta + value interleaved
static int sin_initialized = 0;

static void init_sin_tab(void) {
    if (sin_initialized) return;
    double dphase = 2 * 3.14159265358979323846 / SIN_N_SAMPLES;
    int32_t c = (int32_t)floor(cos(dphase) * (1 << 30) + 0.5);
    int32_t s = (int32_t)floor(sin(dphase) * (1 << 30) + 0.5);
    int32_t u = 1 << 30;
    int32_t v = 0;
    int64_t rnd = 1 << 29;
    for (int i = 0; i < SIN_N_SAMPLES / 2; i++) {
        sintab[(i << 1) + 1] = (v + 32) >> 6;
        sintab[((i + SIN_N_SAMPLES / 2) << 1) + 1] = -((v + 32) >> 6);
        int32_t t = ((int64_t)u * (int64_t)s + (int64_t)v * (int64_t)c + rnd) >> 30;
        u = ((int64_t)u * (int64_t)c - (int64_t)v * (int64_t)s + rnd) >> 30;
        v = t;
    }
    for (int i = 0; i < SIN_N_SAMPLES - 1; i++) {
        sintab[i << 1] = sintab[(i << 1) + 3] - sintab[(i << 1) + 1];
    }
    sintab[(SIN_N_SAMPLES << 1) - 2] = -sintab[(SIN_N_SAMPLES << 1) - 1];
    sin_initialized = 1;
}

// ============================================================================
// Frequency LUT (matches DEXED freqlut.cc)
// ============================================================================

#define FREQ_LG_N_SAMPLES 10
#define FREQ_N_SAMPLES (1 << FREQ_LG_N_SAMPLES)
#define FREQ_SAMPLE_SHIFT (24 - FREQ_LG_N_SAMPLES)
#define FREQ_MAX_LOGFREQ_INT 20

static int32_t freq_lut[FREQ_N_SAMPLES + 1];
static int freq_initialized = 0;
static double freq_sample_rate = 0;

static void init_freq_lut(double sample_rate) {
    if (freq_initialized && freq_sample_rate == sample_rate) return;
    double y = (double)(1LL << (24 + FREQ_MAX_LOGFREQ_INT)) / sample_rate;
    double inc = pow(2, 1.0 / FREQ_N_SAMPLES);
    for (int i = 0; i < FREQ_N_SAMPLES + 1; i++) {
        freq_lut[i] = (int32_t)floor(y + 0.5);
        y *= inc;
    }
    freq_sample_rate = sample_rate;
    freq_initialized = 1;
}

// ============================================================================
// Helper
// ============================================================================

static inline int min_int(int a, int b) { return a < b ? a : b; }
static inline int max_int(int a, int b) { return a > b ? a : b; }

// ============================================================================
// ScaleRate — from DEXED dx7note.cc
// ============================================================================

int dx7ref_scale_rate(int midinote, int sensitivity) {
    int x = min_int(31, max_int(0, midinote / 3 - 7));
    int qratedelta = (sensitivity * x) >> 3;
    return qratedelta;
}

// ============================================================================
// ScaleVelocity — from DEXED dx7note.cc
// ============================================================================

int dx7ref_scale_velocity(int velocity, int sensitivity) {
    int clamped_vel = min_int(127, max_int(0, velocity));
    int vel_idx = min_int(63, clamped_vel >> 1);
    int vel_value = (int)velocity_data[vel_idx] - 239;
    int scaled = ((min_int(sensitivity, 7) * vel_value + 7) >> 3) << 4;
    return scaled;
}

// ============================================================================
// ScaleLevel (KLS) — from DEXED dx7note.cc
// ============================================================================

int dx7ref_scale_level(int midinote, int break_point,
                       int left_depth, int right_depth,
                       int left_curve, int right_curve) {
    int bp = break_point + 21;
    int diff = midinote - bp;
    if (diff == 0) return 0;

    int distance, depth, curve;
    if (diff < 0) {
        distance = -diff; depth = left_depth; curve = left_curve;
    } else {
        distance = diff; depth = right_depth; curve = right_curve;
    }
    if (depth == 0) return 0;

    int group = min_int(31, (distance + 1) / 3);
    int is_linear = (curve == 0 || curve == 3);
    int is_negative = (curve < 2);

    int scale;
    if (is_linear) {
        scale = (group * depth * 329 + 2048) >> 12;
    } else {
        int nls_value = nls_table[min_int(31, group)];
        scale = (nls_value * depth + 1024) >> 11;
    }
    int capped = min_int(127, scale);
    return is_negative ? capped : -capped;
}

// ============================================================================
// scaleoutlevel — from DEXED dx7note.cc
// ============================================================================

int dx7ref_scale_outlevel(int outlevel) {
    if (outlevel >= 20) return 28 + outlevel;
    return level_lut[max_int(0, min_int(19, outlevel))];
}

// ============================================================================
// Exp2 Lookup — from DEXED exp2.cc
// ============================================================================

int32_t dx7ref_exp2_lookup(int32_t x) {
    init_exp2_tab();
    int lowbits = x & ((1 << 14) - 1);
    int x_idx = (x >> 13) & 2046;
    int dy = exp2_tab[x_idx];
    int y0 = exp2_tab[x_idx + 1];
    int y = y0 + ((dy * lowbits) >> 14);
    int shift = 6 - (x >> 24);
    if (shift >= 31) return 0;
    if (shift <= 0) return (int32_t)(y << (-shift));
    return (int32_t)(y >> shift);
}

// ============================================================================
// Sin Lookup — from DEXED sin.cc (SIN_DELTA mode)
// ============================================================================

int32_t dx7ref_sin_lookup(int32_t phase) {
    init_sin_tab();
    const int SHIFT = 24 - SIN_LG_N_SAMPLES;  // 14
    int lowbits = phase & ((1 << SHIFT) - 1);
    int phase_int = (phase >> (SHIFT - 1)) & ((SIN_N_SAMPLES - 1) << 1);
    int dy = sintab[phase_int];
    int y0 = sintab[phase_int + 1];
    return y0 + (((int64_t)dy * (int64_t)lowbits) >> SHIFT);
}

// ============================================================================
// Frequency LUT — from DEXED freqlut.cc
// ============================================================================

void dx7ref_freq_init(double sample_rate) {
    init_freq_lut(sample_rate);
}

int32_t dx7ref_freq_lookup(int32_t logfreq) {
    int ix = (logfreq & 0xffffff) >> FREQ_SAMPLE_SHIFT;
    int32_t y0 = freq_lut[ix];
    int32_t y1 = freq_lut[ix + 1];
    int lowbits = logfreq & ((1 << FREQ_SAMPLE_SHIFT) - 1);
    int32_t y = y0 + ((((int64_t)(y1 - y0) * (int64_t)lowbits)) >> FREQ_SAMPLE_SHIFT);
    int hibits = logfreq >> 24;
    return y >> (FREQ_MAX_LOGFREQ_INT - hibits);
}

// ============================================================================
// Oscillator Frequency — from DEXED dx7note.cc Dx7Note::osc_freq
// ============================================================================

/// Standard tuning: midinote to logfreq
static int32_t midinote_to_logfreq(int midinote) {
    // (log(440) / log(2)) = 8.78135971...
    // 8.78135971 * (1 << 24) = 147389085.7
    // 69 * (1<<24)/12 = 96468992
    const int32_t base = 147389085;   // log2(440) in Q24
    const int32_t step = 1398101;     // (1<<24)/12
    return base + step * (midinote - 69);
}

int32_t dx7ref_osc_freq(int midinote, int mode, int coarse, int fine, int detune) {
    int32_t logfreq;
    if (mode == 0) {
        logfreq = midinote_to_logfreq(midinote);

        // Detune: frequency-dependent, from DEXED dx7note.cc
        double detuneRatio = 0.0209 * exp(-0.396 * (((double)logfreq) / (1 << 24))) / 7;
        logfreq += (int32_t)(detuneRatio * logfreq * (detune - 7));

        logfreq += coarsemul[coarse & 31];
        if (fine) {
            // (1 << 24) / log(2) = 24204406.323123
            logfreq += (int32_t)floor(24204406.323123 * log(1 + 0.01 * fine) + 0.5);
        }
    } else {
        // Fixed frequency mode
        // ((1 << 24) * log(10) / log(2) * .01) << 3
        logfreq = (4458616 * ((coarse & 3) * 100 + fine)) >> 3;
        logfreq += detune > 7 ? 13457 * (detune - 7) : 0;
    }
    return logfreq;
}

// ============================================================================
// EG — from DEXED env.cc
// ============================================================================

static void eg_advance(dx7ref_eg_t *eg, int new_ix);

void dx7ref_eg_init(dx7ref_eg_t *eg,
                    const int rates[4], const int levels[4],
                    int outlevel_raw, int rate_scaling) {
    memset(eg, 0, sizeof(*eg));
    eg->ix = -1;
    eg->level = 0;
    eg->target_level = 0;
    eg->inc = 0;
    eg->rising = 0;
    eg->down = 0;
    for (int i = 0; i < 4; i++) {
        eg->rates[i] = min_int(99, max_int(0, rates[i]));
        eg->levels[i] = min_int(99, max_int(0, levels[i]));
    }
    eg->outlevel = dx7ref_scale_outlevel(outlevel_raw) << 5;
    eg->rate_scaling = rate_scaling;
}

/// Initialize EG with pre-computed outlevel (already includes KLS + velocity)
static void eg_init_with_outlevel(dx7ref_eg_t *eg,
                                  const int rates[4], const int levels[4],
                                  int outlevel, int rate_scaling) {
    memset(eg, 0, sizeof(*eg));
    eg->ix = -1;
    eg->level = 0;
    eg->target_level = 0;
    eg->inc = 0;
    eg->rising = 0;
    eg->down = 0;
    for (int i = 0; i < 4; i++) {
        eg->rates[i] = min_int(99, max_int(0, rates[i]));
        eg->levels[i] = min_int(99, max_int(0, levels[i]));
    }
    eg->outlevel = outlevel;
    eg->rate_scaling = rate_scaling;
}

void dx7ref_eg_note_on(dx7ref_eg_t *eg) {
    eg->level = 0;
    eg->down = 1;
    eg_advance(eg, 0);
}

void dx7ref_eg_note_off(dx7ref_eg_t *eg) {
    if (eg->ix >= 0) {
        eg->down = 0;
        eg_advance(eg, 3);
    }
}

static void eg_advance(dx7ref_eg_t *eg, int new_ix) {
    eg->ix = new_ix;
    if (eg->ix >= 4) { eg->ix = -1; return; }

    int new_level = eg->levels[eg->ix];
    int actual_level = ((dx7ref_scale_outlevel(new_level) >> 1) << 6) + eg->outlevel - 4256;
    if (actual_level < 16) actual_level = 16;
    eg->target_level = actual_level << 16;
    eg->rising = (eg->target_level > eg->level) ? 1 : 0;

    if (eg->target_level == eg->level) {
        if (eg->ix == 3 && eg->down) return;
        eg_advance(eg, eg->ix + 1);
        return;
    }

    int rate = eg->rates[eg->ix];
    int qrate = (rate * 41) >> 6;
    qrate = min_int(63, qrate + eg->rate_scaling);
    int raw_inc = (4 + (qrate & 3)) << (8 + (qrate >> 2));
    eg->inc = raw_inc;
}

int32_t dx7ref_eg_getsample(dx7ref_eg_t *eg) {
    if (eg->ix < 0) return 0;

    if (eg->ix < 3 || (eg->ix < 4 && !eg->down)) {
        if (eg->rising) {
            int32_t jump_target = 1716;
            if (eg->level < (jump_target << 16)) {
                eg->level = jump_target << 16;
            }
            int32_t step = (int32_t)((((int64_t)(17 << 24) - (int64_t)eg->level) >> 24) * (int64_t)eg->inc);
            eg->level += step;
            if (eg->level >= eg->target_level) {
                eg->level = eg->target_level;
                eg_advance(eg, eg->ix + 1);
            }
        } else {
            eg->level -= eg->inc;
            if (eg->level <= eg->target_level) {
                eg->level = eg->target_level;
                eg_advance(eg, eg->ix + 1);
            }
        }
    }

    return eg->level;
}

int dx7ref_eg_compute_inc(int rate, int rate_scaling) {
    int qrate = (rate * 41) >> 6;
    qrate = min_int(63, qrate + rate_scaling);
    return (4 + (qrate & 3)) << (8 + (qrate >> 2));
}

// ============================================================================
// Algorithm Flags
// ============================================================================

int dx7ref_get_algorithm_flags(int algorithm, uint8_t flags[6]) {
    if (algorithm < 1 || algorithm > 32) return -1;
    memcpy(flags, algorithms[algorithm - 1], 6);
    return 0;
}

// ============================================================================
// FM Op Kernel — from DEXED fm_op_kernel.cc
// ============================================================================

/// Modulated operator: output[i] = sin(phase + input[i]) * gain
static void compute_mod(int32_t *output, const int32_t *input,
                        int32_t phase0, int32_t freq,
                        int32_t gain1, int32_t gain2, int add) {
    int32_t dgain = (gain2 - gain1 + (N >> 1)) >> LG_N;
    int32_t gain = gain1;
    int32_t phase = phase0;
    for (int i = 0; i < N; i++) {
        gain += dgain;
        int32_t y = dx7ref_sin_lookup(phase + input[i]);
        int32_t y1 = ((int64_t)y * (int64_t)gain) >> 24;
        if (add) output[i] += y1; else output[i] = y1;
        phase += freq;
    }
}

/// Pure (unmodulated) operator: output[i] = sin(phase) * gain
static void compute_pure(int32_t *output, int32_t phase0, int32_t freq,
                         int32_t gain1, int32_t gain2, int add) {
    int32_t dgain = (gain2 - gain1 + (N >> 1)) >> LG_N;
    int32_t gain = gain1;
    int32_t phase = phase0;
    for (int i = 0; i < N; i++) {
        gain += dgain;
        int32_t y = dx7ref_sin_lookup(phase);
        int32_t y1 = ((int64_t)y * (int64_t)gain) >> 24;
        if (add) output[i] += y1; else output[i] = y1;
        phase += freq;
    }
}

/// Feedback operator: output[i] = sin(phase + fb) * gain, where fb = (y0 + y) >> (shift+1)
static void compute_fb(int32_t *output, int32_t phase0, int32_t freq,
                       int32_t gain1, int32_t gain2,
                       int32_t *fb_buf, int fb_shift, int add) {
    int32_t dgain = (gain2 - gain1 + (N >> 1)) >> LG_N;
    int32_t gain = gain1;
    int32_t phase = phase0;
    int32_t y0 = fb_buf[0];
    int32_t y = fb_buf[1];
    for (int i = 0; i < N; i++) {
        gain += dgain;
        int32_t scaled_fb = (y0 + y) >> (fb_shift + 1);
        y0 = y;
        y = dx7ref_sin_lookup(phase + scaled_fb);
        y = ((int64_t)y * (int64_t)gain) >> 24;
        if (add) output[i] += y; else output[i] = y;
        phase += freq;
    }
    fb_buf[0] = y0;
    fb_buf[1] = y;
}

// ============================================================================
// FmCore::render — from DEXED fm_core.cc
// ============================================================================

static void fm_core_render(int32_t *output, dx7ref_op_params_t params[6],
                           int algorithm, int32_t *fb_buf, int fb_shift) {
    const int kLevelThresh = 1120;
    const uint8_t *alg = algorithms[algorithm];
    int has_contents[3] = { 1, 0, 0 };
    int32_t bus1[N];
    int32_t bus2[N];

    for (int op = 0; op < 6; op++) {
        int flags = alg[op];
        int add = (flags & 0x04) != 0;
        int inbus = (flags >> 4) & 3;
        int outbus = flags & 3;
        int32_t *outptr;
        switch (outbus) {
            case 1: outptr = bus1; break;
            case 2: outptr = bus2; break;
            default: outptr = output; break;
        }
        int32_t gain1 = params[op].gain_out;
        int32_t gain2 = dx7ref_exp2_lookup(params[op].level_in - (14 * (1 << 24)));
        params[op].gain_out = gain2;

        if (gain1 >= kLevelThresh || gain2 >= kLevelThresh) {
            if (!has_contents[outbus]) {
                add = 0;
            }
            if (inbus == 0 || !has_contents[inbus]) {
                if ((flags & 0xc0) == 0xc0 && fb_shift < 16) {
                    compute_fb(outptr, params[op].phase, params[op].freq,
                               gain1, gain2, fb_buf, fb_shift, add);
                } else {
                    compute_pure(outptr, params[op].phase, params[op].freq,
                                 gain1, gain2, add);
                }
            } else {
                int32_t *inptr = (inbus == 1) ? bus1 : bus2;
                compute_mod(outptr, inptr, params[op].phase, params[op].freq,
                            gain1, gain2, add);
            }
            has_contents[outbus] = 1;
        } else if (!add) {
            has_contents[outbus] = 0;
        }
        params[op].phase += params[op].freq << LG_N;
    }
}

// ============================================================================
// Voice Init — from DEXED dx7note.cc Dx7Note::init()
// ============================================================================

void dx7ref_voice_init(dx7ref_voice_t *v, const uint8_t patch[156],
                       int midinote, int velocity, double sample_rate) {
    init_exp2_tab();
    init_sin_tab();
    init_freq_lut(sample_rate);

    memset(v, 0, sizeof(*v));

    int rates[4];
    int levels[4];

    for (int op = 0; op < 6; op++) {
        int off = op * 21;
        for (int i = 0; i < 4; i++) {
            rates[i] = patch[off + i];
            levels[i] = patch[off + 4 + i];
        }
        int outlevel = patch[off + 16];
        outlevel = dx7ref_scale_outlevel(outlevel);
        int level_scaling = dx7ref_scale_level(
            midinote, patch[off + 8], patch[off + 9],
            patch[off + 10], patch[off + 11], patch[off + 12]);
        outlevel += level_scaling;
        outlevel = min_int(127, outlevel);
        outlevel = outlevel << 5;
        outlevel += dx7ref_scale_velocity(velocity, patch[off + 15]);
        outlevel = max_int(0, outlevel);
        int rate_scaling = dx7ref_scale_rate(midinote, patch[off + 13]);
        eg_init_with_outlevel(&v->eg[op], rates, levels, outlevel, rate_scaling);
        dx7ref_eg_note_on(&v->eg[op]);

        int mode = patch[off + 17];
        int coarse = patch[off + 18];
        int fine = patch[off + 19];
        int detune = patch[off + 20];
        int32_t freq = dx7ref_osc_freq(midinote, mode, coarse, fine, detune);
        v->op_mode[op] = mode;
        v->basepitch[op] = freq;

        // Initialize operator params
        v->params[op].phase = 0;
        v->params[op].freq = dx7ref_freq_lookup(freq);
        v->params[op].gain_out = 0;
        v->params[op].level_in = 0;
    }

    v->algorithm = patch[134];
    int feedback = patch[135];
    v->fb_shift = feedback != 0 ? DX7REF_FEEDBACK_BITDEPTH - feedback : 16;
    v->fb_buf[0] = 0;
    v->fb_buf[1] = 0;
}

// ============================================================================
// Voice Render — from DEXED dx7note.cc Dx7Note::compute() (simplified)
// ============================================================================

void dx7ref_voice_render(dx7ref_voice_t *v, int32_t *buf) {
    // No pitch mod, no LFO, no controllers for pure comparison.
    // Just EG → gain → fm_core::render
    for (int op = 0; op < 6; op++) {
        int32_t level = dx7ref_eg_getsample(&v->eg[op]);
        v->params[op].level_in = level;
        // freq is already set and doesn't change (no pitch mod)
    }
    fm_core_render(buf, v->params, v->algorithm, v->fb_buf, v->fb_shift);
}

// ============================================================================
// Voice Note-Off
// ============================================================================

void dx7ref_voice_noteoff(dx7ref_voice_t *v) {
    for (int op = 0; op < 6; op++) {
        dx7ref_eg_note_off(&v->eg[op]);
    }
}
