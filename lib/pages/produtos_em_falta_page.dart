import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProdutosEmFaltaPage extends StatelessWidget {
  const ProdutosEmFaltaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final produtosRef = FirebaseFirestore.instance.collection('produtos');

    return StreamBuilder<QuerySnapshot>(
      stream: produtosRef.where('quantidade', isLessThanOrEqualTo: 0).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Nenhum produto em falta.'));
        }

        final produtos = snapshot.data!.docs;

        return ListView.builder(
          itemCount: produtos.length,
          itemBuilder: (context, index) {
            final produto = produtos[index];
            return ListTile(
              title: Text(produto['nome']),
              subtitle: Text('Quantidade: ${produto['quantidade']}'),
              trailing: const Icon(Icons.warning, color: Colors.red),
            );
          },
        );
      },
    );
  }
}
