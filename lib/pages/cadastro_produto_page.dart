// lib/pages/cadastro_produto_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:kwalps_st/pages/home_page.dart';
import 'package:kwalps_st/services/suppliers_repository.dart';

class CadastroProdutoPage extends StatefulWidget {
  const CadastroProdutoPage({super.key});

  @override
  State<CadastroProdutoPage> createState() => _CadastroProdutoPageState();
}

class _CadastroProdutoPageState extends State<CadastroProdutoPage> {
  final _repo = SuppliersRepository();

  // -----------------------------
  // CONTROLLERS — PRODUTO
  // -----------------------------
  final _nomeController = TextEditingController();
  final _categoriaController = TextEditingController();
  final _fornTelefoneController = TextEditingController();
  final _estoqueMinimoController = TextEditingController(text: '5');

  String? _fornecedorSelecionadoNome;
  String? _fornecedorSelecionadoEmail;

  // cache da stream para resolver email pelo nome
  List<Fornecedor> _fornecedoresCache = const [];

  final _formProdutoKey = GlobalKey<FormState>();
  bool _isSavingProduto = false;

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
    // produto
    _nomeController.dispose();
    _categoriaController.dispose();
    _fornTelefoneController.dispose();
    _estoqueMinimoController.dispose();

    // lote
    _loteCodigoController.dispose();
    _loteQuantidadeController.dispose();
    _loteValidadeController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------
  // SALVAR PRODUTO (sem quantidade/validade/lote)
  // -------------------------------------------------------
  Future<void> _salvarProduto() async {
    if (_isSavingProduto) return;

    if (!_formProdutoKey.currentState!.validate() ||
        (_fornecedorSelecionadoNome == null ||
            _fornecedorSelecionadoNome!.trim().isEmpty)) {
      _err('Preencha todos os campos do PRODUTO corretamente!');
      return;
    }

    setState(() => _isSavingProduto = true);
    FocusScope.of(context).unfocus();

    try {
      final fornecedorNome = _fornecedorSelecionadoNome!.trim();

      // tenta resolver email via cache se não tiver
      String? fornecedorEmail = _fornecedorSelecionadoEmail;
      if ((fornecedorEmail == null || fornecedorEmail.isEmpty) &&
          _fornecedoresCache.isNotEmpty) {
        final norm = _repo.normalize(fornecedorNome);
        final match = _fornecedoresCache.firstWhere(
          (f) => _repo.normalize(f.nome) == norm,
          orElse: () => Fornecedor(id: '', nome: fornecedorNome, email: null),
        );
        fornecedorEmail = match.email;
      }

      final minimo = int.parse(_estoqueMinimoController.text.trim());
      final categoria = _categoriaController.text.trim();
      final fornTelefone = _fornTelefoneController.text.trim();

      final data = <String, dynamic>{
        'nome': _nomeController.text.trim(),
        'categoria': categoria,
        'fornecedor_telefone': fornTelefone.isEmpty ? null : fornTelefone,
        'estoque_minimo': minimo,
        'fornecedor': fornecedorNome,
        'fornecedor_normalizado': _repo.normalize(fornecedorNome),
        if (fornecedorEmail != null && fornecedorEmail.isNotEmpty)
          'fornecedor_email': fornecedorEmail,
        'criado_em': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('produtos').add(data);

      _ok('Produto salvo com sucesso!');
      _resetProdutoForm();
    } catch (e) {
      _err('Falha ao salvar produto: $e');
    } finally {
      if (mounted) setState(() => _isSavingProduto = false);
    }
  }

  void _resetProdutoForm() {
    _nomeController.clear();
    _categoriaController.clear();
    _fornTelefoneController.clear();
    _estoqueMinimoController.text = '5';

    setState(() {
      _fornecedorSelecionadoNome = null;
      _fornecedorSelecionadoEmail = null;
    });

    _formProdutoKey.currentState?.reset();
  }

  // -------------------------------------------------------
  // SALVAR LOTE (usa select de PRODUTO)
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

      await refProd.collection('lotes').add({
        'codigo': codigo.isEmpty ? null : codigo,
        'quantidade': qtd,
        'validade': _loteValidadeSelecionada,
        'criado_em': FieldValue.serverTimestamp(),
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
  // DIALOGS/HELPERS de fornecedor
  // -------------------------------------------------------
  Future<String?> _adicionarFornecedorDialog() async {
    final nomeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Novo Fornecedor'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  filled: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email (opcional)',
                  filled: true,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await _repo.add(
                nome: nomeCtrl.text,
                email: emailCtrl.text.isEmpty ? null : emailCtrl.text,
              );
              Navigator.pop(context, nomeCtrl.text.trim());
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    return result;
  }

  Future<(String nome, String? email)?> _digitarFornecedorManual() async {
    final nomeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fornecedor (manual)'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nomeCtrl,
                decoration: const InputDecoration(
                  hintText: 'Nome do fornecedor',
                  filled: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  hintText: 'Email (opcional)',
                  filled: true,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, true);
            },
            child: const Text('Usar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final nome = nomeCtrl.text.trim();
      final email = emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim();
      return (nome, email);
    }
    return null;
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
        _loteValidadeSelecionada = data;
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
      appBar: AppBar(title: const Text('Cadastro — Produto e Lote')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ==========================
                // CARD 1 — PRODUTO
                // ==========================
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 2,
                  color: cs.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formProdutoKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cadastrar Produto',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 16),

                          // Nome
                          TextFormField(
                            controller: _nomeController,
                            decoration: _input(context, 'Nome do Produto'),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Preencha o nome'
                                    : null,
                          ),
                          const SizedBox(height: 12),

                          // Categoria
                          TextFormField(
                            controller: _categoriaController,
                            decoration: _input(context,
                                'Categoria (ex.: Medicamento, Descartável…)'),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Informe a categoria'
                                    : null,
                          ),
                          const SizedBox(height: 16),

                          // Estoque Mínimo
                          TextFormField(
                            controller: _estoqueMinimoController,
                            decoration: _input(context,
                                'Estoque mínimo (ponto de reposição)'),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Informe o estoque mínimo';
                              }
                              if (int.tryParse(value.trim()) == null) {
                                return 'Valor inválido';
                              }
                              final n = int.parse(value.trim());
                              if (n < 0) return 'Não pode ser negativo';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Fornecedor
                          Text(
                            'Fornecedor',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: StreamBuilder<List<Fornecedor>>(
                                  stream: _repo.streamAll(),
                                  builder: (context, snapshot) {
                                    final fornecedores = snapshot.data ?? [];
                                    _fornecedoresCache = fornecedores;

                                    final items = <DropdownMenuItem<String>>[
                                      ...fornecedores.map((f) =>
                                          DropdownMenuItem<String>(
                                            value: f.nome,
                                            child: Text(
                                              (f.email == null ||
                                                      f.email!.isEmpty)
                                                  ? f.nome
                                                  : '${f.nome}  —  ${f.email}',
                                            ),
                                          )),
                                      const DropdownMenuItem<String>(
                                        value: '__manual__',
                                        child: Text(
                                            'Outro (digitar manualmente)'),
                                      ),
                                    ];

                                    return DropdownButtonFormField<String>(
                                      value: items.any((e) =>
                                              e.value ==
                                              _fornecedorSelecionadoNome)
                                          ? _fornecedorSelecionadoNome
                                          : null,
                                      items: items,
                                      onChanged: (v) async {
                                        if (v == null) return;
                                        if (v == '__manual__') {
                                          final typed =
                                              await _digitarFornecedorManual();
                                        if (typed != null &&
                                            typed.$1.trim().isNotEmpty) {
                                          setState(() {
                                            _fornecedorSelecionadoNome =
                                                typed.$1.trim();
                                            _fornecedorSelecionadoEmail =
                                                typed.$2; // pode ser null
                                          });
                                        }
                                        } else {
                                          final nomeSel = v.trim();
                                          final sel = fornecedores.firstWhere(
                                            (f) =>
                                                _repo.normalize(f.nome) ==
                                                _repo.normalize(nomeSel),
                                            orElse: () => Fornecedor(
                                                id: '',
                                                nome: nomeSel,
                                                email: null),
                                          );
                                          setState(() {
                                            _fornecedorSelecionadoNome =
                                                sel.nome;
                                            _fornecedorSelecionadoEmail =
                                                sel.email; // pode ser null
                                          });
                                        }
                                      },
                                      decoration:
                                          _input(context, 'Selecionar fornecedor'),
                                      dropdownColor: Theme.of(context)
                                          .colorScheme
                                          .surface,
                                      validator: (v) {
                                        final nome =
                                            _fornecedorSelecionadoNome;
                                        if (nome == null ||
                                            nome.trim().isEmpty) {
                                          return 'Informe o fornecedor';
                                        }
                                        return null;
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: () async {
                                  final createdName =
                                      await _adicionarFornecedorDialog();
                                  if (createdName != null) {
                                    setState(() {
                                      _fornecedorSelecionadoNome = createdName;
                                      // email virá pela stream no próximo tick
                                    });
                                    if (mounted) {
                                      _ok('Fornecedor adicionado!');
                                    }
                                  }
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Adicionar'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Telefone do fornecedor (opcional)
                          TextFormField(
                            controller: _fornTelefoneController,
                            decoration: _input(context,
                                'Telefone do fornecedor (opcional)'),
                            keyboardType: TextInputType.phone,
                          ),

                          const SizedBox(height: 20),

                          // Ações produto
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed:
                                    _isSavingProduto ? null : _salvarProduto,
                                icon: _isSavingProduto
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save),
                                label: Text(_isSavingProduto
                                    ? 'Salvando...'
                                    : 'Salvar Produto'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ==========================
                // CARD 2 — LOTE (com SELECT de Produto)
                // ==========================
                Card(
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

                          // SELECT de Produto (carrega em tempo real, com estados)
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
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
                                      'Nenhum produto encontrado. Cadastre um produto primeiro (Admin → Produtos ou no card acima).',
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: null,
                                      items: const [],
                                      onChanged: null, // desabilitado
                                      decoration: _input(context,
                                          'Produto (nenhum disponível)'),
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
                                  child: Text(
                                      nome.isEmpty ? '(sem nome)' : nome),
                                );
                              }).toList();

                              final exists =
                                  docs.any((d) => d.id == _produtoSelecionadoId);
                              if (!exists) {
                                // se o produto selecionado foi apagado, limpa seleção
                                _produtoSelecionadoId = null;
                              }

                              return DropdownButtonFormField<String>(
                                value: exists ? _produtoSelecionadoId : null,
                                items: items,
                                onChanged: (v) =>
                                    setState(() => _produtoSelecionadoId = v),
                                decoration: _input(context,
                                    'Produto (seleciona um cadastrado)'),
                                dropdownColor: Theme.of(context)
                                    .colorScheme
                                    .surface,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          suffixIcon: const Icon(
                                              Icons.calendar_today),
                                        ),
                                        onTap: _selecionarDataValidadeLote,
                                        validator: (_) =>
                                            _produtoSelecionadoId == null
                                                ? null
                                                : (_loteValidadeSelecionada ==
                                                        null
                                                    ? 'Selecione a validade'
                                                    : null),
                                      ),
                                      const SizedBox(height: 12),

                                      // Código (opcional)
                                      TextFormField(
                                        controller: _loteCodigoController,
                                        decoration: _input(context,
                                            'Nº do lote (opcional)'),
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
                                                    Navigator
                                                        .pushAndRemoveUntil(
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
                                              style: TextStyle(
                                                  color: Colors.red),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
