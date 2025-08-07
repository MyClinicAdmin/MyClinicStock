import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CadastroProdutoPage extends StatefulWidget {
  const CadastroProdutoPage({super.key});

  @override
  State<CadastroProdutoPage> createState() => _CadastroProdutoPageState();
}

class _CadastroProdutoPageState extends State<CadastroProdutoPage> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _quantidadeController = TextEditingController();
  final TextEditingController _fornecedorController = TextEditingController();
  DateTime? _validadeSelecionada;

  final _formKey = GlobalKey<FormState>();

  Future<void> _salvarProduto() async {
    if (!_formKey.currentState!.validate() || _validadeSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos corretamente!')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('produtos').add({
      'nome': _nomeController.text,
      'quantidade': int.parse(_quantidadeController.text),
      'validade': _validadeSelecionada,
      'fornecedor': _fornecedorController.text,
      'criado_em': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Produto salvo com sucesso!')),
    );

    _nomeController.clear();
    _quantidadeController.clear();
    _fornecedorController.clear();
    setState(() => _validadeSelecionada = null);
  }

  Future<void> _selecionarDataValidade() async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (data != null) {
      setState(() {
        _validadeSelecionada = data;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar Produto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome do Produto'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Preencha o nome' : null,
              ),
              TextFormField(
                controller: _quantidadeController,
                decoration: const InputDecoration(labelText: 'Quantidade'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Informe a quantidade' : null,
              ),
              TextFormField(
                controller: _fornecedorController,
                decoration: const InputDecoration(labelText: 'Fornecedor'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Informe o fornecedor' : null,
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(_validadeSelecionada == null
                    ? 'Selecionar Validade'
                    : 'Validade: ${DateFormat('dd/MM/yyyy').format(_validadeSelecionada!)}'),
                onPressed: _selecionarDataValidade,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _salvarProduto,
                icon: const Icon(Icons.save),
                label: const Text('Salvar Produto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
