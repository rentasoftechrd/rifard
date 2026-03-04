import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../providers/pos_connected_provider.dart';

class PosConnectedScreen extends ConsumerStatefulWidget {
  const PosConnectedScreen({super.key});

  @override
  ConsumerState<PosConnectedScreen> createState() => _PosConnectedScreenState();
}

class _PosConnectedScreenState extends ConsumerState<PosConnectedScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoRefresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidate(posConnectedProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(posConnectedProvider);

    return AppShell(
      currentPath: '/pos-connected',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Icon(Icons.point_of_sale, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                'POS Conectados',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Los POS envían heartbeat cada 10–30 s. Se considera online si el último heartbeat fue hace ≤ 60 s (configurable en servidor). '
            'Así se ve qué puntos están vendiendo y qué vendedor está en cada dispositivo.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          async.when(
            data: (data) {
              final online = data['online'] as List<dynamic>? ?? [];
              final offline = data['offline'] as List<dynamic>? ?? [];
              final total = online.length + offline.length;
              final hasError = data['error'] == true;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Card(
                        color: AppColors.success.withOpacity(0.15),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi, color: AppColors.success, size: 22),
                              const SizedBox(width: 8),
                              Text('${online.length} online', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.success)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Card(
                        color: AppColors.textMuted.withOpacity(0.15),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off, color: AppColors.textMuted, size: 22),
                              const SizedBox(width: 8),
                              Text('${offline.length} offline', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Total: $total dispositivos', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => ref.invalidate(posConnectedProvider),
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Actualizar',
                      ),
                    ],
                  ),
                  if (hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Card(
                        color: AppColors.danger.withOpacity(0.15),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: AppColors.danger),
                              const SizedBox(width: 12),
                              Text('Error al cargar. Reintente.', style: TextStyle(color: AppColors.danger)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dispositivos', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          if (total == 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'Ningún POS ha enviado heartbeat aún.',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              ),
                            )
                          else
                            Table(
                              columnWidths: const {
                                0: FlexColumnWidth(1.2),
                                1: FlexColumnWidth(1.2),
                                2: FlexColumnWidth(1.2),
                                3: FlexColumnWidth(0.8),
                                4: FlexColumnWidth(1.1),
                                5: FlexColumnWidth(0.7),
                              },
                              children: [
                                const TableRow(
                                  children: [
                                    _Th(text: 'Punto'),
                                    _Th(text: 'Device'),
                                    _Th(text: 'Vendedor'),
                                    _Th(text: 'App'),
                                    _Th(text: 'Último visto'),
                                    _Th(text: 'Estado'),
                                  ],
                                ),
                                ..._rows(online, 'online'),
                                ..._rows(offline, 'offline'),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()),
            ),
            error: (e, _) => Card(
              color: AppColors.danger.withOpacity(0.15),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.danger),
                    const SizedBox(width: 16),
                    Expanded(child: Text('Error: $e', style: TextStyle(color: AppColors.danger))),
                    TextButton(
                      onPressed: () => ref.invalidate(posConnectedProvider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TableRow> _rows(List<dynamic> list, String status) {
    final isOnline = status == 'online';
    return list.map<TableRow>((p) {
      final map = p as Map<String, dynamic>;
      final point = map['point'] as Map<String, dynamic>?;
      final seller = map['seller'] as Map<String, dynamic>?;
      final device = map['device'] as Map<String, dynamic>?;
      final lastSeen = map['lastSeenAt'];
      final lastSeenStr = _formatLastSeen(lastSeen);
      return TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(point?['name']?.toString() ?? '—', overflow: TextOverflow.ellipsis),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(device?['deviceId']?.toString() ?? map['deviceId']?.toString() ?? '—', overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'monospace')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(seller?['fullName']?.toString() ?? '—', overflow: TextOverflow.ellipsis),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(map['appVersion']?.toString() ?? '—', overflow: TextOverflow.ellipsis),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(lastSeenStr, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _StatusChip(isOnline: isOnline),
          ),
        ],
      );
    }).toList();
  }

  String _formatLastSeen(dynamic lastSeen) {
    if (lastSeen == null) return '—';
    String s = lastSeen.toString();
    if (s.length >= 19) s = s.substring(0, 19).replaceFirst('T', ' ');
    return s;
  }
}

class _Th extends StatelessWidget {
  const _Th({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isOnline});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        isOnline ? 'Online' : 'Offline',
        style: TextStyle(
          color: isOnline ? AppColors.success : AppColors.textMuted,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      backgroundColor: isOnline ? AppColors.success.withOpacity(0.2) : AppColors.textMuted.withOpacity(0.2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
