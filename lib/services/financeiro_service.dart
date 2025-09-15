import 'package:cloud_firestore/cloud_firestore.dart';

class FinanceiroService {
  final _col = FirebaseFirestore.instance.collection('finance_movimentos');

  /// tipo: 'entrada' | 'saida' | 'ajuste'
  Future<void> logMovimento({
    required String tipo,
    required String produtoId,
    required String produtoNome,
    String? loteId,
    String? fornecedorId,
    String? fornecedorNome,
    required int quantidade,
    double? precoUnit,       // ENTRADA
    double? precoTotal,      // se não vier, calcula de unit * qtd
    double? custoUnitSaida,  // SAÍDA (custo aplicado)
    String? operador,        // opcional
    DateTime? quando,
    Map<String, dynamic>? extra,
  }) async {
    // calcula total
    double? total;
    if (tipo == 'entrada') {
      total = (precoTotal != null)
          ? precoTotal
          : (precoUnit != null ? precoUnit * quantidade : null);
    } else if (tipo == 'saida') {
      total = (precoTotal != null)
          ? precoTotal
          : (custoUnitSaida != null ? custoUnitSaida * quantidade : null);
    }
    if (total != null) {
      total = double.parse(total.toStringAsFixed(2)); // normaliza 2 casas
    }

    final data = <String, dynamic>{
      'tipo': tipo,
      'produto_id': produtoId,
      'produto_nome': produtoNome,
      'lote_id': loteId,
      'fornecedor_id': fornecedorId,
      'fornecedor_nome': fornecedorNome,
      'quantidade': quantidade,
      'preco_unit': precoUnit,
      'custo_unit_saida': custoUnitSaida,
      'total': total,
      'criado_em': FieldValue.serverTimestamp(),
      if (quando != null) 'quando': Timestamp.fromDate(quando),
      if (extra != null) ...extra, // cuidado: chaves de extra podem sobrescrever
    };

    // só grava operador se veio válido
    if (operador != null && operador.trim().isNotEmpty) {
      data['operador'] = operador.trim();
    }

    await _col.add(data);
  }
}
