# Phase 4a: Multi-Language Kernel Selection — Rust Rationale

**Date:** 2026-04-27
**Status:** Decision documented; implementation deferred until Phase 3a/3b complete.
**Decision:** Adopt Rust as the second-language kernel for Phase 4a, with strict entry conditions.

---

## Summary

For the multi-language kernel of M2DX-Core (Phase 4a), Rust is the chosen target language, but adoption is **conditional on five prerequisites** being met before Rust work begins. Rust wins on bit-exact arithmetic discipline and FFI hub potential, but the audio real-time contract is not magically solved by Rust adoption — the conditions below ensure the discipline that the type system cannot enforce.

## Decision

**Phase 4a will use Rust** for a `ports/rust/` kernel that mirrors `Sources/M2DXCore/Engine/` and `Sources/M2DXCore/Tables/`, gated on the five preconditions below.

### Entry conditions (all must hold before any Rust code lands)

1. **Golden Master first.** Bit-exact test vectors at the Int32 block stage for ≥30 representative scenarios committed to `Tests/GoldenMaster/`. The Rust kernel is verified against these, not against DEXED. This decouples ports from the GPL-derived DEXED reference.
2. **C ABI first.** The Rust kernel exposes a stable `extern "C"` ABI from the first milestone. `cbindgen`-generated headers are committed. ABI versioning, ownership transfer rules, and panic-to-error mapping are documented before non-trivial Rust internals are written.
3. **`unsafe` boundary minimised.** Lock-free SPSC ring buffers and FFI surfaces are the only places `unsafe` may appear. Each `unsafe` block carries a comment justifying why no safe alternative is acceptable. Audited via clippy + cargo-deny in CI.
4. **RT contract enforced by external test, not by language.** Rust's borrow checker does not certify "no allocation, no lock, no wait" on the render path. A `cargo test --features rt-safe-audit` pass that hooks the global allocator and asserts zero allocations across N render blocks must succeed.
5. **SIMD strategy declared upfront.** Decide before code lands whether the Rust kernel uses scalar only, `std::arch` intrinsics, or `portable_simd` (nightly). Match the Swift scalar baseline bit-for-bit before any SIMD optimisation is admitted. The current Swift implementation's Accelerate/vDSP usage is largely confined to dead code (`DSP/VoiceMixer.swift`); the active mix loop at `SynthEngine.swift:840-855` is scalar, so the cross-platform delta is smaller than it appears.

## Why Rust (not C99, not C++, not Zig, not Swift-on-Linux)

| Criterion | Verdict | Reason |
|---|---|---|
| Wrapping arithmetic bit-exact | ✅ | `i32::wrapping_*` and `Wrapping<T>` map 1:1 to Swift's `&*` `&+`. C99 signed overflow is UB; the `uint32_t` cast workaround is fragile under maintenance. |
| Lock-free atomics & RT | ⚠️ Conditional | `std::sync::atomic` ports cleanly from `Synchronization.Atomic`. But ring buffers still require `unsafe`, and the "no alloc, no lock, no wait" discipline is not type-system-enforced. |
| FFI hub potential | ✅ | `cdylib` + `cbindgen` + `repr(C)` produces a clean C ABI consumed by C++/C#/Python/Go/JS. Equivalent to writing C99 by hand, with overflow safety as a bonus. |
| WASM and plugin reach | ⚠️ Conditional | `wasm-bindgen` + `nih-plug` are real but Pure-Rust VST is not at JUCE parity. Treat plugin work as Tier 2 (C++ JUCE wrapper around the Rust kernel). |
| Build / distribution cost | ❌ | Cargo + SwiftPM + cbindgen + multi-target CI is a measurable maintenance cost for a small team. Mitigation: confine Rust to kernel only; tier-2 wrappers stay thin. |
| AI-assisted authoring | ⚠️ Conditional | Numerical kernel code: AI-generated, human-reviewed, works well. Lock-free / `unsafe` / FFI: human-authored, not AI-authored. |

### Rejected alternatives

- **C99** — Signed overflow workarounds (`uint32_t` cast pattern) are fragile, and C lacks compile-time verification of the wrapping discipline. Reject as primary kernel; can be auto-generated as a *consumer* of the Rust C ABI.
- **C++20** — Subtle UB surface area too large for a kernel. **Retained as Tier-2 wrapper** (JUCE plugin) where the existing C++ audio plugin ecosystem is decisive.
- **Zig** — Too immature pre-1.0 for a long-lived kernel. No `cbindgen` equivalent. Reject for now; reconsider after 1.0.
- **Swift-on-Linux** — Adds no new reachable platforms (WASM is experimental; `Synchronization.Atomic` is Apple-stdlib leaning). Zero porting cost is illusory once cross-platform CI is required.

## Process notes

This decision was reviewed in two rounds by independent technical advisors, with each advisor critiquing the other's analysis in Round 2. Convergent findings (Golden Master first; build-cost realism) were adopted directly. Divergent findings were resolved by reading current M2DX source code and verifying claims against actual `file:line` references. During the cross-review, one factual error was caught and rejected — a claim that `i32::wrapping_*` panics on overflow is incorrect; only the unchecked operators panic in debug builds, while `wrapping_*` is panic-free by design.

The five entry conditions synthesise:

- Points where both reviewers agreed (Golden Master, build cost).
- A correction to over-optimistic claims about RT safety being inferred from the type system.
- The SIMD/Accelerate cross-platform consideration, which surfaced only after re-reading `SynthEngine.swift` and confirming Accelerate is largely unused on the hot path.

## Out of scope for Phase 4a

- **Pure-Rust VST plugin distribution** — Phase 4a delivers a Rust kernel only. VST/AU/CLAP plugin work is Phase 4c via a thin C++ JUCE wrapper around the C ABI.
- **C# / Unity binding** — Phase 4d, P/Invoke against the same C ABI.
- **WASM distribution** — Tier 2, after the Rust kernel passes Golden Master.
- **Float-stage bit-exactness** — Out of scope by design; libm transcendentals (`expf`, `sinf`, `powf`) are not bit-portable across platforms. Golden Master enforces Int32 stage exactness; the Float stage uses ULP tolerance.

## References

- `TODO.md` — Phase 3a remaining work (must complete before Phase 4 starts).
- `Tests/M2DXCoreTests/ReferenceTests.swift`, `Tests/M2DXCoreTests/VoiceComparisonTests.swift` — current bit-exact harness against DEXED; the template for the language-neutral Golden Master.
- `Sources/M2DXCore/Tables/Exp2Table.swift:53`, `Sources/M2DXCore/Engine/DX7Voice.swift:392` — wrapping arithmetic anchors any port must reproduce.
- `Sources/M2DXCore/Infrastructure/SnapshotRing.swift`, `Sources/M2DXCore/Infrastructure/SPSCRing.swift` — lock-free contract the Rust port must mirror with explicit `unsafe` boundaries.
- `Sources/M2DXCore/DSP/VoiceMixer.swift` — Accelerate-using code currently dead; informs why the cross-platform SIMD gap is smaller than it first appears.
