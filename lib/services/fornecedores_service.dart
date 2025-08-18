// lib/services/fornecedores_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fornecedor.dart';

class FornecedoresService {
  final _col = FirebaseFirestore.instance.collection('fornecedores');

  // ---------- utils ----------
  static String _norm(String s) => s.toLowerCase().trim();

  static Map<String, dynamic> _baseMapFromModel(Fornecedor f, {bool includeUpdated = true}) {
    final map = <String, dynamic>{
      'nome': f.nome,
      'nome_normalizado': _norm(f.nome),
      if (f.email != null) 'email': f.email,
      if (f.telefone != null) 'telefone': f.telefone,
      if (f.contato != null) 'contato': f.contato,
      if (f.notas != null) 'notas': f.notas,
    };
    if (includeUpdated) {
      map['atualizado_em'] = FieldValue.serverTimestamp();
    }
    return map;
  }

  // ---------- streams / reads ----------
  Stream<List<Fornecedor>> streamAll() {
    return _col.orderBy('nome_normalizado').snapshots().map((qs) {
      return qs.docs.map((d) => Fornecedor.fromMap(d.id, d.data())).toList();
    });
  }

  /// Busca reativa por prefixo (case-insensitive) no nome.
  Stream<List<Fornecedor>> streamSearchByPrefix(String prefix) {
    final p = _norm(prefix);
    if (p.isEmpty) return streamAll();
    final end = '$p\uf8ff';
    final q = _col
        .orderBy('nome_normalizado')
        .where('nome_normalizado', isGreaterThanOrEqualTo: p)
        .where('nome_normalizado', isLessThanOrEqualTo: end);
    return q.snapshots().map((qs) => qs.docs.map((d) => Fornecedor.fromMap(d.id, d.data())).toList());
  }

  Future<Fornecedor?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Fornecedor.fromMap(doc.id, doc.data()!);
  }

  Future<Fornecedor?> findByNome(String nome) async {
    final qs = await _col
        .where('nome_normalizado', isEqualTo: _norm(nome))
        .limit(1)
        .get();
    if (qs.docs.isEmpty) return null;
    final d = qs.docs.first;
    return Fornecedor.fromMap(d.id, d.data());
  }

  Future<bool> existsByNome(String nome) async {
    final qs = await _col
        .where('nome_normalizado', isEqualTo: _norm(nome))
        .limit(1)
        .get();
    return qs.docs.isNotEmpty;
  }

  Future<Map<String, Fornecedor>> mapPorNomeNormalizado() async {
    final qs = await _col.get();
    final map = <String, Fornecedor>{};
    for (final d in qs.docs) {
      final f = Fornecedor.fromMap(d.id, d.data());
      map[_norm(f.nome)] = f;
    }
    return map;
  }

  Future<Map<String, Fornecedor>> mapPorId() async {
    final qs = await _col.get();
    final map = <String, Fornecedor>{};
    for (final d in qs.docs) {
      map[d.id] = Fornecedor.fromMap(d.id, d.data());
    }
    return map;
  }

  // ---------- writes ----------
  Future<String> add(Fornecedor f) async {
    final map = _baseMapFromModel(f);
    map['criado_em'] = FieldValue.serverTimestamp();
    final doc = await _col.add(map);
    return doc.id;
  }

  Future<void> update(String id, Fornecedor f) async {
    final map = _baseMapFromModel(f);
    await _col.doc(id).update(map);
  }

  Future<void> updateFields(String id, Map<String, dynamic> partial) async {
    final map = <String, dynamic>{
      ...partial,
      'atualizado_em': FieldValue.serverTimestamp(),
    };
    if (map.containsKey('nome')) {
      map['nome_normalizado'] = _norm(map['nome']?.toString() ?? '');
    }
    await _col.doc(id).update(map);
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  /// Upsert por nome, sem query na transação:
  /// usa docId = nome_normalizado (determinístico) e faz set(merge:true).
  Future<void> upsertByNome(Fornecedor f) async {
    final norm = _norm(f.nome);
    final ref = _col.doc(norm); // ID fixo = nome_normalizado

    final snap = await ref.get();
    final data = _baseMapFromModel(f);
    if (!snap.exists) {
      data['criado_em'] = FieldValue.serverTimestamp();
    }
    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> setEmailForId(String id, String? email) async {
    final val = (email ?? '').trim();
    await updateFields(id, {
      'email': val.isEmpty ? null : val,
    });
  }

  Future<void> setEmailForNome(String nome, String? email) async {
    final val = (email ?? '').trim();
    await upsertByNome(Fornecedor(
      nome: nome,
      email: val.isEmpty ? null : val,
    ));
  }

  /// Importação em lote; se `matchByNome=true`, usa ID = nome_normalizado
  /// (upsert). Caso contrário, cria novos IDs.
  Future<int> bulkUpsert(List<Fornecedor> items, {bool matchByNome = true}) async {
    if (items.isEmpty) return 0;

    const int maxOps = 400; // margem
    int written = 0;

    WriteBatch? batch;
    int ops = 0;

    Future<void> _commit() async {
      if (batch != null && ops > 0) {
        await batch!.commit();
        written += ops;
      }
      batch = FirebaseFirestore.instance.batch();
      ops = 0;
    }

    await _commit();

    for (final f in items) {
      final data = _baseMapFromModel(f);
      data['criado_em'] = FieldValue.serverTimestamp();

      DocumentReference<Map<String, dynamic>> ref;
      if (matchByNome) {
        ref = _col.doc(_norm(f.nome)); // upsert
      } else {
        ref = _col.doc(); // novo doc
      }

      batch!.set(ref, data, SetOptions(merge: true));
      ops++;
      if (ops >= maxOps) {
        await _commit();
      }
    }

    await _commit();
    return written;
  }
}
