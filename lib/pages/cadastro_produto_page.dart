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

  final _nomeController = TextEditingController();
  final _categoriaController = TextEditingController();     // NOVO
  final _loteController = TextEditingController();          // NOVO
  final _fornTelefoneController = TextEditingController();  // NOVO
  final _quantidadeController = TextEditingController();
  final _estoqueMinimoController = TextEditingController(text: '5');
  final _validadeController = TextEditingController(); // exibe a data formatada

  String? _fornecedorSelecionadoNome;
  String? _fornecedorSelecionadoEmail;
  DateTime? _validadeSelecionada;

  // cache da stream para resolver email pelo nome
  List<Fornecedor> _fornecedoresCache = const [];

  final _formKey = GlobalKey<FormState>();
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _nomeController.dispose();
    _categoriaController.dispose();
    _loteController.dispose();
    _fornTelefoneController.dispose();
    _quantidadeController.dispose();
    _estoqueMinimoController.dispose();
    _validadeController.dispose();
    super.dispose();
  }

  Future<void> _salvarProduto() async {
    if (!_formKey.currentState!.validate() ||
        _validadeSelecionada == null ||
        (_fornecedorSelecionadoNome == null ||
            _fornecedorSelecionadoNome!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos corretamente!')),
      );
      return;
    }

    final fornecedorNome = _fornecedorSelecionadoNome!.trim();

    // se ainda não temos email em memória, tenta resolver via cache
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

    final qtd = int.parse(_quantidadeController.text.trim());
    final minimo = int.parse(_estoqueMinimoController.text.trim());
    final critico = qtd <= minimo;

    final categoria = _categoriaController.text.trim();
    final lote = _loteController.text.trim();
    final fornTelefone = _fornTelefoneController.text.trim();

    final data = <String, dynamic>{
      'nome': _nomeController.text.trim(),
      'categoria': categoria,                              // NOVO
      'lote': lote.isEmpty ? null : lote,                  // NOVO (cópia informativa)
      'fornecedor_telefone': fornTelefone.isEmpty ? null : fornTelefone, // NOVO
      'quantidade': qtd,
      'estoque_minimo': minimo,
      'critico': critico,
      'validade': _validadeSelecionada,
      'fornecedor': fornecedorNome,
      'fornecedor_normalizado': _repo.normalize(fornecedorNome),
      if (fornecedorEmail != null && fornecedorEmail.isNotEmpty)
        'fornecedor_email': fornecedorEmail,
      'criado_em': FieldValue.serverTimestamp(),
    };

    // 1) Cria o produto
    final ref = await FirebaseFirestore.instance.collection('produtos').add(data);

    // 2) Cria LOTE inicial (se houver validade e/ou nº de lote)
    if (_validadeSelecionada != null || lote.isNotEmpty) {
      await ref.collection('lotes').add({
        'codigo': lote.isEmpty ? null : lote,                 // Nº do lote (opcional)
        'quantidade': qtd,
        'validade': _validadeSelecionada,
        'criado_em': FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Produto salvo com sucesso!')),
    );

    _nomeController.clear();
    _categoriaController.clear();
    _loteController.clear();
    _fornTelefoneController.clear();
    _quantidadeController.clear();
    _estoqueMinimoController.text = '5';
    _validadeController.clear();
    setState(() {
      _validadeSelecionada = null;
      _fornecedorSelecionadoNome = null;
      _fornecedorSelecionadoEmail = null;
    });
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
        _validadeController.text = _dateFmt.format(data);
      });
    }
  }

  /// Adiciona fornecedor no repositório (Nome + Email opcional)
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
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                decoration:
                    const InputDecoration(labelText: 'Email (opcional)'),
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

  /// Digitar fornecedor manualmente (Nome + Email opcional, sem gravar no repo)
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
                decoration:
                    const InputDecoration(hintText: 'Nome do fornecedor'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                decoration:
                    const InputDecoration(hintText: 'Email (opcional)'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar Produto')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 640; // 2 colunas quando couber
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dados do Produto',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 16),

                          // Nome
                          TextFormField(
                            controller: _nomeController,
                            decoration: const InputDecoration(
                                labelText: 'Nome do Produto'),
                            validator: (value) => value == null ||
                                    value.trim().isEmpty
                                ? 'Preencha o nome'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Categoria (NOVO)
                          TextFormField(
                            controller: _categoriaController,
                            decoration: const InputDecoration(
                                labelText: 'Categoria (ex.: Medicamento, Descartável…)'),
                            validator: (value) => value == null ||
                                    value.trim().isEmpty
                                ? 'Informe a categoria'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Quantidade + Estoque Mínimo
                          if (wide)
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _quantidadeController,
                                    decoration: const InputDecoration(
                                        labelText:
                                            'Quantidade (stock inicial)'),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Informe a quantidade';
                                      }
                                      if (int.tryParse(value.trim()) == null) {
                                        return 'Quantidade inválida';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _estoqueMinimoController,
                                    decoration: const InputDecoration(
                                        labelText:
                                            'Estoque mínimo (ponto de reposição)'),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Informe o estoque mínimo';
                                      }
                                      if (int.tryParse(value.trim()) == null) {
                                        return 'Valor inválido';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            TextFormField(
                              controller: _quantidadeController,
                              decoration: const InputDecoration(
                                  labelText: 'Quantidade (stock inicial)'),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Informe a quantidade';
                                }
                                if (int.tryParse(value.trim()) == null) {
                                  return 'Quantidade inválida';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _estoqueMinimoController,
                              decoration: const InputDecoration(
                                  labelText:
                                      'Estoque mínimo (ponto de reposição)'),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Informe o estoque mínimo';
                                }
                                if (int.tryParse(value.trim()) == null) {
                                  return 'Valor inválido';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Validade (lote inicial)
                          TextFormField(
                            controller: _validadeController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Validade (do lote cadastrado)',
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            onTap: _selecionarDataValidade,
                            validator: (_) => _validadeSelecionada == null
                                ? 'Selecione a validade'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Nº do lote (opcional) — NOVO
                          TextFormField(
                            controller: _loteController,
                            decoration: const InputDecoration(
                              labelText: 'Nº do lote (opcional)',
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Fornecedor
                          Text('Fornecedor',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: StreamBuilder<List<Fornecedor>>(
                                  stream: _repo.streamAll(),
                                  builder: (context, snapshot) {
                                    final fornecedores = snapshot.data ?? [];
                                    // atualiza cache sempre que a stream emite
                                    _fornecedoresCache = fornecedores;

                                    final items = <DropdownMenuItem<String>>[
                                      ...fornecedores.map((f) =>
                                          DropdownMenuItem<String>(
                                            value: f.nome,
                                            child: Text(
                                              (f.email == null || f.email!.isEmpty)
                                                  ? f.nome
                                                  : '${f.nome}  —  ${f.email}',
                                            ),
                                          )),
                                      const DropdownMenuItem<String>(
                                        value: '__manual__',
                                        child: Text('Outro (digitar manualmente)'),
                                      ),
                                    ];

                                    return DropdownButtonFormField<String>(
                                      value: items.any((e) => e.value == _fornecedorSelecionadoNome)
                                          ? _fornecedorSelecionadoNome
                                          : null,
                                      items: items,
                                      onChanged: (v) async {
                                        if (v == null) return;
                                        if (v == '__manual__') {
                                          final typed = await _digitarFornecedorManual();
                                          if (typed != null && typed.$1.trim().isNotEmpty) {
                                            setState(() {
                                              _fornecedorSelecionadoNome = typed.$1.trim();
                                              _fornecedorSelecionadoEmail = typed.$2; // pode ser null
                                            });
                                          }
                                        } else {
                                          // selecionado da lista: preenche nome + email
                                          final nomeSel = v.trim();
                                          final sel = fornecedores.firstWhere(
                                            (f) => _repo.normalize(f.nome) == _repo.normalize(nomeSel),
                                            orElse: () => Fornecedor(id: '', nome: nomeSel, email: null),
                                          );
                                          setState(() {
                                            _fornecedorSelecionadoNome = sel.nome;
                                            _fornecedorSelecionadoEmail = sel.email; // pode ser null
                                          });
                                        }
                                      },
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        hintText: 'Selecionar fornecedor',
                                      ),
                                      validator: (v) {
                                        final nome = _fornecedorSelecionadoNome;
                                        if (nome == null || nome.trim().isEmpty) {
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
                                  final createdName = await _adicionarFornecedorDialog();
                                  if (createdName != null) {
                                    setState(() {
                                      _fornecedorSelecionadoNome = createdName;
                                      // email virá pela stream no próximo tick
                                    });
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Fornecedor adicionado!')),
                                      );
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
                            decoration: const InputDecoration(
                              labelText: 'Telefone do fornecedor (opcional)',
                            ),
                            keyboardType: TextInputType.phone,
                          ),

                          const SizedBox(height: 28),

                          // Ações
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: _salvarProduto,
                                icon: const Icon(Icons.save),
                                label: const Text('Salvar Produto'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (context) => const HomePage()),
                                    (route) => false,
                                  );
                                },
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                label: const Text('Voltar', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
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
