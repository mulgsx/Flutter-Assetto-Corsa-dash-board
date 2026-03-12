import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'ac_converter.dart';
import 'ac_drawer.dart';

const String prefIpKey = 'ac_pc_ip';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(
      const MaterialApp(
        home: ACDashboardApp(),
        debugShowCheckedModeBanner: false,
      ),
    );
  });
}

class ACDashboardApp extends StatefulWidget {
  const ACDashboardApp({super.key});

  @override
  ACDashboardAppState createState() => ACDashboardAppState();
}

class ACDashboardAppState extends State<ACDashboardApp> {
  static const String defaultIp = '192.168.0.0';
  static const int acPort = 9996;

  final ValueNotifier<double> rpmNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<int> packetCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<String> statusNotifier = ValueNotifier<String>(
    "IDLE: Press 'Start Receiving' to connect.",
  );
  final ValueNotifier<String> currentDisplayedIpNotifier =
      ValueNotifier<String>(defaultIp);

  int _rawPacketCount = 0;
  Timer? _displayUpdateTimer;
  Timer? _connectRetryTimer;

  late final TextEditingController ipController =
      TextEditingController(text: defaultIp);
  late String targetIp = defaultIp;
  bool isListening = false;
  bool _handshakeCompleted = false;
  RawDatagramSocket? _socket;

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
  }

  void _loadSavedIp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString(prefIpKey) ?? defaultIp;
      ipController.text = savedIp;
      targetIp = savedIp;
      currentDisplayedIpNotifier.value = savedIp;
      print('[LOG] Loaded IP: $savedIp');
    } catch (e) {
      print('[ERROR] Failed to load IP: $e');
    }
  }

  void _saveIp(String ip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefIpKey, ip);
      print('[LOG] Saved IP: $ip');
    } catch (e) {
      print('[ERROR] Failed to save IP: $e');
    }
  }

  @override
  void dispose() {
    _stopAll();
    ipController.dispose();
    rpmNotifier.dispose();
    packetCountNotifier.dispose();
    statusNotifier.dispose();
    currentDisplayedIpNotifier.dispose();
    super.dispose();
  }

  bool isValidIp(String ip) => InternetAddress.tryParse(ip) != null;

  void showInvalidIpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invalid IP address format'),
        content: const Text('Enter it in the format 192.168.0.50.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void startListening() async {
    targetIp = ipController.text.trim();
    if (!isValidIp(targetIp)) {
      showInvalidIpDialog();
      return;
    }

    _saveIp(targetIp);

    if (isListening || _socket != null) {
      _stopAll();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    currentDisplayedIpNotifier.value = targetIp;
    statusNotifier.value = 'Connecting to $targetIp:$acPort...';

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        acPort,
      );
    } catch (e) {
      statusNotifier.value = 'ERROR: Failed to bind port $acPort ($e)';
      return;
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

    setState(() {
      isListening = true;
      _handshakeCompleted = false;
      _rawPacketCount = 0;
    });
    packetCountNotifier.value = 0;

    // UIを5Hzで更新（120Hzのパケットを全てUI更新すると重いため）
    _displayUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (packetCountNotifier.value != _rawPacketCount) {
        packetCountNotifier.value = _rawPacketCount;
      }
    });

    // Connect送信 → 2秒ごとにリトライ（ACが起動していない場合を考慮）
    _sendHandshake(ACHandshaker.operationConnect);
    _connectRetryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_handshakeCompleted && isListening) {
        _sendHandshake(ACHandshaker.operationConnect);
        statusNotifier.value = 'Connecting to $targetIp... (retrying)';
      }
    });
  }

  void _sendHandshake(int operationId) {
    try {
      final bytes = ACHandshaker(operationId).toBytes();
      _socket?.send(bytes, InternetAddress(targetIp), acPort);
    } catch (e) {
      print('[ERROR] Handshake send failed: $e');
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
        currentDisplayedIpNotifier.value = receivedIp;
        // CarInfoモードを購読
        _sendHandshake(ACHandshaker.operationCarInfo);
      }
      return;
    }

    // RTCarInfo は328バイト
    if (bytes.length == 328) {
      try {
        final carInfo = RTCarInfo.fromBytes(bytes);
        _rawPacketCount++;
        rpmNotifier.value = carInfo.engineRPM;

        final receivedIp = datagram.address.host;
        if (!statusNotifier.value.startsWith('Receiving')) {
          statusNotifier.value = 'Receiving Data from $receivedIp';
          currentDisplayedIpNotifier.value = receivedIp;
        }
      } catch (e) {
        print('[ERROR] Parse error: $e');
      }
    }
  }

  void stopListening() {
    _stopAll();
    setState(() => isListening = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: ValueListenableBuilder<int>(
        valueListenable: packetCountNotifier,
        builder: (context, count, _) {
          return ValueListenableBuilder<String>(
            valueListenable: statusNotifier,
            builder: (context, status, _) {
              return ACDrawer(
                ipController: ipController,
                isListening: isListening,
                onStart: startListening,
                onStop: stopListening,
                packetCount: count,
                status: status,
              );
            },
          );
        },
      ),
      appBar: AppBar(
        title: const Text('AC Dashboard'),
        leading: SafeArea(
          child: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: RpmDisplay(rpmNotifier: rpmNotifier),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RpmDisplay extends StatelessWidget {
  final ValueNotifier<double> rpmNotifier;

  const RpmDisplay({super.key, required this.rpmNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: rpmNotifier,
      builder: (_, rpm, _) => Text(
        '${rpm.toStringAsFixed(0)} RPM',
        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
      ),
    );
  }
}
