# Golden Master Format Specification

**Status:** Draft v0.3 (incorporates two rounds of independent review on 2026-04-27; format_version 1 pending a brief spot check)
**Audience:** Port authors (Rust / C / C++ / C# kernels), CI maintainers, M2DX-Core contributors.
**Companion docs:** `docs/20260427_003000_phase4a_rust_rationale.md` (why), `docs/golden-master-usage.md` (how to consume — TBD).

---

## 1. Overview

The Golden Master is a set of language-neutral, deterministic test vectors derived from the Swift M2DX kernel. Each vector captures the kernel's output for a specific scenario (preset(s) + MIDI sequence + render config). The vectors serve two purposes:

1. **Verification reference for multi-language ports.** Phase 4a (Rust kernel) and beyond will assert byte-exact equivalence against these vectors instead of running against `Sources/DX7Ref/` (Apache-2.0). This decouples downstream ports from any direct DEXED-derived reference build, so each port can choose its own license and build configuration without inheriting test-target attribution obligations.
2. **Regression detector for the Swift kernel itself.** Any future Swift-side optimisation (SIMD, refactor, codegen change) that drifts the bit-exact output is caught immediately by CI.

### Canonical platform

The vectors are generated on, and byte-exact against, a **canonical platform**: `darwin-arm64` with the system libm shipped in macOS 15+. The Swift kernel uses libm both at LUT initialisation (`Tables/FrequencyTable.swift`, `Tables/ScalingTable.swift`) and at runtime (detune, LFO sin / delay, log-domain volume), so the Int32 stream is **conditionally bit-exact**: byte-exact between two consumers that share Apple libm; small-tolerance match between consumers on platforms with different libm (Linux glibc, MSVCRT, etc.). Tolerance modes in §5 capture this distinction; Int32 cross-platform comparison uses an absolute-integer-difference mode (`i32_abs_<N>`) rather than a Float ULP mode.

### In scope

- Per-voice Int32 output streams (byte-exact on canonical platform).
- Final Float32 stereo output (ULP-tolerant; libm transcendentals make this platform-dependent within ~ULPs even on canonical).
- Optional per-voice feedback bus debug captures (see §3.6).
- Mid-scenario engine operations beyond MIDI events (sample-rate change, oversampling change, all-notes-off, master tuning change, master volume change, algorithm change).
- Multi-timbral scenarios with per-slot preset assignment (TX816, dual, split).
- Scenario metadata sufficient to reproduce the run from any conforming engine.

### Out of scope (v1)

- Float-stage bit-exactness across platforms.
- Kernel internal state (envelope phase, LFO phase, sustain pedal) beyond optional debug captures.
- Audio host integration (CoreAudio, JUCE, AUv3 plumbing).
- Sub-block MIDI event timing — events are quantised to render quantum boundaries (§4).
- Mid-scenario preset switching (`load_sysex` is restricted to `frame: 0` in v1; see §3.4).

---

## 2. Directory layout

```
Tests/GoldenMaster/
├── README.md                              # human pointer to this spec
└── scenarios/
    ├── init_voice_a4_v100/
    │   ├── manifest.json
    │   ├── preset_slot0.syx               # named by slot for clarity
    │   ├── voice_0.i32.bin
    │   ├── stereo_l.f32.bin
    │   └── stereo_r.f32.bin
    ├── tx816_eight_slot_chord/
    │   ├── manifest.json
    │   ├── preset_slot0.syx               # one preset file per occupied slot
    │   ├── preset_slot1.syx
    │   ├── ...
    │   ├── preset_slot7.syx
    │   ├── voice_0.i32.bin
    │   ├── voice_1.i32.bin
    │   ├── voice_8.i32.bin                # voice index follows kMaxVoices=128 array
    │   ├── voice_9.i32.bin
    │   ├── stereo_l.f32.bin
    │   └── stereo_r.f32.bin
    └── ...
```

**Scenario IDs** must match `^[a-z0-9_]{1,64}$`. They are stable identifiers; never reuse a deleted ID with new content.

---

## 3. `manifest.json` schema

Each scenario directory contains exactly one `manifest.json`. Example (single-mode, single voice):

```json
{
  "format_version": 1,
  "scenario_id": "init_voice_a4_v100",
  "scenario_version": 1,
  "description": "INIT VOICE patch in slot 0, A4 (note 69) at velocity 100, hold 1024 frames, then noteOff and 1024 frames of release tail.",
  "engine_config": {
    "sample_rate": 44100,
    "oversampling_mode": "off",
    "render_quantum_frames": 64,
    "block_size": 64,
    "k_max_voices": 128,
    "k_max_slots": 8,
    "midi_queue_capacity": 256,
    "lfo_sh_seed_constant": "0xA5A5A5A55A5A5A5A",
    "voice_alloc_history": "fresh",
    "timbre_mode": "single"
  },
  "delivery": {
    "event_delivery_phase": "start_of_quantum",
    "same_frame_order": "manifest_order",
    "block_chunking_within_quantum": "ascending_offset_block_size",
    "voice_mix_order": "voice_index_ascending"
  },
  "slot_presets": [
    {
      "slot_id": 0,
      "source": "factory:init_voice",
      "sysex_file": "preset_slot0.syx",
      "sha256": "5d41402abc4b2a76b9719d911017c592..."
    }
  ],
  "midi": [
    { "frame": 0,    "kind": "noteOn",  "data1": 69, "data2": 65024 },
    { "frame": 1024, "kind": "noteOff", "data1": 69, "data2": 0     }
  ],
  "engine_ops": [
    { "frame": 0, "op": "set_master_volume", "value": 0.7 },
    { "frame": 0, "op": "set_master_tuning", "value": 0   }
  ],
  "render": {
    "total_frames": 2048
  },
  "voices": {
    "captured_indices": [0],
    "files": [
      {
        "voice_index": 0,
        "slot_id": 0,
        "midi_note": 69,
        "allocation_order": 0,
        "file": "voice_0.i32.bin",
        "format": "Int32LE",
        "frame_count": 2048,
        "sha256": "9a0364b9e99bb480dd25e1f0284c8555...",
        "tolerance": "byte_exact_canonical"
      }
    ]
  },
  "debug_captures": {
    "enabled": false
  },
  "stereo": {
    "left": {
      "file": "stereo_l.f32.bin",
      "format": "Float32LE",
      "frame_count": 2048,
      "sha256": "0987654321abcdef...",
      "tolerance": "ulp_4"
    },
    "right": {
      "file": "stereo_r.f32.bin",
      "format": "Float32LE",
      "frame_count": 2048,
      "sha256": "abcdef1234567890...",
      "tolerance": "ulp_4"
    }
  }
}
```

### 3.1 Top-level fields

| Field | Type | Meaning |
|---|---|---|
| `format_version` | int | This spec's version. Bump on incompatible schema changes. |
| `scenario_id` | string | `^[a-z0-9_]{1,64}$`. Stable forever. |
| `scenario_version` | int | Bumps when the same `scenario_id`'s expected outputs intentionally change. |
| `description` | string | Human-readable purpose of the scenario. |

Provenance (timestamps, generator git SHA) is intentionally **not** stored in the manifest — `git log` on the manifest file is the source of truth. This avoids spurious diff churn on every regeneration.

### 3.2 `engine_config`

| Field | Type | Meaning |
|---|---|---|
| `sample_rate` | float | Base sample rate in Hz. |
| `oversampling_mode` | enum | `"off"` \| `"highQuality"` \| `"lowCPU"`. |
| `render_quantum_frames` | int | Frames per `render()` call. Must divide `render.total_frames` exactly (no partial trailing quantum in v1). |
| `block_size` | int | Internal kernel block size; **normative** at 64 (`kBlockSize` in Swift). The kernel splits each render quantum into ⌈quantum / block_size⌉ blocks at ascending offsets. Ports must use the same cadence. |
| `k_max_voices` | int | Voice array size. Currently 128 (`kMaxVoices` in `Sources/M2DXCore/Engine/Algorithm.swift:7`). |
| `k_max_slots` | int | Slot array size. Currently 8 (`kMaxSlots` in `Sources/M2DXCore/Engine/ParameterSnapshot.swift`). |
| `midi_queue_capacity` | int | MIDI ring buffer size (256 for `SPSCRing`). Scenarios must never enqueue more events per quantum than this. |
| `lfo_sh_seed_constant` | hex string | Must match `SynthEngine.swift`'s S&H PRNG seed constant verbatim; otherwise S&H output diverges. |
| `voice_alloc_history` | enum | `"fresh"` (only legal value in v1) — engine starts from `init()` state: all voices inactive, `dx7VoiceStealIdx = 0`, all controllers at default, S&H PRNGs reseeded from the constant. The Generator and ports must instantiate a fresh engine per scenario. |
| `timbre_mode` | enum | `"single"` \| `"dual"` \| `"split"` \| `"tx816"`. Determines `effectiveMaxVoices` and slot allocation. |

### 3.3 `delivery`

| Field | Type | Meaning |
|---|---|---|
| `event_delivery_phase` | enum | `"start_of_quantum"` (only supported value in v1). |
| `same_frame_order` | enum | `"manifest_order"` (only supported value in v1). |
| `block_chunking_within_quantum` | enum | `"ascending_offset_block_size"` (only supported value in v1) — within a quantum, blocks of size `block_size` are processed at offsets 0, block_size, 2·block_size, … exactly as `renderFramesDX7` does. |
| `voice_mix_order` | enum | `"voice_index_ascending"` (only supported value in v1) — when accumulating voices into the stereo Float buffer, iterate `voicesDX7` in ascending `voice_index` order. Float addition order matters for ULP stability. |

See §4 for the full delivery model.

### 3.4 `slot_presets`

Array of preset assignments per slot. Single-mode scenarios contain exactly one entry (`slot_id: 0`). Multi-timbral scenarios may contain up to `k_max_slots` entries.

| Field | Type | Meaning |
|---|---|---|
| `slot_id` | int | 0-based slot index. |
| `source` | string | `"factory:<name>"` for built-in presets, `"embedded"` for ad-hoc SysEx authored for this scenario. |
| `sysex_file` | string | Relative path inside the scenario directory. Conventionally `preset_slot<N>.syx`. |
| `sha256` | hex string | SHA-256 of the file's bytes. The hash domain is the **full file contents** (whatever bytes the engine's parser ingests, no header stripping). |

Slots not listed in `slot_presets` are treated as unloaded (default `INIT VOICE`-like state, depending on engine init defaults).

### 3.5 `midi[*]` and `engine_ops[*]`

Two parallel timed event arrays referencing frames in the same timeline.

#### `midi[*]`

| Field | Type | Meaning |
|---|---|---|
| `frame` | int ≥ 0 | Sample-frame offset from start of render. Quantised to render quantum (§4). |
| `kind` | enum | `MIDIEvent.Kind` raw name. |
| `data1`, `data2` | int | Per `MIDIEvent` semantics. |

#### `engine_ops[*]`

| Field | Type | Meaning |
|---|---|---|
| `frame` | int ≥ 0 | Same timeline as `midi`. Applied **before** that quantum's MIDI is drained, in manifest order. |
| `op` | enum | `"set_sample_rate"` \| `"set_oversampling"` \| `"do_all_notes_off"` \| `"set_master_tuning"` \| `"set_master_volume"` \| `"set_algorithm"` \| `"load_sysex"`. |
| `value` | varies | Numeric for tuning/volume/algorithm/sample_rate, string for oversampling, file ref for load_sysex. |
| `slot_id` | int (optional) | Required for `set_algorithm` (per-slot algorithm); optional for ops that may be per-slot in the future. |

**Operation constraints (v1):**

- `load_sysex` is **restricted to `frame: 0`** in v1. Mid-scenario preset switching produces ill-defined active-voice state and is deferred to a future format_version.
- `do_all_notes_off` may appear at any frame; it silences all voices in all slots.
- `set_sample_rate` triggers an internal `doAllNotesOff` per current Swift behaviour. Generators and ports must observe this side effect.

### 3.6 `voices`

| Field | Type | Meaning |
|---|---|---|
| `captured_indices` | int array | Indices into `voicesDX7` array for voices that are captured. |
| `files[*].voice_index` | int | Matches a value in `captured_indices`. |
| `files[*].slot_id` | int | Slot the voice was allocated to. |
| `files[*].midi_note` | int | MIDI note that triggered the voice. |
| `files[*].allocation_order` | int | See §3.7. |
| `files[*].file` | string | Relative path. |
| `files[*].format` | string | `"Int32LE"` for v1. |
| `files[*].frame_count` | int | Equal to `render.total_frames`. |
| `files[*].sha256` | hex string | SHA-256 of the file's bytes. |
| `files[*].tolerance` | string | Per §5. |

### 3.7 `allocation_order` rule

The `allocation_order` field disambiguates voices that occupy the same `voicesDX7` slot at different times within a scenario.

**Definition:** A global counter, starting at 0, incremented by 1 each time the engine successfully completes a voice allocation in response to either a MIDI `noteOn` or an internal voice-stealing event. The counter value at the moment of allocation is the voice's `allocation_order`.

**Multi-slot expansion (TX816 / dual / split):** when a single MIDI `noteOn` results in voice allocations to multiple slots, the counter is incremented **once per allocated voice**, in `slot_id` ascending order. For example, a `dual` mode `noteOn` that allocates to slots 0 and 1 produces two consecutive `allocation_order` values: slot 0 voice = N, slot 1 voice = N+1.

**Voice stealing:** when a `noteOn` arrives with no inactive voices, the engine steals an existing voice (round-robin via `dx7VoiceStealIdx`). The stolen voice's slot in `voicesDX7` is reused; the new occupant gets a fresh `allocation_order`. The previous occupant's stream ends at the stealing frame.

**Retrigger of same note:** sending `noteOn` with the same note on top of an active voice yields a new `allocation_order` for the new voice (the engine treats it as a fresh allocation; the previous instance is silenced or stolen depending on policy).

### 3.8 `debug_captures` (optional)

Enables additional intermediate captures for difficult-to-diagnose port mismatches:

```json
"debug_captures": {
  "enabled": true,
  "voices": {
    "0": {
      "bus1": { "file": "voice_0_bus1.i32.bin", "frame_count": 2048, "sha256": "..." },
      "bus2": { "file": "voice_0_bus2.i32.bin", "frame_count": 2048, "sha256": "..." }
    }
  }
}
```

When `enabled: false`, the field may be absent. Most scenarios have debug captures off; enable selectively for scenarios that exercise feedback or multi-bus FM routing.

### 3.9 `stereo`

`left` and `right` each contain one Float32LE file with `file`, `format`, `frame_count`, `sha256`, `tolerance` fields (no slot/midi/allocation fields).

---

## 4. MIDI and engine-op delivery model

The following model is normative; ports must reproduce it exactly.

```
loop while next_quantum_start < render.total_frames:
    let q_start = next_quantum_start
    let q_end   = q_start + render_quantum_frames

    // Phase A: apply engine_ops in this window, manifest order. Side effects
    // (e.g. set_sample_rate triggering doAllNotesOff internally) are observed
    // in real time; subsequent engine_ops in the same quantum see the new state.
    for each op in engine_ops where op.frame in [q_start, q_end):
        engine.apply(op)

    // Phase B: enqueue all MIDI in this window into the SPSC queue, manifest order.
    for each event in midi where event.frame in [q_start, q_end):
        engine.queue_midi(event)

    // Phase C: call render. Inside render the engine drains its MIDI queue,
    // pops the latest SnapshotRing entry, then runs through internal blocks of
    // size `block_size` at ascending offsets, accumulating voices into the
    // stereo buffer in voice_index ascending order.
    engine.render(quantum_frames = render_quantum_frames)
```

### Constraints

- A scenario must never enqueue more than `engine_config.midi_queue_capacity` events into a single quantum. The Generator must reject scenarios that violate this.
- Frames at `q_end` (exclusive) belong to the next quantum.
- `render.total_frames` must be an integer multiple of `render_quantum_frames` (no partial trailing quantum in v1).
- Internal `block_size` chunking is normative: ports must process blocks at offsets 0, `block_size`, 2·`block_size`, … within each quantum, exactly as `renderFramesDX7` does.
- Float voice mixing into stereo accumulator must iterate voices in ascending `voice_index` order. Different orderings produce different ULP results.

---

## 5. Tolerance semantics

### 5.1 Tolerance modes

| Mode | Stream type | Meaning |
|---|---|---|
| `byte_exact` | any | Byte-identical regardless of platform. Only legal when the scenario provably avoids libm at LUT init AND runtime. Rare in v1. |
| `byte_exact_canonical` | Int32 | Byte-identical to the committed `.bin` when the consumer runs on the canonical platform (darwin-arm64 with Apple libm) using the declared `lfo_sh_seed_constant`. On other platforms, fall back to a per-stream `i32_abs_<N>` tolerance declared elsewhere or in policy docs. |
| `i32_abs_<N>` | Int32 | Absolute integer difference per sample ≤ N. Used for cross-platform Int32 comparison where libm divergence makes byte-exactness unrealistic. Default cross-platform value: `i32_abs_2`, validated empirically on the first cross-platform port. |
| `ulp_<N>` | Float32 | Per-sample ULP distance ≤ N (algorithm in §5.2). Default for stereo Float32 outputs is `ulp_4`. |
| `relaxed` | any | No comparison; capture only. Used for debug streams that may legitimately diverge. |

The default for Int32 voice streams is `byte_exact_canonical`. The default for Float32 stereo channels is `ulp_4`.

### 5.2 ULP comparison algorithm (Float32)

For two `f32` values `a` and `b`, with declared tolerance `ulp_N`:

1. **Non-finite handling.** If either is NaN, ±∞, or any other non-finite value, **fail**. Audio output is required to be finite; non-finite is treated as a kernel bug rather than a tolerable divergence.
2. **Zero normalisation.** If `a` is `±0`, treat its bits as `0x00000000`; same for `b`. (`+0` and `-0` are equal regardless of sign bit.)
3. **Total-order mapping** to a monotonic `u32`:

   ```
   fn ord(bits: u32) -> u32 {
       if bits & 0x8000_0000 == 0 {
           bits | 0x8000_0000          // positive: shift above zero
       } else {
           !bits                       // negative: invert so larger-magnitude negatives sort lower
       }
   }
   ```

   This maps `−∞` to the smallest `u32`, `+∞` to the largest, with subnormals correctly ordered. Step 1 has already rejected non-finite, so `ord(±∞)` need not be reached in practice.
4. **Distance.** Compute `|ord(a) − ord(b)|` in `u64` to avoid overflow on opposite-sign inputs.
5. **Compare.** If the distance is ≤ N, the samples match; else fail.

Tolerances are evaluated per-sample; failing one sample fails the stream. `ulp_0` is equivalent to `byte_exact` for finite Float values.

### 5.3 Int32 absolute-difference algorithm

For two `i32` values `a` and `b`, with declared tolerance `i32_abs_N`:

1. Compute `(i64)a − (i64)b` (widen first to avoid overflow).
2. If `|difference|` ≤ N, the samples match; else fail.

`byte_exact` for Int32 is equivalent to `i32_abs_0`.

---

## 6. Versioning policy

### `format_version` (this spec)

Bump when:

- A new required field is added.
- An existing field's semantics change.
- Binary file encoding changes.
- The MIDI / engine-op delivery model in §4 changes.

Generators must refuse to load manifests whose `format_version` exceeds their supported range. Consumers should warn on unknown optional fields but accept them.

### `scenario_version` (per-scenario)

Bump when the MIDI sequence, `engine_ops`, any `slot_presets` content, or `engine_config` changes — anything that legitimately changes the expected output. Bumping requires regenerating all binaries in the directory and updating their `sha256`.

### Adding new scenarios

Allocate a fresh `scenario_id`. Never reuse a deleted ID with new content; bump the version on the existing one if the intent is the same scenario evolved.

### Removing scenarios

Removing a scenario is a breaking change for downstream port CI. Mark deprecated for one minor version cycle (≥ 30 days, or one tagged release) before deletion.

---

## 7. Determinism preconditions

Before any scenario is generated, the Swift kernel must satisfy:

| Precondition | Source | How verified |
|---|---|---|
| No render-time heap allocation | Phase 3a P0 #4 (slotMods scratch) | Manual inspection; Phase 3a P2 `RTSafetyTests` once landed. |
| No SPSC contract violation in MIDI handlers | Phase 3a P0 #2 (doRPN audio-local) | Code review. |
| Per-slot pitchBendRange respected | Phase 3a P0 #3 | Multi-timbral scenarios in vector set. |
| Deterministic S&H LFO | Phase 3a P0 #5 (`SplitMix64` seeded constant) | Scenarios using LFO waveform 5. |
| Unified `masterTuning` + RPN tuning sum | Phase 3a P0 #6 | Held-note master-tuning-change scenario. |
| Latest-value SnapshotRing | Phase 3a P0 #1 (triple buffer) | Bursty UI setter scenarios. |
| Canonical-platform libm match | This spec | Apple libm at LUT init (`Tables/FrequencyTable.swift:14, 29, 53, 75`, `Tables/ScalingTable.swift:131`) and at runtime (`SynthEngine.swift` powf/log10f/log2f/expf/sinf/logf, `DX7Voice.swift:91` powf). Cross-platform consumers fall back to `i32_abs_<N>` per §5. |
| MIDI queue capacity not exceeded per quantum | This spec | Generator must validate; CI check. |
| Voice allocation history starts fresh | This spec (§3.2 `voice_alloc_history: "fresh"`) | Generator must instantiate a new `SynthEngine` per scenario. |
| `block_size` and voice-mix order honoured | This spec (§3.3) | Port harness must implement the same block cadence and mix order. |

A new scenario class may surface previously-undiscovered non-determinism; in that case the kernel must be fixed, or the scenario marked with a looser tolerance, before the scenario can ship as a Golden Master.

---

## 8. Port author quick start

Pseudo-code, illustrative:

```pseudo
for each scenario_dir in Tests/GoldenMaster/scenarios/:
    manifest = read_json(scenario_dir / "manifest.json")
    if manifest.format_version not in supported_range:
        skip with warning
        continue

    // Fresh engine per scenario (voice_alloc_history = "fresh").
    engine = MyKernel.new(
        sample_rate: manifest.engine_config.sample_rate,
        oversampling: manifest.engine_config.oversampling_mode,
        timbre_mode: manifest.engine_config.timbre_mode,
        lfo_sh_seed: parse_hex(manifest.engine_config.lfo_sh_seed_constant)
    )

    // Load each slot preset.
    for entry in manifest.slot_presets:
        engine.load_sysex_to_slot(entry.slot_id, read(scenario_dir / entry.sysex_file))

    int32_outputs = {idx: [] for idx in manifest.voices.captured_indices}
    stereo_l = []
    stereo_r = []
    let quantum = manifest.engine_config.render_quantum_frames

    var f = 0
    while f < manifest.render.total_frames:
        // Phase A: engine_ops, manifest order.
        for op in manifest.engine_ops where op.frame in [f, f + quantum):
            engine.apply(op)
        // Phase B: MIDI, manifest order.
        for event in manifest.midi where event.frame in [f, f + quantum):
            engine.queue_midi(event)
        // Phase C: render exactly one quantum, with normative block_size cadence
        // and voice_index ascending mix order.
        let block = engine.render(quantum)
        for idx in manifest.voices.captured_indices:
            int32_outputs[idx] += block.voice_int32_stream(idx)
        stereo_l += block.left
        stereo_r += block.right
        f += quantum

    for voice in manifest.voices.files:
        expected = read_i32_le(scenario_dir / voice.file)
        actual = int32_outputs[voice.voice_index]
        verify_int32(expected, actual, voice.tolerance)

    expected_l = read_f32_le(scenario_dir / manifest.stereo.left.file)
    expected_r = read_f32_le(scenario_dir / manifest.stereo.right.file)
    verify_float(expected_l, stereo_l, manifest.stereo.left.tolerance)
    verify_float(expected_r, stereo_r, manifest.stereo.right.tolerance)
```

The port does **not** verify the manifest's `sha256` fields; those are for Generator drift detection in the M2DX-Core repo, not for consumption.

---

## 9. Generator quick start

The Swift Generator (`Tests/GoldenMaster/Generator/GoldenMasterGenerator.swift`, planned for Phase 3b sub-task 3) runs in two modes:

```bash
# Regenerate mode: rewrite all .bin files and update manifest sha256 fields.
swift test --filter GoldenMasterGeneratorTests/regenerate

# Verify mode (default in CI): re-run scenarios in memory and compare bytes
# against the committed .bin files. Fails on any drift.
swift test --filter GoldenMasterGeneratorTests/verify
```

Verify mode does not write any files. Regenerate mode does not bump `scenario_version` (that is a manual judgement when the underlying intent of a scenario changes); it only refreshes `.bin` and `sha256`. CI runs verify mode on every PR.

Drift signals:

- A `.bin` byte mismatch indicates either a kernel regression or an intentional change. If intentional, run regenerate locally, commit the new bytes, and update `scenario_version` if the intent changed.
- A `manifest.json` hash mismatch with the same `.bin` bytes indicates the manifest schema or a non-output field was edited. Generator should refuse to verify until consistent.

---

## 10. Optional features (not required for v1 generation)

- **Compressed binaries** — switch to `gzip` or `zstd` if total vector size exceeds ~10 MB.
- **Streaming format** — for very long scenarios; current scheme assumes whole streams fit in memory.
- **Cross-revision drift report** — tooling that compares two generations of the same `scenario_id` and reports per-frame diffs with histograms of distance.
- **Inline preset bytes** — embed `preset_slot<N>.syx` content as base64 inside `manifest.json` for fully-self-contained scenarios.
- **Per-block envelope/LFO state captures** — would add `voice_<n>_state.bin`; useful for diagnosing port mismatches at granularities finer than per-voice output.
- **Mid-scenario `load_sysex`** — currently restricted to `frame: 0`; a future format_version may relax this with a defined active-voice policy.

Items in §10 are deliberately *out of scope* for the first generation but reserve concept space so future schema additions are non-breaking.

---

## 11. Coverage budget

The Generator targets **45–60 scenarios** for v1, distributed roughly as:

| Class | Scenario count | Notes |
|---|---|---|
| INIT VOICE / signature presets | 4–6 | Smoke-test baseline. |
| Per-algorithm representative | 10 | One scenario per signature group from the 32 DX7 algorithms (covers carrier count, feedback location). |
| KLS curves | 4 | Each of the 4 curve types. |
| LFO waveforms | 5 | Triangle, saw down, saw up, square, sin. |
| LFO Sample-and-Hold | 2–3 | Verifies determinism contract from Phase 3a P0 #5. |
| Pitch / RPN | 4 | Pitch bend at multiple ranges, fine + coarse tuning, master-tuning-change-during-held-note. |
| Velocity / KRS | 3 | Velocity sensitivity scaling, keyboard rate scaling extremes. |
| Per-note (MIDI 2.0) | 4 | `perNotePitchBend`, `perNoteCC`, `polyPressure`, `perNoteManagement` reset/detach. |
| Sustain pedal / all-notes-off | 2 | CC64 latch, CC123 / `do_all_notes_off`. |
| Multi-timbral (dual / split / TX816) | 8–12 | Each TimbreMode plus per-slot bend range, per-slot transpose, split-point boundary cases, and at least one TX816 with 8 distinct `slot_presets`. |
| Sample-rate / oversampling change | 2 | Mid-scenario `set_sample_rate`, `set_oversampling`. |
| Voice stealing | 2 | Round-robin steal at full polyphony, per-mode max voices. Both rely on `voice_alloc_history: "fresh"`. |
| Bursty UI setters | 1 | Validates Phase 3a P0 #1 SnapshotRing latest-value semantics. |

Total inline binary footprint estimate: ~5–8 MB committed.

---

## 12. Open questions to resolve before tagging v1.0

- **`ulp_4` empirical validation.** Is 4 ULPs realistic for stereo output even on the canonical platform? Phase 3b's first scenarios should measure observed drift before committing to the default, and adjust per-scenario where needed.
- **`i32_abs_<N>` empirical validation.** Pick the default N for cross-platform Int32 once the first cross-platform port runs (e.g. Linux Rust). Current placeholder: `i32_abs_2`.
- **SysEx hash domain.** v0.3 fixes this as "full file contents" (no header stripping). Confirmed unless the first SysEx-containing scenario surfaces a contradiction.
- **Algorithm coverage matrix.** Pick the 10 representative algorithms for §11 — propose: 1 (3-stack), 5 (parallel), 8 (4-op + 2-op), 16 (split feedback), 32 (all parallel), plus 5 more chosen for distinct topologies.
