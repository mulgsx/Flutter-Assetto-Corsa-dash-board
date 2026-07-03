import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ac_converter.dart';

const String _prefIpKey = 'ac_pc_ip';

/// Owns the UDP connection to Assetto Corsa: handshake, socket lifecycle,
/// packet parsing, and the reactive state derived from it (including the IP
/// input itself). Exposes only [ValueNotifier]s, a [TextEditingController],
/// and plain methods, so widgets can watch the service directly without a
/// parent threading individual values down.
class TelemetryService {
  static const String defaultIp = '192.168.0.0';
  static const int acPort = 9996;

  final ValueNotifier<RTCarInfo> carInfoNotifier = ValueNotifier<RTCarInfo>(
    const RTCarInfo(),
  );
  final ValueNotifier<int> packetCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<double> packetRateNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<String> statusNotifier = ValueNotifier<String>(
    "IDLE: Press 'Start Receiving' to connect.",
  );
  final ValueNotifier<String> currentIpNotifier = ValueNotifier<String>(
    defaultIp,
  );
  final ValueNotifier<bool> isListeningNotifier = ValueNotifier<bool>(false);
  final TextEditingController ipController = TextEditingController(
    text: defaultIp,
  );

  int _rawPacketCount = 0;
  int _lastRateSampleCount = 0;
  Timer? _displayUpdateTimer;
  Timer? _connectRetryTimer;
  String _targetIp = defaultIp;
  bool _handshakeCompleted = false;
  RawDatagramSocket? _socket;

  static bool isValidIp(String ip) => InternetAddress.tryParse(ip) != null;

  Future<void> loadSavedIp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString(_prefIpKey) ?? defaultIp;
      ipController.text = savedIp;
      currentIpNotifier.value = savedIp;
    } catch (e) {
      debugPrint('[ERROR] Failed to load IP: $e');
    }
  }

  Future<void> _saveIp(String ip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefIpKey, ip);
    } catch (e) {
      debugPrint('[ERROR] Failed to save IP: $e');
    }
  }

  /// Validates and connects to [ip]. Returns false if [ip] is not a valid
  /// address, without touching the current connection.
  Future<bool> startListening(String ip) async {
    if (!isValidIp(ip)) return false;
    _targetIp = ip;
    unawaited(_saveIp(ip));

    if (isListeningNotifier.value || _socket != null) {
      _stopAll();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    currentIpNotifier.value = _targetIp;
    statusNotifier.value = 'Connecting to $_targetIp:$acPort...';

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, acPort);
    } catch (e) {
      statusNotifier.value = 'ERROR: Failed to bind port $acPort ($e)';
      return true;
    }

    _socket!.listen(
      (event) {
        if (event == RawSocketEvent.read) {
          _handleData();
        }
      },
      onError: (error) {
        statusNotifier.value = 'ERROR: Socket error ($error)';
        stopListening();
      },
      onDone: () {
        statusNotifier.value = 'Connection Closed.';
        stopListening();
      },
    );

    _handshakeCompleted = false;
    _rawPacketCount = 0;
    _lastRateSampleCount = 0;
    packetCountNotifier.value = 0;
    packetRateNotifier.value = 0.0;
    isListeningNotifier.value = true;

    // UIを5Hzで更新（120Hzのパケットを全てUI更新すると重いため）。
    // 同じ間隔で直近の受信レート（Hz）も計算する。
    _displayUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (
      _,
    ) {
      if (packetCountNotifier.value != _rawPacketCount) {
        packetCountNotifier.value = _rawPacketCount;
      }
      final delta = _rawPacketCount - _lastRateSampleCount;
      _lastRateSampleCount = _rawPacketCount;
      packetRateNotifier.value = delta / 0.2;
    });

    // Connect送信 → 2秒ごとにリトライ（ACが起動していない場合を考慮）
    _sendHandshake(ACHandshaker.operationConnect);
    _connectRetryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_handshakeCompleted && isListeningNotifier.value) {
        _sendHandshake(ACHandshaker.operationConnect);
        statusNotifier.value = 'Connecting to $_targetIp... (retrying)';
      }
    });

    return true;
  }

  void _sendHandshake(int operationId) {
    try {
      final bytes = ACHandshaker(operationId).toBytes();
      _socket?.send(bytes, InternetAddress(_targetIp), acPort);
    } catch (e) {
      debugPrint('[ERROR] Handshake send failed: $e');
    }
  }

  void _handleData() {
    final datagram = _socket?.receive();
    if (datagram == null) return;

    final bytes = datagram.data;

    if (!_handshakeCompleted) {
      // HandshakerResponse は408バイト
      if (bytes.length >= 408) {
        _handshakeCompleted = true;
        _connectRetryTimer?.cancel();
        _connectRetryTimer = null;
        final receivedIp = datagram.address.host;
        statusNotifier.value = 'Connected. Awaiting telemetry from $receivedIp';
        currentIpNotifier.value = receivedIp;
        // CarInfoモードを購読
        _sendHandshake(ACHandshaker.operationCarInfo);
      }
      return;
    }

    // RTCarInfo は328バイト
    if (bytes.length == 328) {
      try {
        carInfoNotifier.value = RTCarInfo.fromBytes(bytes);
        _rawPacketCount++;

        final receivedIp = datagram.address.host;
        if (!statusNotifier.value.startsWith('Receiving')) {
          statusNotifier.value = 'Receiving Data from $receivedIp';
          currentIpNotifier.value = receivedIp;
        }
      } catch (e) {
        debugPrint('[ERROR] Parse error: $e');
      }
    }
  }

  void stopListening() {
    _stopAll();
    isListeningNotifier.value = false;
    packetRateNotifier.value = 0.0;
    if (!statusNotifier.value.startsWith('ERROR')) {
      statusNotifier.value = 'IDLE: Listening stopped.';
    }
  }

  void _stopAll() {
    _connectRetryTimer?.cancel();
    _connectRetryTimer = null;
    _displayUpdateTimer?.cancel();
    _displayUpdateTimer = null;
    if (_socket != null) {
      try {
        _sendHandshake(ACHandshaker.operationDisconnect);
      } catch (_) {}
      _socket?.close();
      _socket = null;
    }
    _handshakeCompleted = false;
  }

  void dispose() {
    _stopAll();
    ipController.dispose();
    carInfoNotifier.dispose();
    packetCountNotifier.dispose();
    packetRateNotifier.dispose();
    statusNotifier.dispose();
    currentIpNotifier.dispose();
    isListeningNotifier.dispose();
  }
}
