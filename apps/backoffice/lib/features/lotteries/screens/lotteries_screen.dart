import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/lotteries_provider.dart';

class LotteriesScreen extends ConsumerStatefulWidget {
  const LotteriesScreen({super.key});

  @override
  ConsumerState<LotteriesScreen> createState() => _LotteriesScreenState();
}

class _LotteriesScreenState extends ConsumerState<LotteriesScreen> {
  void _openCreate() => showDialog(context: context, builder: (_) => _LotteryFormDialog(mode: _FormMode.create, onSaved: () => ref.invalidate(lotteriesListProvider)));
  void _openEdit(Map<String, dynamic> lottery) => showDialog(context: context, builder: (_) => _LotteryFormDialog(mode: _FormMode.edit, lottery: lottery, onSaved: () => ref.invalidate(lotteriesListProvider)));
  void _openDrawTimes(Map<String, dynamic> lottery) => showDialog(context: context, builder: (_) => _DrawTimesDialog(lottery: lottery, onSaved: () => ref.invalidate(lotteriesListProvider)));

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(lotteriesListProvider);
    return AppShell(
      currentPath: '/lotteries',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.confirmation_number, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Text('Loterías', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              FilledButton.icon(
                onPressed: _openCreate,
                icon: const Icon(Icons.add),
                label: const Text('Nueva lotería'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          listAsync.when(
            data: (list) => _LotteriesTable(
              list: list,
              onEdit: _openEdit,
              onDrawTimes: _openDrawTimes,
              onToggleActive: _toggleActive,
            ),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.danger),
                    const SizedBox(width: 16),
                    Expanded(child: Text('Error: $e', style: TextStyle(color: AppColors.danger))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> lottery) async {
    final id = lottery['id'] as String?;
    if (id == null) return;
    final api = ref.read(apiClientProvider);
    final active = (lottery['active'] as bool?) ?? true;
    final resp = await api.put('/lotteries/$id', body: {'active': !active});
    if (!mounted) return;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      ref.invalidate(lotteriesListProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(active ? 'Lotería desactivada' : 'Lotería activada')));
    } else {
      final msg = _tryMessage(resp.body);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $msg')));
    }
  }
}

String _tryMessage(String body) {
  try {
    final m = jsonDecode(body) as Map<String, dynamic>;
    return m['message']?.toString() ?? body;
  } catch (_) {
    return body;
  }
}

String _formatHorarios(List<dynamic> drawTimes) {
  if (drawTimes.isEmpty) return '—';
  final parts = drawTimes.map((t) {
    final m = t as Map<String, dynamic>;
    String time = m['drawTime']?.toString() ?? '';
    if (time.length >= 5) time = time.substring(0, 5);
    return time;
  }).where((s) => s.isNotEmpty).toList();
  return parts.isEmpty ? '—' : parts.join(', ');
}

class _LotteriesTable extends StatelessWidget {
  const _LotteriesTable({required this.list, required this.onEdit, required this.onDrawTimes, required this.onToggleActive});
  final List<dynamic> list;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDrawTimes;
  final void Function(Map<String, dynamic>) onToggleActive;

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.confirmation_number_outlined, size: 64, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text('No hay loterías', style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.8),
            1: FlexColumnWidth(0.9),
            2: FlexColumnWidth(0.6),
            3: FlexColumnWidth(2.2),
            4: FlexColumnWidth(1.2),
          },
          children: [
            TableRow(
              children: [
                _th(context, 'Nombre', align: TextAlign.left),
                _th(context, 'Código', align: TextAlign.center),
                _th(context, 'Activa', align: TextAlign.center),
                _th(context, 'Horarios', align: TextAlign.center),
                _th(context, 'Acciones', align: TextAlign.center),
              ],
            ),
            ...list.map<TableRow>((e) {
              final row = e as Map<String, dynamic>;
              final drawTimesList = row['drawTimes'] as List<dynamic>? ?? [];
              final active = row['active'] as bool? ?? true;
              final horariosText = _formatHorarios(drawTimesList);
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Align(alignment: Alignment.centerLeft, child: Text(row['name']?.toString() ?? '—')),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: Text(row['code']?.toString() ?? '—')),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Center(child: _ActiveChip(active: active))),
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 12, right: 16),
                    child: Center(child: Text(horariosText, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary))),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8, left: 16),
                    child: Center(
                      child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.access_time, color: Colors.white),
                          onPressed: () => onDrawTimes(row),
                          tooltip: 'Horarios',
                          style: IconButton.styleFrom(foregroundColor: Colors.white, backgroundColor: AppColors.secondary),
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.edit),
                          onPressed: () => onEdit(row),
                          tooltip: 'Editar',
                        ),
                        IconButton.filledTonal(
                          icon: Icon(active ? Icons.toggle_on : Icons.toggle_off),
                          onPressed: () => onToggleActive(row),
                          tooltip: active ? 'Desactivar' : 'Activar',
                          style: IconButton.styleFrom(foregroundColor: active ? AppColors.warning : AppColors.success),
                        ),
                      ],
                    ),
                  ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _th(BuildContext context, String label, {TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: align == TextAlign.center ? Alignment.center : (align == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft),
        child: Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(active ? 'Sí' : 'No', style: const TextStyle(fontSize: 12)),
      backgroundColor: active ? AppColors.success.withOpacity(0.2) : AppColors.textMuted.withOpacity(0.2),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

enum _FormMode { create, edit }

class _LotteryFormDialog extends ConsumerStatefulWidget {
  const _LotteryFormDialog({required this.mode, this.lottery, required this.onSaved});
  final _FormMode mode;
  final Map<String, dynamic>? lottery;
  final VoidCallback onSaved;

  @override
  ConsumerState<_LotteryFormDialog> createState() => _LotteryFormDialogState();
}

class _LotteryFormDialogState extends ConsumerState<_LotteryFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late bool _active;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final l = widget.lottery;
    _nameController = TextEditingController(text: l?['name']?.toString() ?? '');
    _codeController = TextEditingController(text: l?['code']?.toString() ?? '');
    _active = l?['active'] as bool? ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.mode == _FormMode.edit;
    return AlertDialog(
      title: Row(
        children: [
          Icon(isEdit ? Icons.edit : Icons.add_circle_outline, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(isEdit ? 'Editar lotería' : 'Nueva lotería'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Código', border: OutlineInputBorder()),
                enabled: !isEdit,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Activa'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    if (name.isEmpty) { setState(() => _error = 'Nombre requerido'); return; }
    if (code.isEmpty) { setState(() => _error = 'Código requerido'); return; }
    setState(() { _error = null; _loading = true; });
    final api = ref.read(apiClientProvider);
    final isEdit = widget.mode == _FormMode.edit;
    final id = widget.lottery?['id'] as String?;
    final resp = isEdit
        ? await api.put('/lotteries/$id', body: {'name': name, 'code': code, 'active': _active})
        : await api.post('/lotteries', body: {'name': name, 'code': code, 'active': _active});
    if (!mounted) return;
    setState(() => _loading = false);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      widget.onSaved();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Lotería actualizada' : 'Lotería creada')));
    } else {
      setState(() => _error = _tryMessage(resp.body));
    }
  }
}

class _DrawTimesDialog extends ConsumerStatefulWidget {
  const _DrawTimesDialog({required this.lottery, required this.onSaved});
  final Map<String, dynamic> lottery;
  final VoidCallback onSaved;

  @override
  ConsumerState<_DrawTimesDialog> createState() => _DrawTimesDialogState();
}

class _DrawTimesDialogState extends ConsumerState<_DrawTimesDialog> {
  List<_DrawTimeRow> _rows = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    final id = widget.lottery['id'] as String?;
    if (id == null) { setState(() => _loading = false); return; }
    final resp = await api.get('/lotteries/$id');
    if (!mounted) return;
    List<_DrawTimeRow> rows = [];
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final times = data['drawTimes'] as List<dynamic>? ?? [];
        rows = times.map((t) {
          final m = t as Map<String, dynamic>;
          String time = m['drawTime']?.toString() ?? '12:00:00';
          if (time.length == 8) time = time.substring(0, 5);
          return _DrawTimeRow(
            drawTime: time,
            closeMinutesBefore: (m['closeMinutesBefore'] as num?)?.toInt() ?? 0,
            active: m['active'] as bool? ?? true,
          );
        }).toList();
        if (rows.isEmpty) rows.add(_DrawTimeRow(drawTime: '14:00', closeMinutesBefore: 30, active: true));
      } catch (_) {
        rows = [_DrawTimeRow(drawTime: '14:00', closeMinutesBefore: 30, active: true)];
      }
    } else {
      rows = [_DrawTimeRow(drawTime: '14:00', closeMinutesBefore: 30, active: true)];
    }
    setState(() { _loading = false; _rows = rows; });
  }

  void _addRow() {
    setState(() => _rows.add(_DrawTimeRow(drawTime: '14:00', closeMinutesBefore: 30, active: true)));
  }

  void _removeAt(int i) {
    if (_rows.length <= 1) return;
    setState(() => _rows.removeAt(i));
  }

  bool _hasDuplicateTime() {
    final times = _rows.map((r) => r.drawTime).toList();
    return times.length != times.toSet().length;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.lottery['name']?.toString() ?? 'Lotería';
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.schedule, color: AppColors.secondary),
          const SizedBox(width: 8),
          Text('Horarios — $name'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 520,
          child: _loading
              ? const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text('Hora (HH:mm), minutos antes del cierre, activo. No duplicar hora.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: 12),
                    Table(
                      columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(1.5), 2: FlexColumnWidth(0.6), 3: FlexColumnWidth(0.5)},
                      children: [
                        TableRow(
                          children: [
                            _th(context, 'Hora'),
                            _th(context, 'Cerrar (min antes)'),
                            _th(context, 'Activo'),
                            _th(context, ''),
                          ],
                        ),
                        ...List.generate(_rows.length, (i) {
                          final r = _rows[i];
                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                                child: TextFormField(
                                  initialValue: r.drawTime,
                                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: '14:00'),
                                  onChanged: (v) => setState(() => _rows[i] = _DrawTimeRow(drawTime: v.trim(), closeMinutesBefore: r.closeMinutesBefore, active: r.active)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                                child: TextFormField(
                                  initialValue: r.closeMinutesBefore.toString(),
                                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    final n = int.tryParse(v) ?? 0;
                                    setState(() => _rows[i] = _DrawTimeRow(drawTime: r.drawTime, closeMinutesBefore: n.clamp(0, 999), active: r.active));
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Switch(
                                  value: r.active,
                                  onChanged: (v) => setState(() => _rows[i] = _DrawTimeRow(drawTime: r.drawTime, closeMinutesBefore: r.closeMinutesBefore, active: v)),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: _rows.length > 1 ? () => setState(() => _removeAt(i)) : null,
                                color: AppColors.danger,
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar horario'),
                      onPressed: () => setState(_addRow),
                    ),
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
        FilledButton(
          onPressed: _saving ? null : () => _save(),
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar horarios'),
        ),
      ],
    );
  }

  Widget _th(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _save() async {
    if (_hasDuplicateTime()) {
      setState(() => _error = 'No puede haber horas duplicadas');
      return;
    }
    setState(() { _error = null; _saving = true; });
    final api = ref.read(apiClientProvider);
    final id = widget.lottery['id'] as String?;
    if (id == null) { setState(() => _saving = false); return; }
    final drawTimes = _rows.map((r) {
      String t = r.drawTime;
      if (!t.contains(':')) t = '$t:00';
      if (t.length == 5) t = '$t:00';
      if (t.length == 4) t = '${t}0:00';
      return {'drawTime': t, 'closeMinutesBefore': r.closeMinutesBefore, 'active': r.active};
    }).toList();
    final resp = await api.put('/lotteries/$id/draw-times', body: {'drawTimes': drawTimes});
    if (!mounted) return;
    setState(() => _saving = false);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      widget.onSaved();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Horarios guardados')));
    } else {
      setState(() => _error = _tryMessage(resp.body));
    }
  }
}

class _DrawTimeRow {
  _DrawTimeRow({required this.drawTime, required this.closeMinutesBefore, required this.active});
  final String drawTime;
  final int closeMinutesBefore;
  final bool active;
}
