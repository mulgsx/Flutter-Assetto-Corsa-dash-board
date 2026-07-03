# Assetto Corsa Protocol Reference / Assetto Corsa通信プロトコル・リファレンス

## Overview / 概要

Assetto Corsaは組み込みUDPサーバーを搭載しており、外部アプリケーション（スマートフォンのダッシュボードアプリなど）からリアルタイムテレメトリデータを取得できます。このドキュメントは、その通信プロトコルの仕組みを説明します。バイト単位のパケット構造は [packet-structure.md](packet-structure.md) を参照してください。

Assetto Corsa has a built-in UDP server that allows external applications (such as smartphone dashboard apps) to retrieve real-time telemetry data. This document explains how the protocol works. For the byte-level packet layouts, see [packet-structure.md](packet-structure.md).

---

## Setup Requirements / セットアップ要件

### Hardware / Environment（ハードウェア/環境）
- **PC running Assetto Corsa** / Assetto Corsaが実行されるPC（Windows/Mac/Linux対応）
- **Smartphone** / スマートフォン（同じWi-Fiネットワーク上）
- **Transport layer** / トランスポート層: UDP port **9996**

### Prerequisites / 事前確認
- PC and smartphone must be on the same network / PCとスマートフォンが同じネットワーク上にあること
- Know the PC's local IP address (e.g., `192.168.1.100`) / PCのローカルIPアドレスを確認

---

## Protocol Layer Structure / 通信プロトコルの階層構造

```
Application Layer / アプリケーション層
┌─────────────────────────────────────────┐
│ Assetto Corsa proprietary protocol      │
│  - Handshake (connection verification)  │
│  - Session information exchange         │
│  - Mode selection                       │
│  - Telemetry data definitions           │
└─────────────────────────────────────────┘
          ↓ (sent/received via UDP)
Transport Layer / トランスポート層
┌─────────────────────────────────────────┐
│ UDP                                     │
│  - No connection establishment          │
│  - No acknowledgment                    │
│  - Low latency (supports 120Hz)         │
│  - Lightweight (ideal for games)        │
└─────────────────────────────────────────┘
          ↓
Network Layer / ネットワーク層
┌─────────────────────────────────────────┐
│ IP (IPv4)                               │
│  - Routing, address management          │
└─────────────────────────────────────────┘
```

### Key Distinction / 重要な区別

| Layer / 層 | Technology / 技術 | Role / 役割 | Implemented by / 実装元 |
|---|---|---|---|
| **Transport / トランスポート** | **UDP** | Sends and receives data / データを送受信する | OS |
| **Application / アプリケーション** | **Handshake protocol / ハンドシェイク・プロトコル** | Connection verification, mode selection / 接続確認・モード選択 | Assetto Corsa |

### Communication Flow / 通信フロー

```
[1] Client → Server: Send handshake (Connect)          クライアント→サーバー: ハンドシェイク送信（Connect）
    ↓ (sent via UDP)
[2] Server → Client: Handshake response + session info サーバー→クライアント: ハンドシェイク応答＋セッション情報
    ↓ (received via UDP)
[3] Client → Server: Send handshake (mode selection)    クライアント→サーバー: ハンドシェイク送信（モード選択）
    ↓ (sent via UDP)
[4] Server → Client: RTCarInfo or RTLap (continuous, 120Hz)  サーバー→クライアント: RTCarInfo/RTLap（120Hzで連続送信）
    ↓ (continuously received via UDP)
```

### Why This Design? / なぜこの設計？

**Why UDP / UDPを選んだ理由:**
- ✅ Low latency, faster than TCP / 低レイテンシー（TCPより高速）
- ✅ Lightweight, game-friendly / 軽量（ゲーム向け）
- ✅ Supports 120Hz high-frequency sending / 120Hzの高頻度送信に対応
- ❌ No connection confirmation at the transport level / ただし接続確認がない

**Supplemented by an application-layer handshake / ハンドシェイク（アプリケーション層）で補った:**
- Confirms the connection is actually alive, at the application layer / 「本当に接続されているか」をアプリケーション層で確認
- Exchanges session info (driver name, car name, etc.) / セッション情報（ドライバー名、車名等）を交換
- Selects the telemetry mode (car telemetry or lap time) / テレメトリモードを選択（カーテレメトリ or ラップタイム）

Note: this "handshake" is a purely application-level convention — there is no OS/transport-level handshake like TCP's SYN/SYN-ACK/ACK. That's why the client must retry the Connect packet itself if no response arrives (UDP guarantees nothing).

補足: ここで言う「ハンドシェイク」はあくまでアプリケーション層の取り決めであり、TCPのSYN/SYN-ACK/ACKのようなOS・トランスポート層の仕組みではありません。UDPは到達を保証しないため、応答が来なければクライアント側が自分でConnectパケットを再送する必要があります。

---

## Troubleshooting / トラブルシューティング

| Symptom / 問題 | Likely layer / 原因が多い層 | How to check / 確認方法 |
|------|---|---|
| Cannot connect / 接続できない | Transport (UDP) / トランスポート層 | Firewall, port, network / ファイアウォール、ポート、ネットワーク |
| Parse errors / パースエラー | Application / アプリケーション層 | Offsets, byte order, string encoding / オフセット、バイト順序、文字エンコード |
| No data arriving / データが来ない | Both / 両層 | Check network first, then handshake / まずネットワーク確認、次にハンドシェイク確認 |
| Garbled text / 文字化け | Application / アプリケーション層 | Verify UTF-16LE decoding / UTF-16LEデコーディング確認 |

### Cannot connect / 接続できない
1. Confirm the PC and phone are on the same network (Wi-Fi, firewall). / PCとスマートフォンが同じネットワーク上か、ファイアウォール設定を確認。
2. Confirm you're using the correct IP address (`ipconfig` on Windows). / 正しいIPアドレスを使用しているか確認（Windowsでは`ipconfig`）。
3. Confirm port 9996 isn't blocked (`netstat -an | findstr 9996` on Windows). / ポート9996がブロックされていないか確認。

### No handshake response / ハンドシェイク応答が来ない
- Confirm Assetto Corsa is running. / Assetto Corsaが起動しているか確認。
- Confirm remote telemetry is enabled in the game's settings. / ゲーム内設定でリモートテレメトリが有効か確認。

### No telemetry data / データが受信できない
- Confirm the packet size (RTCarInfo = 328 bytes). / パケットサイズを確認（RTCarInfo = 328バイト）。
- Confirm the endianness (little-endian). / エンディアン（リトルエンディアン）が正しいか確認。
- Confirm the offsets — see [packet-structure.md](packet-structure.md). / オフセット計算を確認 — [packet-structure.md](packet-structure.md) を参照。

---

## Summary / まとめ

| Layer / 層 | Technology / 技術 | Implemented by / 実装元 | Role / 役割 |
|---|---|---|---|
| **Application / アプリケーション層** | Assetto Corsa handshake protocol / ハンドシェイク・プロトコル | App developer / 開発者が実装 | Connection check, session info, mode selection / 接続確認、セッション情報、モード選択 |
| **Transport / トランスポート層** | UDP | OS | Send/receive packets / データをパケットで送受信 |

**Transport layer (UDP) / トランスポート層（UDP）:**
- Port **9996**
- No OS-level connection establishment / 接続確立なし（OSレベル）
- Low latency, lightweight / 低レイテンシー、軽量

**Application layer (Assetto Corsa's own protocol) / アプリケーション層（Assetto Corsa独自プロトコル）:**
- Handshake sequence: **Connect → Response → Mode Selection** / ハンドシェイク: Connect→Response→モード選択
- Packets / パケット仕様: `Handshaker` (12B), `HandshakerResponse` (408B), `RTCarInfo` (328B), `RTLap` (212B+) — details in [packet-structure.md](packet-structure.md)
- Strings / 文字列: **UTF-16LE (Unicode)**
- Numbers / 数値: **Little Endian**

This project's actual implementation lives in [lib/main.dart](../lib/main.dart) (connection/handshake state machine) and [lib/ac_converter.dart](../lib/ac_converter.dart) (binary parsing) — see those files for the authoritative, working code.

このプロジェクトの実際の実装は [lib/main.dart](../lib/main.dart)（接続・ハンドシェイクの状態管理）と [lib/ac_converter.dart](../lib/ac_converter.dart)（バイナリパース）にあります。実装の正としてはこちらを参照してください。
