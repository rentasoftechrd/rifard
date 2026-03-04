import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../../draws/providers/draws_provider.dart' show serverDateProvider;
import '../providers/results_provider.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDate = '';
  String? _selectedDrawId;
  final _firstController = TextEditingController();
  final _secondController = TextEditingController();
  final _thirdController = TextEditingController();
  String? _resultsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _firstController.dispose();
    _secondController.dispose();
    _thirdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverDate = ref.watch(serverDateProvider).valueOrNull ?? '';
    final dateStr = _selectedDate.isEmpty ? serverDate : _selectedDate;
    if (_selectedDate.isEmpty && serverDate.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _selectedDate = serverDate));

    return AppShell(
      currentPath: '/results',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Icon(Icons.assignment, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text('Resultados', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Doble validación: el operador ingresa resultados (pendiente). Un admin/gerente debe aprobarlos para que sean oficiales.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  tabs: const [
                    Tab(text: 'Ingresar resultados', icon: Icon(Icons.edit_note)),
                    Tab(text: 'Pendientes aprobación', icon: Icon(Icons.pending_actions)),
                  ],
                ),
                SizedBox(
                  height: 420,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _EnterTab(
                        dateStr: dateStr,
                        serverDate: serverDate,
                        selectedDrawId: _selectedDrawId,
                        onDateChanged: (s) => setState(() => _selectedDate = s),
                        onDrawSelected: (id) => setState(() => _selectedDrawId = id),
                        firstController: _firstController,
                        secondController: _secondController,
                        thirdController: _thirdController,
                        resultsError: _resultsError,
                        onResultsError: (e) => setState(() => _resultsError = e),
                        onSubmitted: () => _submitResult(context),
                      ),
                      const _PendingTab(),
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

  Future<void> _submitResult(BuildContext context) async {
    if (_selectedDrawId == null) {
      setState(() => _resultsError = 'Seleccione un sorteo.');
      return;
    }
    final primera = _firstController.text.trim();
    final segunda = _secondController.text.trim();
    final tercera = _thirdController.text.trim();
    if (primera.isEmpty || segunda.isEmpty || tercera.isEmpty) {
      setState(() => _resultsError = 'Ingrese 1era, 2da y 3ra.');
      return;
    }
    final results = <String, dynamic>{
      'primera': primera,
      'segunda': segunda,
      'tercera': tercera,
    };
    setState(() => _resultsError = null);
    final out = await enterResult(ref, _selectedDrawId!, results);
    if (!mounted) return;
    if (out != null) {
      ref.invalidate(pendingResultsProvider);
      ref.invalidate(drawResultProvider(_selectedDrawId!));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resultados guardados (pendientes de aprobación).')));
      _firstController.clear();
      _secondController.clear();
      _thirdController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al guardar. Revise que el sorteo esté cerrado y haya pasado la hora.')));
    }
  }
}

class _EnterTab extends ConsumerWidget {
  const _EnterTab({
    required this.dateStr,
    required this.serverDate,
    required this.selectedDrawId,
    required this.onDateChanged,
    required this.onDrawSelected,
    required this.firstController,
    required this.secondController,
    required this.thirdController,
    required this.resultsError,
    required this.onResultsError,
    required this.onSubmitted,
  });
  final String dateStr;
  final String serverDate;
  final String? selectedDrawId;
  final void Function(String) onDateChanged;
  final void Function(String?) onDrawSelected;
  final TextEditingController firstController;
  final TextEditingController secondController;
  final TextEditingController thirdController;
  final String? resultsError;
  final void Function(String?) onResultsError;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawsAsync = ref.watch(resultsDrawsForDateProvider(dateStr));
    final draws = drawsAsync.valueOrNull ?? [];
    // Incluir sorteos cerrados: por estado en BD (state) o por hora ya pasada (displayStatus), igual que en Sorteos
    final closedDraws = draws.where((d) {
      final m = d as Map<String, dynamic>;
      return m['state'] == 'closed' || m['displayStatus'] == 'closed';
    }).toList();
    final resultAsync = selectedDrawId != null ? ref.watch(drawResultProvider(selectedDrawId!)) : null;
    final existingResult = resultAsync?.valueOrNull;
    final isApproved = existingResult != null && existingResult['status'] == 'approved';

    // Prefill campos 1era/2da/3ra si ya hay resultados (pendientes o aprobados) y los inputs están vacíos.
    if (existingResult != null &&
        firstController.text.isEmpty &&
        secondController.text.isEmpty &&
        thirdController.text.isEmpty) {
      final res = existingResult['results'];
      if (res is Map) {
        firstController.text = res['primera']?.toString() ?? '';
        secondController.text = res['segunda']?.toString() ?? '';
        thirdController.text = res['tercera']?.toString() ?? '';
      }
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Fecha:', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(dateStr.isEmpty ? '...' : dateStr),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dateStr.isNotEmpty ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: serverDate.isNotEmpty ? DateTime.tryParse(serverDate) ?? DateTime.now() : DateTime.now(),
                    );
                    if (picked != null) onDateChanged('${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
                  },
                ),
                if (serverDate.isNotEmpty && dateStr != serverDate) ...[
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => onDateChanged(serverDate), child: const Text('Hoy')),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text('Sorteos cerrados (se puede ingresar resultado)', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            if (closedDraws.isEmpty)
              Text('No hay sorteos cerrados para esta fecha. Cierre el sorteo en la pantalla Sorteos.', style: TextStyle(color: AppColors.warning))
            else
              DropdownButtonFormField<String?>(
                value: selectedDrawId,
                decoration: const InputDecoration(labelText: 'Sorteo', border: OutlineInputBorder(), isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— Seleccione un sorteo —')),
                  ...closedDraws.map((d) {
                    final m = d as Map<String, dynamic>;
                    final lottery = m['lottery'] as Map?;
                    final id = m['id'] as String?;
                    final time = m['drawTime']?.toString().substring(0, 5) ?? '—';
                    return DropdownMenuItem(value: id, child: Text('${lottery?['name'] ?? '—'} $time'));
                  }),
                ],
                onChanged: (id) {
                  onDrawSelected(id);
                  onResultsError(null);
                },
              ),
            if (isApproved && existingResult != null) ...[
              const SizedBox(height: 12),
              Text(
                'Este sorteo ya tiene resultado aprobado. Solo se muestra como consulta, no se puede modificar.',
                style: const TextStyle(color: AppColors.success),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (existingResult['enteredAt'] != null)
                        Text(
                          'Ingresado: ${existingResult['enteredAt']}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                        ),
                      if (existingResult['approvedAt'] != null)
                        Text(
                          'Aprobado: ${existingResult['approvedAt']}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Resultados aprobados:',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        jsonEncode(existingResult['results'] ?? const {}),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (selectedDrawId != null && !isApproved) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: firstController,
                      decoration: const InputDecoration(
                        labelText: '1era',
                        hintText: 'Ej: 12',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: secondController,
                      decoration: const InputDecoration(
                        labelText: '2da',
                        hintText: 'Ej: 34',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: thirdController,
                      decoration: const InputDecoration(
                        labelText: '3ra',
                        hintText: 'Ej: 56',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (resultsError != null) ...[
                const SizedBox(height: 8),
                Text(resultsError!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onSubmitted,
                icon: const Icon(Icons.save),
                label: const Text('Guardar (pendiente de aprobación)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingTab extends ConsumerWidget {
  const _PendingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingResultsProvider);
    return pendingAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return Center(child: Text('No hay resultados pendientes de aprobación.', style: TextStyle(color: AppColors.textMuted)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final r = list[i] as Map<String, dynamic>;
            final draw = r['draw'] as Map<String, dynamic>?;
            final lottery = draw?['lottery'] as Map<String, dynamic>?;
            final drawId = draw?['id'] as String?;
            final results = r['results'];
            final enteredAt = r['enteredAt']?.toString();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(lottery?['name']?.toString() ?? '—', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(width: 8),
                        Text(draw?['drawTime']?.toString().substring(0, 5) ?? '', style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Resultados ingresados: ${results != null ? jsonEncode(results) : '{}'}', style: Theme.of(context).textTheme.bodySmall),
                    if (enteredAt != null) Text('Ingresado: $enteredAt', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: 12),
                    if (drawId != null)
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () => _approve(context, ref, drawId),
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('Aprobar'),
                            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _reject(context, ref, drawId),
                            icon: const Icon(Icons.cancel, size: 18),
                            label: const Text('Rechazar'),
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
      error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: AppColors.danger))),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref, String drawId) async {
    final out = await approveResult(ref, drawId);
    if (!context.mounted) return;
    if (out != null) {
      ref.invalidate(pendingResultsProvider);
      ref.invalidate(drawResultProvider(drawId));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resultado aprobado.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solo ADMIN/SUPER_ADMIN puede aprobar.')));
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, String drawId) async {
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Rechazar resultado'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(labelText: 'Motivo (opcional)', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim()), child: const Text('Rechazar')),
          ],
        );
      },
    );
    if (!context.mounted) return;
    if (reason == null) return; // Cancelar
    final out = await rejectResult(ref, drawId, reason: reason.isEmpty ? null : reason);
    if (!context.mounted) return;
    if (out != null) {
      ref.invalidate(pendingResultsProvider);
      ref.invalidate(drawResultProvider(drawId));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resultado rechazado.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al rechazar.')));
    }
  }
}
