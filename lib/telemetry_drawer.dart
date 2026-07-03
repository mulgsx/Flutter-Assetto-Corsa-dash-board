import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'extensions/build_context_extensions.dart';
import 'telemetry_service.dart';

class TelemetryDrawer extends StatefulWidget {
  // Drawer が必要な状態をすべて service から自分で取得する
  final TelemetryService service;

  const TelemetryDrawer({super.key, required this.service});

  @override
  State<TelemetryDrawer> createState() => _TelemetryDrawerState();
}

class _TelemetryDrawerState extends State<TelemetryDrawer>
    with SingleTickerProviderStateMixin {
  // パルスアニメーション用コントローラ
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    // 1.0（明るい）→ 0.0（暗い）へフェードアウトする
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    // パケットが届くたびにアニメーションをリセットして再生する
    widget.service.packetCountNotifier.addListener(_onPacket);
  }

  void _onPacket() {
    _pulseController.forward(from: 0.0);
  }

  @override
  void dispose() {
    widget.service.packetCountNotifier.removeListener(_onPacket);
    _pulseController.dispose();
    super.dispose();
  }

  void _showInvalidIpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invalid IP address format'),
        content: const Text('Enter it in the format 192.168.0.100.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStart() async {
    final ok = await widget.service.startListening(
      widget.service.ipController.text.trim(),
    );
    if (!ok) _showInvalidIpDialog();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      // 受信中かどうかを監視する
      valueListenable: widget.service.isListeningNotifier,
      builder: (context, isListening, _) {
        return ValueListenableBuilder<String>(
          // 接続ステータスのテキストを監視する
          valueListenable: widget.service.statusNotifier,
          builder: (context, status, _) {
            return GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Drawer(
                // 横向き画面の40%を占める幅に設定する
                width: MediaQuery.of(context).size.width * 0.4,
                child: SingleChildScrollView(
                  // キーボード表示時に入力欄が隠れないよう下に余白を追加する
                  padding: context.keyboardPadding,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        // Drawer 内の全 Widget を幅いっぱいに伸ばす
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'AC Dashboard Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          const SizedBox(height: 8),

                          TextField(
                            // 入力値は service 側で管理し、_handleStart() で参照する
                            controller: widget.service.ipController,
                            // 数字キーボードを表示する
                            // decimal: true  → .（ドット）キーを表示する（IPアドレスに必要）
                            // signed: false  → −（マイナス）キーを非表示にする（IPに不要）
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: false,
                            ),
                            // キーボードをすり抜けた入力を制限する
                            // 数字（0〜9）とドット（.）以外は入力できない
                            // Filters out any input that passes through the keyboard
                            // Only digits (0–9) and dots (.) are allowed
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              // フォーカス時に上に浮き上がるラベル / Label that floats above the field when focused
                              labelText: 'PC IP Address',
                              // 未入力時にグレーで表示されるヒント / Placeholder shown in grey when empty
                              hintText: 'ex: 192.168.0.100',
                              // 枠線を四角形で表示する / Displays a rectangular border around the field
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              // 受信中: 赤（stop） / 停止中: 緑（start）
                              // Listening: red (stop) / Stopped: green (start)
                              backgroundColor: isListening
                                  ? Colors.red
                                  : Colors.green,
                              // 赤・緑どちらでも視認できるよう文字色は白固定
                              // White text ensures readability on both red and green
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            // 開始ボタン押下時にIPアドレスを渡してリスニングを開始する / Starts listening with the entered IP address when the start button is tapped
                            // 不正なフォーマットの場合は _handleStart 内でダイアログを表示する / _handleStart shows a dialog if the format is invalid
                            // 停止ボタン押下時にリスニングを停止する / Stops listening when the stop button is tapped
                            onPressed: isListening
                                ? widget.service.stopListening
                                : _handleStart,
                            child: Text(
                              isListening
                                  ? 'Stop Receiving'
                                  : 'Start Receiving',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _PacketRateIndicator(
                            service: widget.service,
                            pulseAnimation: _pulseAnimation,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Status: $status',
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  status.startsWith('ERROR') ||
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
              ),
            );
          },
        );
      },
    );
  }
}

// パルスドット + Hz 表示をまとめたプライベート Widget
class _PacketRateIndicator extends StatelessWidget {
  final TelemetryService service;
  final Animation<double> pulseAnimation;

  const _PacketRateIndicator({
    required this.service,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      // 受信レート（Hz）を監視する
      valueListenable: service.packetRateNotifier,
      builder: (context, rate, _) {
        return Row(
          children: [
            // パケット受信のたびに光るパルスドット
            AnimatedBuilder(
              animation: pulseAnimation,
              builder: (context, _) {
                return Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(
                      Colors.green.shade900,
                      Colors.greenAccent,
                      pulseAnimation.value,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              '${rate.toStringAsFixed(1)} Hz',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        );
      },
    );
  }
}
