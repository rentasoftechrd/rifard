import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../personas/providers/personas_provider.dart';
import '../providers/vendors_provider.dart';

class VendorsScreen extends ConsumerWidget {
  const VendorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      currentPath: '/vendors',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Icon(Icons.storefront, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                'Vendedores',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Usuarios con rol POS_SELLER o POS_ADMIN. Aquí asignas puntos de venta y el porcentaje de comisión por punto.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(vendorsProvider);
              return async.when(
                data: (list) => _VendorsContent(list: list, ref: ref),
                loading: () => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('Cargando vendedores…', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
                error: (e, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.danger, size: 32),
                        const SizedBox(width: 16),
                        Expanded(child: Text('Error al cargar: $e', style: TextStyle(color: AppColors.danger))),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VendorsContent extends StatelessWidget {
  const _VendorsContent({required this.list, required this.ref});
  final List<VendorListItem> list;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 64, color: AppColors.textMuted.withOpacity(0.6)),
              const SizedBox(height: 16),
              Text(
                'No hay vendedores',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Los vendedores son usuarios con rol POS_SELLER o POS_ADMIN.\nCréalos en Usuarios y asígnales el rol; luego aparecerán aquí para asignarles puntos de venta.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _goToUsers(context),
                icon: const Icon(Icons.people, size: 18),
                label: const Text('Ir a Usuarios'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: AppColors.border.withOpacity(0.3),
            child: Row(
              children: [
                Text(
                  '${list.length} vendedor${list.length == 1 ? '' : 'es'}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 52,
              headingRowColor: WidgetStateProperty.all(AppColors.surface),
              columns: const [
                DataColumn(label: Text('Vendedor')),
                DataColumn(label: Text('Cédula')),
                DataColumn(label: Text('Teléfono')),
                DataColumn(label: Text('Dirección')),
                DataColumn(label: Text('Sector / Ciudad')),
                DataColumn(label: Text('Comisión %')),
                DataColumn(label: Text('Puntos')),
                DataColumn(label: Text('Acciones')),
              ],
              rows: List.generate(list.length, (i) {
                final v = list[i];
                final p = v.persona;
                final commissionStr = v.assignments.isEmpty
                    ? '—'
                    : v.assignments.map((a) => '${a.commissionPercent.toStringAsFixed(1)}%').join(', ');
                final pointsStr = v.assignments.isEmpty
                    ? 'Ninguno'
                    : v.assignments.map((a) => a.pointName.isNotEmpty ? a.pointName : a.pointCode).join(', ');
                return DataRow(
                  color: WidgetStateProperty.all(
                    i.isEven ? AppColors.surface : AppColors.surface.withOpacity(0.95),
                  ),
                  cells: [
                    DataCell(Text(v.fullName, style: const TextStyle(fontWeight: FontWeight.w500))),
                    DataCell(Text(p?.cedula ?? '—', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                    DataCell(Text(p?.phone ?? '—', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                    DataCell(Text(p?.address ?? '—', style: TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    DataCell(Text('${p?.sector ?? '—'} / ${p?.city ?? '—'}', style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                    DataCell(Text(commissionStr)),
                    DataCell(Text(pointsStr, style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (p != null)
                            IconButton.filledTonal(
                              onPressed: () => _openEditPersonaDialog(context, ref, v),
                              icon: const Icon(Icons.person, size: 18),
                              tooltip: 'Editar datos (cédula, dirección, etc.)',
                            ),
                          const SizedBox(width: 6),
                          FilledButton.tonalIcon(
                            onPressed: () => _openAssignDialog(context, ref, v),
                            icon: const Icon(Icons.edit_location_alt, size: 18),
                            label: const Text('Puntos'),
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  void _goToUsers(BuildContext context) {
    context.go('/users');
  }

  void _openAssignDialog(BuildContext context, WidgetRef ref, VendorListItem vendor) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AssignPointsDialog(vendor: vendor, ref: ref),
    );
  }

  void _openEditPersonaDialog(BuildContext context, WidgetRef ref, VendorListItem vendor) {
    if (vendor.persona == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => _EditPersonaDialog(persona: vendor.persona!, ref: ref, onSaved: () => ref.invalidate(vendorsProvider)),
    );
  }
}

class _EditPersonaDialog extends ConsumerStatefulWidget {
  const _EditPersonaDialog({required this.persona, required this.ref, required this.onSaved});
  final VendorPersona persona;
  final WidgetRef ref;
  final VoidCallback onSaved;

  @override
  ConsumerState<_EditPersonaDialog> createState() => _EditPersonaDialogState();
}

class _EditPersonaDialogState extends ConsumerState<_EditPersonaDialog> {
  late final TextEditingController _fullName;
  late final TextEditingController _cedula;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _sector;
  late final TextEditingController _city;
  String _tipo = 'OTRO';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.persona;
    _fullName = TextEditingController(text: p.fullName);
    _cedula = TextEditingController(text: p.cedula ?? '');
    _phone = TextEditingController(text: p.phone ?? '');
    _email = TextEditingController(text: p.email ?? '');
    _address = TextEditingController(text: p.address ?? '');
    _sector = TextEditingController(text: p.sector ?? '');
    _city = TextEditingController(text: p.city ?? '');
    _tipo = p.tipo ?? 'OTRO';
  }

  @override
  void dispose() {
    _fullName.dispose();
    _cedula.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _sector.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.person, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('Editar datos del vendedor'),
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
              ],
              TextField(controller: _fullName, decoration: const InputDecoration(labelText: 'Nombre completo', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: _cedula, decoration: const InputDecoration(labelText: 'Cédula', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: _address, decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: _sector, decoration: const InputDecoration(labelText: 'Sector', border: OutlineInputBorder(), isDense: true))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _city, decoration: const InputDecoration(labelText: 'Ciudad', border: OutlineInputBorder(), isDense: true))),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: 'VENDEDOR', child: Text('Vendedor')),
                  DropdownMenuItem(value: 'EMPLEADO', child: Text('Empleado')),
                  DropdownMenuItem(value: 'OTRO', child: Text('Otro')),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? 'OTRO'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() { _error = null; _loading = true; });
    final result = await updatePersona(widget.ref, widget.persona.id, {
      'fullName': _fullName.text.trim(),
      'cedula': _cedula.text.trim().isEmpty ? null : _cedula.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'sector': _sector.text.trim().isEmpty ? null : _sector.text.trim(),
      'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
      'tipo': _tipo,
    });
    if (!mounted) return;
    setState(() => _loading = false);
    if (result != null) {
      widget.onSaved();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos actualizados')));
    } else {
      setState(() => _error = 'Error al guardar');
    }
  }
}

class _AssignPointsDialog extends ConsumerStatefulWidget {
  const _AssignPointsDialog({required this.vendor, required this.ref});
  final VendorListItem vendor;
  final WidgetRef ref;

  @override
  ConsumerState<_AssignPointsDialog> createState() => _AssignPointsDialogState();
}

class _AssignPointsDialogState extends ConsumerState<_AssignPointsDialog> {
  final Map<String, double> _commissionByPointId = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final a in widget.vendor.assignments) {
      _commissionByPointId[a.pointId] = a.commissionPercent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pointsAsync = ref.watch(vendorPointsProvider);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit_location_alt, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text('Asignar puntos: ${widget.vendor.fullName}', overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: pointsAsync.when(
          data: (points) {
            if (points.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.textMuted, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No hay puntos de venta. Crea puntos en el módulo POS.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selecciona puntos y comisión %',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  ...points.map((p) {
                    final selected = _commissionByPointId.containsKey(p.id);
                    final commission = _commissionByPointId[p.id] ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Checkbox(
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _commissionByPointId[p.id] = 0;
                                } else {
                                  _commissionByPointId.remove(p.id);
                                }
                              });
                            },
                          ),
                          Expanded(child: Text('${p.name} (${p.code})')),
                          if (selected)
                            SizedBox(
                              width: 88,
                              child: TextField(
                                key: ValueKey('comm-${p.id}'),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: '%', isDense: true),
                                onChanged: (s) {
                                  final val = double.tryParse(s.replaceAll(',', '.')) ?? 0;
                                  setState(() => _commissionByPointId[p.id] = val);
                                },
                                controller: TextEditingController(text: commission.toString()),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (e, _) => Text('Error: $e', style: TextStyle(color: AppColors.danger)),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving ? null : () => _save(context),
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context) async {
    setState(() => _saving = true);
    final body = _commissionByPointId.entries
        .map((e) => {'pointId': e.key, 'commissionPercent': e.value})
        .toList();
    await setVendorAssignments(widget.ref, widget.vendor.id, body);
    setState(() => _saving = false);
    if (context.mounted) {
      widget.ref.invalidate(vendorsProvider);
      Navigator.of(context).pop();
    }
  }
}
