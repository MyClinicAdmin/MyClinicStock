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

      // (Opcional) prevenir duplicados por nome, se quiseres:
      // final dup = await FirebaseFirestore.instance
      //    .collection('produtos')
      //    .where('nome', isEqualTo: nome)
      //    .limit(1).get();
      // if (dup.docs.isNotEmpty) {
      //   _err('Já existe um produto com esse nome.');
      //   setState(() => _saving = false);
      //   return;
      // }

      await FirebaseFirestore.instance.collection('produtos').add({
        'nome': nome,
        'criado_em': FieldValue.serverTimestamp(),
      });

      _ok('Produto cadastrado.');
      _nomeCtrl.clear();
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

  void _ok(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));
  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cadastrar novo produto (nome apenas)',
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
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome do produto',
                          filled: true,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Informe o nome'
                                : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saving ? null : _salvar,
                      icon: _saving
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Salvando...' : 'Salvar'),
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
                    final nome = (d['nome'] ?? '').toString();
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
