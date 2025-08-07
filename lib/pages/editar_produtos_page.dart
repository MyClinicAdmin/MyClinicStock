import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EditarProdutosPage extends StatefulWidget {
  const EditarProdutosPage({super.key});

  @override
  State<EditarProdutosPage> createState() => _EditarProdutosPageState();
}

class _EditarProdutosPageState extends State<EditarProdutosPage> {
  String _termoPesquisa = '';

  @override
  Widget build(BuildContext context) {
    final produtosRef = FirebaseFirestore.instance.collection('produtos');

    return Scaffold(
      appBar: AppBar(title: const Text('Pesquisar/Editar Produtos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Pesquisar por nome',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _termoPesquisa = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: produtosRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();

                final produtosFiltrados = snapshot.data!.docs.where((doc) {
                  final nome = doc['nome'].toString().toLowerCase();
                  return nome.contains(_termoPesquisa);
                }).toList();

                if (produtosFiltrados.isEmpty) {
                  return const Center(child: Text('Nenhum produto encontrado.'));
                }

                return ListView.builder(
                  itemCount: produtosFiltrados.length,
                  itemBuilder: (context, index) {
                    final doc = produtosFiltrados[index];
                    final nome = doc['nome'];
                    final quantidade = doc['quantidade'];
                    final fornecedor = doc['fornecedor'];
                    final validade = (doc['validade'] as Timestamp?)?.toDate();

                    return ListTile(
                      title: Text(nome),
                      subtitle: Text(
                        'Qtd: $quantidade - Fornecedor: $fornecedor\nValidade: ${validade != null ? DateFormat('dd/MM/yyyy').format(validade) : 'N/A'}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FormEditarProduto(docId: doc.id, dados: doc),
                            ),
                          );
                        },
                      ),
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
