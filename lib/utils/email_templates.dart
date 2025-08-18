// lib/utils/email_templates.dart
import 'package:intl/intl.dart';

class EmailTemplates {
  static final _df = DateFormat('dd/MM/yyyy');

  /// Texto (plain text) para um fornecedor com seus itens em falta.
  /// Usa lista no formato "1) Produto - Qtd atual / Mínimo - Validade".
  static String textItensEmFalta({
    required String fornecedor,
    required List<_ItemLike> itens,
    String? telefoneEmpresa,
  }) {
    final b = StringBuffer();

    b.writeln('Prezado(a) $fornecedor,');
    b.writeln();
    b.writeln('Solicitamos cotação/abastecimento dos seguintes itens em falta:');
    b.writeln();

    for (int i = 0; i < itens.length; i++) {
      final p = itens[i];
      final validadeStr = (p.validade != null) ? _df.format(p.validade!) : '-';
      b.writeln(
          '${i + 1}) ${p.nome} — Qtd: ${p.quantidade} / Mín: ${p.minimo} — Validade: $validadeStr');
    }

    b.writeln();
    b.writeln('Aguardamos retorno.');
    b.writeln('Atenciosamente,');
    b.writeln('Equipe de Compras');

    if (telefoneEmpresa != null && telefoneEmpresa.trim().isNotEmpty) {
      b.writeln('Telefone: $telefoneEmpresa');
    }
    return b.toString();
  }

  /// Texto consolidado (plain text) juntando todos os fornecedores.
  static String textoConsolidado({
    required List<_GrupoLike> grupos,
    String? telefoneEmpresa,
  }) {
    final b = StringBuffer();
    b.writeln('Itens em falta — Resumo por fornecedor');
    b.writeln();

    for (final g in grupos) {
      b.writeln('Fornecedor: ${g.fornecedor}  ${g.email ?? "(sem e-mail)"}');
      for (int i = 0; i < g.itens.length; i++) {
        final p = g.itens[i];
        final validadeStr =
            (p.validade != null) ? _df.format(p.validade!) : '-';
        b.writeln(
            '  - ${p.nome} — Qtd: ${p.quantidade} / Mín: ${p.minimo} — Val: $validadeStr');
      }
      b.writeln();
    }

    if (telefoneEmpresa != null && telefoneEmpresa.trim().isNotEmpty) {
      b.writeln('Contato: $telefoneEmpresa');
    }
    return b.toString();
  }
}

/// Interfaces internas para não acoplar à implementação do serviço
abstract class _ItemLike {
  String get nome;
  int get quantidade;
  int get minimo;
  DateTime? get validade;
}

abstract class _GrupoLike {
  String get fornecedor;
  String? get email;
  List<_ItemLike> get itens;
}
