// lib/services/authz_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

class AuthorizedUser {
  final String id;
  final String nome;
  final bool ativo;
  final bool isAdmin;
  final String role; // 'admin' | 'operator'

  AuthorizedUser({
    required this.id,
    required this.nome,
    required this.ativo,
    required this.isAdmin,
    required this.role,
  });

  factory AuthorizedUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};
    final isAdminFlag = (data['is_admin'] ?? false) as bool;

    // role normalizado
    String role = (data['role'] ?? (isAdminFlag ? 'admin' : 'operator'))
        .toString()
        .toLowerCase()
        .trim();
    if (role == 'user') role = 'operator'; // migração silenciosa

    final isAdmin = isAdminFlag || role == 'admin';

    return AuthorizedUser(
      id: d.id,
      nome: (data['nome'] ?? '').toString(),
      ativo: (data['ativo'] ?? true) as bool,
      isAdmin: isAdmin,
      role: role,
    );
  }
}

class VerifyResult {
  final bool ok;
  final bool isAdmin;
  final String nome;
  final String role;
  VerifyResult({
    required this.ok,
    required this.isAdmin,
    required this.nome,
    required this.role,
  });
}

class AuthzService {
  final _col = FirebaseFirestore.instance.collection('autorizados');

  String normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String hashKey(String key) => sha256.convert(utf8.encode(key)).toString();

  /// Verifica nome + chave. Aceita `chave_hash` (sha256) OU `chave` simples (se existir).
  /// Retorna tb o papel (role) e se é admin.
  Future<VerifyResult> verifyWithRole({
    required String nome,
    required String chave,
  }) async {
    final norm = normalize(nome);

    final q = await _col
        .where('nome_normalizado', isEqualTo: norm)
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      return VerifyResult(ok: false, isAdmin: false, nome: nome, role: 'operator');
    }

    final data = q.docs.first.data();

    // ativo?
    final ativo = (data['ativo'] ?? true) as bool;
    final storedName = (data['nome'] ?? nome).toString();

    // role normalizado
    String role = (data['role'] ?? '').toString().toLowerCase().trim();
    if (role.isEmpty) role = ((data['is_admin'] ?? false) as bool) ? 'admin' : 'operator';
    if (role == 'user') role = 'operator'; // compat

    // admin final: flag OR role
    final isAdmin = ((data['is_admin'] ?? false) as bool) || role == 'admin';

    if (!ativo) {
      return VerifyResult(ok: false, isAdmin: isAdmin, nome: storedName, role: role);
    }

    // credenciais (hash ou simples)
    final hashArmazenado = (data['chave_hash'] ?? '').toString();
    final chavePlanaArmazenada = (data['chave'] ?? '').toString();

    final ok = (hashArmazenado.isNotEmpty && hashArmazenado == hashKey(chave)) ||
               (chavePlanaArmazenada.isNotEmpty && chavePlanaArmazenada == chave);

    return VerifyResult(ok: ok, isAdmin: isAdmin, nome: storedName, role: role);
  }

  /// Compat: só diz se passou
  Future<bool> verify({required String nome, required String chave}) async {
    final r = await verifyWithRole(nome: nome, chave: chave);
    return r.ok;
  }

  /// Lista todos (para AdminPage)
  Stream<List<AuthorizedUser>> streamAll() {
    return _col
        .orderBy('nome')
        .snapshots()
        .map((q) => q.docs.map(AuthorizedUser.fromDoc).toList());
  }

  /// Adiciona um autorizado.
  /// `role`: 'operator' (padrão) ou 'admin'. Mantém também `is_admin` por compat.
  Future<void> addAuthorized({
    required String nome,
    required String chave,
    bool ativo = true,
    bool isAdmin = false,
    String role = 'operator',
  }) async {
    final roleNorm = role.toLowerCase().trim() == 'admin' ? 'admin' : 'operator';
    await _col.add({
      'nome': nome.trim(),
      'nome_normalizado': normalize(nome),
      'chave_hash': hashKey(chave),
      // opcional: se quiser compat com legado, descomente:
      // 'chave': chave.trim(),
      'ativo': ativo,
      'is_admin': isAdmin || roleNorm == 'admin',
      'role': roleNorm,
      'criado_em': FieldValue.serverTimestamp(),
      'atualizado_em': FieldValue.serverTimestamp(),
    });
  }

  /// Atualiza campos do autorizado. Deixe parâmetros nulos para manter.
  Future<void> updateAuthorized({
    required String id,
    String? novoNome,
    String? novaChave,
    bool? ativo,
    bool? isAdmin,
    String? novoRole,
  }) async {
    final data = <String, dynamic>{
      'atualizado_em': FieldValue.serverTimestamp(),
    };

    if (novoNome != null && novoNome.trim().isNotEmpty) {
      data['nome'] = novoNome.trim();
      data['nome_normalizado'] = normalize(novoNome);
    }
    if (novaChave != null && novaChave.trim().isNotEmpty) {
      data['chave_hash'] = hashKey(novaChave.trim());
      // opcional:
      // data['chave'] = novaChave.trim();
    }
    if (ativo != null) data['ativo'] = ativo;

    if (novoRole != null && novoRole.trim().isNotEmpty) {
      final roleNorm = novoRole.toLowerCase().trim() == 'admin' ? 'admin' : 'operator';
      data['role'] = roleNorm;
      // se não vier isAdmin explícito, mantém coerência
      if (isAdmin == null) data['is_admin'] = (roleNorm == 'admin');
    }
    if (isAdmin != null) data['is_admin'] = isAdmin;

    await _col.doc(id).update(data);
  }

  // Helpers usados na AdminPage
  Future<void> updateName({required String id, required String novoNome}) =>
      updateAuthorized(id: id, novoNome: novoNome);

  Future<void> resetKey({required String id, required String novaChave}) =>
      updateAuthorized(id: id, novaChave: novaChave);

  Future<void> toggleActive(String id, bool ativo) async {
    await _col.doc(id).update({
      'ativo': ativo,
      'atualizado_em': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
