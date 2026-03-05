import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../providers/pos_provider.dart';

/// Módulo POS: creación y gestión de puntos de venta.
/// Los puntos se asignan a vendedores desde Personas → botón "Puntos".
/// El vendedor hace login en la app POS y selecciona el punto para conectar el dispositivo.
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  void _openNewPoint() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _PosPointFormDialog(
        point: null,
        onSaved: () {
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _openEdit(PosPointItem point) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _PosPointFormDialog(
        point: point,
        onSaved: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Future<void> _deactivate(PosPointItem point) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar punto de venta'),
        content: Text(
          '¿Desactivar "${point.name}" (${point.code})? Los vendedores ya no podrán asignar este punto ni conectar dispositivos.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final result = await deactivatePosPointWithError(ref, point.id);
    if (!mounted) return;
    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Punto "${point.name}" desactivado.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error ?? 'Error al desactivar'), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pointsAsync = ref.watch(posPointsAdminProvider);
    return AppShell(
      currentPath: '/pos',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Icon(Icons.point_of_sale, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'POS / Puntos de venta',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                onPressed: _openNewPoint,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Nuevo punto de venta'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Crea y gestiona los puntos de venta. Luego asigna cada punto a los vendedores desde Personas → botón "Puntos". El vendedor inicia sesión en la app POS y selecciona el punto para conectar el dispositivo.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          pointsAsync.when(
            data: (points) => _PointsList(points: points, onEdit: _openEdit, onDeactivate: _deactivate),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (err, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error al cargar puntos: $err', style: TextStyle(color: AppColors.danger)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsList extends StatelessWidget {
  const _PointsList({required this.points, required this.onEdit, required this.onDeactivate});

  final List<PosPointItem> points;
  final void Function(PosPointItem) onEdit;
  final void Function(PosPointItem) onDeactivate;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Icon(Icons.storefront_outlined, size: 56, color: AppColors.textMuted.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text('No hay puntos de venta', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Crea el primero con "Nuevo punto de venta". Luego asígnalo a vendedores desde Personas.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const padding = 0.0;
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 560 ? 2 : 1);
        final availableWidth = constraints.maxWidth - padding * 2 - spacing * (crossAxisCount - 1);
        final cardWidth = availableWidth / crossAxisCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: points.map((p) => SizedBox(width: cardWidth, child: _PointCard(point: p, onEdit: () => onEdit(p), onDeactivate: () => onDeactivate(p)))).toList(),
        );
      },
    );
  }
}

class _PointCard extends StatelessWidget {
  const _PointCard({required this.point, required this.onEdit, required this.onDeactivate});

  final PosPointItem point;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: Icon(Icons.store, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(point.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(point.code, style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontFamily: 'monospace')),
                        if (point.address != null && point.address!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Expanded(child: Text(point.address!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
                    padding: EdgeInsets.zero,
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'deactivate') onDeactivate();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(value: 'deactivate', child: Text('Desactivar')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(point.active ? 'Activo' : 'Inactivo', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: point.active ? AppColors.success : AppColors.textMuted),
                    backgroundColor: point.active ? AppColors.success.withOpacity(0.15) : Colors.transparent,
                  ),
                  if (point.assignmentsCount > 0)
                    Chip(
                      label: Text('${point.assignmentsCount} vendedor${point.assignmentsCount == 1 ? '' : 'es'}', style: const TextStyle(fontSize: 11)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: AppColors.border),
                      backgroundColor: Colors.transparent,
                    ),
                  if (point.devicesCount > 0)
                    Chip(
                      label: Text('${point.devicesCount} dispositivo${point.devicesCount == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: AppColors.border),
                      backgroundColor: Colors.transparent,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                    label: Text('Editar', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, foregroundColor: AppColors.primary),
                  ),
                  if (point.active) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onDeactivate,
                      icon: Icon(Icons.remove_circle_outline, size: 16, color: AppColors.danger),
                      label: Text('Desactivar', style: TextStyle(fontSize: 12, color: AppColors.danger)),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, foregroundColor: AppColors.danger),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosPointFormDialog extends ConsumerStatefulWidget {
  const _PosPointFormDialog({this.point, required this.onSaved});

  final PosPointItem? point;
  final VoidCallback onSaved;

  @override
  ConsumerState<_PosPointFormDialog> createState() => _PosPointFormDialogState();
}

class _PosPointFormDialogState extends ConsumerState<_PosPointFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _address;
  bool _active = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.point;
    _name = TextEditingController(text: p?.name ?? '');
    _code = TextEditingController(text: p?.code ?? '');
    _address = TextEditingController(text: p?.address ?? '');
    _active = p?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final code = _code.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio');
      return;
    }
    if (code.isEmpty) {
      setState(() => _error = 'El código es obligatorio');
      return;
    }
    setState(() { _error = null; _loading = true; });
    if (widget.point == null) {
      final result = await createPosPointWithError(ref, name: name, code: code, address: _address.text.trim().isEmpty ? null : _address.text.trim(), active: _active);
      setState(() => _loading = false);
      if (!mounted) return;
      if (result.error != null) {
        setState(() => _error = result.error);
        return;
      }
      widget.onSaved();
    } else {
      final result = await updatePosPointWithError(ref, widget.point!.id, name: name, code: code, address: _address.text.trim().isEmpty ? null : _address.text.trim(), active: _active);
      setState(() => _loading = false);
      if (!mounted) return;
      if (result.error != null) {
        setState(() => _error = result.error);
        return;
      }
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.point != null;
    final inputDec = InputDecoration(
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _loading ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(foregroundColor: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEdit ? 'Editar punto de venta' : 'Nuevo punto de venta',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.danger.withOpacity(0.5))),
                        child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _name,
                      decoration: inputDec.copyWith(labelText: 'Nombre del punto'),
                      style: const TextStyle(color: AppColors.textPrimary),
                      textCapitalization: TextCapitalization.words,
                      enabled: !_loading,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _code,
                      decoration: inputDec.copyWith(
                        labelText: 'Código (único)',
                        hintText: 'Ej: PTO-001',
                      ),
                      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace'),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]'))],
                      enabled: !_loading,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _address,
                      decoration: inputDec.copyWith(labelText: 'Dirección (opcional)'),
                      style: const TextStyle(color: AppColors.textPrimary),
                      maxLines: 2,
                      enabled: !_loading,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Activo', style: TextStyle(color: AppColors.textPrimary)),
                      subtitle: const Text('Si está inactivo, los vendedores no verán este punto.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      value: _active,
                      onChanged: _loading ? null : (v) => setState(() => _active = v),
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
