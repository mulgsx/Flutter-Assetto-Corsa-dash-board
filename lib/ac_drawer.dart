import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ACDrawer extends StatelessWidget {
  final TextEditingController ipController;
  final bool isListening;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final int packetCount;
  final String status;

  const ACDrawer({
    super.key,
    required this.ipController,
    required this.isListening,
    required this.onStart,
    required this.onStop,
    required this.packetCount,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'AC Dashboard Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ipController,
                  decoration: const InputDecoration(
                    labelText: 'PC IP Address',
                    hintText: 'ex: 192.168.0.50',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isListening ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: isListening ? onStop : onStart,
                  child: Text(
                    isListening ? 'Stop Receiving' : 'Start Receiving',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Packets: $packetCount',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Status: $status',
                  style: TextStyle(
                    fontSize: 14,
                    color: status.startsWith('ERROR') ||
                            status.contains('Closed') ||
                            status.startsWith('IDLE')
                        ? Colors.red.shade700
                        : status.startsWith('Receiving')
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
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
