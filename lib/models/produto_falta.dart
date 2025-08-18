import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProdutoFalta {
  final String nome;
  final int quantidade;
  final int minimo;
  final String validadeFmt;

  ProdutoFalta({
    required this.nome,
    required this.quantidade,
    required this.minimo,
    required this.validadeFmt,
  });

  static String _fmtDateAny(dynamic v) {
    if (v == null) return '-';
    DateTime? d;
    if (v is Timestamp) d = v.toDate();
    else if (v is DateTime) d = v;
    if (d == null) return '-';
    return DateFormat('dd/MM/yyyy').format(d);
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory ProdutoFalta.fromProdutoDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? const <String, dynamic>{};
    return ProdutoFalta(
      nome: (data['nome'] ?? '').toString(),
      quantidade: _toInt(data['quantidade']),
      minimo: _toInt(data['estoque_minimo']),
      validadeFmt: _fmtDateAny(data['validade']),
    );
  }
}
