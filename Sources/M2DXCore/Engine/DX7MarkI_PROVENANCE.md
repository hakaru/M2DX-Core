# DX7 "Mark I" OPS-chip emulation — clean-room provenance

This Mark I FM path is a clean-room reimplementation of the Yamaha DX7 OPS-chip
log-sine + exponential signal path, derived solely from public documentation.
It does NOT copy Dexed's GPL-3.0 `EngineMkI.cpp`.

## Public sources
- Ken Shirriff, "Reverse-engineering the Yamaha DX7 synthesizer's sound chip
  from die photos" (righto.com) — OPS log-sin / exp architecture.
- OPL3 math documentation: github.com/gtaylormb/opl3_fpga/blob/master/docs/opl3math/opl3math.pdf
- Yamaha DX7 service/technical documentation (OPS frequency/EG architecture).

## Formulas (public OPS math)
- Log-sine table (1024 entries, first quadrant), value at index i:
  `sinLog[i] = round( -1024 * log2( sin( ((0.5 + i) / 1024) * (pi/2) ) ) )`
  Quadrants 2–4 are produced by index folding (`i XOR 1023`) and a sign bit.
- Exp table (1024 entries), value at index i:
  `sinExp[i] = round( (2^(i/1024) - 1) * 4096 )`
- Operator output: `expVal = sinLog(phase) + attenuation` (log domain);
  `mantissa = 4096 + sinExp[(expVal & 0x3FF) XOR 0x3FF]`;
  `out = (mantissa >> (expVal >> 10))` with sign from the log-sine quadrant.
- Per-operator attenuation from the shared EG level (`level_in`, Q24-domain,
  same value Modern feeds to exp2): `atten = ENV_MAX - (level_in >> 14)`,
  clamped to `[0, ENV_MAX]`, with `atten == 0 -> ENV_MAX - 1`. `ENV_MAX = 1<<14`.

## Constants
- ENV_BITDEPTH = 14, ENV_MAX = 16384, log/exp table size = 1024, table bit-depth
  = 10, output left-shift = 13.
