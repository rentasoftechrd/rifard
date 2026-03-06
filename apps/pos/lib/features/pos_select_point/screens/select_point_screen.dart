import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/http/api_client.dart';
import '../../../core/session/pos_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class SelectPointScreen extends ConsumerStatefulWidget {
  const SelectPointScreen({super.key});

  @override
  ConsumerState<SelectPointScreen> createState() => _SelectPointScreenState();
}

class _SelectPointScreenState extends ConsumerState<SelectPointScreen> {
  List<Map<String, dynamic>> _points = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    final resp = await api.get('/pos/points');
    if (resp.statusCode == 200) {
      final list = _parsePointsList(resp.body);
      setState(() {
        _points = list;
        _loading = false;
      });
    } else {
      setState(() {
        _error = 'Failed to load points';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _parsePointsList(String s) {
    try {
      final decoded = jsonDecode(s);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (decoded is Map && decoded['data'] is List) {
        return (decoded['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Seleccionar punto de venta', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(apiClientProvider).setToken(null);
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              itemCount: _points.length,
              itemBuilder: (_, i) {
                final p = _points[i];
                final name = p['name'] ?? p['code'] ?? 'Point';
                final pointId = p['id']?.toString();
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.2), child: Icon(Icons.store, color: AppColors.primary)),
                    title: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(p['code']?.toString() ?? '', style: const TextStyle(color: AppColors.textMuted)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () async {
                      final id = pointId?.trim().toLowerCase();
                      if (id != null && id.isNotEmpty) {
                        await setPointId(id);
                        ref.invalidate(posSessionProvider);
                        if (mounted) context.go('/home');
                      } else {
                        context.go('/printer-setup');
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
