import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/pagos_provider.dart';

const _betTypes = ['quiniela', 'pale', 'tripleta', 'superpale'];

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

class PagosScreen extends ConsumerWidget {
  const PagosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(payoutsListProvider);

    return AppShell(
      currentPath: '/pagos',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Icon(Icons.payments, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text('Precios', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            r'Precio = cantidad que pagamos por cada peso/dólar apostado. Ej: $5 apostados al 65, precio quiniela 20 → si sale el 65 pagamos 5 × 20 = $100.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Text(
            'Números: del 1 al 100. El 100 se escribe "00". Del 1 al 9 con cero a la izquierda (01, 02, …, 09).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          listAsync.when(
            data: (list) => _PagosTable(list: list),
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
}

class _PagosTable extends ConsumerStatefulWidget {
  const _PagosTable({required this.list});
  final List<dynamic> list;

  @override
  ConsumerState<_PagosTable> createState() => _PagosTableState();
}

class _PagosTableState extends ConsumerState<_PagosTable> {
  final _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _fillControllers(widget.list);
  }

  void _fillControllers(List<dynamic> list) {
    final map = list.cast<Map<String, dynamic>>();
    for (final bt in _betTypes) {
      final rows = map.where((e) => e['betType'] == bt).toList();
      final row = rows.isEmpty ? null : rows.first as Map<String, dynamic>;
      final mult = row?['multiplier'];
      final str = mult != null ? (mult is num ? mult.toString() : mult.toString()) : '';
      _controllers[bt] ??= TextEditingController(text: str);
      _controllers[bt]!.text = str;
    }
  }

  @override
  void didUpdateWidget(covariant _PagosTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.list != widget.list) _fillControllers(widget.list);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.list;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Precio por tipo de jugada (por cada peso/dólar apostado)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(0.8),
              },
              children: [
                const TableRow(
                  children: [
                    Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                    Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Precio', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                    Padding(padding: EdgeInsets.only(bottom: 8), child: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                ..._betTypes.map<TableRow>((bt) {
                  final ctrl = _controllers[bt];
                  return TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_betTypeLabel(bt))),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: TextField(
                          controller: ctrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            hintText: 'Ej. 20',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: FilledButton(
                          onPressed: () => _save(context, bt),
                          child: const Text('Guardar'),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, String betType) async {
    final ctrl = _controllers[betType];
    if (ctrl == null) return;
    final mult = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
    if (mult == null || mult < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese un precio válido (número ≥ 0).')));
      return;
    }
    final success = await updatePayout(ref, betType, mult);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'Guardado.' : 'Error al guardar.')));
  }
}
