# 📄 Bias Calibration Tool

## 要件定義書 + 基本設計（v3.0 完成版）

---

# 1. システム概要

本システムはカセットデッキの調整を支援するGUIアプリケーションであり、以下を提供する：

* バイアス調整（Noise + Tone）
* 対話型ガイド
* ワウフラ測定
* テスト音源生成・書き出し

---

# 2. システム目的

* スペクトラム解析不要の調整体験提供
* 初心者でも調整可能にする
* 実機レベルの精度確保

---

# 3. スコープ

## 対象

* カセットデッキ（Type I / II / IV）
* 外部オーディオ入力

---

## 非対象

* EQ調整
* ノイズリダクション調整
* 自動バイアス制御

---

# 4. 機能一覧

| ID | 機能                |
| -- | ----------------- |
| F1 | Noise Calibration |
| F2 | Tone Calibration  |
| F3 | Guided Mode       |
| F4 | Wow & Flutter測定   |
| F5 | Signal Export     |
| F6 | 内蔵信号生成            |

---

# 5. システム構成

```text
Audio Input
   ↓
Signal Processor
   ↓
Analysis Engine
   ↓
Evaluation Engine
   ↓
UI Layer
```

---

# 6. UI設計

---

## 6.1 タブ構成

```text
[ Bias ] [ Guided ] [ Wow & Flutter ] [ Signal Export ]
```

---

# 7. 機能仕様

---

# 7.1 Noise Calibration（粗調整）

---

## 目的

* 周波数特性の補正

---

## 入力

* ホワイトノイズ

---

## 処理

```text
高域平均（8k〜12kHz）
中域平均（1k〜4kHz）
差分算出
```

---

## 出力

* バイアスメーター
* 状態（OVER / OK / UNDER）

---

## 判定

| 値         | 状態    |
| --------- | ----- |
| > +0.5 dB | UNDER |
| -0.5〜+0.5 | OK    |
| < -0.5    | OVER  |

---

---

# 7.2 Tone Calibration（仕上げ）

---

## 目的

👉 歪み最小点の特定

---

## 入力

* 10kHzサイン波

---

## 処理

```text
出力レベル測定
最大値検出
現在値との差分算出
```

---

## 出力

* レベルメーター
* Peak Hold
* 状態表示

---

## 判定

| 条件               | 状態    |
| ---------------- | ----- |
| peak付近           | MAX   |
| peak -0.5〜-1.5dB | 推奨    |
| peakより上          | UNDER |
| peakより下          | OVER  |

---

---

# 7.3 Guided Mode

---

## 目的

* 初心者支援

---

## フロー

```text
1. 準備
2. Noise Calibration
3. Tone Calibration
4. 完了
```

---

## UI

* ステップ形式
* メッセージ表示
* ボタン遷移

---

---

# 7.4 Wow & Flutter

---

## 入力

* 3kHzトーン

---

## 処理

```text
瞬時周波数検出
変動計算
RMS算出
```

---

## 出力

| 値      | 評価        |
| ------ | --------- |
| <0.05% | EXCELLENT |
| <0.1%  | GOOD      |
| <0.2%  | OK        |
| >0.2%  | BAD       |

---

---

# 7.5 Signal Export

---

## 目的

* 外部再生用テスト信号生成

---

## 出力ファイル

```text
calibration_noise.wav
calibration_tone_10k.wav
```

---

## 仕様

| 項目      | 値        |
| ------- | -------- |
| フォーマット  | WAV      |
| サンプルレート | 44.1kHz  |
| ビット深度   | 16bit    |
| チャンネル   | Stereo   |
| レベル     | -12 dBFS |

---

---

# 7.6 内蔵信号生成

---

## 種類

* ホワイトノイズ
* 10kHzトーン

---

## 仕様

* リアルタイム生成
* 固定レベル

---

---

# 8. データフロー

```text
Audio Input → FFT → Band Analysis → Difference → Evaluation → UI
```

---

# 9. アルゴリズム設計

---

## 9.1 Noise

```text
normalized = high_band - mid_band
bias_error = tape - source
```

---

## 9.2 Tone

```text
peak = max(level)
delta = current - peak
```

---

## 9.3 Wow & Flutter

```text
Δf / f → RMS
```

---

---

# 10. UIコンポーネント

---

## 必須

* バイアスメーター
* レベルメーター
* ステータス表示
* ボタン群

---

## 表示ルール

👉 メーター中心
👉 数値は補助

---

---

# 11. 非機能要件

| 項目     | 要件     |
| ------ | ------ |
| レイテンシ  | <200ms |
| CPU使用率 | <20%   |
| 起動時間   | <2秒    |
| OS     | macOS  |

---

---

# 12. UX設計

---

## 初心者

👉 Guided

---

## 中級者

👉 Noise → Tone

---

## 上級者

👉 Toneのみ

---

---

# 13. 成功条件

---

* ユーザーが迷わない
* 調整時間が短い
* 再現性がある

---

---

# 14. リスク

| リスク      | 対策    |
| -------- | ----- |
| 入力レベル不適切 | レベル警告 |
| 外部音源品質   | 内蔵生成  |
| ノイズ環境    | 安定度表示 |

---

---

# 15. 完成定義

---

👉 **中央に合わせるだけで正しく調整できる**

---

# 🔚 最終まとめ

---

👉 Noiseで方向
👉 Toneで決定
👉 GUIで直感

---

