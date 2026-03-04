import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/http/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({super.key, required this.code});
  final String code;

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  Map<String, dynamic>? _ticket;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    final resp = await api.get('/tickets/code/${widget.code}');
    if (resp.statusCode == 200) {
      setState(() {
        _ticket = Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
        _loading = false;
      });
    } else {
      setState(() {
        _error = 'Ticket no encontrado';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ticket')),
        body: Center(child: Text(_error!)),
      );
    }
    final t = _ticket!;
    return Scaffold(
      appBar: AppBar(title: Text('Ticket ${t['ticketCode'] ?? widget.code}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Código: ${t['ticketCode'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Total: \$${t['totalAmount'] ?? '0'}'),
          Text('Estado: ${t['status'] ?? ''}'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/sell'),
            child: const Text('Nueva venta'),
          ),
        ],
      ),
    );
  }
}
