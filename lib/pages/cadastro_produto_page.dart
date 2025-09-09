// lib/pages/cadastro_produto_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:kwalps_st/pages/home_page.dart';

class CadastroProdutoPage extends StatefulWidget {
  const CadastroProdutoPage({super.key});

  @override
  State<CadastroProdutoPage> createState() => _CadastroProdutoPageState();
}

class _CadastroProdutoPageState extends State<CadastroProdutoPage> {
  // -----------------------------
  // CONTROLLERS — LOTE
  // -----------------------------
  final _loteCodigoController = TextEditingController();
  final _loteQuantidadeController = TextEditingController();
  final _loteValidadeController = TextEditingController(); // exibe a data
  DateTime? _loteValidadeSelecionada;
  String? _produtoSelecionadoId;

  final _formLoteKey = GlobalKey<FormState>();
  bool _isSavingLote = false;

  // datas
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _loteCodigoController.dispose();
    _loteQuantidadeController.dispose();
    _loteValidadeController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------
  // SALVAR LOTE (sempre para Produto existente)
  // -------------------------------------------------------
  Future<void> _salvarLote() async {
    if (_isSavingLote) return;

    if (!_formLoteKey.currentState!.validate() ||
        _produtoSelecionadoId == null ||
        _loteValidadeSelecionada == null) {
      _err('Preencha todos os campos do LOTE corretamente!');
      return;
    }

    setState(() => _isSavingLote = true);
    FocusScope.of(context).unfocus();

    try {
      final qtd = int.parse(_loteQuantidadeController.text.trim());
      final codigo = _loteCodigoController.text.trim();
      final refProd = FirebaseFirestore.instance
          .collection('produtos')
          .doc(_produtoSelecionadoId);

      // 1) cria o documento do lote
      await refProd.collection('lotes').add({
        'codigo': codigo.isEmpty ? null : codigo,
        'quantidade': qtd,
        'validade': _loteValidadeSelecionada,
        'criado_em': FieldValue.serverTimestamp(),
      });

      // 2) (opcional, recomendado) incrementa quantidade_total no produto
      await refProd.update({
        'quantidade_total': FieldValue.increment(qtd),
      }).catchError((_) {
        // Se não existir o campo ainda, não é erro crítico.
      });

      _ok('Lote salvo com sucesso!');
      _resetLoteForm();
    } catch (e) {
      _err('Falha ao salvar lote: $e');
    } finally {
      if (mounted) setState(() => _isSavingLote = false);
    }
  }

  void _resetLoteForm() {
    _loteCodigoController.clear();
    _loteQuantidadeController.clear();
    _loteValidadeController.clear();
    setState(() {
      _produtoSelecionadoId = null;
      _loteValidadeSelecionada = null;
    });
    _formLoteKey.currentState?.reset();
  }

  // -------------------------------------------------------
  // UI HELPERS
  // -------------------------------------------------------
  void _ok(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  Future<void> _selecionarDataValidadeLote() async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (data != null) {
      setState(() {
        _loteValidadeSelecionada = DateTime(
          data.year,
          data.month,
          data.day,
          12, // meio-dia para evitar edge cases de timezone
        );
        _loteValidadeController.text = _dateFmt.format(data);
      });
    }
  }

  InputDecoration _input(BuildContext context, String label,
      {Widget? suffixIcon, String? hint}) {
    final cs = Theme.of(context).colorScheme;
    final fill = cs.surface;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: cs.primary, width: 1.6),
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  // -------------------------------------------------------
  // BUILD
  // -------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar Lote')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 2,
              color: cs.surface,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formLoteKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cadastrar Lote para Produto existente',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),

                      // SELECT de Produto (carrega em tempo real)
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('produtos')
                            .orderBy('nome')
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Erro ao carregar produtos.',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => setState(() {}),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Tentar novamente'),
                                ),
                              ],
                            );
                          }

                          if (!snap.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            );
                          }

                          final docs = snap.data!.docs;
                          final hasDocs = docs.isNotEmpty;

                          if (!hasDocs) {
                            // Não há produtos cadastrados ainda
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nenhum produto encontrado. Cadastre um produto primeiro (por ex., na página Admin → Produtos).',
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: null,
                                  items: const [],
                                  onChanged: null, // desabilitado
                                  decoration: _input(
                                      context, 'Produto (nenhum disponível)'),
                                ),
                              ],
                            );
                          }

                          // Há produtos: monta items e mantém seleção, se ainda existir
                          final items = docs.map((d) {
                            final nome =
                                (d['nome'] ?? '').toString().trim();
                            return DropdownMenuItem<String>(
                              value: d.id,
                              child:
                                  Text(nome.isEmpty ? '(sem nome)' : nome),
                            );
                          }).toList();

                          final exists = docs.any(
                              (d) => d.id == _produtoSelecionadoId);
                          if (!exists) {
                            // se o produto selecionado foi apagado, limpa seleção
                            _produtoSelecionadoId = null;
                          }

                          return DropdownButtonFormField<String>(
                            value: exists ? _produtoSelecionadoId : null,
                            items: items,
                            onChanged: (v) =>
                                setState(() => _produtoSelecionadoId = v),
                            decoration: _input(
                                context, 'Produto (seleciona um cadastrado)'),
                            dropdownColor:
                                Theme.of(context).colorScheme.surface,
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Selecione um produto'
                                : null,
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // BLOQUEIA campos do lote até escolher um produto
                      Builder(
                        builder: (context) {
                          final bloqueado = _produtoSelecionadoId == null;

                          return AbsorbPointer(
                            absorbing: bloqueado,
                            child: Opacity(
                              opacity: bloqueado ? 0.55 : 1.0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Quantidade
                                  TextFormField(
                                    controller: _loteQuantidadeController,
                                    decoration: _input(
                                        context, 'Quantidade do lote'),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (_produtoSelecionadoId == null) {
                                        return null; // a seleção do produto já é obrigatória
                                      }
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Informe a quantidade';
                                      }
                                      final n = int.tryParse(v.trim());
                                      if (n == null || n <= 0) {
                                        return 'Quantidade inválida';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // Validade
                                  TextFormField(
                                    controller: _loteValidadeController,
                                    readOnly: true,
                                    decoration: _input(
                                      context,
                                      'Validade',
                                      suffixIcon:
                                          const Icon(Icons.calendar_today),
                                    ),
                                    onTap: _selecionarDataValidadeLote,
                                    validator: (_) {
                                      if (_produtoSelecionadoId == null) {
                                        return null;
                                      }
                                      if (_loteValidadeSelecionada == null) {
                                        return 'Selecione a validade';
                                      }
                                      // não aceitar datas no passado
                                      final hoje = DateTime.now();
                                      final v = DateTime(
                                        _loteValidadeSelecionada!.year,
                                        _loteValidadeSelecionada!.month,
                                        _loteValidadeSelecionada!.day,
                                      );
                                      final h = DateTime(
                                          hoje.year, hoje.month, hoje.day);
                                      if (v.isBefore(h)) {
                                        return 'Validade não pode ser no passado';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // Código (opcional)
                                  TextFormField(
                                    controller: _loteCodigoController,
                                    decoration: _input(
                                        context, 'Nº do lote (opcional)'),
                                  ),
                                  const SizedBox(height: 20),

                                  // Ações lote
                                  Row(
                                    children: [
                                      FilledButton.icon(
                                        onPressed: _isSavingLote
                                            ? null
                                            : _salvarLote,
                                        icon: _isSavingLote
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.save),
                                        label: Text(_isSavingLote
                                            ? 'Salvando...'
                                            : 'Salvar Lote'),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        onPressed: _isSavingLote
                                            ? null
                                            : () {
                                                Navigator.pushAndRemoveUntil(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const HomePage(),
                                                  ),
                                                  (route) => false,
                                                );
                                              },
                                        icon: const Icon(Icons.cancel,
                                            color: Colors.red),
                                        label: const Text(
                                          'Voltar',
                                          style:
                                              TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
