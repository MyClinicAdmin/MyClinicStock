// lib/pages/produtos_admin_tab.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProdutosAdminTab extends StatefulWidget {
  const ProdutosAdminTab({super.key});

  @override
  State<ProdutosAdminTab> createState() => _ProdutosAdminTabState();
}

class _ProdutosAdminTabState extends State<ProdutosAdminTab> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  bool _saving = false;

  // fornecedor selecionado (id do doc) e cache para resolver nome/email ao salvar
  String? _fornecedorSelId;
  List<_FornecedorLite> _fornecedoresCache = const [];

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    FocusScope.of(context).unfocus();

    try {
      final nome = _nomeCtrl.text.trim();
      final fornecedor = _fornecedoresCache
          .firstWhere((f) => f.id == _fornecedorSelId, orElse: () => _FornecedorLite.empty());

      await FirebaseFirestore.instance.collection('produtos').add({
        'nome': nome,
        'criado_em': FieldValue.serverTimestamp(),
        // ligação ao fornecedor
        'fornecedor_id': fornecedor.id?.isNotEmpty == true ? fornecedor.id : null,
        'fornecedor': fornecedor.nome?.isNotEmpty == true ? fornecedor.nome : null,
        'fornecedor_email': fornecedor.email?.isNotEmpty == true ? fornecedor.email : null,
        // utilidade para buscas/ordenações futuras
        'fornecedor_normalizado': (fornecedor.nome ?? '').trim().toLowerCase(),
      });

      _ok('Produto cadastrado.');
      _nomeCtrl.clear();
      setState(() => _fornecedorSelId = null);
      _formKey.currentState?.reset();
    } catch (e) {
      _err('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await FirebaseFirestore.instance.collection('produtos').doc(id).delete();
      _ok('Produto removido.');
    } catch (e) {
      _err('Falha ao remover: $e');
    }
  }

  void _ok(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  void _err(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cadastrar novo produto',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: cs.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Nome do produto
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nomeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nome do produto',
                              filled: true,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Informe o nome'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _saving ? null : _salvar,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: Text(_saving ? 'Salvando...' : 'Salvar'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // SELECT de fornecedor (nome + email)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('fornecedores')
                          .orderBy('nome')
                          .snapshots(),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Erro ao carregar fornecedores.'),
                          );
                        }
                        if (!snap.hasData) {
                          return const LinearProgressIndicator();
                        }

                        final docs = snap.data!.docs;
                        _fornecedoresCache = docs
                            .map((d) => _FornecedorLite(
                                  id: d.id,
                                  nome: (d['nome'] ?? '').toString().trim(),
                                  email: (d['email'] ?? '').toString().trim(),
                                ))
                            .toList();

                        if (docs.isEmpty) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Nenhum fornecedor cadastrado ainda.'),
                          );
                        }

                        // garantir que a seleção ainda existe
                        final exists = _fornecedoresCache.any((f) => f.id == _fornecedorSelId);
                        if (!exists) _fornecedorSelId = null;

                        return DropdownButtonFormField<String>(
                          value: exists ? _fornecedorSelId : null,
                          items: _fornecedoresCache.map((f) {
                            final label = (f.email == null || f.email!.isEmpty)
                                ? (f.nome ?? '')
                                : '${f.nome} — ${f.email}';
                            return DropdownMenuItem<String>(
                              value: f.id,
                              child: Text(label),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _fornecedorSelId = v),
                          decoration: const InputDecoration(
                            labelText: 'Fornecedor',
                            filled: true,
                          ),
                          validator: (v) =>
                              v == null ? 'Selecione um fornecedor' : null,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Text('Produtos existentes',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('produtos')
                  .orderBy('nome')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Erro: ${snap.error}',
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Nenhum produto cadastrado.'));
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final nome = (d['nome'] ?? '').toString().trim();
                    final fornecedorNome =
                        (d['fornecedor'] ?? '').toString().trim();
                    final fornecedorEmail =
                        (d['fornecedor_email'] ?? '').toString().trim();

                    return Card(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: cs.outline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          nome.isEmpty ? '(sem nome)' : nome,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: (fornecedorNome.isEmpty && fornecedorEmail.isEmpty)
                            ? null
                            : Text(
                                fornecedorEmail.isEmpty
                                    ? 'Fornecedor: $fornecedorNome'
                                    : 'Fornecedor: $fornecedorNome — $fornecedorEmail',
                              ),
                        trailing: IconButton(
                          tooltip: 'Eliminar',
                          onPressed: () => _delete(d.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
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

class _FornecedorLite {
  final String? id;
  final String? nome;
  final String? email;

  const _FornecedorLite({this.id, this.nome, this.email});
  factory _FornecedorLite.empty() => const _FornecedorLite();
}
