import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class EnviarEmailPage extends StatelessWidget {
  const EnviarEmailPage({super.key});

  Future<void> _enviarEmailComProdutosEmFalta() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('produtos')
        .where('quantidade', isLessThanOrEqualTo: 0)
        .get();

    if (snapshot.docs.isEmpty) {
      print('Nenhum produto em falta.');
      return;
    }

    final listaProdutos = snapshot.docs
        .map((doc) => "- ${doc['nome']} (Qtd: ${doc['quantidade']})")
        .join('\n');

    final email = Uri.encodeFull(
      "mailto:fornecedores@empresa.com?subject=Produtos em Falta&body=Prezados,%0A%0ASegue a lista de produtos em falta:%0A\n$listaProdutos",
    );

    if (await canLaunchUrl(Uri.parse(email))) {
      await launchUrl(Uri.parse(email));
    } else {
      throw 'Não foi possível abrir o app de email.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _enviarEmailComProdutosEmFalta,
        icon: const Icon(Icons.email),
        label: const Text("Enviar Email para Fornecedores"),
      ),
    );
  }
}
