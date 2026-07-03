import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ac_converter.dart';
import 'telemetry_drawer.dart';
import 'telemetry_service.dart';

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
  final TelemetryService _telemetry = TelemetryService();

  @override
  void initState() {
    super.initState();
    _telemetry.loadSavedIp();
  }

  @override
  void dispose() {
    _telemetry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: TelemetryDrawer(service: _telemetry),
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
                    child: RpmDisplay(carInfoNotifier: _telemetry.carInfoNotifier),
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
  final ValueNotifier<RTCarInfo> carInfoNotifier;

  const RpmDisplay({super.key, required this.carInfoNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RTCarInfo>(
      valueListenable: carInfoNotifier,
      builder: (_, carInfo, _) => Text(
        '${carInfo.engineRPM.toStringAsFixed(0)} RPM',
        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
      ),
    );
  }
}
