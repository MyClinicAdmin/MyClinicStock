// lib/services/stock_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'financeiro_service.dart';

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

  factory Movimento.fromQueryDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final data = d.data();
    return Movimento(
      id: d.id,
      produtoId: (data['produto_id'] ?? '').toString(),
      produtoNome: (data['produto_nome'] ?? '').toString(),
      tipo: (data['tipo'] ?? '').toString(),
      quantidade: (data['quantidade'] as num?)?.toInt() ?? 0,
      motivo: ((data['motivo'] ?? '').toString().isEmpty)
          ? null
          : (data['motivo'] ?? '').toString(),
      operador: ((data['operador'] ?? '').toString().isEmpty)
          ? null
          : (data['operador'] ?? '').toString(),
      criadoEm: (data['criado_em'] as Timestamp?)?.toDate(),
    );
  }
}

class StockService {
  final _db = FirebaseFirestore.instance;
  final _prodCol = FirebaseFirestore.instance.collection('produtos');
  final FinanceiroService _finService;

  StockService({FinanceiroService? financeiroService})
      : _finService = financeiroService ?? FinanceiroService();

  Future<void> registrarSaida({
    required String produtoId,
    required int quantidade,
    String motivo = 'consumo',
    String? operador,       // opcional
    String? loteId,
    double? custoUnitSaida, // opcional
  }) async {
    final ref = _prodCol.doc(produtoId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Produto não encontrado');
      final data = snap.data() as Map<String, dynamic>;

      final atual =
          ((data['quantidade_total'] ?? data['quantidade']) as num?)?.toInt() ??
              0;
      final minimo = (data['estoque_minimo'] as num?)?.toInt() ?? 0;

      if (quantidade <= 0) throw Exception('Quantidade inválida');
      if (atual - quantidade < 0) throw Exception('Stock insuficiente');

      final novo = atual - quantidade;

      tx.update(ref, {
        'quantidade_total': novo,
        'quantidade': novo, // mantém compatibilidade
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

    // Log financeiro (fora da transação)
    await _finService.logMovimento(
      tipo: 'saida',
      produtoId: produtoId,
      produtoNome: await _nomeProduto(produtoId),
      loteId: loteId,
      quantidade: quantidade,
      custoUnitSaida: custoUnitSaida,
      operador: operador,
      extra: {'motivo': motivo},
    );
  }

  Future<void> registrarEntrada({
    required String produtoId,
    required int quantidade,
    String motivo = 'compra',
    String? operador,       // opcional
    String? loteId,
    double? precoUnit,      // opcional
    double? precoTotal,     // opcional
    String? fornecedorId,   // opcional
    String? fornecedorNome, // opcional
  }) async {
    final ref = _prodCol.doc(produtoId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Produto não encontrado');
      final data = snap.data() as Map<String, dynamic>;

      final atual =
          ((data['quantidade_total'] ?? data['quantidade']) as num?)?.toInt() ??
              0;
      final minimo = (data['estoque_minimo'] as num?)?.toInt() ?? 0;

      if (quantidade <= 0) throw Exception('Quantidade inválida');

      final novo = atual + quantidade;

      tx.update(ref, {
        'quantidade_total': novo,
        'quantidade': novo, // mantém compatibilidade
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

    // Log financeiro
    await _finService.logMovimento(
      tipo: 'entrada',
      produtoId: produtoId,
      produtoNome: await _nomeProduto(produtoId),
      loteId: loteId,
      quantidade: quantidade,
      precoUnit: precoUnit,
      precoTotal: precoTotal,
      fornecedorId: fornecedorId,
      fornecedorNome: fornecedorNome,
      operador: operador,
      extra: {'motivo': motivo},
    );
  }

  Future<void> ajustarEstoque({
    required String produtoId,
    required int novoValor,
    String motivo = 'ajuste',
    String? operador, // opcional
  }) async {
    final ref = _prodCol.doc(produtoId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Produto não encontrado');
      final data = snap.data() as Map<String, dynamic>;

      final minimo = (data['estoque_minimo'] as num?)?.toInt() ?? 0;
      if (novoValor < 0) throw Exception('Valor inválido');

      tx.update(ref, {
        'quantidade_total': novoValor,
        'quantidade': novoValor, // mantém compatibilidade
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

    // Se quiser, podemos logar o ajuste no financeiro com uma regra de custo.
  }

  Stream<List<Movimento>> streamMovimentos({int limit = 300}) {
    return _db
        .collectionGroup('movimentos')
        .orderBy('criado_em', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(Movimento.fromQueryDoc).toList());
  }

  Stream<List<Movimento>> streamMovimentosDoProduto(
    String produtoId, {
    int limit = 200,
  }) {
    return _prodCol
        .doc(produtoId)
        .collection('movimentos')
        .orderBy('criado_em', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(Movimento.fromQueryDoc).toList());
  }

  Future<String> _nomeProduto(String produtoId) async {
    final doc = await _db.collection('produtos').doc(produtoId).get();
    return (doc.data()?['nome'] ?? '—').toString();
  }
}
