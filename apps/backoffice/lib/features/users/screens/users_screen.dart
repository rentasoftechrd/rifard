import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../../personas/providers/personas_provider.dart';
import '../providers/users_provider.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  int _page = 1;
  static const int _limit = 20;

  void _openCreate() {
    showDialog<void>(
      context: context,
      builder: (_) => _UserFormDialog(
        mode: _FormMode.create,
        onSaved: () => ref.invalidate(usersListProvider),
      ),
    );
  }

  void _openEdit(Map<String, dynamic> user) {
    showDialog<void>(
      context: context,
      builder: (_) => _UserFormDialog(
        mode: _FormMode.edit,
        user: user,
        onSaved: () => ref.invalidate(usersListProvider),
      ),
    );
  }

  void _openRoles(Map<String, dynamic> user) {
    showDialog<void>(
      context: context,
      builder: (_) => _AssignRolesDialog(
        user: user,
        onSaved: () => ref.invalidate(usersListProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(usersListProvider((page: _page, limit: _limit)));

    return AppShell(
      currentPath: '/users',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people, color: AppColors.primary, size: 26),
                              const SizedBox(width: 10),
                              Text(
                                'Usuarios y roles',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 560,
                            child: Text(
                              'Crear y editar usuarios, asignar roles y activar o desactivar.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textMuted,
                                height: 1.35,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: _openCreate,
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Nuevo usuario'),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  listAsync.when(
            data: (payload) {
              final data = payload['data'] as List<dynamic>? ?? [];
              final meta = payload['meta'] as Map<String, dynamic>? ?? {};
              final total = meta['total'] as int? ?? 0;
              return _UsersTable(
                list: data,
                page: _page,
                limit: _limit,
                total: total,
                onPageChanged: (p) => setState(() => _page = p),
                onEdit: _openEdit,
                onAssignRoles: _openRoles,
                onToggleActive: _toggleActive,
              );
            },
            loading: () => const Center(
              child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()),
            ),
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
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    final id = user['id'] as String?;
    if (id == null) return;
    final active = user['active'] as bool? ?? true;
    final ok = await setUserActive(ref, id, !active);
    if (!mounted) return;
    if (ok) {
      ref.invalidate(usersListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(active ? 'Usuario desactivado' : 'Usuario activado')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cambiar estado')),
      );
    }
  }
}

class _UsersTable extends StatelessWidget {
  const _UsersTable({
    required this.list,
    required this.page,
    required this.limit,
    required this.total,
    required this.onPageChanged,
    required this.onEdit,
    required this.onAssignRoles,
    required this.onToggleActive,
  });

  final List<dynamic> list;
  final int page;
  final int limit;
  final int total;
  final void Function(int) onPageChanged;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onAssignRoles;
  final void Function(Map<String, dynamic>) onToggleActive;

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            children: [
              Icon(Icons.people_outline, size: 64, color: AppColors.textMuted.withOpacity(0.6)),
              const SizedBox(height: 16),
              Text('No hay usuarios', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Crea el primer usuario con el botón "Nuevo usuario".',
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
                Text(
                  '$total usuario${total == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (totalPages > 1)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 22),
                        onPressed: hasPrev ? () => onPageChanged(page - 1) : null,
                        style: IconButton.styleFrom(padding: const EdgeInsets.all(8)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('$page / $totalPages', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 22),
                        onPressed: hasNext ? () => onPageChanged(page + 1) : null,
                        style: IconButton.styleFrom(padding: const EdgeInsets.all(8)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 52,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 72,
              columnSpacing: 24,
              horizontalMargin: 20,
              columns: [
                DataColumn(label: Text('ID Persona', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Nombre', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Email', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Roles', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Activo', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Acciones', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              ],
              rows: list.map<DataRow>((e) {
                final row = e as Map<String, dynamic>;
                final userRoles = row['userRoles'] as List<dynamic>? ?? [];
                final rolesStr = userRoles
                    .map((r) => (r as Map<String, dynamic>)['role']?['code']?.toString())
                    .whereType<String>()
                    .join(', ');
                final persona = row['persona'] as Map<String, dynamic>?;
                final personaId = row['personaId']?.toString() ?? persona?['id']?.toString() ?? '—';
                final active = row['active'] as bool? ?? true;
                return DataRow(
                  cells: [
                    DataCell(
                      Tooltip(
                        message: personaId,
                        child: Text(
                          personaId == '—' ? '—' : personaId.length > 12 ? '${personaId.substring(0, 8)}…' : personaId,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                    DataCell(Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        row['fullName']?.toString() ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                    )),
                    DataCell(Text(row['email']?.toString() ?? '—', style: TextStyle(color: AppColors.textMuted, fontSize: 14))),
                    DataCell(Text(rolesStr.isEmpty ? '—' : rolesStr, style: const TextStyle(fontSize: 14))),
                    DataCell(Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: _ActiveChip(active: active))),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filledTonal(
                              onPressed: () => onEdit(row),
                              icon: const Icon(Icons.edit_outlined, size: 22),
                              tooltip: 'Editar',
                              style: IconButton.styleFrom(padding: const EdgeInsets.all(10), minimumSize: const Size(44, 44)),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: () => onAssignRoles(row),
                              icon: const Icon(Icons.badge_outlined, size: 22),
                              tooltip: 'Asignar roles',
                              style: IconButton.styleFrom(padding: const EdgeInsets.all(10), minimumSize: const Size(44, 44)),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: () => onToggleActive(row),
                              icon: Icon(active ? Icons.toggle_on : Icons.toggle_off, size: 30, color: active ? AppColors.warning : AppColors.success),
                              tooltip: active ? 'Desactivar' : 'Activar',
                              style: IconButton.styleFrom(padding: const EdgeInsets.all(6), minimumSize: const Size(44, 44)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
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
      label: Text(active ? 'Sí' : 'No', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      backgroundColor: active ? AppColors.success.withOpacity(0.2) : AppColors.textMuted.withOpacity(0.2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );
  }
}

enum _FormMode { create, edit }

class _UserFormDialog extends ConsumerStatefulWidget {
  const _UserFormDialog({required this.mode, this.user, required this.onSaved});
  final _FormMode mode;
  final Map<String, dynamic>? user;
  final VoidCallback onSaved;

  @override
  ConsumerState<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<_UserFormDialog> {
  late final TextEditingController _passwordController;
  late final TextEditingController _personaFullName;
  late final TextEditingController _personaCedula;
  late final TextEditingController _personaPhone;
  late final TextEditingController _personaEmail;
  late final TextEditingController _personaAddress;
  late final TextEditingController _personaSector;
  late final TextEditingController _personaCity;
  late bool _active;
  List<String> _selectedRoleIds = [];
  String? _selectedPersonaId;
  bool _createNewPersona = false;
  String _personaTipo = 'OTRO';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _passwordController = TextEditingController();
    _personaFullName = TextEditingController();
    _personaCedula = TextEditingController();
    _personaPhone = TextEditingController();
    _personaEmail = TextEditingController();
    _personaAddress = TextEditingController();
    _personaSector = TextEditingController();
    _personaCity = TextEditingController();
    _active = u?['active'] as bool? ?? true;
    final persona = u?['persona'] as Map<String, dynamic>?;
    if (persona != null) {
      _selectedPersonaId = persona['id']?.toString();
      _personaTipo = persona['tipo']?.toString() ?? 'OTRO';
    }
    final userRoles = u?['userRoles'] as List<dynamic>? ?? [];
    _selectedRoleIds = userRoles
        .map((r) => (r as Map<String, dynamic>)['role']?['id']?.toString())
        .whereType<String>()
        .toList();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _personaFullName.dispose();
    _personaCedula.dispose();
    _personaPhone.dispose();
    _personaEmail.dispose();
    _personaAddress.dispose();
    _personaSector.dispose();
    _personaCity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.mode == _FormMode.edit;
    final rolesAsync = ref.watch(rolesListProvider);

    // Mismo diseño que el diálogo de Personas: card surface, header con botón Guardar
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
    const spacing = 12.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 560),
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
                      isEdit ? 'Editar usuario' : 'Nuevo usuario',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 512),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    const Text(
                      'Información del usuario',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Elige la persona y define contraseña y roles. Nombre, email y teléfono se toman de la persona.',
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
                    const Text('Persona', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _PersonaSelector(
                      selectedId: _selectedPersonaId,
                      createNew: _createNewPersona,
                      onSelect: (id) => setState(() { _selectedPersonaId = id; _createNewPersona = id == '__new__'; }),
                      onTipoChange: (v) => setState(() => _personaTipo = v ?? 'OTRO'),
                      personaTipo: _personaTipo,
                      inputDecoration: inputDec,
                    ),
                    if (!_createNewPersona && _selectedPersonaId != null && _selectedPersonaId != '__new__') ...[
                      SizedBox(height: spacing),
                      _PersonaEmailPreview(personaId: _selectedPersonaId!),
                    ],
                    if (_createNewPersona) ...[
                      SizedBox(height: spacing),
                      _NewPersonaForm(
                        fullName: _personaFullName,
                        cedula: _personaCedula,
                        phone: _personaPhone,
                        email: _personaEmail,
                        address: _personaAddress,
                        sector: _personaSector,
                        city: _personaCity,
                        tipo: _personaTipo,
                        onTipoChanged: (v) => setState(() => _personaTipo = v ?? 'OTRO'),
                        inputDecoration: inputDec,
                      ),
                    ],
                    if (isEdit && _selectedPersonaId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Persona vinculada. Edita sus datos en Personas si hace falta.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                      ),
                    SizedBox(height: spacing),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: inputDec.copyWith(
                        labelText: isEdit ? 'Nueva contraseña (dejar vacío para no cambiar)' : 'Contraseña',
                      ),
                    ),
                    SizedBox(height: spacing),
                    SwitchListTile(
                      title: const Text('Activo', style: TextStyle(color: AppColors.textPrimary)),
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    const Text('Roles', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    rolesAsync.when(
                      data: (roles) {
                        return Column(
                          children: roles.map((r) {
                            final id = r['id']?.toString() ?? '';
                            final code = r['code']?.toString() ?? '';
                            final name = r['name']?.toString() ?? code;
                            final selected = _selectedRoleIds.contains(id);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (selected) {
                                    _selectedRoleIds = _selectedRoleIds.where((e) => e != id).toList();
                                  } else {
                                    _selectedRoleIds = [..._selectedRoleIds, id];
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: selected,
                                        onChanged: (v) {
                                          setState(() {
                                            if (v == true) {
                                              _selectedRoleIds = [..._selectedRoleIds, id];
                                            } else {
                                              _selectedRoleIds = _selectedRoleIds.where((e) => e != id).toList();
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '$name ($code)',
                                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                      error: (e, _) => Text('Error: $e', style: TextStyle(color: AppColors.danger, fontSize: 13)),
                    ),
                  ],
                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    final isEdit = widget.mode == _FormMode.edit;

    String? personaId = _selectedPersonaId;
    if (_createNewPersona) {
      final pName = _personaFullName.text.trim();
      if (pName.isEmpty) {
        setState(() => _error = 'Nombre de la persona requerido si creas nueva');
        return;
      }
      final personaEmail = _personaEmail.text.trim();
      if (personaEmail.isEmpty) {
        setState(() => _error = 'La persona debe tener email (para el login del usuario)');
        return;
      }
      final personaBody = {
        'fullName': pName,
        'cedula': _personaCedula.text.trim().isEmpty ? null : _personaCedula.text.trim(),
        'phone': _personaPhone.text.trim().isEmpty ? null : _personaPhone.text.trim(),
        'email': personaEmail.isEmpty ? null : personaEmail,
        'address': _personaAddress.text.trim().isEmpty ? null : _personaAddress.text.trim(),
        'sector': _personaSector.text.trim().isEmpty ? null : _personaSector.text.trim(),
        'city': _personaCity.text.trim().isEmpty ? null : _personaCity.text.trim(),
        'tipo': _personaTipo,
      };
      final created = await createPersona(ref, personaBody);
      if (created == null) {
        setState(() => _error = 'Error al crear la persona');
        return;
      }
      personaId = created['id']?.toString();
    } else if (!isEdit && (_selectedPersonaId == '__new__' || _selectedPersonaId == null)) {
      setState(() => _error = 'Selecciona una persona para el usuario');
      return;
    }

    if (!isEdit && password.length < 6) {
      setState(() => _error = 'Contraseña mínimo 6 caracteres');
      return;
    }

    // Traer el email de la persona para guardarlo en la tabla de usuarios
    String? emailParaUsuario;
    if (_createNewPersona) {
      emailParaUsuario = _personaEmail.text.trim();
      if (emailParaUsuario.isEmpty) emailParaUsuario = null;
    } else if (personaId != null && personaId != '__new__') {
      final payload = await ref.read(personasListProvider((page: 1, limit: 200, tipo: null)).future);
      final list = payload['data'] as List<dynamic>? ?? [];
      final persona = list.cast<Map<String, dynamic>>().where((e) => e['id']?.toString() == personaId).toList();
      if (persona.isNotEmpty) {
        final e = persona.first['email']?.toString().trim();
        if (e != null && e.isNotEmpty) emailParaUsuario = e;
      }
    }

    if (!isEdit && emailParaUsuario == null) {
      setState(() => _error = 'La persona debe tener email para el usuario. Edítala en Personas o usa "Crear nueva persona" con email.');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    String? errorMsg;
    if (isEdit) {
      final body = <String, dynamic>{
        'active': _active,
        'personaId': personaId,
      };
      if (password.isNotEmpty) body['password'] = password;
      final result = await updateUserWithError(ref, widget.user!['id'] as String, body);
      errorMsg = result.error;
      if (result.data != null && mounted) {
        setState(() => _loading = false);
        widget.onSaved();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario guardado')));
        return;
      }
    } else {
      final body = <String, dynamic>{
        'personaId': personaId!,
        'password': password,
        'active': _active,
        'roleIds': _selectedRoleIds,
      };
      if (emailParaUsuario != null && emailParaUsuario.isNotEmpty) {
        body['email'] = emailParaUsuario;
      }
      final result = await createUserWithError(ref, body);
      errorMsg = result.error;
      if (result.data != null && mounted) {
        setState(() => _loading = false);
        widget.onSaved();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario guardado')));
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = errorMsg ?? 'Error al guardar. Revisa los datos.';
    });
  }
}

/// Muestra el email de la persona seleccionada (se usará para el usuario). Solo lectura.
class _PersonaEmailPreview extends ConsumerWidget {
  const _PersonaEmailPreview({required this.personaId});
  final String personaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(personasListProvider((page: 1, limit: 200, tipo: null)));
    return async.when(
      data: (payload) {
        final list = payload['data'] as List<dynamic>? ?? [];
        final persona = list.cast<Map<String, dynamic>>().where((e) => e['id']?.toString() == personaId).firstOrNull;
        final email = persona?['email']?.toString().trim();
        if (email == null || email.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 20, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Esta persona no tiene email. Edítala en Personas y añade un email para poder crear el usuario.',
                    style: TextStyle(fontSize: 13, color: AppColors.warning),
                  ),
                ),
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.email_outlined, size: 20, color: AppColors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Email (de la persona)', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    SelectableText(email, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _PersonaSelector extends ConsumerWidget {
  const _PersonaSelector({
    required this.selectedId,
    required this.createNew,
    required this.onSelect,
    required this.onTipoChange,
    required this.personaTipo,
    this.inputDecoration,
  });
  final String? selectedId;
  final bool createNew;
  final void Function(String?) onSelect;
  final void Function(String?) onTipoChange;
  final String personaTipo;
  final InputDecoration? inputDecoration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(personasListProvider((page: 1, limit: 200, tipo: null)));
    final dec = inputDecoration ?? const InputDecoration(border: OutlineInputBorder(), isDense: true);
    return async.when(
      data: (payload) {
        final list = payload['data'] as List<dynamic>? ?? [];
        final items = <DropdownMenuItem<String>>[
          const DropdownMenuItem(value: null, child: Text('Sin vincular')),
          DropdownMenuItem(value: '__new__', child: Text('Crear nueva persona...')),
          ...list.map((e) {
            final m = e as Map<String, dynamic>;
            final id = m['id']?.toString() ?? '';
            final name = m['fullName']?.toString() ?? '';
            final tipo = m['tipo']?.toString() ?? '';
            return DropdownMenuItem(value: id, child: Text('$name ($tipo)'));
          }),
        ];
        final value = createNew ? '__new__' : selectedId;
        return DropdownButtonFormField<String>(
          value: value,
          decoration: dec,
          borderRadius: BorderRadius.circular(10),
          items: items,
          onChanged: (v) => onSelect(v),
        );
      },
      loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Text('Error: $e', style: TextStyle(color: AppColors.danger, fontSize: 12)),
    );
  }
}

class _NewPersonaForm extends StatelessWidget {
  const _NewPersonaForm({
    required this.fullName,
    required this.cedula,
    required this.phone,
    required this.email,
    required this.address,
    required this.sector,
    required this.city,
    required this.tipo,
    required this.onTipoChanged,
    this.inputDecoration,
  });
  final TextEditingController fullName;
  final TextEditingController cedula;
  final TextEditingController phone;
  final TextEditingController email;
  final TextEditingController address;
  final TextEditingController sector;
  final TextEditingController city;
  final String tipo;
  final void Function(String?) onTipoChanged;
  final InputDecoration? inputDecoration;

  @override
  Widget build(BuildContext context) {
    final dec = inputDecoration ?? const InputDecoration(border: OutlineInputBorder(), isDense: true);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Datos de la persona', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          TextField(controller: fullName, decoration: dec.copyWith(labelText: 'Nombre completo')),
          const SizedBox(height: 10),
          TextField(controller: cedula, decoration: dec.copyWith(labelText: 'Cédula')),
          const SizedBox(height: 10),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: dec.copyWith(labelText: 'Teléfono')),
          const SizedBox(height: 10),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: dec.copyWith(labelText: 'Email')),
          const SizedBox(height: 10),
          TextField(controller: address, decoration: dec.copyWith(labelText: 'Dirección')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: sector, decoration: dec.copyWith(labelText: 'Sector'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: city, decoration: dec.copyWith(labelText: 'Ciudad'))),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: tipo,
            decoration: dec.copyWith(labelText: 'Tipo de persona'),
            borderRadius: BorderRadius.circular(10),
            items: const [
              DropdownMenuItem(value: 'VENDEDOR', child: Text('Vendedor')),
              DropdownMenuItem(value: 'EMPLEADO', child: Text('Empleado')),
              DropdownMenuItem(value: 'OTRO', child: Text('Otro')),
            ],
            onChanged: onTipoChanged,
          ),
        ],
      ),
    );
  }
}

class _AssignRolesDialog extends ConsumerStatefulWidget {
  const _AssignRolesDialog({required this.user, required this.onSaved});
  final Map<String, dynamic> user;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AssignRolesDialog> createState() => _AssignRolesDialogState();
}

class _AssignRolesDialogState extends ConsumerState<_AssignRolesDialog> {
  List<String> _selectedRoleIds = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final userRoles = widget.user['userRoles'] as List<dynamic>? ?? [];
    _selectedRoleIds = userRoles
        .map((r) => (r as Map<String, dynamic>)['role']?['id']?.toString())
        .whereType<String>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(rolesListProvider);
    final name = widget.user['fullName']?.toString() ?? widget.user['email']?.toString() ?? 'Usuario';

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.badge, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('Asignar roles: $name', overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],
              rolesAsync.when(
                data: (roles) {
                  return Column(
                    children: roles.map((r) {
                      final id = r['id']?.toString() ?? '';
                      final code = r['code']?.toString() ?? '';
                      final nameRole = r['name']?.toString() ?? code;
                      final selected = _selectedRoleIds.contains(id);
                      return CheckboxListTile(
                        title: Text('$nameRole ($code)'),
                        value: selected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedRoleIds = [..._selectedRoleIds, id];
                            } else {
                              _selectedRoleIds = _selectedRoleIds.where((e) => e != id).toList();
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final result = await assignRoles(ref, widget.user['id'] as String, _selectedRoleIds);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result != null) {
      widget.onSaved();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Roles actualizados')));
    } else {
      setState(() => _error = 'Error al guardar roles');
    }
  }
}
