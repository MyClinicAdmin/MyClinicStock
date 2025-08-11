import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProdutosAVencerPage extends StatelessWidget {
  const ProdutosAVencerPage({super.key});

  DateTime? _parseValidade(dynamic v) {
    try {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) return DateTime.parse(v); // "YYYY-MM-DD"
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final limite = agora.add(const Duration(days: 30));
    final df = DateFormat('dd/MM/yyyy');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('produtos').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('Erro ao carregar produtos.'));
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = (snap.data?.docs ?? [])
            .where((d) {
              final dt = _parseValidade(d['validade']);
              return dt != null && dt.isAfter(agora) && dt.isBefore(limite);
            })
            .toList()
          ..sort((a, b) {
            final da = _parseValidade(a['validade'])!;
            final db = _parseValidade(b['validade'])!;
            return da.compareTo(db);
          });

        if (docs.isEmpty) {
          return const Center(child: Text('Nenhum produto a vencer em 30 dias.'));
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = docs[i];
            final validade = _parseValidade(d['validade'])!;
            final dias = validade.difference(agora).inDays;
            return ListTile(
              leading: const Icon(Icons.warning_amber, color: Colors.orange),
              title: Text(d['nome'] ?? '—'),
              subtitle: Text('Validade: ${df.format(validade)}'),
              trailing: Chip(label: Text('$dias dias')),
            );
          },
        );
      },
    );
  }
}
