import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProdutosAVencerPage extends StatelessWidget {
  const ProdutosAVencerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final limite = now.add(const Duration(days: 30));

    return Scaffold(
      appBar: AppBar(title: const Text('Produtos a Vencer')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('produtos').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar produtos.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final produtos = snapshot.data!.docs.where((doc) {
            final dataValidade = (doc['validade'] as Timestamp).toDate();
            return dataValidade.isAfter(now) && dataValidade.isBefore(limite);
          }).toList();

          if (produtos.isEmpty) {
            return const Center(child: Text('Nenhum produto a vencer em 30 dias.'));
          }

          return ListView.builder(
            itemCount: produtos.length,
            itemBuilder: (context, index) {
              final produto = produtos[index];
              final dataValidade = (produto['validade'] as Timestamp).toDate();

              return ListTile(
                leading: const Icon(Icons.warning_amber),
                title: Text(produto['nome']),
                subtitle: Text('Validade: ${dataValidade.day}/${dataValidade.month}/${dataValidade.year}'),
              );
            },
          );
        },
      ),
    );
  }
}
