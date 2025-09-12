// lib/pages/produtos_a_vencer_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProdutosAVencerPage extends StatefulWidget {
  const ProdutosAVencerPage({super.key});

  @override
  State<ProdutosAVencerPage> createState() => _ProdutosAVencerPageState();
}

class _ProdutosAVencerPageState extends State<ProdutosAVencerPage> {
  final _fmt = DateFormat('dd/MM/yyyy');
  final Map<String, Map<String, dynamic>?> _produtoCache = {};

  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
  String _d(DateTime d) => _fmt.format(d);

  // Paleta por faixa de dias
  (Color bg, Color on) _colorsFor(int dias, ColorScheme cs, {bool vencido = false}) {
    if (vencido) return (cs.errorContainer, cs.onErrorContainer);           // vencido
    if (dias <= 7) return (cs.tertiaryContainer, cs.onTertiaryContainer);   // muito urgente
    if (dias <= 14) return (cs.secondaryContainer, cs.onSecondaryContainer);// urgente
    return (cs.surfaceContainerHighest, cs.onSurfaceVariant);               // atenção
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final agora = DateTime.now();
    final hoje = _dayStart(agora);
    final limite = hoje.add(const Duration(days: 30));

    // --- Streams ---
    final vencidosStream = FirebaseFirestore.instance
        .collectionGroup('lotes')
        .where('validade', isLessThanOrEqualTo: Timestamp.fromDate(hoje))
        .orderBy('validade')
        .snapshots();

    final aVencerStream = FirebaseFirestore.instance
        .collectionGroup('lotes')
        .where('validade', isGreaterThan: Timestamp.fromDate(hoje))
        .where('validade', isLessThanOrEqualTo: Timestamp.fromDate(limite))
        .orderBy('validade')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('A vencer em 30 dias')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // ======= VENCIDOS =======
          _sectionTitle('Vencidos', cs),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: vencidosStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return _errorBox('Erro: ${snap.error}');
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return _emptyBox('Nenhum lote vencido.');
              }

              return Column(
                children: docs.map((d) {
                  final data = d.data();
                  final ts = data['validade'] as Timestamp?;
                  final val = ts?.toDate();
                  final qtd = (data['quantidade'] ?? 0) is int
                      ? (data['quantidade'] as int)
                      : int.tryParse('${data['quantidade']}') ?? 0;
                  final codigo = (data['codigo'] ?? '').toString();
                  final dias = val == null ? 0 : val.difference(hoje).inDays;

                  final produtoRef = d.reference.parent.parent;
                  final cacheKey = produtoRef?.path ?? '';

                  Widget card(Map<String, dynamic>? prod) {
                    final nome = (prod?['nome'] ?? '—').toString();
                    final categoria = (prod?['categoria'] ?? '').toString();
                    final fornecedor = (prod?['fornecedor'] ?? '').toString();
                    final (bg, on) = _colorsFor(dias, cs, vencido: true);

                    return _loteCard(
                      icon: Icons.error_outline,
                      nome: nome,
                      categoria: categoria,
                      fornecedor: fornecedor,
                      codigo: codigo,
                      qtd: qtd,
                      validade: val == null ? '—' : _d(val),
                      chipText: 'Vencido',
                      chipBg: bg,
                      chipOn: on,
                    );
                  }

                  final cached = _produtoCache[cacheKey];
                  if (cached != null || cacheKey.isEmpty) return card(cached);

                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: produtoRef?.get(),
                    builder: (context, ps) {
                      final prod = ps.data?.data();
                      _produtoCache[cacheKey] = prod;
                      if (ps.connectionState == ConnectionState.waiting) {
                        return _loadingTile('Carregando produto...');
                      }
                      return card(prod);
                    },
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 16),
          // ======= A VENCER (30 DIAS) =======
          _sectionTitle('Próximos 30 dias', cs),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: aVencerStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return _errorBox('Erro: ${snap.error}');
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return _emptyBox('Nenhum lote a vencer em 30 dias.');
              }

              return Column(
                children: docs.map((d) {
                  final data = d.data();
                  final ts = data['validade'] as Timestamp?;
                  final val = ts?.toDate();
                  final qtd = (data['quantidade'] ?? 0) is int
                      ? (data['quantidade'] as int)
                      : int.tryParse('${data['quantidade']}') ?? 0;
                  final codigo = (data['codigo'] ?? '').toString();

                  final dias = val == null ? 0 : val.difference(hoje).inDays;
                  final produtoRef = d.reference.parent.parent;
                  final cacheKey = produtoRef?.path ?? '';

                  final (bg, on) = _colorsFor(dias, cs);

                  Widget card(Map<String, dynamic>? prod) {
                    final nome = (prod?['nome'] ?? '—').toString();
                    final categoria = (prod?['categoria'] ?? '').toString();
                    final fornecedor = (prod?['fornecedor'] ?? '').toString();

                    String faixa;
                    if (dias <= 7) {
                      faixa = 'Em $dias dia${dias == 1 ? '' : 's'}';
                    } else if (dias <= 14) {
                      faixa = '8–14 dias';
                    } else {
                      faixa = '15–30 dias';
                    }

                    return _loteCard(
                      icon: Icons.warning_amber_rounded,
                      nome: nome,
                      categoria: categoria,
                      fornecedor: fornecedor,
                      codigo: codigo,
                      qtd: qtd,
                      validade: val == null ? '—' : _d(val),
                      chipText: faixa,
                      chipBg: bg,
                      chipOn: on,
                    );
                  }

                  final cached = _produtoCache[cacheKey];
                  if (cached != null || cacheKey.isEmpty) return card(cached);

                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: produtoRef?.get(),
                    builder: (context, ps) {
                      final prod = ps.data?.data();
                      _produtoCache[cacheKey] = prod;
                      if (ps.connectionState == ConnectionState.waiting) {
                        return _loadingTile('Carregando produto...');
                      }
                      return card(prod);
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // -------- UI helpers --------
  Widget _sectionTitle(String t, ColorScheme cs) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t,
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800,
              color: cs.onSurface.withOpacity(.9),
            )),
      );

  Widget _errorBox(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(msg, textAlign: TextAlign.center),
        ),
      );

  Widget _emptyBox(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(msg),
        ),
      );

  Widget _loadingTile(String msg) => ListTile(
        leading: const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text(msg),
      );

  Widget _loteCard({
    required IconData icon,
    required String nome,
    required String categoria,
    required String fornecedor,
    required String codigo,
    required int qtd,
    required String validade,
    required String chipText,
    required Color chipBg,
    required Color chipOn,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(icon, color: chipOn),
        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (categoria.isNotEmpty) Text('Categoria: $categoria'),
            if (fornecedor.isNotEmpty) Text('Fornecedor: $fornecedor'),
            Text('Lote: ${codigo.isEmpty ? '(sem nº)' : codigo}  •  Qtd: $qtd'),
            Text('Validade: $validade'),
          ],
        ),
        trailing: Chip(
          backgroundColor: chipBg,
          label: Text(chipText,
              style: TextStyle(color: chipOn, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
