// lib/pages/cadastro_produto_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kwalps_st/pages/home_page.dart';

class CadastroProdutoPage extends StatefulWidget {
  const CadastroProdutoPage({super.key});

  @override
  State<CadastroProdutoPage> createState() => _CadastroProdutoPageState();
}

class _CadastroProdutoPageState extends State<CadastroProdutoPage> {
  // --- STATE COMPARTILHADO PELO WIZARD ---
  final _formKey = GlobalKey<FormState>();

  String? _produtoId;
  String? _produtoNome;

  final _qtdCtrl = TextEditingController(text: '1'); // editável
  final _validadeCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();

  DateTime? _validade;
  final _dateFmt = DateFormat('dd/MM/yyyy');
  bool _salvando = false;

  @override
  void dispose() {
    _qtdCtrl.dispose();
    _validadeCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  // ---------------- UI HELPERS ----------------
  InputDecoration _input(BuildContext context, String label,
      {Widget? suffixIcon, String? hint}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: cs.surface, // fundo visível
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  ButtonStyle get _bigPrimary => FilledButton.styleFrom(
        minimumSize: const Size(140, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      );

  ButtonStyle get _bigOutlined => OutlinedButton.styleFrom(
        minimumSize: const Size(140, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      );

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(t,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      );

  void _ok(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  void _erro(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  // --------------- AÇÕES ---------------
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      helpText: 'Selecione a data de validade',
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (d != null) {
      setState(() {
        _validade = DateTime(d.year, d.month, d.day, 12);
        _validadeCtrl.text = _dateFmt.format(d);
      });
    }
  }

  void _limpar() {
    setState(() {
      _produtoId = null;
      _produtoNome = null;
      _qtdCtrl.text = '1';
      _validade = null;
      _validadeCtrl.clear();
      _codigoCtrl.clear();
    });
    _formKey.currentState?.reset();
  }

  Future<void> _salvar({BuildContext? dialogCtx}) async {
    if (_salvando) return;

    final qtd = int.tryParse(_qtdCtrl.text.trim()) ?? 0;
    if (_produtoId == null) {
      _erro('Escolha um produto.');
      return;
    }
    if (qtd <= 0) {
      _erro('Quantidade deve ser maior que zero.');
      return;
    }
    if (_validade == null) {
      _erro('Escolha a validade.');
      return;
    }

    setState(() => _salvando = true);
    FocusScope.of(context).unfocus();

    try {
      final refProd =
          FirebaseFirestore.instance.collection('produtos').doc(_produtoId);

      await refProd.collection('lotes').add({
        'codigo':
            _codigoCtrl.text.trim().isEmpty ? null : _codigoCtrl.text.trim(),
        'quantidade': qtd,
        'validade': _validade,
        'criado_em': FieldValue.serverTimestamp(),
      });

      await refProd.update({
        'quantidade_total': FieldValue.increment(qtd),
      }).catchError((_) {});

      _ok('Lote salvo com sucesso.');
      _limpar();

      // fecha o modal (o contexto deve ser o do diálogo)
      if (dialogCtx != null && Navigator.of(dialogCtx).canPop()) {
        Navigator.of(dialogCtx).pop();
      }
    } catch (e) {
      _erro('Falha ao salvar lote: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // --------------- MODAL WIZARD ---------------
  Future<void> _abrirWizard() async {
    int step = 0;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final cs = Theme.of(dialogCtx).colorScheme;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Widget conteudo;

            // ===== PASSO 1 — PRODUTO =====
            if (step == 0) {
              conteudo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titulo('1. Selecionar produto'),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('produtos')
                        .orderBy('nome')
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return ListTile(
                          leading:
                              const Icon(Icons.error_outline, color: Colors.red),
                          title: const Text('Erro ao carregar produtos.'),
                          trailing: IconButton(
                            onPressed: () => setModalState(() {}),
                            icon: const Icon(Icons.refresh),
                          ),
                        );
                      }
                      if (!snap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        );
                      }

                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text(
                            'Nenhum produto encontrado. Cadastre produtos na aba Admin → Produtos.',
                            style: TextStyle(fontSize: 16),
                          ),
                        );
                      }

                      final items = docs.map((d) {
                        final data =
                            d.data() as Map<String, dynamic>? ?? {};
                        final nome =
                            (data['nome'] ?? '').toString().trim();
                        return DropdownMenuItem<String>(
                          value: d.id,
                          child: Text(
                            nome.isEmpty ? '(sem nome)' : nome,
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      }).toList();

                      return DropdownButtonFormField<String>(
                        value: _produtoId,
                        items: items,
                        onChanged: (v) {
                          setModalState(() {
                            _produtoId = v;
                            // atualiza também o nome visível
                            final doc = docs.firstWhere(
                              (d) => d.id == v,
                              orElse: () => docs.first,
                            );
                            final data =
                                doc.data() as Map<String, dynamic>? ?? {};
                            _produtoNome =
                                (data['nome'] ?? '').toString().trim();
                          });
                        },
                        decoration: _input(context, 'Produto (selecione)'),
                        dropdownColor: cs.surface, // fundo do menu
                        isExpanded: true,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Selecione um produto'
                            : null,
                        style: const TextStyle(fontSize: 16),
                        menuMaxHeight: 400,
                      );
                    },
                  ),
                ],
              );
            }
            // ===== PASSO 2 — DETALHES =====
            else if (step == 1) {
              conteudo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titulo('2. Detalhes do lote'),
                  const SizedBox(height: 8),

                  // QUANTIDADE: campo + –/+
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _qtdCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: _input(
                              context, 'Quantidade (nº de unidades)'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () {
                          final n =
                              int.tryParse(_qtdCtrl.text.trim()) ?? 1;
                          final v = (n > 1) ? n - 1 : 1;
                          _qtdCtrl.text = '$v';
                          setModalState(() {});
                        },
                        icon: const Icon(Icons.remove),
                        iconSize: 28,
                        tooltip: 'Diminuir',
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        onPressed: () {
                          final n =
                              int.tryParse(_qtdCtrl.text.trim()) ?? 1;
                          _qtdCtrl.text = '${n + 1}';
                          setModalState(() {});
                        },
                        icon: const Icon(Icons.add),
                        iconSize: 28,
                        tooltip: 'Aumentar',
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // VALIDADE
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _validadeCtrl,
                          readOnly: true,
                          decoration: _input(
                              context, 'Validade',
                              suffixIcon: const Icon(Icons.calendar_today)),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () async {
                          await _pickDate();
                          setModalState(() {});
                        },
                        icon: const Icon(Icons.event),
                        label: const Text('Escolher data'),
                        style: _bigPrimary,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _codigoCtrl,
                    decoration:
                        _input(context, 'Código / Nº do lote (opcional)'),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              );
            }
            // ===== PASSO 3 — CONFIRMAR =====
            else {
              final qtd = int.tryParse(_qtdCtrl.text.trim()) ?? 0;
              conteudo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titulo('3. Confirmar'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        _linhaResumo(
                          icon: Icons.inventory_2,
                          label: 'Produto',
                          value: _produtoNome ?? '—',
                        ),
                        const SizedBox(height: 8),
                        _linhaResumo(
                          icon: Icons.onetwothree,
                          label: 'Quantidade',
                          value: qtd > 0 ? '$qtd un' : '—',
                        ),
                        const SizedBox(height: 8),
                        _linhaResumo(
                          icon: Icons.event,
                          label: 'Validade',
                          value: _validadeCtrl.text.isEmpty
                              ? '—'
                              : _validadeCtrl.text,
                        ),
                        if (_codigoCtrl.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _linhaResumo(
                            icon: Icons.qr_code_2,
                            label: 'Código',
                            value: _codigoCtrl.text.trim(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }

            return AlertDialog(
              titlePadding:
                  const EdgeInsets.only(left: 20, right: 12, top: 16),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Row(
                children: [
                  Text(step == 0
                      ? 'Novo lote — Passo 1/3'
                      : step == 1
                          ? 'Novo lote — Passo 2/3'
                          : 'Novo lote — Passo 3/3'),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: SingleChildScrollView(child: conteudo),
              ),
              actions: [
                Row(
                  children: [
                    if (step > 0)
                      OutlinedButton.icon(
                        onPressed: () => setModalState(() => step--),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Voltar'),
                        style: _bigOutlined,
                      ),
                    TextButton.icon(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                    ),
                    const Spacer(),
                    if (step < 2)
                      FilledButton.icon(
                        onPressed: () {
                          // validação simples por etapa
                          if (step == 0 && _produtoId == null) {
                            _erro('Selecione um produto.');
                            return;
                          }
                          if (step == 1) {
                            final qtd = int.tryParse(_qtdCtrl.text.trim()) ?? 0;
                            if (qtd <= 0) {
                              _erro('Quantidade inválida.');
                              return;
                            }
                            if (_validade == null) {
                              _erro('Escolha a validade.');
                              return;
                            }
                          }
                          setModalState(() => step++);
                        },
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Próximo'),
                        style: _bigPrimary,
                      ),
                    if (step == 2)
                      FilledButton.icon(
                        onPressed: _salvando
                            ? null
                            : () => _salvar(dialogCtx: dialogCtx),
                        icon: _salvando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                            _salvando ? 'Salvando...' : 'Confirmar e salvar'),
                        style: _bigPrimary,
                      ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // linha visual do resumo (ícone + rótulo + valor grande)
  Widget _linhaResumo(
      {required IconData icon,
      required String label,
      required String value}) {
    return Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 10),
        Text('$label: ',
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  // --------------- BUILD (um botão para abrir o wizard) ---------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Adicionar um novo lote',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Clique no botão abaixo e siga os 3 passos simples.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _abrirWizard,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Novo Lote (passo a passo)'),
                      style: _bigPrimary,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const HomePage()),
                          (r) => false,
                        );
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Voltar'),
                      style: _bigOutlined,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
