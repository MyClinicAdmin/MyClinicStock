// lib/services/suppliers_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SuppliersRepository {
  final _col = FirebaseFirestore.instance.collection('fornecedores');

  String normalize(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Stream<List<Fornecedor>> streamAll() {
    return _col.orderBy('nome').snapshots().map((q) {
      return q.docs.map((d) => Fornecedor.fromDoc(d)).toList();
    });
  }

  Future<String> add({required String nome, String? email}) async {
    final data = {
      'nome': nome.trim(),
      'nome_normalizado': normalize(nome),
      'email': (email ?? '').trim(),
      'criado_em': FieldValue.serverTimestamp(),
    };
    final doc = await _col.add(data);
    return doc.id;
  }

  Future<void> update(String id, {required String nome, String? email}) async {
    await _col.doc(id).update({
      'nome': nome.trim(),
      'nome_normalizado': normalize(nome),
      'email': (email ?? '').trim(),
      'atualizado_em': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  Future<String?> getEmailByName(String nome) async {
    final norm = normalize(nome);
    final snap = await _col
        .where('nome_normalizado', isEqualTo: norm)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    final email = (data['email'] ?? '').toString().trim();
    return email.isEmpty ? null : email;
  }

  /// Opcional: popular a coleção fornecedores a partir dos nomes de 'produtos'
  Future<void> seedFromProdutos() async {
    final produtosSnap =
        await FirebaseFirestore.instance.collection('produtos').get();

    final seen = <String>{};
    for (final d in produtosSnap.docs) {
      final nome = (d.data()['fornecedor'] ?? '').toString().trim();
      if (nome.isEmpty) continue;
      final norm = normalize(nome);
      if (seen.contains(norm)) continue;
      seen.add(norm);

      final exists = await _col
          .where('nome_normalizado', isEqualTo: norm)
          .limit(1)
          .get();
      if (exists.docs.isNotEmpty) continue;

      await _col.add({
        'nome': nome,
        'nome_normalizado': norm,
        'email': '',
        'criado_em': FieldValue.serverTimestamp(),
      });
    }
  }
}

class Fornecedor {
  final String id;
  final String nome;
  final String? email;

  Fornecedor({required this.id, required this.nome, this.email});

  factory Fornecedor.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return Fornecedor(
      id: doc.id,
      nome: (data['nome'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
    );
  }
}
