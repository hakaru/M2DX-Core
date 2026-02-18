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

// NLS table: 32 entries for exponential KLS curve (index 0-31)
// Matches DEXED dx7note.cc ScaleCurve for exp curves
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
// ScaleRate — from DEXED dx7note.cc
// ============================================================================

static inline int min_int(int a, int b) { return a < b ? a : b; }
static inline int max_int(int a, int b) { return a > b ? a : b; }

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
        distance = -diff;
        depth = left_depth;
        curve = left_curve;
    } else {
        distance = diff;
        depth = right_depth;
        curve = right_curve;
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
        // Sustain at stage 3 while key held
        if (eg->ix == 3 && eg->down) return;
        eg_advance(eg, eg->ix + 1);
        return;
    }

    int rate = eg->rates[eg->ix];
    int qrate = (rate * 41) >> 6;
    qrate = min_int(63, qrate + eg->rate_scaling);
    int raw_inc = (4 + (qrate & 3)) << (8 + (qrate >> 2));
    eg->inc = raw_inc;  // No SR correction for reference (44100 Hz assumed)
}

int32_t dx7ref_eg_getsample(dx7ref_eg_t *eg) {
    if (eg->ix < 0) return 0;

    if (eg->ix < 3 || (eg->ix < 4 && !eg->down)) {
        if (eg->rising) {
            // Attack
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
            // Decay/Release
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
