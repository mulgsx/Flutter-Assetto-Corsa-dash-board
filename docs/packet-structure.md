# Packet Structure / パケット構造リファレンス

Byte-level layout of every Assetto Corsa UDP telemetry packet. All packets are application-layer data sent/received over plain UDP on port **9996**. Numbers are little-endian; strings are UTF-16LE unless noted otherwise. For the protocol flow these packets are used in, see [assetto-corsa-protocol-reference.md](assetto-corsa-protocol-reference.md).

Assetto Corsaの各UDPテレメトリパケットのバイト単位の構造です。すべてポート**9996**の生UDPで送受信されるアプリケーション層のデータです。数値はリトルエンディアン、文字列は特に断りがない限りUTF-16LEです。これらのパケットが使われる通信フローについては [assetto-corsa-protocol-reference.md](assetto-corsa-protocol-reference.md) を参照してください。

> This project currently only parses a subset of these fields — see [lib/ac_converter.dart](../lib/ac_converter.dart) (`ACHandshaker`, `RTCarInfo`) for what's actually implemented. The tables below document the **full** wire format for reference.
>
> 本プロジェクトでは現状これらのフィールドの一部のみをパースしています — 実際に実装されている範囲は [lib/ac_converter.dart](../lib/ac_converter.dart)（`ACHandshaker`, `RTCarInfo`）を参照してください。以下の表は参考として**フルスペック**を記載しています。

---

## 1. Handshaker (12 bytes) — client → server / クライアント→サーバー

Sent by the client to initiate a connection or select a mode.
クライアントが接続開始・モード選択のために送信するパケット。

| Offset | Type | Size | Description / 説明 |
|---|---|---|---|
| 0 | uint32 | 4 | `identifier` — device ID, usually 1 / デバイスID（通常1） |
| 4 | uint32 | 4 | `version` — protocol version, usually 1 / プロトコルバージョン（通常1） |
| 8 | uint32 | 4 | `operationId` — 0=Connect, 1=CarInfo, 2=LapInfo, 3=Disconnect |

---

## 2. HandshakerResponse (408 bytes fixed) — server → client / サーバー→クライアント

Sent by the server in reply to a Connect handshake. Contains session info.
サーバーからのハンドシェイク応答。セッション情報を含む。

| Offset | Type | Size | Description / 説明 |
|---|---|---|---|
| 0 | string[50] (UTF-16LE) | 100 | `carName` |
| 100 | string[50] (UTF-16LE) | 100 | `driverName` |
| 200 | uint32 | 4 | `identifier` — status code, 4242 / ステータスコード（4242） |
| 204 | uint32 | 4 | `version` — server version / サーバーバージョン |
| 208 | string[50] (UTF-16LE) | 100 | `trackName` |
| 308 | string[50] (UTF-16LE) | 100 | `trackConfig` |

Strings are UTF-16LE, 100 bytes each (50 chars × 2 bytes). / 文字列はUTF-16LEで100バイト（50文字×2バイト）。

---

## 3. RTCarInfo (328 bytes fixed) — server → client, continuous @ ~120Hz / サーバー→クライアント（連続送信）

Vehicle telemetry, streamed continuously once the client sends `operationId=1` (CarInfo).
クライアントが`operationId=1`（CarInfo）を送信した後、継続的に配信される車両テレメトリ。

| Offset | Type | Size | Description / 説明 |
|---|---|---|---|
| 0 | string[2] (ASCII) | 4 | `identifier` — always "AC" |
| 4 | uint32 | 4 | `size` — struct size, 328 / 構造体サイズ（328） |
| 8 | float32 | 4 | `speed_Kmh` — speed in km/h / 速度 |
| 12 | float32 | 4 | `speed_Mph` — speed in mph |
| 16 | float32 | 4 | `speed_Ms` — speed in m/s |
| 20 | uint8 | 1 | `isAbsEnabled` |
| 21 | uint8 | 1 | `isAbsInAction` |
| 22 | uint8 | 1 | `isTcInAction` — traction control active / トラクションコントロール作動 |
| 23 | uint8 | 1 | `isTcEnabled` |
| 24 | uint8 | 1 | `isInPit` |
| 25 | uint8 | 1 | `isEngineLimiterOn` |
| 28 | float32 | 4 | `accG_vertical` — vertical G / 垂直G |
| 32 | float32 | 4 | `accG_horizontal` — lateral G / 横G |
| 36 | float32 | 4 | `accG_frontal` — longitudinal G / 前後G |
| 40 | uint32 | 4 | `lapTime` — current lap time, ms / 現在のラップタイム |
| 44 | uint32 | 4 | `lastLap` — previous lap time, ms |
| 48 | uint32 | 4 | `bestLap` — best lap time, ms |
| 52 | uint32 | 4 | `lapCount` |
| 56 | float32 | 4 | `gas` — throttle 0-1 / スロットル |
| 60 | float32 | 4 | `brake` — 0-1 |
| 64 | float32 | 4 | `clutch` — 0-1 |
| 68 | float32 | 4 | `engineRPM` |
| 72 | float32 | 4 | `steer` — steering angle, -1 to 1 / ハンドル角 |
| 76 | uint32 | 4 | `gear` — 0=R, 1=N, 2+=forward / ギア |
| 80 | float32 | 4 | `cgHeight` — center of gravity height / 重心高さ |
| 84 | float32[4] | 16 | `wheelAngularSpeed` — per wheel / 各輪のホイール回転速度 |
| 100 | float32[4] | 16 | `slipAngle` — slip angle / スリップ角 |
| 116 | float32[4] | 16 | `slipAngle_ContactPatch` — contact patch slip angle / 接地面スリップ角 |
| 132 | float32[4] | 16 | `slipRatio` — スリップレート |
| 148 | float32[4] | 16 | `tyreSlip` — タイヤスリップ |
| 164 | float32[4] | 16 | `ndSlip` — normalized slip / ノーマライズドスリップ |
| 180 | float32[4] | 16 | `load` — tyre load / タイヤ荷重 |
| 196 | float32[4] | 16 | `Dy` — lateral force / 横力 |
| 212 | float32[4] | 16 | `Mz` — self-aligning moment / 自動復帰モーメント |
| 228 | float32[4] | 16 | `tyreDirtyLevel` — タイヤダーティレベル |
| 244 | float32[4] | 16 | `camberRAD` — camber angle, radians / キャンバー角 |
| 260 | float32[4] | 16 | `tyreRadius` — タイヤ半径 |
| 276 | float32[4] | 16 | `tyreLoadedRadius` — loaded tyre radius / 荷重時タイヤ半径 |
| 292 | float32[4] | 16 | `suspensionHeight` — サスペンション高 |
| 308 | float32 | 4 | `carPositionNormalized` — normalized track position / トラック上の正規化位置 |
| 312 | float32 | 4 | `carSlope` — vehicle pitch angle / 車体傾斜角 |
| 316 | float32[3] | 12 | `carCoordinates` — 3D world coordinates / 3D座標 |

Fields marked `[4]` are per-wheel arrays in FL, FR, RL, RR order (Assetto Corsa's standard wheel ordering).
`[4]`の付いたフィールドは各輪の配列（FL, FR, RL, RRの順、Assetto Corsa標準の並び）。

This project's [lib/ac_converter.dart](../lib/ac_converter.dart) `RTCarInfo.fromBytes` currently reads only `speedKmh` (offset 8), `gas` (56), `brake` (60), `engineRPM` (68), `gear` (76), and `lapTime` (40) — the rest of the struct above is unused but still arrives on the wire.

本プロジェクトの[lib/ac_converter.dart](../lib/ac_converter.dart)の`RTCarInfo.fromBytes`は現状、`speedKmh`(offset 8)・`gas`(56)・`brake`(60)・`engineRPM`(68)・`gear`(76)・`lapTime`(40)のみを読み取っています。それ以外のフィールドは未使用ですが、パケット自体には引き続き含まれています。

---

## 4. RTLap (212+ bytes) — server → client, per lap / サーバー→クライアント（ラップ完了ごと）

Lap time data, sent once per completed lap when the client has subscribed with `operationId=2` (LapInfo).
クライアントが`operationId=2`（LapInfo）を購読している場合、ラップ完了ごとに送信されるラップタイムデータ。

| Offset | Type | Size | Description / 説明 |
|---|---|---|---|
| 0 | uint32 | 4 | `carIdentifierNumber` — vehicle identifier / 車両識別番号 |
| 4 | uint32 | 4 | `lap` — lap number / ラップ番号 |
| 8 | string[50] (UTF-16LE) | 100 | `driverName` |
| 108 | string[50] (UTF-16LE) | 100 | `carName` |
| 208 | uint32 | 4 | `time` — lap time, ms / ラップタイム |

This project does not currently subscribe to or parse `RTLap`. / 本プロジェクトは現状`RTLap`の購読・パースを行っていません。
