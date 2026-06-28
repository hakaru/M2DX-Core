// dx7refmki.c — "Mark I" (OPS log-sin + exp) reference for comparison testing.
//
// Clean-room twin of M2DX-Core's Swift Mark I path. Built ONLY from our own
// Apache code (dx7ref.c scaffolding) + the public OPS formulas documented in
// DX7MarkI_PROVENANCE.md / MarkISinTables.swift / DX7MarkI.swift.
// It does NOT copy Dexed's GPL-3.0 EngineMkI.cpp.
// SPDX-License-Identifier: Apache-2.0
//
// REUSED VERBATIM (in spirit) from dx7ref.c — these are our own Apache code:
//   * EG (env.cc-derived):  eg_advance / note_on / note_off / getsample
//   * frequency LUT + osc_freq + the scale_* helpers
//   * the 32×6 algorithm flag table (`algorithms`)
//   * voice_init from the 156-byte patch + the N=64 block render scaffold
//
// REPLACED to match the Swift Mark I (DX7MarkI.swift / renderBlockMarkI):
//   * per-sample operator: sin*gain  ->  OPS log-sin + exp (`mki_sin`)
//   * gain:                exp2(level)  ->  log-attenuation (`mki_atten`)
//   * silence guard:       inverted (smaller attenuation = audible)
//   * feedback shift:      +2 for algIndex 3/5/31 (`fb_shift_mki`)
//   * fused Alg 4 (idx 3) / Alg 6 (idx 5) feedback chains

#include "dx7refmki.h"
#include <math.h>
#include <string.h>

// ============================================================================
// Constants
// ============================================================================

#define LG_N DX7REFMKI_LG_N
#define N DX7REFMKI_N
#define ENV_MAX DX7REFMKI_ENV_MAX
#define LEVEL_THRESH DX7REFMKI_LEVEL_THRESH

// ============================================================================
// Tables shared with dx7ref (our own Apache data) — velocity / NLS / level /
// coarse multiplier / algorithm flags. Kept local (static) so the two C
// references stay independent translation units.
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

static const int nls_table[32] = {
    0,  0,  0,  1,  2,  4,  6,  9,
    13, 17, 22, 28, 34, 41, 49, 58,
    68, 79, 90, 103, 116, 131, 146, 163,
    181, 200, 220, 241, 264, 288, 313, 339
};

static const int level_lut[20] = {
    0, 5, 9, 13, 17, 20, 23, 25, 27, 29,
    31, 33, 35, 37, 39, 41, 42, 43, 45, 46
};

static const int32_t coarsemul[32] = {
    -16777216, 0, 16777216, 26591258, 33554432, 38955489, 43368474, 47099600,
    50331648, 53182516, 55732705, 58039632, 60145690, 62083076, 63876816,
    65546747, 67108864, 68576247, 69959732, 71268397, 72509921, 73690858,
    74816848, 75892776, 76922906, 77910978, 78860292, 79773775, 80654032,
    81503396, 82323963, 83117622
};

// Algorithm flags — operator order [0]=OP6, [1]=OP5, ..., [5]=OP1.
// Identical to dx7ref.c `algorithms` AND to M2DXCore kAlgorithmFlags.
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
// Mark I OPS log-sine + exp tables — regenerated from the SAME formulas as
// MarkISinTables.swift (NOT from any GPL table dump).
//   sinlog[i] = round( -1024 * log2( sin( ((0.5+i)/1024) * (pi/2) ) ) )
//   sinexp[i] = round( (2^(i/1024) - 1) * 4096 )
// ============================================================================

static uint16_t sinlog[1024];
static uint16_t sinexp[1024];
static int mki_tables_initialized = 0;

void dx7refmki_tables_init(void) {
    if (mki_tables_initialized) return;
    const double half_pi = 3.14159265358979323846 / 2.0;
    for (int i = 0; i < 1024; i++) {
        double x = sin(((0.5 + (double)i) / 1024.0) * half_pi);
        sinlog[i] = (uint16_t)floor(-1024.0 * log2(x) + 0.5);
    }
    for (int i = 0; i < 1024; i++) {
        sinexp[i] = (uint16_t)floor((pow(2.0, (double)i / 1024.0) - 1.0) * 4096.0 + 0.5);
    }
    mki_tables_initialized = 1;
}

// ============================================================================
// mki_sin — C twin of Swift `mkiSin` (DX7MarkI.swift).
// ============================================================================

#define MKI_NEG_BIT  0x8000u
#define MKI_LOG_MASK 1023u

// Log-sine with quadrant folding. phi = top 10 bits of the Q24 phase.
// Twin of Swift `markISinLog`.
static inline uint16_t mki_sin_log(uint32_t phi) {
    uint16_t index = (uint16_t)(phi & MKI_LOG_MASK);
    switch (phi & (1024u * 3u)) {
        case 0u:        return sinlog[index];
        case 1024u:     return sinlog[index ^ (uint16_t)MKI_LOG_MASK];
        case 1024u * 2u:return (uint16_t)(sinlog[index] | MKI_NEG_BIT);
        default:        return (uint16_t)(sinlog[index ^ (uint16_t)MKI_LOG_MASK] | MKI_NEG_BIT);
    }
}

int32_t dx7refmki_sin(int32_t phase, uint16_t atten) {
    // phi = top bits, unsigned (no signed shift) — Swift: UInt32(bitPattern: phase) >> 12
    uint32_t phi = (uint32_t)phase >> 12;
    uint16_t expVal = (uint16_t)(mki_sin_log(phi) + atten);   // &+ wraps mod 2^16
    int signed_neg = (expVal & MKI_NEG_BIT) != 0;
    expVal = (uint16_t)(expVal & (uint16_t)~MKI_NEG_BIT);
    int32_t mantissa = (int32_t)4096 + (int32_t)sinexp[(expVal & 0x3FFu) ^ 0x3FFu];
    int shift = (int)(expVal >> 10);
    int32_t result = (shift >= 31) ? 0 : (mantissa >> shift);
    return signed_neg ? (((-result) - 1) << 13) : (result << 13);
}

// ============================================================================
// mki_atten — C twin of Swift `markIAtten` (DX7MarkI.swift).
// ============================================================================

uint16_t dx7refmki_atten(int32_t level_in) {
    int32_t raw = (int32_t)ENV_MAX - (level_in >> 14);
    int32_t clamped = raw;
    if (clamped < 0) clamped = 0;
    if (clamped > ENV_MAX) clamped = ENV_MAX;
    return (clamped == 0) ? (uint16_t)(ENV_MAX - 1) : (uint16_t)clamped;
}

// ============================================================================
// Frequency LUT — same math as dx7ref (our own Apache code).
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

void dx7refmki_freq_init(double sample_rate) {
    init_freq_lut(sample_rate);
}

int32_t dx7refmki_freq_lookup(int32_t logfreq) {
    int ix = (logfreq & 0xffffff) >> FREQ_SAMPLE_SHIFT;
    int32_t y0 = freq_lut[ix];
    int32_t y1 = freq_lut[ix + 1];
    int lowbits = logfreq & ((1 << FREQ_SAMPLE_SHIFT) - 1);
    int32_t y = y0 + ((((int64_t)(y1 - y0) * (int64_t)lowbits)) >> FREQ_SAMPLE_SHIFT);
    int hibits = logfreq >> 24;
    return y >> (FREQ_MAX_LOGFREQ_INT - hibits);
}

// ============================================================================
// Helpers + scaling math — identical to dx7ref (our own Apache code).
// ============================================================================

static inline int min_int(int a, int b) { return a < b ? a : b; }
static inline int max_int(int a, int b) { return a > b ? a : b; }

static int scale_rate(int midinote, int sensitivity) {
    int x = min_int(31, max_int(0, midinote / 3 - 7));
    int qratedelta = (sensitivity * x) >> 3;
    return qratedelta;
}

static int scale_velocity(int velocity, int sensitivity) {
    int clamped_vel = min_int(127, max_int(0, velocity));
    int vel_idx = min_int(63, clamped_vel >> 1);
    int vel_value = (int)velocity_data[vel_idx] - 239;
    int scaled = ((min_int(sensitivity, 7) * vel_value + 7) >> 3) << 4;
    return scaled;
}

static int scale_level(int midinote, int break_point,
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

static int scale_outlevel(int outlevel) {
    if (outlevel >= 20) return 28 + outlevel;
    return level_lut[max_int(0, min_int(19, outlevel))];
}

static int32_t midinote_to_logfreq(int midinote) {
    const int32_t base = 147389085;   // log2(440) in Q24
    const int32_t step = 1398101;     // (1<<24)/12
    return base + step * (midinote - 69);
}

int32_t dx7refmki_osc_freq(int midinote, int mode, int coarse, int fine, int detune) {
    int32_t logfreq;
    if (mode == 0) {
        logfreq = midinote_to_logfreq(midinote);
        double detuneRatio = 0.0209 * exp(-0.396 * (((double)logfreq) / (1 << 24))) / 7;
        logfreq += (int32_t)(detuneRatio * logfreq * (detune - 7));
        logfreq += coarsemul[coarse & 31];
        if (fine) {
            logfreq += (int32_t)floor(24204406.323123 * log(1 + 0.01 * fine) + 0.5);
        }
    } else {
        logfreq = (4458616 * ((coarse & 3) * 100 + fine)) >> 3;
        logfreq += detune > 7 ? 13457 * (detune - 7) : 0;
    }
    return logfreq;
}

// ============================================================================
// EG — identical to dx7ref (env.cc-derived; our own Apache code).
// ============================================================================

static void eg_advance(dx7refmki_eg_t *eg, int new_ix);

static void eg_init_with_outlevel(dx7refmki_eg_t *eg,
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

void dx7refmki_eg_note_on(dx7refmki_eg_t *eg) {
    eg->level = 0;
    eg->down = 1;
    eg_advance(eg, 0);
}

void dx7refmki_eg_note_off(dx7refmki_eg_t *eg) {
    if (eg->ix >= 0) {
        eg->down = 0;
        eg_advance(eg, 3);
    }
}

static void eg_advance(dx7refmki_eg_t *eg, int new_ix) {
    eg->ix = new_ix;
    if (eg->ix >= 4) { eg->ix = -1; return; }

    int new_level = eg->levels[eg->ix];
    int actual_level = ((scale_outlevel(new_level) >> 1) << 6) + eg->outlevel - 4256;
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

int32_t dx7refmki_eg_getsample(dx7refmki_eg_t *eg) {
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

// ============================================================================
// Mark I single-input FM kernels — C twins of DX7MarkI.swift
// (computeModMkI / computePureMkI / computeFbMkI).
// ============================================================================

// attenRamp: full block -> (d + n/2) >> LG_N ; partial -> d / n.
// Twin of Swift `attenRamp`.
static inline int32_t mki_atten_ramp(uint16_t a1, uint16_t a2, int n) {
    int32_t d = (int32_t)a2 - (int32_t)a1;
    if (n == N) {
        return (d + (int32_t)(n >> 1)) >> LG_N;
    }
    return d / (int32_t)n;
}

// max(0, acc) clamped into the UInt16 the Swift passes as the attenuation
// (Swift: UInt16(truncatingIfNeeded: max(0, aAcc))).
static inline uint16_t mki_clamp_atten(int32_t acc) {
    int32_t v = (acc < 0) ? 0 : acc;
    return (uint16_t)((uint32_t)v & 0xFFFFu);   // truncatingIfNeeded
}

// OPS modulation alignment: forward modulation feeds the carrier phase 3 bits
// lower than MSFA. Twin of Swift `markIModScale` at the ÷8 default (Q12 scale 512 → v>>3).
static inline int32_t mki_mod_scale(int32_t v) { return v >> 3; }

static void compute_mod_mki(int32_t *output, const int32_t *input,
                            int32_t phase0, int32_t freq,
                            uint16_t atten1, uint16_t atten2, int add, int n) {
    int32_t dA = mki_atten_ramp(atten1, atten2, n);
    int32_t aAcc = (int32_t)atten1;
    int32_t phase = phase0;
    for (int i = 0; i < n; i++) {
        aAcc += dA;
        int32_t y = dx7refmki_sin(phase + mki_mod_scale(input[i]), mki_clamp_atten(aAcc));
        if (add) output[i] += y; else output[i] = y;
        phase += freq;
    }
}

static void compute_pure_mki(int32_t *output,
                             int32_t phase0, int32_t freq,
                             uint16_t atten1, uint16_t atten2, int add, int n) {
    int32_t dA = mki_atten_ramp(atten1, atten2, n);
    int32_t aAcc = (int32_t)atten1;
    int32_t phase = phase0;
    for (int i = 0; i < n; i++) {
        aAcc += dA;
        int32_t y = dx7refmki_sin(phase, mki_clamp_atten(aAcc));
        if (add) output[i] += y; else output[i] = y;
        phase += freq;
    }
}

static void compute_fb_mki(int32_t *output, int32_t phase0, int32_t freq,
                           uint16_t atten1, uint16_t atten2,
                           int32_t *fb_buf, int fb_shift, int add, int n) {
    int32_t dA = mki_atten_ramp(atten1, atten2, n);
    int32_t aAcc = (int32_t)atten1;
    int32_t phase = phase0;
    int32_t y0 = fb_buf[0];
    int32_t y = fb_buf[1];
    for (int i = 0; i < n; i++) {
        aAcc += dA;
        int32_t scaled_fb = (y0 + y) >> (fb_shift + 1);
        y0 = y;
        y = dx7refmki_sin(phase + scaled_fb, mki_clamp_atten(aAcc));
        if (add) output[i] += y; else output[i] = y;
        phase += freq;
    }
    fb_buf[0] = y0;
    fb_buf[1] = y;
}

// ============================================================================
// Mark I fused feedback chains — C twins of computeFb2MkI / computeFb3MkI.
// Heap-free param block mirroring Swift MarkIChainParams.
// ============================================================================

typedef struct {
    int32_t phase[3];
    int32_t freq[3];
    int32_t level_in[3];
} mki_chain_params_t;

// Alg 6: op0 (fb) -> op1. output[i] = y (overwrite, no add).
static void compute_fb2_mki(int32_t *output, mki_chain_params_t *p,
                            uint16_t atten01, uint16_t atten02,
                            int32_t *fb_buf, int fb_shift) {
    int32_t dA0 = mki_atten_ramp(atten01, atten02, N);
    int32_t a0 = (int32_t)atten01;
    uint16_t a1Target = dx7refmki_atten(p->level_in[1]);
    int32_t ph0 = p->phase[0];
    int32_t ph1 = p->phase[1];
    int32_t y0 = fb_buf[0];
    int32_t y = fb_buf[1];
    for (int i = 0; i < N; i++) {
        int32_t scaled_fb = (y0 + y) >> (fb_shift + 1);
        a0 += dA0;
        y0 = y;
        y = dx7refmki_sin(ph0 + scaled_fb, mki_clamp_atten(a0));
        ph0 += p->freq[0];
        y = dx7refmki_sin(ph1 + mki_mod_scale(y), a1Target);
        ph1 += p->freq[1];
        output[i] = y;
    }
    p->phase[0] = ph0;
    p->phase[1] = ph1;
    fb_buf[0] = y0;
    fb_buf[1] = y;
}

// Alg 4: op0 (fb) -> op1 -> op2. output[i] = y (overwrite, no add).
static void compute_fb3_mki(int32_t *output, mki_chain_params_t *p,
                            uint16_t atten01, uint16_t atten02,
                            int32_t *fb_buf, int fb_shift) {
    int32_t dA0 = mki_atten_ramp(atten01, atten02, N);
    int32_t a0 = (int32_t)atten01;
    uint16_t a1 = dx7refmki_atten(p->level_in[1]);
    uint16_t a2 = dx7refmki_atten(p->level_in[2]);
    int32_t ph0 = p->phase[0];
    int32_t ph1 = p->phase[1];
    int32_t ph2 = p->phase[2];
    int32_t y0 = fb_buf[0];
    int32_t y = fb_buf[1];
    for (int i = 0; i < N; i++) {
        int32_t scaled_fb = (y0 + y) >> (fb_shift + 1);
        a0 += dA0;
        y0 = y;
        y = dx7refmki_sin(ph0 + scaled_fb, mki_clamp_atten(a0)); ph0 += p->freq[0];
        y = dx7refmki_sin(ph1 + mki_mod_scale(y), a1); ph1 += p->freq[1];
        y = dx7refmki_sin(ph2 + mki_mod_scale(y), a2); ph2 += p->freq[2];
        output[i] = y;
    }
    p->phase[0] = ph0;
    p->phase[1] = ph1;
    p->phase[2] = ph2;
    fb_buf[0] = y0;
    fb_buf[1] = y;
}

// ============================================================================
// Voice Init — from the 156-byte patch (SAME layout as dx7ref_voice_init).
// ============================================================================

void dx7refmki_voice_init(dx7refmki_voice_t *v, const uint8_t patch[156],
                          int midinote, int velocity, double sample_rate) {
    dx7refmki_tables_init();
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
        outlevel = scale_outlevel(outlevel);
        int level_scaling = scale_level(
            midinote, patch[off + 8], patch[off + 9],
            patch[off + 10], patch[off + 11], patch[off + 12]);
        outlevel += level_scaling;
        outlevel = min_int(127, outlevel);
        outlevel = outlevel << 5;
        outlevel += scale_velocity(velocity, patch[off + 15]);
        outlevel = max_int(0, outlevel);
        int rate_scaling = scale_rate(midinote, patch[off + 13]);
        eg_init_with_outlevel(&v->eg[op], rates, levels, outlevel, rate_scaling);
        dx7refmki_eg_note_on(&v->eg[op]);

        int mode = patch[off + 17];
        int coarse = patch[off + 18];
        int fine = patch[off + 19];
        int detune = patch[off + 20];
        int32_t freq = dx7refmki_osc_freq(midinote, mode, coarse, fine, detune);
        v->op_mode[op] = mode;
        v->basepitch[op] = freq;

        v->params[op].phase = 0;
        v->params[op].freq = dx7refmki_freq_lookup(freq);
        v->params[op].level_in = 0;
        // markIGainOut defaults to ENV_MAX (silent) at note-on — twin of
        // DX7Operator.markIGainOut: UInt16 = kMarkIEnvMax.
        v->params[op].mki_atten_out = (uint16_t)ENV_MAX;
    }

    v->algorithm = patch[134];
    int feedback = patch[135];
    // Twin of dx7ref: feedbackShiftValue = BITDEPTH - fb (or 16 when fb==0).
    v->fb_shift = feedback != 0 ? DX7REFMKI_FEEDBACK_BITDEPTH - feedback : 16;
    v->fb_buf[0] = 0;
    v->fb_buf[1] = 0;
}

// ============================================================================
// Voice Render — C twin of DX7Voice.renderBlockMarkI.
// Per-operator `while opIdx` routing with: inverted silence guard, fused
// Alg 4/6 chains, +2 feedback shift for algIndex 3/5/31.
// ============================================================================

void dx7refmki_voice_render(dx7refmki_voice_t *v, int32_t *buf) {
    // EG → level_in for every op (no pitch mod / LFO / controllers).
    for (int op = 0; op < 6; op++) {
        v->params[op].level_in = dx7refmki_eg_getsample(&v->eg[op]);
    }

    int algIndex = max_int(0, min_int(v->algorithm, 31));
    const uint8_t *alg = algorithms[algIndex];

    // Mark I deepens feedback by 2 shifts for the 3/6/32 algorithms (idx 3/5/31).
    int fb_shift_mki = (algIndex == 3 || algIndex == 5 || algIndex == 31)
        ? min_int(v->fb_shift + 2, 16)
        : v->fb_shift;

    // bus1 / bus2 scratch + carrier sum live in `buf`. hasContents: [0]=output,
    // [1]=bus1, [2]=bus2. output starts "has contents" exactly as the Swift.
    int32_t bus1[N];
    int32_t bus2[N];
    int has_contents[3] = { 1, 0, 0 };

    int opIdx = 0;
    while (opIdx < 6) {
        int flags = alg[opIdx];
        int add = (flags & 0x04) != 0;
        int inbus = (flags >> 4) & 3;
        int outbus = flags & 3;
        int isFbOp = (flags & 0xC0) == 0xC0;

        int32_t *outptr;
        switch (outbus) {
            case 1: outptr = bus1; break;
            case 2: outptr = bus2; break;
            default: outptr = buf; break;
        }

        // Gain setup (Mark I): atten2 = this block's attenuation, atten1 = prev
        // block's (carried for the ramp). Larger = quieter.
        uint16_t atten2 = dx7refmki_atten(v->params[opIdx].level_in);
        uint16_t atten1 = v->params[opIdx].mki_atten_out;
        v->params[opIdx].mki_atten_out = atten2;

        // Silence guard (inverted): audible when attenuation BELOW threshold.
        if (!(atten1 < (uint16_t)LEVEL_THRESH || atten2 < (uint16_t)LEVEL_THRESH)) {
            if (!add) {
                switch (outbus) {
                    case 1: has_contents[1] = 0; break;
                    case 2: has_contents[2] = 0; break;
                    default: break;
                }
            }
            v->params[opIdx].phase += v->params[opIdx].freq * (int32_t)N;
            opIdx += 1;
            continue;
        }

        int shouldAdd;
        switch (outbus) {
            case 1: shouldAdd = add && has_contents[1]; break;
            case 2: shouldAdd = add && has_contents[2]; break;
            default: shouldAdd = add; break;
        }

        int32_t opPhase = v->params[opIdx].phase;
        int32_t opFreq = v->params[opIdx].freq;

        // Fused Alg 4 (idx 3, 3-op) / Alg 6 (idx 5, 2-op) feedback chains.
        // Triggered when the feedback op (opIdx 0) is reached with feedback
        // enabled. Downstream ops are consumed (phase advanced + skipped).
        if (isFbOp && v->fb_shift < 16 && opIdx == 0 && (algIndex == 3 || algIndex == 5)) {
            int32_t fb_buf[2] = { v->fb_buf[0], v->fb_buf[1] };
            if (algIndex == 5) {
                // Alg 6: op0 (OP6, fb) -> op1 (OP5).
                mki_chain_params_t p;
                p.phase[0] = v->params[0].phase; p.phase[1] = v->params[1].phase; p.phase[2] = 0;
                p.freq[0]  = v->params[0].freq;  p.freq[1]  = v->params[1].freq;  p.freq[2]  = 0;
                p.level_in[0] = v->params[0].level_in;
                p.level_in[1] = v->params[1].level_in;
                p.level_in[2] = 0;
                compute_fb2_mki(buf, &p, atten1, atten2, fb_buf, fb_shift_mki);
                v->fb_buf[0] = fb_buf[0]; v->fb_buf[1] = fb_buf[1];
                v->params[0].phase = p.phase[0];
                v->params[1].phase = p.phase[1];
                // op1's ramp anchor (Swift: ops.0.markIGainOut = markIAtten(ops.1.levelIn)).
                v->params[0].mki_atten_out = dx7refmki_atten(v->params[1].level_in);
                opIdx = 2;  // consumed op0 + op1
            } else {
                // Alg 4: op0 (OP6, fb) -> op1 (OP5) -> op2 (OP4).
                mki_chain_params_t p;
                p.phase[0] = v->params[0].phase; p.phase[1] = v->params[1].phase; p.phase[2] = v->params[2].phase;
                p.freq[0]  = v->params[0].freq;  p.freq[1]  = v->params[1].freq;  p.freq[2]  = v->params[2].freq;
                p.level_in[0] = v->params[0].level_in;
                p.level_in[1] = v->params[1].level_in;
                p.level_in[2] = v->params[2].level_in;
                compute_fb3_mki(buf, &p, atten1, atten2, fb_buf, fb_shift_mki);
                v->fb_buf[0] = fb_buf[0]; v->fb_buf[1] = fb_buf[1];
                v->params[0].phase = p.phase[0];
                v->params[1].phase = p.phase[1];
                v->params[2].phase = p.phase[2];
                opIdx = 3;  // consumed op0 + op1 + op2
            }
            has_contents[0] = 1;
            continue;
        }

        if (inbus == 0 || (inbus == 1 && !has_contents[1]) || (inbus == 2 && !has_contents[2])) {
            if (isFbOp && v->fb_shift < 16) {
                int32_t fb_buf[2] = { v->fb_buf[0], v->fb_buf[1] };
                // NOTE: Swift uses the per-op fbBuf here; only op0 carries fb in
                // these algorithms, so this path reads/writes op0's fb_buf.
                // (Twin reads ops.opIdx.fbBuf; our op_params has a single shared
                // fb_buf on the voice, used only by the feedback operator.)
                compute_fb_mki(outptr, opPhase, opFreq, atten1, atten2,
                               fb_buf, fb_shift_mki, shouldAdd, N);
                v->fb_buf[0] = fb_buf[0]; v->fb_buf[1] = fb_buf[1];
            } else {
                compute_pure_mki(outptr, opPhase, opFreq, atten1, atten2, shouldAdd, N);
            }
        } else {
            const int32_t *inptr = (inbus == 1) ? bus1 : bus2;
            compute_mod_mki(outptr, inptr, opPhase, opFreq, atten1, atten2, shouldAdd, N);
        }

        switch (outbus) {
            case 1: has_contents[1] = 1; break;
            case 2: has_contents[2] = 1; break;
            default: break;
        }

        v->params[opIdx].phase = opPhase + opFreq * (int32_t)N;
        opIdx += 1;
    }
}

// ============================================================================
// Voice Note-Off
// ============================================================================

void dx7refmki_voice_noteoff(dx7refmki_voice_t *v) {
    for (int op = 0; op < 6; op++) {
        dx7refmki_eg_note_off(&v->eg[op]);
    }
}
