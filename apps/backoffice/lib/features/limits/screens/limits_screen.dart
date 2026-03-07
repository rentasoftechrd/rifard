import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../../draws/providers/draws_provider.dart' show serverDateProvider;
import '../../lotteries/providers/lotteries_provider.dart';
import '../providers/limits_provider.dart';

const _limitTypes = ['global', 'by_number', 'by_bet_type'];
const _betTypes = ['quiniela', 'pale', 'tripleta', 'superpale'];

String _typeLabel(String type) {
  switch (type) {
    case 'global':
      return 'Global';
    case 'by_number':
      return 'Por número';
    case 'by_bet_type':
      return 'Por tipo jugada';
    default:
      return type;
  }
}

String _betTypeLabel(String bt) {
  switch (bt) {
    case 'quiniela':
      return 'Quiniela';
    case 'pale':
      return 'Palé';
    case 'tripleta':
      return 'Tripleta';
    case 'superpale':
      return 'Superpalé';
    default:
      return bt;
  }
}

String _formatMoney(dynamic n) {
  if (n == null) return '—';
  final v = n is num ? n.toDouble() : double.tryParse(n.toString());
  if (v == null) return '—';
  return 'RD\$ ${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)}';
}

String _scopeLabel(Map<String, dynamic> m) {
  final lot = m['lottery'] as Map<String, dynamic>?;
  final draw = m['draw'] as Map<String, dynamic>?;
  final lotteryName = lot?['name']?.toString();
  final drawTime = draw?['drawTime']?.toString();
  if (lotteryName != null && lotteryName.isNotEmpty) {
    final t = drawTime != null && drawTime.length >= 5 ? drawTime.substring(0, 5) : drawTime ?? '';
    return t.isNotEmpty ? '$lotteryName $t' : lotteryName;
  }
  return '';
}

class LimitsScreen extends ConsumerStatefulWidget {
  const LimitsScreen({super.key});

  @override
  ConsumerState<LimitsScreen> createState() => _LimitsScreenState();
}

class _LimitsScreenState extends ConsumerState<LimitsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverDate = ref.watch(serverDateProvider).valueOrNull ?? '';
    final dateStr = ref.watch(limitsDateFilterProvider).isEmpty ? serverDate : ref.watch(limitsDateFilterProvider);
    if (ref.read(limitsDateFilterProvider).isEmpty && serverDate.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(limitsDateFilterProvider.notifier).state = serverDate;
      });
    }

    final lotteryId = ref.watch(limitsLotteryIdProvider);
    final drawId = ref.watch(limitsDrawIdProvider);
    final lotteriesAsync = ref.watch(lotteriesListProvider);
    final drawsAsync = ref.watch(limitsDrawsForDateProvider(dateStr));
    final limitsAsync = ref.watch(limitsListProvider);

    final lotteries = lotteriesAsync.valueOrNull ?? [];
    final draws = drawsAsync.valueOrNull ?? [];
    final drawsFiltered = lotteryId == null || lotteryId.isEmpty
        ? draws
        : draws.where((d) => (d as Map)['lotteryId'] == lotteryId).toList();
    final hasScope = lotteryId != null && lotteryId.isNotEmpty && drawId != null && drawId.isNotEmpty;

    return AppShell(
      currentPath: '/limits',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Icon(Icons.speed, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text('Límites', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Los límites aplican siempre; puede incrementarlos o reducirlos. Solo Super Administrador puede hacer cambios. Así se evita fraude.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Card(
            child: InkWell(
              onTap: () => setState(() {}),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.filter_list, size: 20, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text('Filtrar por lotería/sorteo (solo en casos excepcionales)', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(dateStr.isEmpty ? 'Fecha...' : dateStr),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dateStr.isNotEmpty ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: serverDate.isNotEmpty ? DateTime.tryParse(serverDate) ?? DateTime.now() : DateTime.now(),
                              );
                              if (picked != null) {
                                ref.read(limitsDateFilterProvider.notifier).state =
                                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                ref.read(limitsDrawIdProvider.notifier).state = null;
                              }
                            },
                          ),
                          if (serverDate.isNotEmpty && dateStr != serverDate) ...[
                            const SizedBox(width: 8),
                            TextButton(onPressed: () => ref.read(limitsDateFilterProvider.notifier).state = serverDate, child: const Text('Hoy')),
                          ],
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<String?>(
                              value: lotteryId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Lotería', border: OutlineInputBorder(), isDense: true),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('— Todas —', overflow: TextOverflow.ellipsis)),
                                ...lotteries.map((l) {
                                  final m = l as Map<String, dynamic>;
                                  final name = m['name']?.toString() ?? '—';
                                  return DropdownMenuItem(value: m['id'] as String?, child: Text(name, overflow: TextOverflow.ellipsis));
                                }),
                              ],
                              onChanged: (v) {
                                ref.read(limitsLotteryIdProvider.notifier).state = v;
                                ref.read(limitsDrawIdProvider.notifier).state = null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<String?>(
                              value: drawId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Sorteo', border: OutlineInputBorder(), isDense: true),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('— Todos —', overflow: TextOverflow.ellipsis)),
                                ...drawsFiltered.map((d) {
                                  final m = d as Map<String, dynamic>;
                                  final lot = m['lottery'] as Map?;
                                  final time = m['drawTime']?.toString();
                                  final t = time != null && time.length >= 5 ? time.substring(0, 5) : time ?? '—';
                                  return DropdownMenuItem(value: m['id'] as String?, child: Text('${lot?['name'] ?? '—'} $t', overflow: TextOverflow.ellipsis));
                                }),
                              ],
                              onChanged: (v) => ref.read(limitsDrawIdProvider.notifier).state = v,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (lotteryId != null || drawId != null)
                            TextButton.icon(
                              onPressed: () {
                                ref.read(limitsLotteryIdProvider.notifier).state = null;
                                ref.read(limitsDrawIdProvider.notifier).state = null;
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              label: const Text('Quitar filtro'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  tabs: const [
                    Tab(text: 'Global', icon: Icon(Icons.pie_chart_outline)),
                    Tab(text: 'Por número', icon: Icon(Icons.tag)),
                    Tab(text: 'Por tipo jugada', icon: Icon(Icons.category)),
                  ],
                ),
                SizedBox(
                  height: 420,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _LimitsTab(type: 'global', limitsAsync: limitsAsync),
                      _LimitsTab(type: 'by_number', limitsAsync: limitsAsync),
                      _LimitsTab(type: 'by_bet_type', limitsAsync: limitsAsync),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitsTab extends ConsumerWidget {
  const _LimitsTab({
    required this.type,
    required this.limitsAsync,
  });
  final String type;
  final AsyncValue<List<dynamic>> limitsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = limitsAsync.valueOrNull ?? [];
    final filtered = list.where((e) => (e as Map)['type'] == type).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Límites ${_typeLabel(type)}', style: Theme.of(context).textTheme.titleMedium),
              FilledButton.icon(
                onPressed: () => _openForm(context, ref, null),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Nuevo'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: limitsAsync.when(
              data: (_) {
                if (filtered.isEmpty) {
                  return Center(child: Text('No hay límites de este tipo.', style: TextStyle(color: AppColors.textMuted)));
                }
                return SingleChildScrollView(
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.2),
                      1: FlexColumnWidth(0.8),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(0.6),
                      4: FlexColumnWidth(0.8),
                    },
                    children: [
                      const TableRow(
                        children: [
                          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Detalle / Alcance', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Máx. pago', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Activo', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      ...filtered.map<TableRow>((e) {
                        final m = e as Map<String, dynamic>;
                        final id = m['id'] as String?;
                        final detail = type == 'by_number'
                            ? (m['numberKey']?.toString() ?? '—')
                            : type == 'by_bet_type'
                                ? _betTypeLabel(m['betType']?.toString() ?? '')
                                : '—';
                        final scope = _scopeLabel(m);
                        final active = m['active'] as bool? ?? true;
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(_typeLabel(m['type']?.toString() ?? ''))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(scope.isNotEmpty ? '$detail · $scope' : (detail != '—' ? detail : 'Global'))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(_formatMoney(m['maxPayout']))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Icon(active ? Icons.check_circle : Icons.cancel, size: 20, color: active ? AppColors.success : AppColors.textMuted)),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: id == null ? null : () => _openForm(context, ref, m),
                                    style: IconButton.styleFrom(foregroundColor: AppColors.primary),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    onPressed: id == null ? null : () => _confirmDelete(context, ref, id),
                                    style: IconButton.styleFrom(foregroundColor: AppColors.danger),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: AppColors.danger))),
            ),
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      builder: (ctx) => _LimitFormDialog(
        type: type,
        lotteryId: existing?['lotteryId'] as String?,
        drawId: existing?['drawId'] as String?,
        existing: existing,
        onSaved: () {
          ref.invalidate(limitsListProvider);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar límite'),
        content: const Text('¿Eliminar este límite?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), style: FilledButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final success = await deleteLimit(ref, id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'Límite eliminado.' : 'Error al eliminar.')));
      }
    }
  }
}

class _LimitFormDialog extends ConsumerStatefulWidget {
  const _LimitFormDialog({
    required this.type,
    this.lotteryId,
    this.drawId,
    this.existing,
    required this.onSaved,
  });
  final String type;
  final String? lotteryId;
  final String? drawId;
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;

  @override
  ConsumerState<_LimitFormDialog> createState() => _LimitFormDialogState();
}

class _LimitFormDialogState extends ConsumerState<_LimitFormDialog> {
  late final TextEditingController _maxPayoutController;
  late final TextEditingController _numberKeyController;
  String _betType = 'quiniela';
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final payoutVal = e?['maxPayout'];
    final payoutStr = payoutVal != null ? (payoutVal is num ? payoutVal.toString() : payoutVal.toString()) : '';
    _maxPayoutController = TextEditingController(text: payoutStr);
    _numberKeyController = TextEditingController(text: e?['numberKey']?.toString() ?? '');
    _betType = e?['betType']?.toString() ?? 'quiniela';
    _active = e?['active'] as bool? ?? true;
  }

  @override
  void dispose() {
    _maxPayoutController.dispose();
    _numberKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuevo límite ${_typeLabel(widget.type)}' : 'Editar límite'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.type == 'by_number') ...[
                TextFormField(
                  controller: _numberKeyController,
                  decoration: const InputDecoration(labelText: 'Número (ej. 23)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16),
              ],
              if (widget.type == 'by_bet_type') ...[
                DropdownButtonFormField<String>(
                  value: _betType,
                  decoration: const InputDecoration(labelText: 'Tipo de jugada', border: OutlineInputBorder()),
                  items: _betTypes.map((b) => DropdownMenuItem(value: b, child: Text(_betTypeLabel(b)))).toList(),
                  onChanged: (v) => setState(() => _betType = v ?? 'quiniela'),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _maxPayoutController,
                decoration: const InputDecoration(labelText: 'Máximo pago (RD\$)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Activo'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving ? null : () => _submit(ref),
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _submit(WidgetRef ref) async {
    final maxPayoutStr = _maxPayoutController.text.trim();
    final maxPayout = double.tryParse(maxPayoutStr.replaceAll(',', '.'));
    if (maxPayout == null || maxPayout < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Máximo pago inválido.')));
      return;
    }
    if (widget.type == 'by_number' && _numberKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese el número.')));
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'type': widget.type,
      'lotteryId': widget.lotteryId,
      'drawId': widget.drawId,
      'maxPayout': maxPayout,
      'active': _active,
    };
    if (widget.existing?['id'] != null) body['id'] = widget.existing!['id'];
    if (widget.type == 'by_number') body['numberKey'] = _numberKeyController.text.trim();
    if (widget.type == 'by_bet_type') body['betType'] = _betType;

    final errorMsg = await upsertLimit(ref, body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (errorMsg == null) {
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Límite guardado.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $errorMsg')));
    }
  }
}
