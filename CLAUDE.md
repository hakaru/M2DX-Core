# CLAUDE.md

このファイルは、本リポジトリで作業する Claude Code (claude.ai/code) への指針を提供します。

## ビルドとテスト

```bash
swift build                          # M2DXCore + DX7Ref ターゲットをビルド
swift test                           # 全 107 テストを実行
swift test --verbose                 # テスト名を含めて詳細出力
swift test --filter Table            # 単一スイート（例: TableTests, AlgorithmTests, VoiceComparisonTests）
swift test --filter VoiceComparison/initVoiceMatchesDEXED   # 単一テスト
```

CI (`.github/workflows/ci.yml`) は `macos-15` + Xcode 16 で動作し、加えて `Sources/` 配下に文字列 `msfa` が存在しないかを `grep` で検査する。1 件でもヒットすればビルドは失敗する（後述「クリーンルーム規約」を参照）。要件: Swift 6.0+, macOS 15+ / iOS 18+。

## パッケージ構成

`Package.swift` には 2 つの SwiftPM ターゲットがある:

- **`M2DXCore`**（Swift, 本体ライブラリ）— `Accelerate` をリンクし、`Sources/M2DXCore/Preset/Resources/SysEx`（ファクトリ ROM）をリソースとして同梱する。
- **`DX7Ref`**（C, テスト専用）— DEXED の参照実装を `dx7ref_*` として公開。`ReferenceTests` と `VoiceComparisonTests` におけるビット単位比較にのみ用いる。**`M2DXCore` の本体コードからインポートしてはならない**。

`Sources/M2DXCore/` 以下のディレクトリ:

| ディレクトリ | 役割 |
|---|---|
| `Engine/` | `SynthEngine`（最上位のボイス管理 + レンダ + MIDI）、`DX7Voice`、`DX7Operator`、`DX7Envelope`、`Algorithm`、`ParameterSnapshot` |
| `Tables/` | 自前生成 LUT: `SinTable` (Q30)、`Exp2Table` (Q30)、`FrequencyTable`、`ScalingTable` (KLS) |
| `Infrastructure/` | `SnapshotRing<T>`（最新値 SPSC）と `SPSCRing<T>`（FIFO SPSC）— いずれも `package` スコープ、`Synchronization.Atomic` で実装 |
| `DSP/` | `Downsampler`（vDSP FIR デシメーション）、`VoiceMixer`（vDSP ミックス/クリップ/変換） |
| `Preset/` | `DX7Preset`、`DX7SysExParser`（4104 バイト 32 ボイスのバルクダンプ）、`DX7Algorithms`（32 アルゴリズム）、`DX7FactoryPresets` |

テストは `Tests/M2DXCoreTests/` に配置。XCTest ではなく Swift Testing（`import Testing`、`@Suite`、`@Test`、`#expect`）を使用している。

## アーキテクチャ: スレッドモデルこそがアーキテクチャ

ライブラリ全体が「**オーディオレンダースレッドはアロケートしない、ブロックしない**」という制約から設計されている。ほぼ全ての設計判断はここから派生する。

- **UI → オーディオ: パラメータ** は単一の `SnapshotRing<SynthParamSnapshot>`（容量 64）を流れる。プロデューサ（任意の UI/setter 呼び出し）はシャドウ `SynthParamSnapshot` を変更し `version` をインクリメントしてから `pushLatest` する。コンシューマ（`SynthEngine.render`）は `popLatest` で**最新だけ**を取り、中間スナップショットはスキップする。メモリ順序は `writeIndex` に release ストア、`readIndex` に acquire ロード。
- **UI → オーディオ: MIDI** は `SPSCRing<MIDIEvent>`（容量 256）を流れる。FIFO で、スナップショットのように合体できないため別系統。
- **`SynthParamSnapshot` はコピーがヒープフリーでなければならない。** `slots` と `slotConfigs` は `Array` ではなく**固定長タプル**（`kMaxSlots = 8`）で持つ。以前の issue #2 は「リングが古いスナップショットを破棄する際に、その中の `Array` が解放され、レンダースレッドでヒープ free が走る」問題だった。アクセスは `slot(at:)` / `setSlot(at:)` / `config(at:)` / `setConfig(at:)` のサブスクリプト経由で行い、ここに `Array` を再導入してはならない。
- **ボイス配列と DSP のスクラッチバッファは全て `UnsafeMutablePointer` で `SynthEngine.init` 時に事前確保する**（`voicesDX7`, `dx7BlockBuf`, `dx7Bus1/2`, `floatScratch`, `panGainL/R`）。`VoiceMixer.accumulateVoice` のような DSP ヘルパは呼び出し側から `scratch` を受け取る（issue #3）。内部アロケーションを足さないこと。
- `SynthEngine` は `final class @unchecked Sendable`。`unchecked` の対価は上記リング規律で支払っている。`NSLock` も `pthread_mutex` も使わない。

## 2 つの合成モード（と実際に動いている方）

提案書では **DX7 モード**（Int32 固定小数点、Q24 位相 / Q30 振幅、OPS チップにビット単位で一致）と **Clean モード**（Float32, 拡張用）が定義されている。だが**現状動いているのは DX7 モードのみ**で、`SynthEngine` は `DX7Voice` と `dx7BlockBuf: Int32` を確保し、ブロック後に `vDSP_vflt32` で Float に変換している。古いドキュメント（`docs/proposal.md`）が描く別系統の `Voice.swift`/`Operator.swift` Float パスは現存しない。提案書は「設計意図」として読み、現状の構造そのものとしては読まないこと。

`OversamplingMode`（`.off`, `.highQuality`, `.lowCPU`）は、ブロックを 2× で動かして `Downsampler` で間引くかを切り替える。

## 規約・落とし穴（自明でないもの）

- **クリーンルーム規約。** `Sources/` 配下に `msfa` を含む識別子・コメント・文字列を一切置かない。CI が `grep` で検査する。`Sources/DX7Ref/` の DEXED 由来 C コードはテスト専用ターゲットなので許容されているが、本体コードはクリーンに保つ。
- **アルゴリズム番号は 2 通りある。**
  - `SynthEngine.setAlgorithm(_:)`、`DX7Preset.algorithm`、`OperatorSnapshot/SlotSnapshot.algorithm`: **0 始まり (0–31)**。
  - `DX7AlgorithmDefinition.number` と `DX7Algorithms.definition(for:)`: **1 始まり (1–32, DX7 流儀)**。
  - 相互変換時の off-by-one が定番バグ。
- **オペレータ番号付け。** setter API の `opIndex: 0...5` は DX7 流儀の **OP6…OP1** にマップする（つまり index 0 は OP6）。DX7 のデータシートや SysEx レイアウトは逆順なので、パラメータ移植時は要注意。
- **MIDI 2.0 ベロシティ形式。** `MIDIEvent.noteOn` の `data2` は下位ワードに 16-bit ベロシティを持つ。標準 7-bit ベロシティを送るときは **9 ビット左シフト**: `UInt32(vel7) << 9`（127 → `0xFE00`）。`kind` に関わらず `data2 == 0` は Note Off として扱われる。
- **MIDI 2.0 イベント種別。** `MIDIEvent.Kind` は基本 4 種に加えて `channelPressure`, `polyPressure`, `perNotePitchBend`, `perNoteCC`, `perNoteManagement`, `registeredController`, `assignableController` を持つ。`data2` にパックしたエンコードを使う（per-note CC や RPN/NRPN なら `(index << 24) | (value & 0x00FFFFFF)`）。フォーマット仕様は `SynthEngine.swift` のヘッダコメントが正。
- **CC のハンドリング。** 結線済みなのは CC 1, 2, 4, 7, 11, 64, 123 のみ（mod/breath/foot/volume/expression/sustain/all-notes-off）。Sustain (CC64) は `data2 ≥ 0x40000000` でラッチする。
- **ロックフリーリングは `package` スコープ。** `SnapshotRing` と `SPSCRing` はあえて `public` にしていない。`SynthEngine` のスレッド契約の実装詳細であり、可視性を広げないこと。
- **DEXED 一致は数値で強制されている。** `ReferenceTests` と `VoiceComparisonTests` は、M2DX の出力と `DX7Ref`（DEXED の `scale_rate`, `scale_velocity`, `scale_level`, `exp2`, EG, アルゴリズム出力, ボイス全体の波形）を**全入力スイープ**で比較する。`Tables/`、`DX7Operator`、`DX7Envelope`、`DX7Voice`、`Algorithm` のいずれかを変更したら、これらは確実に大きく失敗する。これは助言ではなくリグレッション検出器。

## どこに何があるか

- **公開 API と各パラメータの値域:** `docs/API.md`（網羅的かつ現状反映済み）。
- **設計の動機（ライセンス、スレッドモデル、MIDI 2.0、SIMD 計画）:** `docs/proposal.md`（ただしディレクトリ構成は構想段階のもので、一部のファイルは実在しない）。
- **進捗 / ロードマップ:** `TODO.md`（Phase 2 は 2026-02-16 時点で ✅ 完了、Phase 3 = SPM リリース、Phase 4 = TX816/AUv3）と `CHANGELOG.md`。
- **ファクトリプリセット:** `Sources/M2DXCore/Preset/Resources/SysEx/`（rom1a–rom4b に加えて `dx7ii/`, `greymatter/`, `vrc/` のサブバンク）。
