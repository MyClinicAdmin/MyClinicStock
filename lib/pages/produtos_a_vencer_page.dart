import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProdutosAVencerPage extends StatelessWidget {
  const ProdutosAVencerPage({super.key});

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  String _fmtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final hoje = _startOfDay(agora);
    final limite = hoje.add(const Duration(days: 30));

    // 1) Lotes que vencem nos próximos 30 dias (modelo novo)
    final lotesStream = FirebaseFirestore.instance
        .collectionGroup('lotes')
        .where('validade', isGreaterThan: Timestamp.fromDate(hoje))
        .where('validade', isLessThanOrEqualTo: Timestamp.fromDate(limite))
        .orderBy('validade')
        .snapshots();

    // 2) Produtos “legados” que têm validade no documento (sem lotes)
    final produtosLegadoStream = FirebaseFirestore.instance
        .collection('produtos')
        .where('validade', isGreaterThan: Timestamp.fromDate(hoje))
        .where('validade', isLessThanOrEqualTo: Timestamp.fromDate(limite))
        .orderBy('validade')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Produtos a Vencer (30 dias)')),
      body: Column(
        children: [
          // --- Lotes (modelo novo) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: lotesStream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Erro ao carregar lotes.'));
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final lotes = snap.data?.docs ?? [];
                if (lotes.isEmpty) {
                  return const Center(
                    child: Text('Nenhum lote a vencer em 30 dias.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: lotes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final loteDoc = lotes[i];
                    final lote = loteDoc.data();
                    final validadeTs = lote['validade'] as Timestamp?;
                    final validade = validadeTs?.toDate();
                    final qtd = (lote['quantidade'] ?? 0) as int;
                    final codigo = (lote['codigo'] ?? '')?.toString() ?? '';

                    // produto pai do subpath .../produtos/{id}/lotes/{id}
                    final produtoRef = loteDoc.reference.parent.parent;

                    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: produtoRef?.get(),
                      builder: (context, prodSnap) {
                        final data = prodSnap.data?.data() ?? {};
                        final nome = (data['nome'] ?? '—').toString();
                        final categoria = (data['categoria'] ?? '').toString();
                        final fornecedor = (data['fornecedor'] ?? '').toString();

                        final dias = validade == null
                            ? 0
                            : validade.difference(hoje).inDays;

                        return ListTile(
                          leading: const Icon(Icons.warning_amber, color: Colors.orange),
                          title: Text(nome),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (categoria.isNotEmpty)
                                Text('Categoria: $categoria'),
                              if (fornecedor.isNotEmpty)
                                Text('Fornecedor: $fornecedor'),
                              Text('Lote: ${codigo.isEmpty ? '(sem nº)' : codigo} — Qtd: $qtd'),
                              Text('Validade: ${validade == null ? '-' : _fmtDate(validade)}'),
                            ],
                          ),
                          trailing: Chip(label: Text('$dias dias')),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          const Divider(height: 1),

          // --- Produtos com validade no doc (legado) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: produtosLegadoStream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Erro ao carregar produtos (legado).'));
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final prods = (snap.data?.docs ?? []).toList()
                  ..sort((a, b) {
                    final va = (a.data()['validade'] as Timestamp).toDate();
                    final vb = (b.data()['validade'] as Timestamp).toDate();
                    return va.compareTo(vb);
                  });

                if (prods.isEmpty) {
                  return const Center(child: Text('Sem itens no modo legado.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: prods.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final d = prods[i];
                    final data = d.data();
                    final nome = (data['nome'] ?? '—').toString();
                    final categoria = (data['categoria'] ?? '').toString();
                    final fornecedor = (data['fornecedor'] ?? '').toString();
                    final validade = (data['validade'] as Timestamp).toDate();
                    final dias = validade.difference(hoje).inDays;

                    return ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(nome),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (categoria.isNotEmpty)
                            Text('Categoria: $categoria'),
                          if (fornecedor.isNotEmpty)
                            Text('Fornecedor: $fornecedor'),
                          Text('Validade: ${_fmtDate(validade)}'),
                          const Text('(sem lotes — modo legado)'),
                        ],
                      ),
                      trailing: Chip(label: Text('$dias dias')),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
