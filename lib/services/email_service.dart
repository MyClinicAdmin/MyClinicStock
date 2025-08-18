// lib/services/email_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

/// Item para e-mail (um produto em falta)
class ItemEmail {
  final String nome;
  final int quantidade;
  final int minimo;
  final String validadeFmt; // já formatado (ex.: 12/10/2025)

  ItemEmail({
    required this.nome,
    required this.quantidade,
    required this.minimo,
    required this.validadeFmt,
  });
}

/// Grupo por fornecedor
class GrupoEmail {
  final String fornecedor;
  final String? email; // pode ser null => usar fallback
  final List<ItemEmail> itens;

  GrupoEmail({
    required this.fornecedor,
    required this.itens,
    required this.email,
  });
}

class EmailService {
  /// Lê `produtos` no Firestore e agrupa por fornecedor
  /// Critério: itens com quantidade <= estoque_minimo
  static Future<List<GrupoEmail>> carregarGrupos() async {
    final col = FirebaseFirestore.instance.collection('produtos');
    final snap = await col.get();

    // fornecedor -> holder
    final Map<String, _EmailHolder> mapa = {};

    for (final d in snap.docs) {
      final data = d.data();
      final nome = (data['nome'] ?? '').toString().trim();
      if (nome.isEmpty) continue;

      final qtd = (data['quantidade'] ?? 0) as int;
      final minimo = (data['estoque_minimo'] ?? 0) as int;
      if (qtd > minimo) continue; // só em falta/abaixo do mínimo

      // validade
      String validadeFmt = '-';
      try {
        final v = data['validade'];
        DateTime? dt;
        if (v is Timestamp) dt = v.toDate();
        if (v is DateTime) dt = v;
        if (v is String && v.isNotEmpty) dt = DateTime.tryParse(v);
        if (dt != null) {
          final dd = dt.day.toString().padLeft(2, '0');
          final mm = dt.month.toString().padLeft(2, '0');
          final yy = dt.year.toString();
          validadeFmt = '$dd/$mm/$yy';
        }
      } catch (_) {}

      final fornecedor = ((data['fornecedor'] ?? '') as String).trim().isEmpty
          ? '(Sem fornecedor)'
          : (data['fornecedor'] as String).trim();

      final email = (data['fornecedor_email'] ?? '').toString().trim();

      mapa.putIfAbsent(
        fornecedor,
        () => _EmailHolder(email: email.isEmpty ? null : email),
      );

      mapa[fornecedor]!.itens.add(
        ItemEmail(
          nome: nome,
          quantidade: qtd,
          minimo: minimo,
          validadeFmt: validadeFmt,
        ),
      );
    }

    final grupos = <GrupoEmail>[];
    for (final entry in mapa.entries) {
      grupos.add(
        GrupoEmail(
          fornecedor: entry.key,
          email: entry.value.email,
          itens: entry.value.itens,
        ),
      );
    }

    // ordena por fornecedor
    grupos.sort((a, b) => a.fornecedor.toLowerCase().compareTo(b.fornecedor.toLowerCase()));
    // dentro de cada grupo, ordena por nome do produto
    for (final g in grupos) {
      g.itens.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    }

    return grupos;
  }

  /// Texto simples por fornecedor (para mailto/body ou copiar)
  static String textoFornecedor({
    required String fornecedor,
    required List<ItemEmail> itens,
  }) {
    final b = StringBuffer();
    b.writeln('Prezados $fornecedor,');
    b.writeln('');
    b.writeln('Seguem itens em falta/abaixo do mínimo:');
    b.writeln('');
    b.writeln('Produto | Qtd | Mín. | Validade');
    b.writeln('--------------------------------');
    for (final p in itens) {
      b.writeln('${p.nome} | ${p.quantidade} | ${p.minimo} | ${p.validadeFmt}');
    }
    b.writeln('');
    b.writeln('Atenciosamente,');
    b.writeln('Equipe de Compras');
    return b.toString();
  }

  /// HTML de pré-visualização por fornecedor (simples)
  static String previewHtmlFornecedor(String fornecedor, List<ItemEmail> itens) {
    final rows = itens.map((p) => '''
<tr>
  <td style="padding:6px;border:1px solid #ddd;">${_esc(p.nome)}</td>
  <td style="padding:6px;border:1px solid #ddd;" align="right">${p.quantidade}</td>
  <td style="padding:6px;border:1px solid #ddd;" align="right">${p.minimo}</td>
  <td style="padding:6px;border:1px solid #ddd;">${_esc(p.validadeFmt)}</td>
</tr>
''').join();

    return '''
<h3>Fornecedor: ${_esc(fornecedor)}</h3>
<table style="border-collapse:collapse">
  <thead>
    <tr>
      <th style="padding:6px;border:1px solid #ddd;">Produto</th>
      <th style="padding:6px;border:1px solid #ddd;">Qtd</th>
      <th style="padding:6px;border:1px solid #ddd;">Mín.</th>
      <th style="padding:6px;border:1px solid #ddd;">Validade</th>
    </tr>
  </thead>
  <tbody>
    $rows
  </tbody>
</table>
''';
  }

  /// Texto consolidado (todos os fornecedores)
  static String textoConsolidado(List<GrupoEmail> grupos) {
    final b = StringBuffer();
    b.writeln('Prezados,');
    b.writeln('');
    b.writeln('Segue a relação consolidada de itens em falta/abaixo do mínimo:');
    b.writeln('');

    for (final g in grupos) {
      b.writeln('Fornecedor: ${g.fornecedor} ${g.email != null ? '(${g.email})' : ''}');
      b.writeln('Produto | Qtd | Mín. | Validade');
      b.writeln('--------------------------------');
      for (final p in g.itens) {
        b.writeln('${p.nome} | ${p.quantidade} | ${p.minimo} | ${p.validadeFmt}');
      }
      b.writeln('');
    }

    b.writeln('Atenciosamente,');
    b.writeln('Equipe de Compras');
    return b.toString();
  }

  /// HTML consolidado (para pré-visualização)
  static String previewHtmlConsolidado(List<GrupoEmail> grupos) {
    final sections = grupos.map((g) => previewHtmlFornecedor(g.fornecedor, g.itens)).join('<hr/>');
    return '<div>$sections</div>';
  }

  /// Copia texto para a área de transferência
  static Future<void> copiarTexto(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}

// holder interno
class _EmailHolder {
  final String? email;
  final List<ItemEmail> itens = [];
  _EmailHolder({required this.email});
}

// escapar básico para HTML
String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
