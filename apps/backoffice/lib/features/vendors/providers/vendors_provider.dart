import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/http/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class VendorAssignment {
  VendorAssignment({
    required this.pointId,
    required this.pointName,
    required this.pointCode,
    required this.commissionPercent,
  });
  final String pointId;
  final String pointName;
  final String pointCode;
  final double commissionPercent;
}

class VendorPersona {
  VendorPersona({
    required this.id,
    required this.fullName,
    this.cedula,
    this.phone,
    this.email,
    this.address,
    this.sector,
    this.city,
    this.tipo,
  });
  final String id;
  final String fullName;
  final String? cedula;
  final String? phone;
  final String? email;
  final String? address;
  final String? sector;
  final String? city;
  final String? tipo;
}

class VendorListItem {
  VendorListItem({
    required this.id,
    required this.fullName,
    required this.email,
    required this.assignments,
    this.persona,
  });
  final String id;
  final String fullName;
  final String email;
  final List<VendorAssignment> assignments;
  final VendorPersona? persona;
}

Future<List<VendorListItem>> fetchVendors(Ref ref) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.get('/vendors');
  if (resp.statusCode != 200) return [];
  try {
    final list = jsonDecode(resp.body) as List<dynamic>? ?? [];
    return list.map<VendorListItem>((raw) {
      final m = raw as Map<String, dynamic>;
      final assignments = (m['assignments'] as List<dynamic>? ?? []).map<VendorAssignment>((a) {
        final am = a as Map<String, dynamic>;
        double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
        return VendorAssignment(
          pointId: am['pointId']?.toString() ?? '',
          pointName: am['pointName']?.toString() ?? '',
          pointCode: am['pointCode']?.toString() ?? '',
          commissionPercent: _d(am['commissionPercent']),
        );
      }).toList();
      final p = m['persona'] as Map<String, dynamic>?;
      VendorPersona? persona;
      if (p != null) {
        persona = VendorPersona(
          id: p['id']?.toString() ?? '',
          fullName: p['fullName']?.toString() ?? '',
          cedula: p['cedula']?.toString(),
          phone: p['phone']?.toString(),
          email: p['email']?.toString(),
          address: p['address']?.toString(),
          sector: p['sector']?.toString(),
          city: p['city']?.toString(),
          tipo: p['tipo']?.toString(),
        );
      }
      return VendorListItem(
        id: m['id']?.toString() ?? '',
        fullName: m['fullName']?.toString() ?? '',
        email: m['email']?.toString() ?? '',
        assignments: assignments,
        persona: persona,
      );
    }).toList();
  } catch (_) {
    return [];
  }
}

final vendorsProvider = FutureProvider.autoDispose<List<VendorListItem>>((ref) => fetchVendors(ref));

class PosPointOption {
  PosPointOption({required this.id, required this.name, required this.code});
  final String id;
  final String name;
  final String code;
}

Future<List<PosPointOption>> fetchVendorPoints(Ref ref) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.get('/vendors/points');
  if (resp.statusCode != 200) return [];
  try {
    final list = jsonDecode(resp.body) as List<dynamic>? ?? [];
    return list.map<PosPointOption>((raw) {
      final m = raw as Map<String, dynamic>;
      return PosPointOption(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        code: m['code']?.toString() ?? '',
      );
    }).toList();
  } catch (_) {
    return [];
  }
}

final vendorPointsProvider = FutureProvider.autoDispose<List<PosPointOption>>((ref) => fetchVendorPoints(ref));

Future<VendorListItem?> setVendorAssignments(dynamic ref, String userId, List<Map<String, dynamic>> assignments) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.put('/vendors/$userId/assignments', body: {'assignments': assignments});
  if (resp.statusCode != 200) return null;
  ref.invalidate(vendorsProvider);
  try {
    final raw = jsonDecode(resp.body) as Map<String, dynamic>?;
    if (raw == null) return null;
    final list = (raw['assignments'] as List<dynamic>? ?? []).map<VendorAssignment>((a) {
      final am = a as Map<String, dynamic>;
      double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
      return VendorAssignment(
        pointId: am['pointId']?.toString() ?? '',
        pointName: am['pointName']?.toString() ?? '',
        pointCode: am['pointCode']?.toString() ?? '',
        commissionPercent: _d(am['commissionPercent']),
      );
    }).toList();
    final p = raw['persona'] as Map<String, dynamic>?;
    VendorPersona? persona;
    if (p != null) {
      persona = VendorPersona(
        id: p['id']?.toString() ?? '',
        fullName: p['fullName']?.toString() ?? '',
        cedula: p['cedula']?.toString(),
        phone: p['phone']?.toString(),
        email: p['email']?.toString(),
        address: p['address']?.toString(),
        sector: p['sector']?.toString(),
        city: p['city']?.toString(),
        tipo: p['tipo']?.toString(),
      );
    }
    return VendorListItem(
      id: raw['id']?.toString() ?? userId,
      fullName: raw['fullName']?.toString() ?? '',
      email: raw['email']?.toString() ?? '',
      assignments: list,
      persona: persona,
    );
  } catch (_) {
    return null;
  }
}
