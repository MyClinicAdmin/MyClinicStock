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
  final _minCtrl = TextEditingController(text: '5');

  final _searchCtrl = TextEditingController();
  String _query = '';

  bool _saving = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _minCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ===================== Diálogos grandes (Sucesso/Erro/Confirmação) =====================

  Future<void> _showResultDialog({
    required bool ok,
    String? title,
    required String message,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final icon = ok ? Icons.check_circle_rounded : Icons.error_outline_rounded;
    final color = ok ? cs.primary : cs.error;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: color),
              const SizedBox(height: 12),
              Text(
                title ?? (ok ? 'Sucesso' : 'Ocorreu um erro'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    IconData icon = Icons.help_outline_rounded,
    Color? color,
    String cancelText = 'Cancelar',
    String confirmText = 'Confirmar',
  }) async {
    final cs = Theme.of(context).colorScheme;
    final icColor = color ?? cs.primary;

    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: icColor),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(cancelText),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(confirmText),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
    return res == true;
  }

  // ======================================================================

  Future<void> _salvar() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    FocusScope.of(context).unfocus();

    try {
      final nome = _nomeCtrl.text.trim();
      final minimo = int.parse(_minCtrl.text.trim());

      await FirebaseFirestore.instance.collection('produtos').add({
        'nome': nome,
        'estoque_minimo': minimo,
        'quantidade_total': 0, // inicia sem stock
        'criado_em': FieldValue.serverTimestamp(),
      });

      await _showResultDialog(
        ok: true,
        title: 'Produto cadastrado',
        message: 'O produto "$nome" foi criado com sucesso.',
      );

      _nomeCtrl.clear();
      _minCtrl.text = '5';
      _formKey.currentState?.reset();
    } catch (e) {
      await _showResultDialog(
        ok: false,
        title: 'Erro ao salvar',
        message: '$e',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmarDelete(String id, String nome) async {
    final ok = await _confirm(
      title: 'Eliminar produto?',
      message:
          'Tem certeza que deseja eliminar "${nome.isEmpty ? '(sem nome)' : nome}"?\nEsta ação não pode ser desfeita.',
      icon: Icons.delete_forever_rounded,
      color: Theme.of(context).colorScheme.error,
      confirmText: 'Eliminar',
    );

    if (ok) {
      await _delete(id, nome);
    }
  }

  Future<void> _delete(String id, String nome) async {
    try {
      await FirebaseFirestore.instance.collection('produtos').doc(id).delete();
      await _showResultDialog(
        ok: true,
        title: 'Produto eliminado',
        message: 'O produto "${nome.isEmpty ? '(sem nome)' : nome}" foi removido.',
      );
    } catch (e) {
      await _showResultDialog(
        ok: false,
        title: 'Falha ao eliminar',
        message: '$e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cadastrar novo produto', style: TextStyle(fontWeight: FontWeight.w700)),
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
                    // Nome + Estoque mínimo + Salvar
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _nomeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nome do produto',
                              filled: true,
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _minCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Estoque mínimo',
                              filled: true,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Informe o mínimo';
                              }
                              final n = int.tryParse(v.trim());
                              if (n == null || n < 0) return 'Valor inválido';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _saving ? null : _salvar,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: Text(_saving ? 'Salvando...' : 'Salvar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          // Cabeçalho + barra de pesquisa
          Row(
            children: [
              const Text('Produtos existentes', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              SizedBox(
                width: 360,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Pesquisar por nome…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('produtos')
                  .orderBy('nome')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Erro: ${snap.error}', textAlign: TextAlign.center),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snap.data!.docs;
                if (_query.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data();
                    final nome = (data['nome'] ?? '').toString().toLowerCase();
                    return nome.contains(_query);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(child: Text('Nenhum produto encontrado.'));
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final data = d.data();
                    final nome = (data['nome'] ?? '').toString().trim();
                    final minimo = (data['estoque_minimo'] ?? 0) as int;

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
                        subtitle: Text('Mínimo: $minimo'),
                        trailing: IconButton(
                          tooltip: 'Eliminar',
                          onPressed: () => _confirmarDelete(d.id, nome),
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
