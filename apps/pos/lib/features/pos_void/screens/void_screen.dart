import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/http/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class VoidScreen extends ConsumerStatefulWidget {
  const VoidScreen({super.key});

  @override
  ConsumerState<VoidScreen> createState() => _VoidScreenState();
}

class _VoidScreenState extends ConsumerState<VoidScreen> {
  final _codeController = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _voidTicket() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Ingrese código de ticket');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final api = ref.read(apiClientProvider);
      final getResp = await api.get('/tickets/code/$code');
      if (getResp.statusCode != 200) {
        setState(() {
          _error = 'Ticket no encontrado';
          _loading = false;
        });
        return;
      }
      final data = jsonDecode(getResp.body) as Map;
      final id = data['id'] as String?;
      if (id == null) {
        setState(() {
          _error = 'Ticket sin ID';
          _loading = false;
        });
        return;
      }
      final voidResp = await api.post('/tickets/$id/void', body: {});
      if (voidResp.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket anulado')));
        if (mounted) context.go('/sell');
      } else {
        final err = jsonDecode(voidResp.body) as Map;
        setState(() {
          _error = err['code']?.toString() ?? err['message']?.toString() ?? 'Error al anular';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anular ticket'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/sell')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Código de ticket', border: OutlineInputBorder()),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _voidTicket(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _voidTicket,
              child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Anular'),
            ),
          ],
        ),
      ),
    );
  }
}
