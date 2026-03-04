import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/http/api_client.dart';
import '../../../core/session/pos_session.dart';
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar punto'), actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await ref.read(apiClientProvider).setToken(null);
            if (mounted) context.go('/login');
          },
        ),
      ]),
      body: _error != null
          ? Center(child: Text(_error!))
          : ListView.builder(
              itemCount: _points.length,
              itemBuilder: (_, i) {
                final p = _points[i];
                final name = p['name'] ?? p['code'] ?? 'Point';
                final pointId = p['id']?.toString();
                return ListTile(
                  title: Text(name),
                  subtitle: Text(p['code']?.toString() ?? ''),
                  onTap: () async {
                    if (pointId != null && pointId.isNotEmpty) {
                      await setPointId(pointId);
                      ref.invalidate(posSessionProvider);
                      if (mounted) context.go('/sell');
                    } else {
                      context.go('/printer-setup');
                    }
                  },
                );
              },
            ),
    );
  }
}
