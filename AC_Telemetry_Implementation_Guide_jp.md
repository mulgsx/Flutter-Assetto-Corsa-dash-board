# Assetto Corsa テレメトリデータ取得実装ガイド

## 概要

Assetto Corsaは組み込みUDPサーバーを搭載しており、外部アプリケーション（スマートフォンのダッシュボードアプリなど）からリアルタイムテレメトリデータを取得できます。このドキュメントは、Dartを使用したFlutterアプリケーションでの実装方法を説明します。

---

## セットアップ要件

### ハードウェア/環境
- **Assetto Corsaが実行されるPC** （Windows/Mac/Linux対応）
- **スマートフォン** （同じWi-Fiネットワーク上）
- **トランスポート層**: UDP port **9996**

### 事前確認
- PCとスマートフォンが同じネットワーク上にあること
- PCのローカルIPアドレス（例：`192.168.1.100`）を確認

---

## 通信プロトコルの階層構造

### **階層による役割の違い**

```
アプリケーション層
┌─────────────────────────────────────────┐
│ Assetto Corsa独自プロトコル             │
│  - ハンドシェイク（接続確認）           │
│  - セッション情報交換                   │
│  - モード選択                           │
│  - テレメトリデータ定義                 │
└─────────────────────────────────────────┘
          ↓ (UDPで送受信)
トランスポート層
┌─────────────────────────────────────────┐
│ UDP                                     │
│  - 接続確立なし                         │
│  - 確認応答なし                         │
│  - 低レイテンシー（120Hz対応）         │
│  - 軽量（ゲームに最適）                 │
└─────────────────────────────────────────┘
          ↓
ネットワーク層
┌─────────────────────────────────────────┐
│ IP (IPv4)                               │
│  - ルーティング、アドレス管理           │
└─────────────────────────────────────────┘
```

### **重要な区別**

| 層 | 技術 | 役割 | 実装元 |
|---|---|---|---|
| **トランスポート** | **UDP** | データを送受信する | OSが実装 |
| **アプリケーション** | **ハンドシェイク・プロトコル** | 接続確認・モード選択 | Assetto Corsaが実装 |

### **通信フロー**

```
[1] クライアント → サーバー: ハンドシェイク送信（Connect）
    ↓ (UDP で送信)
[2] サーバー → クライアント: ハンドシェイク応答 + セッション情報
    ↓ (UDP で受信)
[3] クライアント → サーバー: ハンドシェイク送信（モード選択）
    ↓ (UDP で送信)
[4] サーバー → クライアント: RTCarInfo または RTLap（連続送信 120Hz）
    ↓ (UDP で連続受信)
```

### **なぜこの設計？**

**UDPを選んだ理由:**
- ✅ 低レイテンシー（TCPより高速）
- ✅ 軽量（ゲーム向け）
- ✅ 120Hzの高頻度送信に対応
- ❌ ただし接続確認がない

**ハンドシェイク（アプリケーション層）で補った:**
- 「本当に接続されているか」をアプリケーション層で確認
- セッション情報（ドライバー名、車名等）を交換
- テレメトリモードを選択（カーテレメトリ or ラップタイム）

---

## プロトコル仕様

### アプリケーション層パケット仕様

このセクションで説明するパケット構造は、**Assetto Corsaが独自に定義したアプリケーション層プロトコル**です。これらのデータはすべて**UDPで送受信**されます。

#### 1. Handshaker（12バイト）

**[アプリケーション層]** クライアントがサーバーに送信。初期化と通信モード選択に使用。

```
Offset  Type    Size  説明
------  ----    ----  ----
0       uint32  4     identifier (デバイスID, 通常1)
4       uint32  4     version (プロトコルバージョン, 通常1)
8       uint32  4     operationId (0=Connect, 1=CarInfo, 2=LapInfo, 3=Disconnect)
```

**このパケットはUDP（トランスポート層）で送信されます**

#### 2. HandshakerResponse（408バイト固定）

**[アプリケーション層]** サーバーからの応答。セッション情報を含む。

```
Offset  Type               Size  説明
------  ----               ----  ----
0       string[50]         100   carName (Unicode UTF-16LE)
100     string[50]         100   driverName (Unicode UTF-16LE)
200     uint32             4     identifier (ステータスコード, 4242)
204     uint32             4     version (サーバーバージョン)
208     string[50]         100   trackName (Unicode UTF-16LE)
308     string[50]         100   trackConfig (Unicode UTF-16LE)
```

**注意**: 
- 文字列はUTF-16LE（Unicode）で100バイト（50文字×2バイト）
- このパケットもUDP（トランスポート層）で受信されます

#### 3. RTCarInfo（328バイト固定）

**[アプリケーション層]**

車両テレメトリデータ。CarInfoモード時に連続送信。

```
Offset  Type              Size  説明
------  ----              ----  ----
0       string[2]         4     identifier ("AC" = ASCII)
4       uint32            4     size (構造体サイズ = 328)
8       float32           4     speed_Kmh (速度 km/h)
12      float32           4     speed_Mph (速度 mph)
16      float32           4     speed_Ms (速度 m/s)
20      uint8             1     isAbsEnabled (ABS有効)
21      uint8             1     isAbsInAction (ABS作動)
22      uint8             1     isTcInAction (トラクションコントロール作動)
23      uint8             1     isTcEnabled (トラクションコントロール有効)
24      uint8             1     isInPit (ピット内フラグ)
25      uint8             1     isEngineLimiterOn (エンジンリミッター)
28      float32           4     accG_vertical (垂直G)
32      float32           4     accG_horizontal (横G)
36      float32           4     accG_frontal (前後G)
40      uint32            4     lapTime (現在のラップタイム ms)
44      uint32            4     lastLap (前ラップタイム ms)
48      uint32            4     bestLap (ベストラップ ms)
52      uint32            4     lapCount (ラップ数)
56      float32           4     gas (スロットル 0-1)
60      float32           4     brake (ブレーキ 0-1)
64      float32           4     clutch (クラッチ 0-1)
68      float32           4     engineRPM (エンジン回転数)
72      float32           4     steer (ハンドル角 -1 to 1)
76      uint32            4     gear (ギア 0=R, 1=N, 2+=前進)
80      float32           4     cgHeight (重心高さ)
84      float32[4]        16    wheelAngularSpeed (ホイール回転速度 各輪)
100     float32[4]        16    slipAngle (スリップ角)
116     float32[4]        16    slipAngle_ContactPatch (接地面スリップ角)
132     float32[4]        16    slipRatio (スリップレート)
148     float32[4]        16    tyreSlip (タイヤスリップ)
164     float32[4]        16    ndSlip (ノーマライズドスリップ)
180     float32[4]        16    load (タイヤ荷重)
196     float32[4]        16    Dy (横力)
212     float32[4]        16    Mz (自動復帰モーメント)
228     float32[4]        16    tyreDirtyLevel (タイヤダーティレベル)
244     float32[4]        16    camberRAD (キャンバー角 ラジアン)
260     float32[4]        16    tyreRadius (タイヤ半径)
276     float32[4]        16    tyreLoadedRadius (荷重時タイヤ半径)
292     float32[4]        16    suspensionHeight (サスペンション高)
308     float32           4     carPositionNormalized (トラック上の正規化位置)
312     float32           4     carSlope (車体傾斜角)
316     float32[3]        12    carCoordinates (3D座標)
```

#### 4. RTLap（212バイト以上）

**[アプリケーション層]** ラップタイムデータ。LapInfoモード時に各ラップ完了時に送信。

```
Offset  Type        Size  説明
------  ----        ----  ----
0       uint32      4     carIdentifierNumber (車両識別番号)
4       uint32      4     lap (ラップ番号)
8       string[50]  100   driverName (Unicode UTF-16LE)
108     string[50]  100   carName (Unicode UTF-16LE)
208     uint32      4     time (ラップタイム ms)
```

**注意**: このパケットもUDP（トランスポート層）で受信されます

---

## Dart/Flutter実装

### 1. データ構造定義

```dart
import 'dart:typed_data';

/// Assetto Corsaテレメトリパーサー
class ACConverter {
  /// ハンドシェイク構造体
  static class Handshaker {
    static const int OPERATION_CONNECT = 0;
    static const int OPERATION_CAR_INFO = 1;
    static const int OPERATION_LAP_INFO = 2;
    static const int OPERATION_DISCONNECT = 3;
    
    final int identifier;
    final int version;
    final int operationId;
    
    Handshaker(
      this.operationId, {
      this.identifier = 1,
      this.version = 1,
    });
    
    /// 構造体をバイト列に変換
    Uint8List toBytes() {
      final buffer = BytesBuilder();
      _writeUint32(buffer, identifier);
      _writeUint32(buffer, version);
      _writeUint32(buffer, operationId);
      return buffer.toBytes();
    }
  }
  
  /// ハンドシェイク応答
  static class HandshakerResponse {
    String carName;
    String driverName;
    int identifier;
    int version;
    String trackName;
    String trackConfig;
    
    HandshakerResponse({
      this.carName = '',
      this.driverName = '',
      this.identifier = 0,
      this.version = 0,
      this.trackName = '',
      this.trackConfig = '',
    });
    
    /// バイト列から構造体を生成
    factory HandshakerResponse.fromBytes(Uint8List bytes) {
      if (bytes.length < 408) {
        throw Exception('Invalid handshaker response packet size');
      }
      
      return HandshakerResponse(
        carName: _readUnicodeString(bytes, 0, 50),
        driverName: _readUnicodeString(bytes, 100, 50),
        identifier: _readUint32(bytes, 200),
        version: _readUint32(bytes, 204),
        trackName: _readUnicodeString(bytes, 208, 50),
        trackConfig: _readUnicodeString(bytes, 308, 50),
      );
    }
    
    @override
    String toString() => 'HandshakerResponse('
        'car: $carName, driver: $driverName, '
        'track: $trackName($trackConfig))';
  }
  
  /// 車両テレメトリデータ
  static class RTCarInfo {
    String identifier;
    int size;
    double speedKmh;
    double speedMph;
    double speedMs;
    bool isAbsEnabled;
    bool isAbsInAction;
    bool isTcInAction;
    bool isTcEnabled;
    bool isInPit;
    bool isEngineLimiterOn;
    double accG_vertical;
    double accG_horizontal;
    double accG_frontal;
    int lapTime;
    int lastLap;
    int bestLap;
    int lapCount;
    double gas;
    double brake;
    double clutch;
    double engineRPM;
    double steer;
    int gear;
    double cgHeight;
    List<double> wheelAngularSpeed; // [4]
    List<double> slipAngle; // [4]
    List<double> slipAngle_ContactPatch; // [4]
    List<double> slipRatio; // [4]
    List<double> tyreSlip; // [4]
    List<double> ndSlip; // [4]
    List<double> load; // [4]
    List<double> Dy; // [4]
    List<double> Mz; // [4]
    List<double> tyreDirtyLevel; // [4]
    List<double> camberRAD; // [4]
    List<double> tyreRadius; // [4]
    List<double> tyreLoadedRadius; // [4]
    List<double> suspensionHeight; // [4]
    double carPositionNormalized;
    double carSlope;
    List<double> carCoordinates; // [3]
    
    RTCarInfo({
      this.identifier = '',
      this.size = 0,
      this.speedKmh = 0,
      this.speedMph = 0,
      this.speedMs = 0,
      this.isAbsEnabled = false,
      this.isAbsInAction = false,
      this.isTcInAction = false,
      this.isTcEnabled = false,
      this.isInPit = false,
      this.isEngineLimiterOn = false,
      this.accG_vertical = 0,
      this.accG_horizontal = 0,
      this.accG_frontal = 0,
      this.lapTime = 0,
      this.lastLap = 0,
      this.bestLap = 0,
      this.lapCount = 0,
      this.gas = 0,
      this.brake = 0,
      this.clutch = 0,
      this.engineRPM = 0,
      this.steer = 0,
      this.gear = 0,
      this.cgHeight = 0,
      List<double>? wheelAngularSpeed,
      List<double>? slipAngle,
      List<double>? slipAngle_ContactPatch,
      List<double>? slipRatio,
      List<double>? tyreSlip,
      List<double>? ndSlip,
      List<double>? load,
      List<double>? Dy,
      List<double>? Mz,
      List<double>? tyreDirtyLevel,
      List<double>? camberRAD,
      List<double>? tyreRadius,
      List<double>? tyreLoadedRadius,
      List<double>? suspensionHeight,
      this.carPositionNormalized = 0,
      this.carSlope = 0,
      List<double>? carCoordinates,
    })  : wheelAngularSpeed = wheelAngularSpeed ?? [0, 0, 0, 0],
          slipAngle = slipAngle ?? [0, 0, 0, 0],
          slipAngle_ContactPatch = slipAngle_ContactPatch ?? [0, 0, 0, 0],
          slipRatio = slipRatio ?? [0, 0, 0, 0],
          tyreSlip = tyreSlip ?? [0, 0, 0, 0],
          ndSlip = ndSlip ?? [0, 0, 0, 0],
          load = load ?? [0, 0, 0, 0],
          Dy = Dy ?? [0, 0, 0, 0],
          Mz = Mz ?? [0, 0, 0, 0],
          tyreDirtyLevel = tyreDirtyLevel ?? [0, 0, 0, 0],
          camberRAD = camberRAD ?? [0, 0, 0, 0],
          tyreRadius = tyreRadius ?? [0, 0, 0, 0],
          tyreLoadedRadius = tyreLoadedRadius ?? [0, 0, 0, 0],
          suspensionHeight = suspensionHeight ?? [0, 0, 0, 0],
          carCoordinates = carCoordinates ?? [0, 0, 0];
    
    /// バイト列から構造体を生成
    factory RTCarInfo.fromBytes(Uint8List bytes) {
      if (bytes.length < 328) {
        throw Exception('Invalid RTCarInfo packet size: ${bytes.length}');
      }
      
      return RTCarInfo(
        identifier: _readString(bytes, 0, 2),
        size: _readUint32(bytes, 4),
        speedKmh: _readFloat32(bytes, 8),
        speedMph: _readFloat32(bytes, 12),
        speedMs: _readFloat32(bytes, 16),
        isAbsEnabled: _readBool(bytes, 20),
        isAbsInAction: _readBool(bytes, 21),
        isTcInAction: _readBool(bytes, 22),
        isTcEnabled: _readBool(bytes, 23),
        isInPit: _readBool(bytes, 24),
        isEngineLimiterOn: _readBool(bytes, 25),
        accG_vertical: _readFloat32(bytes, 28),
        accG_horizontal: _readFloat32(bytes, 32),
        accG_frontal: _readFloat32(bytes, 36),
        lapTime: _readUint32(bytes, 40),
        lastLap: _readUint32(bytes, 44),
        bestLap: _readUint32(bytes, 48),
        lapCount: _readUint32(bytes, 52),
        gas: _readFloat32(bytes, 56),
        brake: _readFloat32(bytes, 60),
        clutch: _readFloat32(bytes, 64),
        engineRPM: _readFloat32(bytes, 68),
        steer: _readFloat32(bytes, 72),
        gear: _readUint32(bytes, 76),
        cgHeight: _readFloat32(bytes, 80),
        wheelAngularSpeed: _readFloat32Array(bytes, 84, 4),
        slipAngle: _readFloat32Array(bytes, 100, 4),
        slipAngle_ContactPatch: _readFloat32Array(bytes, 116, 4),
        slipRatio: _readFloat32Array(bytes, 132, 4),
        tyreSlip: _readFloat32Array(bytes, 148, 4),
        ndSlip: _readFloat32Array(bytes, 164, 4),
        load: _readFloat32Array(bytes, 180, 4),
        Dy: _readFloat32Array(bytes, 196, 4),
        Mz: _readFloat32Array(bytes, 212, 4),
        tyreDirtyLevel: _readFloat32Array(bytes, 228, 4),
        camberRAD: _readFloat32Array(bytes, 244, 4),
        tyreRadius: _readFloat32Array(bytes, 260, 4),
        tyreLoadedRadius: _readFloat32Array(bytes, 276, 4),
        suspensionHeight: _readFloat32Array(bytes, 292, 4),
        carPositionNormalized: _readFloat32(bytes, 308),
        carSlope: _readFloat32(bytes, 312),
        carCoordinates: _readFloat32Array(bytes, 316, 3),
      );
    }
    
    @override
    String toString() => 'RTCarInfo('
        'speed: ${speedKmh.toStringAsFixed(1)}km/h, '
        'rpm: ${engineRPM.toStringAsFixed(0)}, '
        'gear: $gear, '
        'lapTime: ${(lapTime / 1000).toStringAsFixed(2)}s)';
  }
  
  /// ラップタイムデータ
  static class RTLap {
    int carIdentifierNumber;
    int lap;
    String driverName;
    String carName;
    int time;
    
    RTLap({
      this.carIdentifierNumber = 0,
      this.lap = 0,
      this.driverName = '',
      this.carName = '',
      this.time = 0,
    });
    
    /// バイト列から構造体を生成
    factory RTLap.fromBytes(Uint8List bytes) {
      if (bytes.length < 212) {
        throw Exception('Invalid RTLap packet size: ${bytes.length}');
      }
      
      return RTLap(
        carIdentifierNumber: _readUint32(bytes, 0),
        lap: _readUint32(bytes, 4),
        driverName: _readUnicodeString(bytes, 8, 50),
        carName: _readUnicodeString(bytes, 108, 50),
        time: _readUint32(bytes, 208),
      );
    }
    
    @override
    String toString() => 'RTLap('
        'lap: $lap, '
        'driver: $driverName, '
        'car: $carName, '
        'time: ${(time / 1000).toStringAsFixed(2)}s)';
  }
  
  // ==================== ヘルパー関数 ====================
  
  /// UTF-16LE文字列を読み込む
  static String _readUnicodeString(Uint8List bytes, int offset, int maxLen) {
    final codeUnits = <int>[];
    for (int i = 0; i < maxLen * 2; i += 2) {
      if (offset + i + 1 >= bytes.length) break;
      int byte1 = bytes[offset + i];
      int byte2 = bytes[offset + i + 1];
      int codeUnit = byte1 | (byte2 << 8);
      if (codeUnit == 0) break;
      codeUnits.add(codeUnit);
    }
    return String.fromCharCodes(codeUnits);
  }
  
  /// ASCII文字列を読み込む
  static String _readString(Uint8List bytes, int offset, int maxLen) {
    final codeUnits = <int>[];
    for (int i = 0; i < maxLen; i++) {
      if (offset + i >= bytes.length) break;
      int byte = bytes[offset + i];
      if (byte == 0) break;
      codeUnits.add(byte);
    }
    return String.fromCharCodes(codeUnits);
  }
  
  /// uint32を読み込む (Little Endian)
  static int _readUint32(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length) return 0;
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }
  
  /// float32を読み込む (Little Endian)
  static double _readFloat32(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length) return 0;
    final data = ByteData.view(bytes.buffer, offset, 4);
    return data.getFloat32(0, Endian.little);
  }
  
  /// bool値を読み込む
  static bool _readBool(Uint8List bytes, int offset) {
    if (offset >= bytes.length) return false;
    return bytes[offset] != 0;
  }
  
  /// float32配列を読み込む
  static List<double> _readFloat32Array(Uint8List bytes, int offset, int count) {
    final result = <double>[];
    for (int i = 0; i < count; i++) {
      result.add(_readFloat32(bytes, offset + i * 4));
    }
    return result;
  }
  
  /// uint32を書き込む (Little Endian)
  static void _writeUint32(BytesBuilder buffer, int value) {
    buffer.addByte(value & 0xFF);
    buffer.addByte((value >> 8) & 0xFF);
    buffer.addByte((value >> 16) & 0xFF);
    buffer.addByte((value >> 24) & 0xFF);
  }
}
```

### 2. UDP接続クラス

```dart
import 'dart:io';
import 'dart:typed_data';

/// Assetto CorsaのUDPクライアント
class ACUdpClient {
  static const int AC_PORT = 9996;
  
  final String ipAddress;
  final Function(HandshakerResponse) onSessionInfo;
  final Function(RTCarInfo) onCarInfoUpdate;
  final Function(RTLap) onLapUpdate;
  final Function(String) onError;
  
  late RawDatagramSocket _socket;
  bool _isConnected = false;
  bool _handshakeCompleted = false;
  
  ACUdpClient({
    required this.ipAddress,
    required this.onSessionInfo,
    required this.onCarInfoUpdate,
    required this.onLapUpdate,
    required this.onError,
  });
  
  bool get isConnected => _isConnected;
  
  /// サーバーに接続
  Future<void> connect() async {
    try {
      // ソケット作成
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AC_PORT,
      );
      
      // リッスン開始
      _socket.listen((event) {
        if (event == RawSocketEvent.read) {
          _handleData();
        }
      });
      
      // ハンドシェイク送信（Connect）
      _sendHandshake(ACConverter.Handshaker.OPERATION_CONNECT);
      _isConnected = true;
    } catch (e) {
      onError('接続エラー: $e');
      _isConnected = false;
    }
  }
  
  /// 切断
  void disconnect() {
    if (_isConnected) {
      _sendHandshake(ACConverter.Handshaker.OPERATION_DISCONNECT);
      _socket.close();
      _isConnected = false;
      _handshakeCompleted = false;
    }
  }
  
  /// テレメトリ購読開始
  void subscribeCarInfo() {
    _sendHandshake(ACConverter.Handshaker.OPERATION_CAR_INFO);
  }
  
  /// ラップタイム購読開始
  void subscribeLapInfo() {
    _sendHandshake(ACConverter.Handshaker.OPERATION_LAP_INFO);
  }
  
  /// ハンドシェイク送信
  void _sendHandshake(int operationId) {
    try {
      final handshaker = ACConverter.Handshaker(operationId);
      final bytes = handshaker.toBytes();
      _socket.send(bytes, InternetAddress(ipAddress), AC_PORT);
    } catch (e) {
      onError('ハンドシェイク送信エラー: $e');
    }
  }
  
  /// データ受信処理
  void _handleData() {
    try {
      final datagram = _socket.receive();
      if (datagram == null) return;
      
      final bytes = datagram.data;
      
      if (!_handshakeCompleted) {
        // ハンドシェイク応答の処理
        try {
          final response = ACConverter.HandshakerResponse.fromBytes(bytes);
          onSessionInfo(response);
          _handshakeCompleted = true;
          
          // テレメトリ購読開始
          subscribeCarInfo();
        } catch (e) {
          onError('ハンドシェイク応答パースエラー: $e');
        }
      } else {
        // テレメトリデータの処理
        try {
          if (bytes.length == 328) {
            // RTCarInfo
            final carInfo = ACConverter.RTCarInfo.fromBytes(bytes);
            onCarInfoUpdate(carInfo);
          } else if (bytes.length >= 212) {
            // RTLap
            final lapInfo = ACConverter.RTLap.fromBytes(bytes);
            onLapUpdate(lapInfo);
          }
        } catch (e) {
          onError('テレメトリパースエラー: $e');
        }
      }
    } catch (e) {
      onError('データ受信エラー: $e');
    }
  }
}
```

### 3. 使用例

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ACUdpClient _acClient;
  String _ipAddress = '192.168.1.100'; // デフォルトIP
  String _sessionInfo = '接続待機中...';
  String _telemetry = 'テレメトリ受信待機中...';
  
  @override
  void initState() {
    super.initState();
    _initializeClient();
  }
  
  void _initializeClient() {
    _acClient = ACUdpClient(
      ipAddress: _ipAddress,
      onSessionInfo: (response) {
        setState(() {
          _sessionInfo = 'ドライバー: ${response.driverName}\n'
              '車: ${response.carName}\n'
              'トラック: ${response.trackName}(${response.trackConfig})';
        });
      },
      onCarInfoUpdate: (carInfo) {
        setState(() {
          _telemetry = 'テレメトリ:\n'
              '速度: ${carInfo.speedKmh.toStringAsFixed(1)}km/h\n'
              'RPM: ${carInfo.engineRPM.toStringAsFixed(0)}\n'
              'ギア: ${carInfo.gear}\n'
              'ラップ: ${(carInfo.lapTime / 1000).toStringAsFixed(2)}s\n'
              'スロットル: ${(carInfo.gas * 100).toStringAsFixed(1)}%\n'
              'ブレーキ: ${(carInfo.brake * 100).toStringAsFixed(1)}%';
        });
      },
      onLapUpdate: (lapInfo) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lapInfo.toString())),
        );
      },
      onError: (error) {
        setState(() {
          _sessionInfo = 'エラー: $error';
        });
      },
    );
  }
  
  @override
  void dispose() {
    _acClient.disconnect();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AC Telemetry Dashboard',
      home: Scaffold(
        appBar: AppBar(title: const Text('Assetto Corsa Dashboard')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // IP入力
              TextField(
                decoration: const InputDecoration(
                  labelText: 'PCのIPアドレス',
                  hintText: '例: 192.168.1.100',
                ),
                onChanged: (value) {
                  _ipAddress = value;
                },
              ),
              const SizedBox(height: 16),
              
              // 接続ボタン
              ElevatedButton(
                onPressed: _acClient.isConnected
                    ? () {
                        _acClient.disconnect();
                        setState(() {});
                      }
                    : () async {
                        _initializeClient();
                        await _acClient.connect();
                        setState(() {});
                      },
                child: Text(_acClient.isConnected ? '切断' : '接続'),
              ),
              const SizedBox(height: 16),
              
              // セッション情報
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_sessionInfo),
              ),
              const SizedBox(height: 16),
              
              // テレメトリ表示
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_telemetry),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## 実装上での層の関係

### **開発者が意識すべき階層**

Flutterアプリ開発時に、何をしているのかを理解することが重要です：

```
【アプリケーション層】← 開発者が実装する部分
┌─────────────────────────────────────────┐
│ 1. Handshaker.toBytes()                 │ ← バイト列へ変換
│ 2. Handshaker データをパース            │ ← 受信データを解析
│ 3. RTCarInfo.fromBytes()                │ ← バイト列をモデルに
│ 4. ビジネスロジック（スピードメータ等）│ ← UIで表示
└─────────────────────────────────────────┘
          ↓ _socket.send() / .receive()
【トランスポート層】← OSが自動的に処理
┌─────────────────────────────────────────┐
│ 1. UDPでパケット送信                    │
│ 2. ネットワークを通じて伝送             │
│ 3. UDPでパケット受信                    │
└─────────────────────────────────────────┘
```

### **実装のポイント**

```dart
// ✅ これはアプリケーション層の処理
final handshaker = Handshaker(OPERATION_CONNECT);
final bytes = handshaker.toBytes();  // バイト列に変換

// ✅ これはトランスポート層（UDP）で処理される
_socket.send(bytes, InternetAddress(ipAddress), AC_PORT);
//    ↓
// OSが自動的にUDPで送信

// ✅ これはトランスポート層で受信
final datagram = _socket.receive();  // UDPが自動処理

// ✅ これはアプリケーション層で処理
final response = HandshakerResponse.fromBytes(datagram.data);
```

### **トラブルシューティングのポイント**

| 問題 | 原因が多い層 | 確認方法 |
|------|---|---|
| **接続できない** | トランスポート層（UDP） | ファイアウォール、ポート、ネットワーク |
| **パースエラー** | アプリケーション層 | オフセット、バイト順序、文字エンコード |
| **データが来ない** | 両層 | まずネットワーク確認、次にハンドシェイク確認 |
| **文字化け** | アプリケーション層 | UTF-16LE デコーディング確認 |

---

## トラブルシューティング

### 接続できない

1. **PCとスマートフォンが同じネットワーク上か確認**
   - Wi-Fi設定を確認
   - ファイアウォール設定確認

2. **正しいIPアドレスを使用しているか**
   ```bash
   # Windows PC上で確認
   ipconfig
   ```

3. **ポート9996がブロックされていないか**
   ```bash
   # Windows: ポート確認
   netstat -an | findstr 9996
   ```

### ハンドシェイク応答が来ない

- Assetto Corsaが起動しているか確認
- ゲーム内設定でリモートテレメトリが有効か確認

### データが受信できない

- パケットサイズを確認（RTCarInfo = 328バイト）
- エンディアン（Little Endian）が正しいか確認
- オフセット計算が正しいか確認

### 文字列が文字化けする

- Unicode (UTF-16LE) デコーディングが正しいか確認
- 文字列長の計算（50文字 = 100バイト）を確認

---

## まとめ

このガイドに従うことで、Flutterアプリケーションから確実にAssetto Corsaのテレメトリデータを取得できます。

### **層による役割の整理**

| 層 | 技術 | 実装元 | 役割 |
|---|---|---|---|
| **アプリケーション層** | Assetto Corsaハンドシェイク・プロトコル | 開発者が実装 | 接続確認、セッション情報、モード選択 |
| **トランスポート層** | UDP | OSが実装 | データをパケットで送受信 |

### **重要ポイント**

**トランスポート層（UDP）:**
- ポート番号: **9996**
- 接続確立なし（OSレベル）
- 低レイテンシー、軽量

**アプリケーション層（Assetto Corsa独自プロトコル）:**
- ハンドシェイク: **Connect → Response → Mode Selection**
- パケット仕様
  - Handshaker: 12バイト
  - HandshakerResponse: 408バイト
  - RTCarInfo: 328バイト（テレメトリ）
  - RTLap: 212バイト以上（ラップタイム）
- 文字列: **UTF-16LE (Unicode)**
- 数値: **Little Endian**

### **開発時の意識**

```dart
// UDPは「物質的な送受信手段」
_socket.send(bytes, ip, 9996);  // ← OSが処理

// ハンドシェイクは「通信ルール」
Handshaker(OPERATION_CONNECT)   // ← 開発者が実装
```

Assetto Corsaは**UDPの速度**と**ハンドシェイク信頼性**の両立を実現しています。
