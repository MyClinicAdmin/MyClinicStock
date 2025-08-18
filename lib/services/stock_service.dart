// lib/services/stock_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Movimento {
  final String id;
  final String produtoId;
  final String produtoNome;
  final String tipo; // 'entrada' | 'saida' | 'ajuste'
  final int quantidade;
  final String? motivo;
  final String? operador;
  final DateTime? criadoEm;

  Movimento({
    required this.id,
    required this.produtoId,
    required this.produtoNome,
    required this.tipo,
    required this.quantidade,
    this.motivo,
    this.operador,
    this.criadoEm,
  });

  // Quando vier de collectionGroup (QueryDocumentSnapshot)
  factory Movimento.fromQueryDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    return Movimento(
      id: d.id,
      produtoId: (data['produto_id'] ?? '').toString(),
      produtoNome: (data['produto_nome'] ?? '').toString(),
      tipo: (data['tipo'] ?? '').toString(),
      quantidade: (data['quantidade'] ?? 0) as int,
      motivo: (data['motivo'] ?? '').toString().isEmpty ? null : (data['motivo'] ?? '').toString(),
      operador: (data['operador'] ?? '').toString().isEmpty ? null : (data['operador'] ?? '').toString(),
      criadoEm: (data['criado_em'] as Timestamp?)?.toDate(),
    );
  }

  // Versão alternativa caso você use DocumentSnapshot em algum lugar
  factory Movimento.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? <String, dynamic>{};
    return Movimento(
      id: d.id,
      produtoId: (data['produto_id'] ?? '').toString(),
      produtoNome: (data['produto_nome'] ?? '').toString(),
      tipo: (data['tipo'] ?? '').toString(),
      quantidade: (data['quantidade'] ?? 0) as int,
      motivo: (data['motivo'] ?? '').toString().isEmpty ? null : (data['motivo'] ?? '').toString(),
      operador: (data['operador'] ?? '').toString().isEmpty ? null : (data['operidor'] ?? '').toString(),
      criadoEm: (data['criado_em'] as Timestamp?)?.toDate(),
    );
  }
}

class StockService {
  final _prodCol = FirebaseFirestore.instance.collection('produtos');

  Future<void> registrarSaida({
    required String produtoId,
    required int quantidade,
    String motivo = 'consumo',
    String? operador,
  }) async {
    final ref = _prodCol.doc(produtoId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Produto não encontrado');
      final data = snap.data() as Map<String, dynamic>;
      final atual = (data['quantidade'] ?? 0) as int;
      final minimo = (data['estoque_minimo'] ?? 0) as int;
      if (quantidade <= 0) throw Exception('Quantidade inválida');
      if (atual - quantidade < 0) throw Exception('Stock insuficiente');

      final novo = atual - quantidade;
      tx.update(ref, {
        'quantidade': novo,
        'critico': novo <= minimo,
        'atualizado_em': FieldValue.serverTimestamp(),
      });

      final movRef = ref.collection('movimentos').doc();
      tx.set(movRef, {
        'tipo': 'saida',
        'quantidade': quantidade,
        'motivo': motivo,
        if (operador != null && operador.isNotEmpty) 'operador': operador,
        'produto_id': ref.id,
        'produto_nome': (data['nome'] ?? '').toString(),
        'criado_em': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> registrarEntrada({
    required String produtoId,
    required int quantidade,
    String motivo = 'compra',
    String? operador,
  }) async {
    final ref = _prodCol.doc(produtoId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Produto não encontrado');
      final data = snap.data() as Map<String, dynamic>;
      final atual = (data['quantidade'] ?? 0) as int;
      final minimo = (data['estoque_minimo'] ?? 0) as int;
      if (quantidade <= 0) throw Exception('Quantidade inválida');

      final novo = atual + quantidade;
      tx.update(ref, {
        'quantidade': novo,
        'critico': novo <= minimo,
        'atualizado_em': FieldValue.serverTimestamp(),
      });

      final movRef = ref.collection('movimentos').doc();
      tx.set(movRef, {
        'tipo': 'entrada',
        'quantidade': quantidade,
        'motivo': motivo,
        if (operador != null && operador.isNotEmpty) 'operador': operador,
        'produto_id': ref.id,
        'produto_nome': (data['nome'] ?? '').toString(),
        'criado_em': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> ajustarEstoque({
    required String produtoId,
    required int novoValor,
    String motivo = 'ajuste',
    String? operador,
  }) async {
    final ref = _prodCol.doc(produtoId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Produto não encontrado');
      final data = snap.data() as Map<String, dynamic>;
      final minimo = (data['estoque_minimo'] ?? 0) as int;
      if (novoValor < 0) throw Exception('Valor inválido');

      tx.update(ref, {
        'quantidade': novoValor,
        'critico': novoValor <= minimo,
        'atualizado_em': FieldValue.serverTimestamp(),
      });

      final movRef = ref.collection('movimentos').doc();
      tx.set(movRef, {
        'tipo': 'ajuste',
        'quantidade': novoValor,
        'motivo': motivo,
        if (operador != null && operador.isNotEmpty) 'operador': operador,
        'produto_id': ref.id,
        'produto_nome': (data['nome'] ?? '').toString(),
        'criado_em': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Histórico global (Admin)
  Stream<List<Movimento>> streamMovimentos({int limit = 300}) {
    return FirebaseFirestore.instance
        .collectionGroup('movimentos')
        .orderBy('criado_em', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(Movimento.fromQueryDoc).toList());
  }

  /// Histórico por produto específico (útil se precisar)
  Stream<List<Movimento>> streamMovimentosDoProduto(String produtoId, {int limit = 200}) {
    return _prodCol
        .doc(produtoId)
        .collection('movimentos')
        .orderBy('criado_em', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(Movimento.fromQueryDoc).toList());
  }
}
