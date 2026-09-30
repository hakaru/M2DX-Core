# Host render event phase (M2DX #119)

The AU host needs to retain its active automation after a new control snapshot arrives, then apply its current render events in order. Replaying retained automation into the MIDI FIFO on every block would consume note-event capacity and repeat the expensive voice parameter update.

Add a synchronous, nonescaping `render(into:bufferR:frameCount:processEvents:)` overload. Its callback receives whether a control snapshot was consumed. It runs after snapshot, mode/controller reset and completed-voice reclamation, before voice parameter application and audio generation. The original render API remains available.

The callback may call `processRenderParameter(_:)` and `processRenderMIDI(_:)`. These directly process events on the audio thread, without the FIFO. Parameter CC7 updates the synthesis master-volume field; physical MIDI CC7 remains the independent channel-volume multiplier. Host parameter NRPNs keep their existing native value transport.

The host restores its still-active parameter values only when the callback reports a new control snapshot, then processes the current host event list in its original order. Explicit host edits invalidate the corresponding retained values before their new control snapshot arrives. Callers must use their control-side storage rather than read or write the engine's shadow from the audio thread.

- [x] Add regression tests for both engines: retained detune vs control-only PCM reference, later explicit replacement, sustain/reset ordering, master-volume versus CC7, and events exceeding MIDI FIFO capacity without queue drops.
- [x] Implement the event phase and direct event entry points; retain the queue path for callers of the original API. Focused RenderEventPhase/NRPNAutomation tests pass (13 tests).
- [x] Prepare engine/oversampling/sample-rate/voice-budget changes before both event paths. Regression tests require audible PCM and active voices; the first LAYER note allocates all 64 requested voices.
- [x] Pass focused (13 tests) and full Debug/Release tests (349 tests, 62 suites each), then review independently. The mode-preparation order finding is resolved; no remaining P1/P2 found in the Core API review.
- [x] Document the public thread contract in the API reference.
- [ ] Publish a release before the app adopts the API.

No callbacks may allocate, block, access main-actor state or call control setters. The callback's lifetime ends with `render`; the engine never stores it. Existing queued MIDI is drained after the callback, so callers requiring one ordered host event stream should deliver that stream through the callback only.
