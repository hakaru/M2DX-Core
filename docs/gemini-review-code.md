Checking build status...
Build is up-to-date.
(node:72095) Warning: `--localstorage-file` was provided without a valid path
(Use `node --trace-warnings ...` to show where the warning was created)
YOLO mode is enabled. All tool calls will be automatically approved.
YOLO mode is enabled. All tool calls will be automatically approved.
I am starting by reading `GEMINI.md` to understand the project context and requirements.

Error executing tool read_file: File not found.
I will list the files in the root directory again to confirm the presence of `GEMINI.md` or similar documentation.

I will check the `docs/` directory to see if `GEMINI.md` is located there.

I will list the existing issues on GitHub to avoid duplicate reporting.

I will read the contents of `docs/API.md` to review its accuracy and completeness.

I will read `Sources/M2DXCore/Engine/SynthEngine.swift` to verify the `SynthEngine` class API.

I will read `Sources/M2DXCore/Engine/ParameterSnapshot.swift` to verify the parameter structures described in `API.md`.

I will read `Sources/M2DXCore/Preset/DX7Preset.swift` to verify the `DX7Preset` structure.

I will read `Sources/M2DXCore/Preset/DX7SysExParser.swift` to verify the SysEx parser API.

I will read `Sources/M2DXCore/Preset/DX7Algorithms.swift` to verify the algorithm definitions.

I will read `Sources/M2DXCore/Preset/DX7FactoryPresets.swift` to verify the factory presets API.

I will search for the definition of `scaleVelocity` to understand how MIDI velocity is handled.

I will read `Sources/M2DXCore/Tables/ScalingTable.swift`.

I will read `Sources/M2DXCore/Engine/DX7Voice.swift` to see how the algorithm index is used.

I will read `Sources/M2DXCore/Infrastructure/SPSCRing.swift` and `Sources/M2DXCore/Infrastructure/SnapshotRing.swift` to ensure they match the thread-safety claims in `API.md`.

I will read `Sources/M2DXCore/Infrastructure/SnapshotRing.swift`.

I will create a GitHub issue for the algorithm index inconsistency.

I will create a GitHub issue for the MIDI velocity handling ambiguity.

`docs/API.md` の新規追加に伴う、API仕様書の正確性および網羅性のレビューを完了しました。

### レビュー結果要約

`docs/API.md` は、プロジェクトの主要なコンポーネントを網羅しており、特にリアルタイム安全性を考慮した設計（ロックフリー SPSC リングバッファ）に関する記述は非常に正確です。しかし、実装との間に重大な不整合が2点確認されたため、GitHub Issue を起票しました。

#### 発見された重大な問題 (Importance: High)

1.  **アルゴリズム・インデックスの不整合 ([#10](https://github.com/hakaru/M2DX-Core/issues/10)):**
    *   **問題:** `DX7Preset` や `initVoice` ではアルゴリズムが 0-31 (0-indexed) で扱われていますが、`API.md` では 1-32 と記載され、サンプルコードでも `-1` する処理が含まれています。また、`DX7Algorithms.definition(for:)` は 1-32 を期待しているため、このままでは不整合が生じます。
    *   **影響:** ユーザーがドキュメント通りに実装すると、誤ったアルゴリズムが選択されたり、`nil` が返されるなどのバグが発生します。

2.  **MIDI ベロシティ処理の非標準的な挙動 ([#11](https://github.com/hakaru/M2DX-Core/issues/11)):**
    *   **問題:** 実装上、`data2` のベロシティは 16-bit で受け取り、内部で 9 ビット右シフト (`>> 9`) して 7-bit に変換しています。標準的な MIDI ベロシティ (127 など) を渡すと `0` (無音) になり、最大音量を得るには `0xFE00` 以上を渡す必要があります。
    *   **影響:** 一般的な MIDI プログラミングの常識と大きく乖離しており、ユーザーが音が出ない、あるいは非常に小さい音しか出ないといった混乱を招く可能性が非常に高いです。

#### その他の指摘事項 (Importance: Medium/Minor)

*   **`DX7OperatorPreset.detuneCents`:** `detune - 7` という計算式が提示されていますが、DX7のデチューンステップは厳密に 1 cent ではないため、プロパティ名が誤解を招く可能性があります。
*   **`setOperatorWaveform`:** リファレンスには存在しますが、現状の実装は Sine 波固定の no-op です。将来的な DX7II 対応用である旨の注記があると親切です。

### 結論

基本構成は非常に優れていますが、上記 Issue にて指摘した「アルゴリズムのインデックス基準」と「MIDIベロシティの仕様」の2点について、ドキュメントまたは実装を修正することを強く推奨します。
