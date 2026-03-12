# Assetto Corsa Telemetry Data Implementation Guide

## Overview

Assetto Corsa has a built-in UDP server that allows external applications (such as smartphone dashboard apps) to retrieve real-time telemetry data. This document explains how to implement this in a Flutter application using Dart.

---

## Setup Requirements

### Hardware / Environment
- **PC running Assetto Corsa** (Windows/Mac/Linux)
- **Smartphone** (on the same Wi-Fi network)
- **Transport layer**: UDP port **9996**

### Prerequisites
- PC and smartphone must be on the same network
- Know the PC's local IP address (e.g., `192.168.1.100`)

---

## Communication Protocol Layer Structure

### **Role of Each Layer**

```
Application Layer
┌─────────────────────────────────────────┐
│ Assetto Corsa proprietary protocol      │
│  - Handshake (connection verification)  │
│  - Session information exchange         │
│  - Mode selection                       │
│  - Telemetry data definitions           │
└─────────────────────────────────────────┘
          ↓ (sent/received via UDP)
Transport Layer
┌─────────────────────────────────────────┐
│ UDP                                     │
│  - No connection establishment          │
│  - No acknowledgment                   │
│  - Low latency (supports 120Hz)         │
│  - Lightweight (ideal for games)        │
└─────────────────────────────────────────┘
          ↓
Network Layer
┌─────────────────────────────────────────┐
│ IP (IPv4)                               │
│  - Routing, address management          │
└─────────────────────────────────────────┘
```

### **Key Distinction**

| Layer | Technology | Role | Implemented by |
|---|---|---|---|
| **Transport** | **UDP** | Sends and receives data | OS |
| **Application** | **Handshake protocol** | Connection verification, mode selection | Assetto Corsa |

### **Communication Flow**

```
[1] Client → Server: Send handshake (Connect)
    ↓ (sent via UDP)
[2] Server → Client: Handshake response + session info
    ↓ (received via UDP)
[3] Client → Server: Send handshake (mode selection)
    ↓ (sent via UDP)
[4] Server → Client: RTCarInfo or RTLap (continuous at 120Hz)
    ↓ (continuously received via UDP)
```

### **Why This Design?**

**Why UDP:**
- ✅ Low latency (faster than TCP)
- ✅ Lightweight (game-friendly)
- ✅ Supports high-frequency sending at 120Hz
- ❌ However, no connection confirmation

**Supplemented by handshake (application layer):**
- Verifies "is the connection actually alive" at the application layer
- Exchanges session info (driver name, car name, etc.)
- Selects telemetry mode (car telemetry or lap time)

---

## Protocol Specification

### Application Layer Packet Specification

The packet structures described in this section are the **application layer protocol defined by Assetto Corsa**. All of this data is **sent and received via UDP**.

#### 1. Handshaker (12 bytes)

**[Application Layer]** Sent by the client to the server. Used for initialization and communication mode selection.

```
Offset  Type    Size  Description
------  ----    ----  -----------
0       uint32  4     identifier (device ID, usually 1)
4       uint32  4     version (protocol version, usually 1)
8       uint32  4     operationId (0=Connect, 1=CarInfo, 2=LapInfo, 3=Disconnect)
```

**This packet is sent via UDP (transport layer)**

#### 2. HandshakerResponse (408 bytes fixed)

**[Application Layer]** Response from the server. Contains session information.

```
Offset  Type               Size  Description
------  ----               ----  -----------
0       string[50]         100   carName (Unicode UTF-16LE)
100     string[50]         100   driverName (Unicode UTF-16LE)
200     uint32             4     identifier (status code, 4242)
204     uint32             4     version (server version)
208     string[50]         100   trackName (Unicode UTF-16LE)
308     string[50]         100   trackConfig (Unicode UTF-16LE)
```

**Notes**:
- Strings are UTF-16LE (Unicode), 100 bytes (50 characters × 2 bytes)
- This packet is also received via UDP (transport layer)

#### 3. RTCarInfo (328 bytes fixed)

**[Application Layer]**

Vehicle telemetry data. Sent continuously in CarInfo mode.

```
Offset  Type              Size  Description
------  ----              ----  -----------
0       string[2]         4     identifier ("AC" = ASCII)
4       uint32            4     size (struct size = 328)
8       float32           4     speed_Kmh (speed in km/h)
12      float32           4     speed_Mph (speed in mph)
16      float32           4     speed_Ms (speed in m/s)
20      uint8             1     isAbsEnabled (ABS enabled)
21      uint8             1     isAbsInAction (ABS active)
22      uint8             1     isTcInAction (traction control active)
23      uint8             1     isTcEnabled (traction control enabled)
24      uint8             1     isInPit (in pit flag)
25      uint8             1     isEngineLimiterOn (engine limiter)
28      float32           4     accG_vertical (vertical G-force)
32      float32           4     accG_horizontal (lateral G-force)
36      float32           4     accG_frontal (longitudinal G-force)
40      uint32            4     lapTime (current lap time in ms)
44      uint32            4     lastLap (previous lap time in ms)
48      uint32            4     bestLap (best lap time in ms)
52      uint32            4     lapCount (number of laps)
56      float32           4     gas (throttle 0-1)
60      float32           4     brake (brake 0-1)
64      float32           4     clutch (clutch 0-1)
68      float32           4     engineRPM (engine RPM)
72      float32           4     steer (steering angle -1 to 1)
76      uint32            4     gear (gear: 0=R, 1=N, 2+=forward)
80      float32           4     cgHeight (center of gravity height)
84      float32[4]        16    wheelAngularSpeed (wheel rotation speed, per wheel)
100     float32[4]        16    slipAngle (slip angle)
116     float32[4]        16    slipAngle_ContactPatch (contact patch slip angle)
132     float32[4]        16    slipRatio (slip ratio)
148     float32[4]        16    tyreSlip (tyre slip)
164     float32[4]        16    ndSlip (normalized slip)
180     float32[4]        16    load (tyre load)
196     float32[4]        16    Dy (lateral force)
212     float32[4]        16    Mz (self-aligning moment)
228     float32[4]        16    tyreDirtyLevel (tyre dirt level)
244     float32[4]        16    camberRAD (camber angle in radians)
260     float32[4]        16    tyreRadius (tyre radius)
276     float32[4]        16    tyreLoadedRadius (loaded tyre radius)
292     float32[4]        16    suspensionHeight (suspension height)
308     float32           4     carPositionNormalized (normalized position on track)
312     float32           4     carSlope (vehicle pitch angle)
316     float32[3]        12    carCoordinates (3D coordinates)
```

#### 4. RTLap (212+ bytes)

**[Application Layer]** Lap time data. Sent at each lap completion in LapInfo mode.

```
Offset  Type        Size  Description
------  ----        ----  -----------
0       uint32      4     carIdentifierNumber (vehicle identifier)
4       uint32      4     lap (lap number)
8       string[50]  100   driverName (Unicode UTF-16LE)
108     string[50]  100   carName (Unicode UTF-16LE)
208     uint32      4     time (lap time in ms)
```

**Note**: This packet is also received via UDP (transport layer)

---

## Dart/Flutter Implementation

### 1. Data Structure Definitions

```dart
import 'dart:typed_data';

/// Assetto Corsa telemetry parser
class ACConverter {
  /// Handshake struct
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

    /// Convert struct to byte array
    Uint8List toBytes() {
      final buffer = BytesBuilder();
      _writeUint32(buffer, identifier);
      _writeUint32(buffer, version);
      _writeUint32(buffer, operationId);
      return buffer.toBytes();
    }
  }

  /// Handshake response
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

    /// Create struct from byte array
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

  /// Vehicle telemetry data
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

    /// Create struct from byte array
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

  /// Lap time data
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

    /// Create struct from byte array
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

  // ==================== Helper Functions ====================

  /// Read UTF-16LE string
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

  /// Read ASCII string
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

  /// Read uint32 (Little Endian)
  static int _readUint32(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length) return 0;
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  /// Read float32 (Little Endian)
  static double _readFloat32(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length) return 0;
    final data = ByteData.view(bytes.buffer, offset, 4);
    return data.getFloat32(0, Endian.little);
  }

  /// Read bool value
  static bool _readBool(Uint8List bytes, int offset) {
    if (offset >= bytes.length) return false;
    return bytes[offset] != 0;
  }

  /// Read float32 array
  static List<double> _readFloat32Array(Uint8List bytes, int offset, int count) {
    final result = <double>[];
    for (int i = 0; i < count; i++) {
      result.add(_readFloat32(bytes, offset + i * 4));
    }
    return result;
  }

  /// Write uint32 (Little Endian)
  static void _writeUint32(BytesBuilder buffer, int value) {
    buffer.addByte(value & 0xFF);
    buffer.addByte((value >> 8) & 0xFF);
    buffer.addByte((value >> 16) & 0xFF);
    buffer.addByte((value >> 24) & 0xFF);
  }
}
```

### 2. UDP Connection Class

```dart
import 'dart:io';
import 'dart:typed_data';

/// Assetto Corsa UDP client
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

  /// Connect to server
  Future<void> connect() async {
    try {
      // Create socket
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AC_PORT,
      );

      // Start listening
      _socket.listen((event) {
        if (event == RawSocketEvent.read) {
          _handleData();
        }
      });

      // Send handshake (Connect)
      _sendHandshake(ACConverter.Handshaker.OPERATION_CONNECT);
      _isConnected = true;
    } catch (e) {
      onError('Connection error: $e');
      _isConnected = false;
    }
  }

  /// Disconnect
  void disconnect() {
    if (_isConnected) {
      _sendHandshake(ACConverter.Handshaker.OPERATION_DISCONNECT);
      _socket.close();
      _isConnected = false;
      _handshakeCompleted = false;
    }
  }

  /// Start subscribing to car telemetry
  void subscribeCarInfo() {
    _sendHandshake(ACConverter.Handshaker.OPERATION_CAR_INFO);
  }

  /// Start subscribing to lap info
  void subscribeLapInfo() {
    _sendHandshake(ACConverter.Handshaker.OPERATION_LAP_INFO);
  }

  /// Send handshake
  void _sendHandshake(int operationId) {
    try {
      final handshaker = ACConverter.Handshaker(operationId);
      final bytes = handshaker.toBytes();
      _socket.send(bytes, InternetAddress(ipAddress), AC_PORT);
    } catch (e) {
      onError('Handshake send error: $e');
    }
  }

  /// Handle received data
  void _handleData() {
    try {
      final datagram = _socket.receive();
      if (datagram == null) return;

      final bytes = datagram.data;

      if (!_handshakeCompleted) {
        // Handle handshake response
        try {
          final response = ACConverter.HandshakerResponse.fromBytes(bytes);
          onSessionInfo(response);
          _handshakeCompleted = true;

          // Start telemetry subscription
          subscribeCarInfo();
        } catch (e) {
          onError('Handshake response parse error: $e');
        }
      } else {
        // Handle telemetry data
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
          onError('Telemetry parse error: $e');
        }
      }
    } catch (e) {
      onError('Data receive error: $e');
    }
  }
}
```

### 3. Usage Example

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
  String _ipAddress = '192.168.1.100'; // Default IP
  String _sessionInfo = 'Waiting for connection...';
  String _telemetry = 'Waiting for telemetry...';

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
          _sessionInfo = 'Driver: ${response.driverName}\n'
              'Car: ${response.carName}\n'
              'Track: ${response.trackName}(${response.trackConfig})';
        });
      },
      onCarInfoUpdate: (carInfo) {
        setState(() {
          _telemetry = 'Telemetry:\n'
              'Speed: ${carInfo.speedKmh.toStringAsFixed(1)}km/h\n'
              'RPM: ${carInfo.engineRPM.toStringAsFixed(0)}\n'
              'Gear: ${carInfo.gear}\n'
              'Lap: ${(carInfo.lapTime / 1000).toStringAsFixed(2)}s\n'
              'Throttle: ${(carInfo.gas * 100).toStringAsFixed(1)}%\n'
              'Brake: ${(carInfo.brake * 100).toStringAsFixed(1)}%';
        });
      },
      onLapUpdate: (lapInfo) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lapInfo.toString())),
        );
      },
      onError: (error) {
        setState(() {
          _sessionInfo = 'Error: $error';
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
              // IP input
              TextField(
                decoration: const InputDecoration(
                  labelText: 'PC IP Address',
                  hintText: 'e.g. 192.168.1.100',
                ),
                onChanged: (value) {
                  _ipAddress = value;
                },
              ),
              const SizedBox(height: 16),

              // Connect button
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
                child: Text(_acClient.isConnected ? 'Disconnect' : 'Connect'),
              ),
              const SizedBox(height: 16),

              // Session info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_sessionInfo),
              ),
              const SizedBox(height: 16),

              // Telemetry display
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

## Layer Relationships in Implementation

### **Layers the Developer Should Be Aware Of**

When developing a Flutter app, it is important to understand what each part does:

```
[Application Layer] ← Part implemented by the developer
┌─────────────────────────────────────────┐
│ 1. Handshaker.toBytes()                 │ ← Convert to byte array
│ 2. Parse Handshaker data               │ ← Analyze received data
│ 3. RTCarInfo.fromBytes()                │ ← Byte array to model
│ 4. Business logic (speedometer, etc.)  │ ← Display in UI
└─────────────────────────────────────────┘
          ↓ _socket.send() / .receive()
[Transport Layer] ← Handled automatically by the OS
┌─────────────────────────────────────────┐
│ 1. Send packets via UDP                 │
│ 2. Transmit over network               │
│ 3. Receive packets via UDP              │
└─────────────────────────────────────────┘
```

### **Implementation Key Points**

```dart
// ✅ This is application layer processing
final handshaker = Handshaker(OPERATION_CONNECT);
final bytes = handshaker.toBytes();  // Convert to byte array

// ✅ This is handled by the transport layer (UDP)
_socket.send(bytes, InternetAddress(ipAddress), AC_PORT);
//    ↓
// OS automatically sends via UDP

// ✅ This is received by the transport layer
final datagram = _socket.receive();  // UDP handles automatically

// ✅ This is processed by the application layer
final response = HandshakerResponse.fromBytes(datagram.data);
```

### **Troubleshooting by Layer**

| Problem | Most likely layer | How to check |
|---------|---|---|
| **Cannot connect** | Transport layer (UDP) | Firewall, port, network |
| **Parse error** | Application layer | Offset, byte order, character encoding |
| **No data arriving** | Both layers | Check network first, then handshake |
| **Garbled characters** | Application layer | Verify UTF-16LE decoding |

---

## Troubleshooting

### Cannot Connect

1. **Verify PC and smartphone are on the same network**
   - Check Wi-Fi settings
   - Check firewall settings

2. **Are you using the correct IP address?**
   ```bash
   # Check on Windows PC
   ipconfig
   ```

3. **Is port 9996 blocked?**
   ```bash
   # Windows: check port
   netstat -an | findstr 9996
   ```

### No Handshake Response

- Verify Assetto Corsa is running
- Verify remote telemetry is enabled in game settings

### Cannot Receive Data

- Check packet size (RTCarInfo = 328 bytes)
- Verify endianness (Little Endian) is correct
- Verify offset calculations are correct

### Garbled Strings

- Verify Unicode (UTF-16LE) decoding is correct
- Verify string length calculation (50 chars = 100 bytes)


---

## Summary

Following this guide, you can reliably retrieve telemetry data from Assetto Corsa in a Flutter application.

### **Layer Roles Summary**

| Layer | Technology | Implemented by | Role |
|---|---|---|---|
| **Application Layer** | Assetto Corsa handshake protocol | Developer | Connection verification, session info, mode selection |
| **Transport Layer** | UDP | OS | Send and receive data as packets |

### **Key Points**

**Transport Layer (UDP):**
- Port number: **9996**
- No connection establishment (OS level)
- Low latency, lightweight

**Application Layer (Assetto Corsa proprietary protocol):**
- Handshake: **Connect → Response → Mode Selection**
- Packet specifications:
  - Handshaker: 12 bytes
  - HandshakerResponse: 408 bytes
  - RTCarInfo: 328 bytes (telemetry)
  - RTLap: 212+ bytes (lap time)
- Strings: **UTF-16LE (Unicode)**
- Numbers: **Little Endian**

### **Mindset During Development**

```dart
// UDP is the "physical means of sending/receiving"
_socket.send(bytes, ip, 9996);  // ← OS handles this

// Handshake is the "communication rules"
Handshaker(OPERATION_CONNECT)   // ← Developer implements this
```

Assetto Corsa achieves both **UDP speed** and **handshake reliability**.
