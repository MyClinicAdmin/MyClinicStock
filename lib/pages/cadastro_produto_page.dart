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

enum _PrecoModo { unidade, total }

class _CadastroProdutoPageState extends State<CadastroProdutoPage> {
  // --- STATE COMPARTILHADO PELO WIZARD ---
  final _formKey = GlobalKey<FormState>();

  String? _produtoId;
  String? _produtoNome;

  // Fornecedor (opcional)
  String? _fornecedorId;
  String? _fornecedorNome;

  final _qtdCtrl = TextEditingController(text: '1'); // editável
  final _validadeCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();

  // Preços
  final _precoUnitCtrl = TextEditingController(); // p/ unidade
  final _precoTotalCtrl = TextEditingController(); // p/ lote
  _PrecoModo _precoModo = _PrecoModo.unidade;

  DateTime? _validade;
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _moneyFmt = NumberFormat.currency(symbol: 'Kz ', decimalDigits: 2);
  bool _salvando = false;

  @override
  void dispose() {
    _qtdCtrl.dispose();
    _validadeCtrl.dispose();
    _codigoCtrl.dispose();
    _precoUnitCtrl.dispose();
    _precoTotalCtrl.dispose();
    super.dispose();
  }

  // ---------------- UI HELPERS ----------------
  InputDecoration _input(BuildContext context, String label,
      {Widget? suffixIcon, String? hint, Widget? prefix}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: cs.surface, // fundo visível
      prefixIcon: prefix,
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

  // ----------------- Avisos (dialogs compactos) -----------------
  Future<void> _dialogAviso({
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 46, color: color),
              const SizedBox(height: 10),
              Text(
                title ?? (ok ? 'Sucesso' : 'Ocorreu um erro'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
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

  // ---------------- UTIL (preço) ----------------
  double? _parseMoney(String raw) {
    if (raw.trim().isEmpty) return null;
    final s = raw.replaceAll('.', '').replaceAll(',', '.'); // básico
    return double.tryParse(s);
  }

  String _formatMoney(num v) => _moneyFmt.format(v);

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
      _fornecedorId = null;
      _fornecedorNome = null;
      _qtdCtrl.text = '1';
      _validade = null;
      _validadeCtrl.clear();
      _codigoCtrl.clear();
      _precoUnitCtrl.clear();
      _precoTotalCtrl.clear();
      _precoModo = _PrecoModo.unidade;
    });
    _formKey.currentState?.reset();
  }

  ({double? unit, double? total}) _resolvePrecos() {
    final qtd = int.tryParse(_qtdCtrl.text.trim()) ?? 0;
    final unit = _parseMoney(_precoUnitCtrl.text);
    final total = _parseMoney(_precoTotalCtrl.text);

    if (_precoModo == _PrecoModo.unidade) {
      if (unit != null && qtd > 0) {
        final t = unit * qtd;
        return (unit: unit, total: t);
      }
      // se não informou unit, não força nada
      return (unit: unit, total: total);
    } else {
      // total do lote
      if (total != null && qtd > 0) {
        final u = total / qtd;
        return (unit: u, total: total);
      }
      return (unit: unit, total: total);
    }
  }

  Future<void> _salvar({BuildContext? dialogCtx}) async {
    if (_salvando) return;

    final qtd = int.tryParse(_qtdCtrl.text.trim()) ?? 0;
    if (_produtoId == null) {
      await _dialogAviso(ok: false, title: 'Produto', message: 'Escolha um produto.');
      return;
    }
    if (qtd <= 0) {
      await _dialogAviso(ok: false, title: 'Quantidade inválida', message: 'Informe uma quantidade maior que zero.');
      return;
    }
    if (_validade == null) {
      await _dialogAviso(ok: false, title: 'Validade', message: 'Escolha a data de validade.');
      return;
    }

    final precos = _resolvePrecos();

    setState(() => _salvando = true);
    FocusScope.of(context).unfocus();

    try {
      final refProd =
          FirebaseFirestore.instance.collection('produtos').doc(_produtoId);

      final loteData = <String, dynamic>{
        'codigo': _codigoCtrl.text.trim().isEmpty ? null : _codigoCtrl.text.trim(),
        'quantidade': qtd,
        'validade': _validade,
        'criado_em': FieldValue.serverTimestamp(),
      };

      // persistir fornecedor se selecionado
      if (_fornecedorId != null && _fornecedorNome != null) {
        loteData['fornecedor_id'] = _fornecedorId;
        loteData['fornecedor_nome'] = _fornecedorNome;
      }

      if (precos.unit != null) {
        loteData['preco_unitario'] = double.parse(precos.unit!.toStringAsFixed(2));
      }
      if (precos.total != null) {
        loteData['preco_total'] = double.parse(precos.total!.toStringAsFixed(2));
      }

      await refProd.collection('lotes').add(loteData);

      await refProd.update({
        'quantidade_total': FieldValue.increment(qtd),
      }).catchError((_) {});

      await _dialogAviso(
        ok: true,
        title: 'Lote salvo',
        message: 'Lote de "${_produtoNome ?? ''}" registado com sucesso.',
      );

      _limpar();

      // fecha o modal (o contexto deve ser o do diálogo)
      if (dialogCtx != null && Navigator.of(dialogCtx).canPop()) {
        Navigator.of(dialogCtx).pop();
      }
    } catch (e) {
      await _dialogAviso(ok: false, title: 'Falha ao salvar', message: '$e');
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
            // Helpers de UI internas ao modal
            Widget precoModoChips() {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Preço por unidade'),
                    selected: _precoModo == _PrecoModo.unidade,
                    onSelected: (_) => setModalState(() => _precoModo = _PrecoModo.unidade),
                    avatar: const Icon(Icons.calculate, size: 18),
                  ),
                  ChoiceChip(
                    label: const Text('Preço total do lote'),
                    selected: _precoModo == _PrecoModo.total,
                    onSelected: (_) => setModalState(() => _precoModo = _PrecoModo.total),
                    avatar: const Icon(Icons.payments_rounded, size: 18),
                  ),
                ],
              );
            }

            String previewTotal() {
              final qtd = int.tryParse(_qtdCtrl.text.trim()) ?? 0;
              final unit = _parseMoney(_precoUnitCtrl.text);
              final total = _parseMoney(_precoTotalCtrl.text);
              if (_precoModo == _PrecoModo.unidade) {
                if (unit != null && qtd > 0) return _formatMoney(unit * qtd);
              } else {
                if (total != null) return _formatMoney(total);
              }
              return '—';
            }

            Widget conteudo;

            // ===== PASSO 1 — PRODUTO + FORNECEDOR =====
            if (step == 0) {
              conteudo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titulo('1. Selecionar produto'),
                  const SizedBox(height: 8),
                  // Produtos
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('produtos')
                        .orderBy('nome')
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return ListTile(
                          leading: const Icon(Icons.error_outline, color: Colors.red),
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

                      // Mapa id->nome para setar o _produtoNome corretamente
                      final Map<String, String> map = {
                        for (final d in docs)
                          d.id: (((d.data() as Map<String, dynamic>? ?? {})['nome'] ?? '') as String).trim()
                      };

                      final items = docs.map((d) {
                        final nome = map[d.id] ?? '(sem nome)';
                        return DropdownMenuItem<String>(
                          value: d.id,
                          child: Text(nome.isEmpty ? '(sem nome)' : nome, style: const TextStyle(fontSize: 16)),
                        );
                      }).toList();

                      return DropdownButtonFormField<String>(
                        value: _produtoId,
                        items: items,
                        onChanged: (v) {
                          setModalState(() {
                            _produtoId = v;
                            _produtoNome = v == null ? null : (map[v] ?? '');
                          });
                        },
                        decoration: _input(context, 'Produto (selecione)'),
                        dropdownColor: cs.surface,
                        isExpanded: true,
                        validator: (v) => (v == null || v.isEmpty) ? 'Selecione um produto' : null,
                        style: const TextStyle(fontSize: 16),
                        menuMaxHeight: 400,
                      );
                    },
                  ),

                  const SizedBox(height: 14),
                  _titulo('Fornecedor (opcional)'),
                  const SizedBox(height: 8),

                  // Fornecedores (select similar ao admin)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('fornecedores')
                        .orderBy('nome')
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return ListTile(
                          leading: const Icon(Icons.error_outline, color: Colors.red),
                          title: const Text('Erro ao carregar fornecedores.'),
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
                      final Map<String, String> map = {
                        for (final d in docs)
                          d.id: (((d.data() as Map<String, dynamic>? ?? {})['nome'] ?? '') as String).trim()
                      };

                      final items = <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('(Sem fornecedor)'),
                        ),
                        ...docs.map((d) {
                          final nome = map[d.id] ?? '(sem nome)';
                          return DropdownMenuItem<String?>(
                            value: d.id,
                            child: Text(nome.isEmpty ? '(sem nome)' : nome),
                          );
                        }),
                      ];

                      return DropdownButtonFormField<String?>(
                        value: _fornecedorId,
                        items: items,
                        onChanged: (v) {
                          setModalState(() {
                            _fornecedorId = v;
                            _fornecedorNome = v == null ? null : (map[v] ?? '');
                          });
                        },
                        decoration: _input(context, 'Fornecedor'),
                        dropdownColor: cs.surface,
                        isExpanded: true,
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
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: _input(context, 'Quantidade (nº de unidades)'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () {
                          final n = int.tryParse(_qtdCtrl.text.trim()) ?? 1;
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
                          final n = int.tryParse(_qtdCtrl.text.trim()) ?? 1;
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
                            context,
                            'Validade',
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
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

                  // CÓDIGO
                  TextFormField(
                    controller: _codigoCtrl,
                    decoration: _input(context, 'Código / Nº do lote (opcional)'),
                    style: const TextStyle(fontSize: 16),
                  ),

                  const Divider(height: 24),

                  // Modo de preço
                  Text('Preço', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  precoModoChips(),
                  const SizedBox(height: 10),

                  if (_precoModo == _PrecoModo.unidade) ...[
                    // Preço por UNIDADE -> total calculado
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _precoUnitCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                            decoration: _input(
                              context,
                              'Preço por unidade',
                              prefix: const Padding(
                                padding: EdgeInsets.only(left: 12, right: 6),
                                child: Text('Kz', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: TextEditingController(text: previewTotal()),
                            readOnly: true,
                            decoration: _input(context, 'Total (auto)'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Preço TOTAL DO LOTE -> unidade estimada
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _precoTotalCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                            decoration: _input(
                              context,
                              'Preço total do lote',
                              prefix: const Padding(
                                padding: EdgeInsets.only(left: 12, right: 6),
                                child: Text('Kz', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: TextEditingController(
                              text: (() {
                                final qtd = int.tryParse(_qtdCtrl.text.trim()) ?? 0;
                                final tot = _parseMoney(_precoTotalCtrl.text);
                                if (tot != null && qtd > 0) {
                                  return _formatMoney(tot / qtd);
                                }
                                return '—';
                              })(),
                            ),
                            readOnly: true,
                            decoration: _input(context, 'Unitário (estimado)'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            }
            // ===== PASSO 3 — CONFIRMAR =====
            else {
              final qtd = int.tryParse(_qtdCtrl.text.trim()) ?? 0;
              final precos = _resolvePrecos();
              final unitStr = (precos.unit != null) ? _formatMoney(precos.unit!) : '—';
              final totalStr = (precos.total != null) ? _formatMoney(precos.total!) : '—';

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
                        _linhaResumo(icon: Icons.inventory_2, label: 'Produto', value: _produtoNome ?? '—'),
                        const SizedBox(height: 8),
                        _linhaResumo(icon: Icons.onetwothree, label: 'Quantidade', value: qtd > 0 ? '$qtd un' : '—'),
                        const SizedBox(height: 8),
                        _linhaResumo(icon: Icons.event, label: 'Validade', value: _validadeCtrl.text.isEmpty ? '—' : _validadeCtrl.text),
                        if (_codigoCtrl.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _linhaResumo(icon: Icons.qr_code_2, label: 'Código', value: _codigoCtrl.text.trim()),
                        ],
                        if (_fornecedorNome != null && _fornecedorNome!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _linhaResumo(icon: Icons.factory_rounded, label: 'Fornecedor', value: _fornecedorNome!),
                        ],
                        const SizedBox(height: 10),
                        const Divider(),
                        const SizedBox(height: 6),
                        _linhaResumo(icon: Icons.calculate, label: 'Preço unitário', value: unitStr),
                        const SizedBox(height: 8),
                        _linhaResumo(icon: Icons.payments_rounded, label: 'Preço total', value: totalStr),
                      ],
                    ),
                  ),
                ],
              );
            }

            return AlertDialog(
              titlePadding: const EdgeInsets.only(left: 20, right: 12, top: 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            _dialogAviso(ok: false, title: 'Produto', message: 'Selecione um produto.');
                            return;
                          }
                          if (step == 1) {
                            final qtd = int.tryParse(_qtdCtrl.text.trim()) ?? 0;
                            if (qtd <= 0) {
                              _dialogAviso(ok: false, title: 'Quantidade inválida', message: 'Informe uma quantidade maior que zero.');
                              return;
                            }
                            if (_validade == null) {
                              _dialogAviso(ok: false, title: 'Validade', message: 'Escolha a data de validade.');
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
                        onPressed: _salvando ? null : () => _salvar(dialogCtx: dialogCtx),
                        icon: _salvando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(_salvando ? 'Salvando...' : 'Confirmar e salvar'),
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
  Widget _linhaResumo({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
