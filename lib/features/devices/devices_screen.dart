import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/core/widgets/app_card.dart';
import '../../app/store/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/models/device.dart';
import 'device_scanner.dart';

/// 주변 ESP32 세트를 BLE 로 찾아 내 계정에 등록한다.
/// ESP32 한 대는 센서와 수문/펌프 제어를 담당하는 "한 세트"다.
/// 등록한 세트는 논 추가/연결 화면에서 논에 배정할 수 있다.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  final DeviceScanner _scanner = MockDeviceScanner();
  StreamSubscription<ScannedDevice>? _sub;
  bool _scanning = false;
  final List<ScannedDevice> _found = [];

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _found.clear();
    });
    _sub = _scanner
        .scan(timeout: const Duration(seconds: 5))
        .listen((d) {
          if (!mounted) return;
          setState(() => _found.add(d));
        }, onDone: () {
          if (mounted) setState(() => _scanning = false);
        });
  }

  Future<void> _register(ScannedDevice d) async {
    try {
      await ref.read(devicesProvider.notifier).register(
            deviceId: d.deviceId,
            name: d.name,
            type: d.type,
            hasGate: d.hasGate,
            hasPump: d.hasPump,
            sensors: d.sensors,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${d.name} 등록 완료')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _remove(Device d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('기기 삭제'),
        content: Text('${d.name}을(를) 등록에서 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.riskSevere),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(devicesProvider.notifier).remove(d.deviceId);
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);
    final theme = Theme.of(context);
    final registered = {
      for (final d in devices) d.deviceId,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('내 기기 등록')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('주변 ESP32 찾기', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'ESP32 한 대가 센서와 수문/펌프를 담당하는 한 세트예요.\n논이 크면 구역별로 세트를 여러 대 등록하세요.',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 12),
            if (_scanning)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (!_scanning && _found.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '주변 장치를 찾지 못했어요. 다시 찾기를 눌러주세요.',
                  style: theme.textTheme.labelMedium,
                ),
              ),
            for (final d in _found) ...[
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        d.hasGate || d.hasPump
                            ? Icons.settings_remote_rounded
                            : Icons.sensors_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            d.sensors.join(' · '),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (registered.contains(d.deviceId))
                      const Chip(
                        label: Text('등록됨'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.green,
                        labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                      )
                    else
                      FilledButton.tonal(
                        onPressed: () => _register(d),
                        child: const Text('등록'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _scanning ? null : _scan,
              icon: const Icon(Icons.bluetooth_searching_rounded),
              label: const Text('다시 찾기'),
            ),
            const SizedBox(height: 24),
            Text('내 세트 (${devices.length})', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (devices.isEmpty)
              Text(
                '아직 등록된 세트가 없어요.',
                style: theme.textTheme.labelMedium,
              ),
            for (final d in devices) ...[
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        d.hasGate || d.hasPump
                            ? Icons.settings_remote_rounded
                            : Icons.sensors_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            [
                              if (d.hasGate) '수문',
                              if (d.hasPump) '펌프',
                              ...d.sensors,
                            ].join(' · '),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          Text(
                            d.paddyId == null
                                ? '논 미배정'
                                : '배정: ${d.paddyId}',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: AppColors.riskSevere,
                      onPressed: () => _remove(d),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
