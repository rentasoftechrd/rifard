import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../providers/personas_provider.dart';
import '../../vendors/providers/vendors_provider.dart';

/// Formato cédula RD: 000-0000000-0
class _CedulaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 11) return oldValue;
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 3) buffer.write('-');
      if (i == 10) buffer.write('-');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formato teléfono: 000-000-0000
class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) return oldValue;
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) buffer.write('-');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatCedula(String? value) {
  if (value == null || value.isEmpty) return '';
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length > 11) return value;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 3) buffer.write('-');
    if (i == 10) buffer.write('-');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String _formatPhone(String? value) {
  if (value == null || value.isEmpty) return '';
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length > 10) return value;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 3 || i == 6) buffer.write('-');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

class PersonasScreen extends ConsumerStatefulWidget {
  const PersonasScreen({super.key});

  @override
  ConsumerState<PersonasScreen> createState() => _PersonasScreenState();
}

class _PersonasScreenState extends ConsumerState<PersonasScreen> {
  int _page = 1;
  String? _tipoFilter;
  static const int _limit = 25;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(personasListProvider((page: _page, limit: _limit, tipo: _tipoFilter)));

    return AppShell(
      currentPath: '/personas',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          // Card contenedora con colores del sistema
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: título, descripción, botón
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
                                const SizedBox(width: 12),
                                Text(
                                  'Personas',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Datos de personas (vendedores, empleados). Comisión % se guarda al editar. Para asignar puntos de venta: crea usuario con rol Vendedor y usa el botón "Puntos" en la fila.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textMuted,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: () => _openNewPersona(context),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Nueva persona'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: async.when(
            data: (payload) {
              final data = payload['data'] as List<dynamic>? ?? [];
              final meta = payload['meta'] as Map<String, dynamic>? ?? {};
              final total = meta['total'] as int? ?? 0;
              return _PersonasTable(
                list: data,
                page: _page,
                limit: _limit,
                total: total,
                tipoFilter: _tipoFilter,
                onPageChanged: (p) => setState(() => _page = p),
                onTipoFilterChanged: (t) => setState(() { _tipoFilter = t; _page = 1; }),
                onEdit: (persona) => _openEditPersona(context, persona),
                onAssignPoints: _openAssignPoints,
              );
            },
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openNewPersona(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _PersonaFormDialog(onSaved: () => ref.invalidate(personasListProvider)),
    );
  }

  void _openEditPersona(BuildContext context, Map<String, dynamic> persona) {
    showDialog<void>(
      context: context,
      builder: (_) => _PersonaFormDialog(persona: persona, onSaved: () => ref.invalidate(personasListProvider)),
    );
  }

  void _openAssignPoints(BuildContext context, WidgetRef ref, String userId, String fullName, List<dynamic> initialAssignments) {
    showDialog<void>(
      context: context,
      builder: (_) => _AssignPointsDialog(
        userId: userId,
        fullName: fullName,
        initialAssignments: initialAssignments,
        ref: ref,
        onSaved: () => ref.invalidate(personasListProvider),
      ),
    );
  }
}

/// Tarjeta de persona: muestra todos los datos sin cortar, estilo lista de clientes.
class _PersonaCard extends StatelessWidget {
  const _PersonaCard({
    required this.persona,
    required this.onEdit,
    required this.onAssignPoints,
  });
  final Map<String, dynamic> persona;
  final VoidCallback onEdit;
  final VoidCallback onAssignPoints;

  @override
  Widget build(BuildContext context) {
    final m = persona;
    final name = m['fullName']?.toString() ?? '—';
    // Iniciales: primera del nombre + primera del apellido (ej. Luis Alberto -> LA)
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final initials = parts.length >= 2
        ? '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase()
        : (name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase());
    final isVendedor = m['isVendedor'] as bool? ?? false;
    final assignments = m['assignments'] as List<dynamic>? ?? [];
    final defaultComm = m['defaultCommissionPercent'];
    final hasDefaultComm = defaultComm != null && (defaultComm is num || double.tryParse(defaultComm.toString()) != null);
    String commissionStr = '—';
    if (isVendedor) {
      if (assignments.isNotEmpty) {
        commissionStr = assignments.map((a) => '${(a as Map)['commissionPercent']}%').join(', ');
      } else if (hasDefaultComm) {
        commissionStr = '${defaultComm}%';
      }
    }
    final pointsStr = assignments.isEmpty ? '—' : assignments.map((a) => (a as Map)['pointName']?.toString() ?? (a['pointCode']?.toString() ?? '')).join(', ');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nombre + avatar + menú
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primary)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          _row(Icons.location_on_outlined, (m['address']?.toString() ?? '').trim().isEmpty ? '—' : (m['address']?.toString() ?? '—').trim()),
                          if (_sectorCity(m).isNotEmpty) ...[
                            const SizedBox(height: 1),
                            _row(Icons.place_outlined, _sectorCity(m)),
                          ],
                          const SizedBox(height: 1),
                          _row(Icons.email_outlined, m['email']?.toString() ?? '—'),
                          const SizedBox(height: 1),
                          _oneLine(Icons.phone_outlined, m['phone']?.toString(), m['cedula']?.toString()),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
                      padding: EdgeInsets.zero,
                      onSelected: (v) {
                        if (v == 'edit') onEdit();
                        if (v == 'points') onAssignPoints();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Editar')),
                        if (isVendedor && m['userId'] != null) const PopupMenuItem(value: 'points', child: Text('Puntos de venta')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Chips de tipo y comisión
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Chip(
                      label: Text((m['tipo']?.toString() ?? '—').toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: AppColors.border),
                      backgroundColor: Colors.transparent,
                    ),
                    if (isVendedor && commissionStr != '—')
                      Chip(
                        label: Text('Comisión $commissionStr', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: AppColors.border),
                        backgroundColor: Colors.transparent,
                      ),
                  ],
                ),
                if (isVendedor && pointsStr != '—') ...[
                  const SizedBox(height: 2),
                  Text('Puntos: $pointsStr', style: TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 6),
                // Botones Editar / Puntos (alineados a la izquierda)
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                      label: Text('Editar', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                    if (isVendedor && m['userId'] != null) ...[
                      const SizedBox(width: 6),
                      FilledButton.icon(
                        onPressed: onAssignPoints,
                        icon: const Icon(Icons.edit_location_alt, size: 16),
                        label: const Text('Puntos', style: TextStyle(fontSize: 12)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _row(IconData icon, String text) {
    final show = text.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Expanded(
          child: SelectableText(
            show ? text : '—',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  /// Una línea con dos valores (ej. teléfono · cédula) o uno con sufijo (ej. dirección, sector/ciudad).
  /// Alineado a la izquierda; si maxLines es 1 usa ellipsis para evitar overflow.
  static Widget _oneLine(IconData icon, String? a, String? b, {String? suffix, int maxLines = 1}) {
    final partA = (a ?? '').trim().isEmpty ? null : (a ?? '').trim();
    final partB = (b ?? '').trim().isEmpty ? null : (b ?? '').trim();
    final hasSuffix = suffix != null && suffix.trim().isNotEmpty && suffix != '—';
    String text = '—';
    if (partA != null && partB != null) {
      text = '$partA · $partB';
    } else if (partA != null) {
      text = partA;
    } else if (partB != null) {
      text = partB;
    }
    if (hasSuffix && text != '—') text = '$text · $suffix';
    else if (hasSuffix) text = suffix;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }

  static String _sectorCity(Map<String, dynamic> m) {
    final s = m['sector']?.toString()?.trim() ?? '';
    final c = m['city']?.toString()?.trim() ?? '';
    if (s.isEmpty && c.isEmpty) return '';
    if (s.isEmpty) return c;
    if (c.isEmpty) return s;
    return '$s / $c';
  }
}

class _PersonasTable extends ConsumerWidget {
  const _PersonasTable({
    required this.list,
    required this.page,
    required this.limit,
    required this.total,
    required this.tipoFilter,
    required this.onPageChanged,
    required this.onTipoFilterChanged,
    required this.onEdit,
    required this.onAssignPoints,
  });

  final List<dynamic> list;
  final int page;
  final int limit;
  final int total;
  final String? tipoFilter;
  final void Function(int) onPageChanged;
  final void Function(String?) onTipoFilterChanged;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(BuildContext, WidgetRef, String, String, List<dynamic>) onAssignPoints;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (list.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            children: [
              Icon(Icons.person_outline, size: 64, color: AppColors.textMuted.withOpacity(0.6)),
              const SizedBox(height: 16),
              Text('No hay personas', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Crea la primera con "Nueva persona". Luego en Usuarios vincula un usuario y asígnale rol POS_SELLER para activar comisión.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    final totalPages = (total / limit).ceil().clamp(1, 999999);
    final hasPrev = page > 1;
    final hasNext = page < totalPages;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: AppColors.border.withOpacity(0.25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$total persona${total == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String?>(
                        value: tipoFilter,
                        hint: const Text('Tipo'),
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Todos')),
                          DropdownMenuItem(value: 'VENDEDOR', child: Text('Vendedor')),
                          DropdownMenuItem(value: 'EMPLEADO', child: Text('Empleado')),
                          DropdownMenuItem(value: 'OTRO', child: Text('Otro')),
                        ],
                        onChanged: (v) => onTipoFilterChanged(v),
                      ),
                    ],
                  ),
                ),
                if (totalPages > 1)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_left), onPressed: hasPrev ? () => onPageChanged(page - 1) : null, style: IconButton.styleFrom(padding: const EdgeInsets.all(8))),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('$page / $totalPages', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted))),
                      IconButton(icon: const Icon(Icons.chevron_right), onPressed: hasNext ? () => onPageChanged(page + 1) : null, style: IconButton.styleFrom(padding: const EdgeInsets.all(8))),
                    ],
                  ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              const padding = 16.0;
              final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1));
              final availableWidth = constraints.maxWidth - padding * 2 - spacing * (crossAxisCount - 1);
              final cardWidth = availableWidth / crossAxisCount;
              return Padding(
                padding: const EdgeInsets.all(padding),
                child: Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (var i = 0; i < list.length; i++)
                      SizedBox(
                        width: cardWidth,
                        child: _PersonaCard(
                          persona: list[i] as Map<String, dynamic>,
                          onEdit: () => onEdit(list[i] as Map<String, dynamic>),
                          onAssignPoints: () {
                            final m = list[i] as Map<String, dynamic>;
                            if (m['isVendedor'] == true && m['userId'] != null) {
                              onAssignPoints(context, ref, m['userId'] as String, m['fullName']?.toString() ?? '', m['assignments'] as List<dynamic>? ?? []);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PersonaFormDialog extends ConsumerStatefulWidget {
  const _PersonaFormDialog({this.persona, required this.onSaved});
  final Map<String, dynamic>? persona;
  final VoidCallback onSaved;

  @override
  ConsumerState<_PersonaFormDialog> createState() => _PersonaFormDialogState();
}

class _PersonaFormDialogState extends ConsumerState<_PersonaFormDialog> {
  late final TextEditingController _fullName;
  late final TextEditingController _cedula;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _sector;
  late final TextEditingController _city;
  late final TextEditingController _commissionPercent;
  late String _tipo;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.persona;
    _fullName = TextEditingController(text: p?['fullName']?.toString() ?? '');
    _cedula = TextEditingController(text: _formatCedula(p?['cedula']?.toString()));
    _phone = TextEditingController(text: _formatPhone(p?['phone']?.toString()));
    _email = TextEditingController(text: p?['email']?.toString() ?? '');
    _address = TextEditingController(text: p?['address']?.toString() ?? '');
    _sector = TextEditingController(text: p?['sector']?.toString() ?? '');
    _city = TextEditingController(text: p?['city']?.toString() ?? '');
    _tipo = p?['tipo']?.toString() ?? 'OTRO';
    final commission = p?['defaultCommissionPercent'];
    _commissionPercent = TextEditingController(
      text: commission != null ? commission.toString().replaceFirst(RegExp(r'\.0+$'), '') : '',
    );
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
    _commissionPercent.dispose();
    super.dispose();
  }

  // Colores del sistema: surface, border, textPrimary, textMuted
  static const _spacing = 12.0;

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.persona != null;
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
        constraints: const BoxConstraints(maxWidth: 720),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: atrás, título, botón Guardar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(foregroundColor: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEdit ? 'Editar persona' : 'Nueva persona',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  FilledButton(
                    onPressed: _loading ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sección con título y descripción
                    const Text(
                      'Información de la persona',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Completa los datos. Puedes editarlos después desde esta misma pantalla.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.danger.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, size: 20, color: AppColors.danger),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                          ],
                        ),
                      ),
                    ],
                    // Dos columnas: datos a la izquierda, tipo a la derecha (diálogo más ancho)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final useTwoCols = constraints.maxWidth > 500;
                        final leftCol = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: TextField(controller: _fullName, decoration: inputDec.copyWith(labelText: 'Nombre completo', hintText: 'Ej. Juan Pérez García'))),
                                const SizedBox(width: _spacing),
                                SizedBox(
                                  width: 200,
                                  child: TextField(
                                    controller: _cedula,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [_CedulaInputFormatter(), LengthLimitingTextInputFormatter(13)],
                                    decoration: inputDec.copyWith(labelText: 'Cédula', hintText: '000-0000000-0'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: _spacing),
                            Row(
                              children: [
                                SizedBox(
                                  width: 180,
                                  child: TextField(
                                    controller: _phone,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [_PhoneInputFormatter(), LengthLimitingTextInputFormatter(12)],
                                    decoration: inputDec.copyWith(labelText: 'Teléfono', hintText: '809-555-0000'),
                                  ),
                                ),
                                const SizedBox(width: _spacing),
                                Expanded(child: TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: inputDec.copyWith(labelText: 'Email'))),
                              ],
                            ),
                            const SizedBox(height: _spacing),
                            TextField(controller: _address, decoration: inputDec.copyWith(labelText: 'Dirección')),
                            const SizedBox(height: _spacing),
                            Row(
                              children: [
                                Expanded(child: TextField(controller: _sector, decoration: inputDec.copyWith(labelText: 'Sector'))),
                                const SizedBox(width: _spacing),
                                Expanded(child: TextField(controller: _city, decoration: inputDec.copyWith(labelText: 'Ciudad'))),
                              ],
                            ),
                            if (_tipo == 'VENDEDOR') ...[
                              const SizedBox(height: _spacing),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: _commissionPercent,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                        LengthLimitingTextInputFormatter(5),
                                      ],
                                      decoration: inputDec.copyWith(
                                        labelText: 'Comisión %',
                                        hintText: '0 - 100',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Por defecto para este vendedor (opcional)',
                                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ],
                            if (!useTwoCols) ...[
                              const SizedBox(height: _spacing),
                              DropdownButtonFormField<String>(
                                value: _tipo,
                                decoration: inputDec.copyWith(labelText: 'Tipo de persona'),
                                isExpanded: true,
                                menuMaxHeight: 220,
                                borderRadius: BorderRadius.circular(10),
                                items: const [
                                  DropdownMenuItem(value: 'VENDEDOR', child: Text('Vendedor')),
                                  DropdownMenuItem(value: 'EMPLEADO', child: Text('Empleado')),
                                  DropdownMenuItem(value: 'OTRO', child: Text('Otro')),
                                ],
                                onChanged: (v) => setState(() => _tipo = v ?? 'OTRO'),
                              ),
                            ],
                          ],
                        );
                        if (!useTwoCols) return leftCol;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: leftCol),
                            const SizedBox(width: 24),
                            SizedBox(
                              width: 200,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text('Tipo de persona', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: _tipo,
                                    decoration: inputDec.copyWith(labelText: null, hintText: 'Seleccionar'),
                                    isExpanded: true,
                                    menuMaxHeight: 220,
                                    borderRadius: BorderRadius.circular(10),
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
                          ],
                        );
                      },
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

  Future<void> _save() async {
    if (_fullName.text.trim().isEmpty) {
      setState(() => _error = 'Nombre requerido');
      return;
    }
    final commissionStr = _commissionPercent.text.trim();
    final defaultCommissionPercent = commissionStr.isEmpty
        ? null
        : (double.tryParse(commissionStr.replaceAll(',', '.')));
    if (_tipo == 'VENDEDOR' && defaultCommissionPercent != null && (defaultCommissionPercent < 0 || defaultCommissionPercent > 100)) {
      setState(() => _error = 'Comisión debe estar entre 0 y 100');
      return;
    }
    setState(() { _error = null; _loading = true; });
    final body = {
      'fullName': _fullName.text.trim(),
      'cedula': _cedula.text.trim().isEmpty ? null : _cedula.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'sector': _sector.text.trim().isEmpty ? null : _sector.text.trim(),
      'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
      'tipo': _tipo,
      if (_tipo == 'VENDEDOR') 'defaultCommissionPercent': defaultCommissionPercent,
    };
    final result = widget.persona != null
        ? await updatePersonaWithError(ref, widget.persona!['id'] as String, body)
        : await createPersonaWithError(ref, body);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.data != null) {
      widget.onSaved();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Persona guardada')));
    } else {
      setState(() => _error = result.error ?? 'Error al guardar');
    }
  }
}

class _AssignPointsDialog extends ConsumerStatefulWidget {
  const _AssignPointsDialog({
    required this.userId,
    required this.fullName,
    required this.initialAssignments,
    required this.ref,
    required this.onSaved,
  });
  final String userId;
  final String fullName;
  final List<dynamic> initialAssignments;
  final WidgetRef ref;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AssignPointsDialog> createState() => _AssignPointsDialogState();
}

class _AssignPointsDialogState extends ConsumerState<_AssignPointsDialog> {
  late final Map<String, double> _commissionByPointId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _commissionByPointId = {};
    for (final a in widget.initialAssignments) {
      final m = a as Map<String, dynamic>;
      final pointId = m['pointId']?.toString();
      if (pointId != null) {
        final v = m['commissionPercent'];
        _commissionByPointId[pointId] = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
      }
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
          Expanded(child: Text('Asignar puntos: ${widget.fullName}', overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: pointsAsync.when(
          data: (points) {
            if (points.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No hay puntos de venta. Crea puntos en el módulo POS.'),
              );
            }
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selecciona puntos y comisión % (rol Vendedor activa este campo)', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textMuted)),
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e', style: TextStyle(color: AppColors.danger)),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving ? null : () => _save(),
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final body = _commissionByPointId.entries.map((e) => {'pointId': e.key, 'commissionPercent': e.value}).toList();
    await setVendorAssignments(widget.ref, widget.userId, body);
    if (!mounted) return;
    setState(() => _saving = false);
    widget.ref.invalidate(personasListProvider);
    widget.onSaved();
    if (mounted) Navigator.of(context).pop();
  }
}
