// lib/pages/produtos_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:kwalps_st/services/authz_service.dart';
import 'package:kwalps_st/services/session_service.dart';
import 'package:kwalps_st/services/stock_service.dart'; // <-- (novo)
import 'package:kwalps_st/pages/enviar_email_page.dart';

class ProdutosPage extends StatefulWidget {
  const ProdutosPage({super.key});
  @override
  State<ProdutosPage> createState() => _ProdutosPageState();
}

class _ProdutosPageState extends State<ProdutosPage> {
  String _search = '';

  // ===================== TOASTS (azul/branco) =====================
  void _ok(String msg) => _toast(
        msg,
        icon: Icons.check_circle,
        bg: Theme.of(context).colorScheme.primary,
        fg: Theme.of(context).colorScheme.onPrimary,
      );

  void _err(String msg) => _toast(
        msg,
        icon: Icons.error_outline,
        bg: Theme.of(context).colorScheme.error,
        fg: Theme.of(context).colorScheme.onError,
      );

  void _toast(
    String msg, {
    required IconData icon,
    required Color bg,
    required Color fg,
  }) {
    final sb = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 18),
      duration: const Duration(seconds: 2),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: bg.withOpacity(.25), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(color: fg, fontWeight: FontWeight.w700),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(sb);
  }
  // ===============================================================

  String _tsToString(dynamic v) {
    if (v == null) return '-';
    try {
      final date = (v as dynamic).toDate?.call();
      if (date is DateTime) {
        final yyyy = date.year.toString().padLeft(4, '0');
        final mm = date.month.toString().padLeft(2, '0');
        final dd = date.day.toString().padLeft(2, '0');
        return '$yyyy-$mm-$dd';
      }
    } catch (_) {}
    return v.toString();
  }

  // Próxima validade entre lotes (fallback: validade do produto)
  Future<String> _carregarProximaValidade(String produtoId, String fallbackVal) async {
    final lotesCol = FirebaseFirestore.instance
        .collection('produtos')
        .doc(produtoId)
        .collection('lotes');

    final q = await lotesCol.orderBy('validade').get();
    if (q.docs.isEmpty) return fallbackVal;

    DateTime? earliest;
    for (final d in q.docs) {
      final v = d.data()['validade'];
      if (v != null) {
        final dt = (v as dynamic).toDate?.call();
        if (dt is DateTime) {
          if (earliest == null || dt.isBefore(earliest)) earliest = dt;
        }
      }
    }
    if (earliest == null) return fallbackVal;

    String fmt(DateTime d) {
      final yyyy = d.year.toString().padLeft(4, '0');
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return '$yyyy-$mm-$dd';
    }

    return fmt(earliest);
  }

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('produtos');
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos'),
        actions: [
          IconButton(
            tooltip: 'Enviar email aos fornecedores',
            icon: const Icon(Icons.mail_outline_rounded),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EnviarEmailPage()));
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Pesquisar por produto ou categoria…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: col.orderBy('nome').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erro ao carregar produtos:\n${snap.error}', textAlign: TextAlign.center),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhum produto cadastrado.'));
          }

          final docs = snap.data!.docs.toList()
            ..sort((a, b) {
              final na = (a.data()['nome'] ?? '').toString().toLowerCase();
              final nb = (b.data()['nome'] ?? '').toString().toLowerCase();
              return na.compareTo(nb);
            });

          final filtered = _search.isEmpty
              ? docs
              : docs.where((d) {
                  final data = d.data();
                  final nome = (data['nome'] ?? '').toString().toLowerCase();
                  final cat = (data['categoria'] ?? '').toString().toLowerCase();
                  return nome.contains(_search) || cat.contains(_search);
                }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('Nenhum resultado.'));
          }

          return LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              int cols = 1;
              if (w >= 1200) {
                cols = 4;
              } else if (w >= 900) {
                cols = 3;
              } else if (w >= 600) {
                cols = 2;
              }

              return GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.20,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final d = filtered[i];
                  final data = d.data();
                  final produtoId = d.id;

                  final nome = (data['nome'] ?? '').toString();
                  final categoria = (data['categoria'] ?? '').toString();

                  // Casts seguros
                  final qtdTotal = ((data['quantidade_total'] ?? data['quantidade']) as num?)?.toInt() ?? 0;
                  final minimo   = (data['estoque_minimo'] as num?)?.toInt() ?? 0;
                  final critico  = qtdTotal > 0 ? (qtdTotal <= minimo) : false;
                  final validadeProduto = _tsToString(data['validade']);

                  final estado = _estadoEstoque(qtdTotal, minimo, critico);
                  final estadoColor = _estadoColor(context, estado);

                  return _ProdutoQuickCard(
                    title: nome.isEmpty ? '(sem nome)' : nome,
                    headerColor: cs.primary,
                    estadoLabel: estado,
                    estadoColor: estadoColor,
                    lines: [
                      _InfoFutureLine(
                        icon: Icons.event,
                        label: 'Próx. validade',
                        future: _carregarProximaValidade(produtoId, validadeProduto),
                      ),
                      _infoSimple(Icons.category, 'Categoria', categoria.isEmpty ? '-' : categoria),
                      _infoSimple(Icons.numbers, 'Total', '$qtdTotal'),
                      _infoSimple(Icons.flag, 'Mínimo', '$minimo'),
                    ],
                    onOpenLotes: () => _openLotesSheet(context, produtoId: produtoId, produtoNome: nome),
                    onOpenEmail: null,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _estadoEstoque(int qtd, int minimo, bool critico) {
    if (qtd <= 0) return 'Sem stock';
    if (critico) return 'Abaixo do mínimo ($minimo)';
    return 'OK';
  }

  Color _estadoColor(BuildContext context, String estado) {
    if (estado.startsWith('Sem')) return const Color(0xFFE53935);
    if (estado.startsWith('Abaixo')) return const Color(0xFFFF9800);
    return const Color(0xFF1DB954);
  }

  // ======= Modal LOTES =======
  Future<void> _openLotesSheet(
    BuildContext context, {
    required String produtoId,
    required String produtoNome,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final moneyFmt = NumberFormat.currency(symbol: 'Kz ', decimalDigits: 2);

    bool isActive(DateTime? validade, int qtd) {
      if (validade == null) return qtd > 0;
      final today = DateTime.now();
      final v = DateTime(validade.year, validade.month, validade.day);
      final today0 = DateTime(today.year, today.month, today.day);
      final notExpired = !v.isBefore(today0); // hoje conta como válido
      return qtd > 0 && notExpired;
    }

    DateTime inatividadeEm(Map<String, dynamic> lote, DateTime? validade, bool ativo) {
      final tsAtual = lote['atualizado_em'];
      final tsCriado = lote['criado_em'];
      final atualizado = _castTs(tsAtual) ?? _castTs(tsCriado);
      if (!ativo) {
        final today = DateTime.now();
        final v = validade == null ? null : DateTime(validade.year, validade.month, validade.day);
        final expired = v == null ? false : !v.isAfter(DateTime(today.year, today.month, today.day));
        if (expired && v != null) return v;
        return atualizado ?? v ?? DateTime.now();
      }
      return atualizado ?? DateTime.now();
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .88,
          minChildSize: .5,
          maxChildSize: .95,
          builder: (context, controller) {
            final lotesQuery = FirebaseFirestore.instance
                .collection('produtos')
                .doc(produtoId)
                .collection('lotes');

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      Text(
                        'Lotes de "$produtoNome"',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: lotesQuery.snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return const Center(child: Text('Erro ao listar lotes.'));
                      }
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final allDocs = snap.data?.docs ?? [];
                      if (allDocs.isEmpty) {
                        return const Center(child: Text('Nenhum lote cadastrado para este produto.'));
                      }

                      // Oculta lotes marcados como resolvidos
                      final docs = allDocs.where((d) {
                        final data = d.data();
                        final resolvido = (data['resolvido'] ?? false) == true;
                        return !resolvido;
                      }).toList();

                      final hoje = DateTime.now();

                      final mapped = docs.map((d) {
                        final lote = d.data();
                        final codigo = (lote['codigo'] ?? '').toString().trim();
                        final qtd = (lote['quantidade'] as num?)?.toInt() ?? 0;

                        final ts = lote['validade'];
                        DateTime? validade;
                        try {
                          validade = (ts as dynamic).toDate?.call();
                        } catch (_) {}

                        final ativo = isActive(validade, qtd);
                        final inativado = inatividadeEm(lote, validade, ativo);
                        final dias = validade == null
                            ? null
                            : DateTime(validade.year, validade.month, validade.day)
                                .difference(DateTime(hoje.year, hoje.month, hoje.day))
                                .inDays;

                        final precoUnit = (lote['preco_unitario'] is num) ? (lote['preco_unitario'] as num).toDouble() : null;
                        final precoTotal = (lote['preco_total'] is num) ? (lote['preco_total'] as num).toDouble() : null;

                        final fornecedorNome = (lote['fornecedor_nome'] ?? '').toString().trim();
                        final fornecedorId = (lote['fornecedor_id'] ?? '').toString().trim();

                        return (
                          ref: d.reference,
                          codigo: codigo,
                          qtd: qtd,
                          validade: validade,
                          dias: dias,
                          ativo: ativo,
                          inativadoEm: inativado,
                          precoUnit: precoUnit,
                          precoTotal: precoTotal,
                          fornecedor: fornecedorNome.isEmpty ? '—' : fornecedorNome,
                          fornecedorId: fornecedorId.isEmpty ? null : fornecedorId
                        );
                      }).toList();

                      final ativos = mapped.where((e) => e.ativo).toList()
                        ..sort((a, b) {
                          final va = a.validade ?? DateTime(9999);
                          final vb = b.validade ?? DateTime(9999);
                          return va.compareTo(vb);
                        });

                      final inativos = mapped.where((e) => !e.ativo).toList()
                        ..sort((a, b) => b.inativadoEm.compareTo(a.inativadoEm));

                      return ListView(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                        children: [
                          _sectionTitle('Ativos (${ativos.length})'),
                          if (ativos.isEmpty)
                            _emptyBox('Nenhum lote ativo.')
                          else
                            ...ativos.asMap().entries.map((e) {
                              final i = e.key;
                              final l = e.value;

                              final border = _borderFor(cs, l.validade, hoje);
                              final chip = _chipText(l.dias);

                              return _LoteRowCard(
                                index: i + 1,
                                codigo: l.codigo,
                                qtd: l.qtd,
                                validadeStr: l.validade == null ? '-' : _yyyyMmDd(l.validade!),
                                chipText: chip,
                                ativo: true,
                                borderColor: border,
                                statusColor: const Color(0xFF1DB954),
                                precoUnit: l.precoUnit == null ? '—' : moneyFmt.format(l.precoUnit!),
                                precoTotal: l.precoTotal == null ? '—' : moneyFmt.format(l.precoTotal!),
                                fornecedor: l.fornecedor,
                                onSaida: () async {
                                  final q = await _askQtd(context, title: 'Registrar SAÍDA (lote ${i + 1})');
                                  if (q == null) return;

                                  final session = SessionService();
                                  if (!session.adminOverride && !session.hasValidOperator) {
                                    final cred = await _askCredenciais(context);
                                    if (cred == null) return;
                                    final res = await AuthzService().verifyWithRole(nome: cred.$1, chave: cred.$2);
                                    if (!mounted) return;
                                    if (!res.ok) {
                                      _err('Credenciais inválidas.');
                                      return;
                                    }
                                    if (res.isAdmin) {
                                      await session.setAdminOverride(true, name: res.nome);
                                    } else {
                                      await session.saveOrRefreshOperator(name: res.nome, key: cred.$2);
                                    }
                                  }

                                  if (q > l.qtd) {
                                    _err('Quantidade maior que o disponível no lote.');
                                    return;
                                  }

                                  try {
                                    await StockService().registrarSaida(
                                      produtoId: produtoId,
                                      quantidade: q,
                                      motivo: 'consumo',
                                      operador: SessionService().adminName ?? SessionService().operatorName ?? 'operador',
                                      loteId: l.ref.id,
                                      custoUnitSaida: l.precoUnit, // pode ser null
                                    );
                                    if (mounted) _ok('Saída registada.');
                                  } catch (e) {
                                    if (mounted) _err('Erro ao registar saída: $e');
                                  }
                                },
                                onEntrada: () async {
                                  final q = await _askQtd(context, title: 'Registrar ENTRADA (lote ${i + 1})');
                                  if (q == null) return;

                                  final session = SessionService();
                                  if (!session.adminOverride) {
                                    final cred = await _askCredenciais(context, titulo: 'Autenticar Admin');
                                    if (cred == null) return;
                                    final res = await AuthzService().verifyWithRole(nome: cred.$1, chave: cred.$2);
                                    if (!mounted) return;
                                    if (!res.ok || !res.isAdmin) {
                                      _err('Apenas administrador pode lançar ENTRADA.');
                                      return;
                                    }
                                    await session.setAdminOverride(true, name: res.nome);
                                  }

                                  try {
                                    await StockService().registrarEntrada(
                                      produtoId: produtoId,
                                      quantidade: q,
                                      motivo: 'compra',
                                      operador: SessionService().adminName ?? SessionService().operatorName ?? 'admin',
                                      loteId: l.ref.id,
                                      precoUnit: l.precoUnit,
                                      precoTotal: null,
                                      fornecedorId: l.fornecedorId,
                                      fornecedorNome: (l.fornecedor == '—') ? null : l.fornecedor,
                                    );
                                    if (mounted) _ok('Entrada registada.');
                                  } catch (e) {
                                    if (mounted) _err('Erro ao registar entrada: $e');
                                  }
                                },
                              );
                            }),

                          const SizedBox(height: 12),
                          _sectionTitle('Inativos (${inativos.length})'),
                          if (inativos.isEmpty)
                            _emptyBox('Nenhum lote inativo.')
                          else
                            ...inativos.asMap().entries.map((e) {
                              final i = e.key;
                              final l = e.value;

                              final border = _borderFor(cs, l.validade, hoje);
                              final chip = _chipText(l.dias);
                              final inatStr = _yyyyMmDd(l.inativadoEm);

                              return _LoteRowCard(
                                index: i + 1,
                                codigo: l.codigo,
                                qtd: l.qtd,
                                validadeStr: l.validade == null ? '-' : _yyyyMmDd(l.validade!),
                                chipText: chip,
                                ativo: false,
                                borderColor: border,
                                statusColor: const Color(0xFFE53935),
                                precoUnit: l.precoUnit == null ? '—' : moneyFmt.format(l.precoUnit!),
                                precoTotal: l.precoTotal == null ? '—' : moneyFmt.format(l.precoTotal!),
                                inativadoEm: 'Inativado em: $inatStr',
                                fornecedor: l.fornecedor,
                              );
                            }),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _borderFor(ColorScheme cs, DateTime? validade, DateTime hoje) {
    if (validade == null) return cs.outlineVariant;
    final v = DateTime(validade.year, validade.month, validade.day);
    if (v.isBefore(DateTime(hoje.year, hoje.month, hoje.day))) {
      return const Color(0xFFE53935);
    } else if (v.difference(hoje).inDays <= 30) {
      return const Color(0xFFFF9800);
    } else {
      return const Color(0xFF1DB954);
    }
  }

  String _chipText(int? dias) {
    if (dias == null) return '—';
    if (dias < 0) return 'Vencido';
    if (dias == 0) return 'Vence hoje';
    if (dias == 1) return 'Amanhã';
    return 'Faltam $dias dias';
  }

  DateTime? _castTs(dynamic v) {
    try {
      final d = (v as dynamic)?.toDate?.call();
      if (d is DateTime) return d;
    } catch (_) {}
    return null;
  }

  static String _yyyyMmDd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final d2 = d.day.toString().padLeft(2, '0');
    return '$y-$m-$d2';
  }

  Future<int?> _askQtd(BuildContext context, {required String title}) async {
    final ctrl = TextEditingController();
    final form = GlobalKey<FormState>();
    return showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Form(
          key: form,
          child: TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantidade'),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null || n <= 0) return 'Informe uma quantidade válida';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              Navigator.pop(context, int.parse(ctrl.text.trim()));
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<(String, String)?> _askCredenciais(BuildContext context, {String titulo = 'Autenticar'}) async {
    final nome = TextEditingController();
    final chave = TextEditingController();
    final form = GlobalKey<FormState>();
    bool obscure = true;
    return showDialog<(String, String)>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) {
          return AlertDialog(
            title: Text(titulo),
            content: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nome,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: chave,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Chave',
                      suffixIcon: IconButton(
                        onPressed: () => setSt(() => obscure = !obscure),
                        icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a chave' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  if (!form.currentState!.validate()) return;
                  Navigator.pop(context, (nome.text.trim(), chave.text.trim()));
                },
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ===== Lines compactas =====
Widget _infoSimple(IconData icon, String label, String value) {
  final style = const TextStyle(fontSize: 15);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Icon(icon, size: 16),
      const SizedBox(width: 6),
      Expanded(
        child: Text('$label: $value', overflow: TextOverflow.ellipsis, style: style),
      ),
    ],
  );
}

class _InfoFutureLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<String> future;
  const _InfoFutureLine({required this.icon, required this.label, required this.future});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return FutureBuilder<String>(
      future: future,
      builder: (context, snap) {
        final value = snap.data ?? '…';
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: onSurface.withOpacity(.8)),
            const SizedBox(width: 6),
            Expanded(
              child: Text('$label: $value', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
            ),
          ],
        );
      },
    );
  }
}

// ====== Card mais compacto e com badge forte ======
class _ProdutoQuickCard extends StatelessWidget {
  final String title;
  final Color headerColor;
  final String estadoLabel;
  final Color estadoColor;
  final List<Widget> lines;
  final VoidCallback onOpenLotes;
  final VoidCallback? onOpenEmail;

  const _ProdutoQuickCard({
    required this.title,
    required this.headerColor,
    required this.estadoLabel,
    required this.estadoColor,
    required this.lines,
    required this.onOpenLotes,
    this.onOpenEmail,
  });

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          // Cabeçalho
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: estadoColor,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(color: estadoColor.withOpacity(.25), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    estadoLabel.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Corpo
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: DefaultTextStyle(
                style: const TextStyle(fontSize: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...lines.expand((w) sync* {
                      yield w;
                      yield const SizedBox(height: 4);
                    }).toList()
                      ..removeLast(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (onOpenEmail != null)
                          IconButton.filledTonal(
                            tooltip: 'Email',
                            onPressed: onOpenEmail,
                            icon: const Icon(Icons.mail_outline_rounded, size: 20),
                          ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: onOpenLotes,
                          icon: const Icon(Icons.inventory_2_outlined, size: 18),
                          label: const Text('Abrir lotes'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            textStyle: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====== Card/Row de LOTE com status à esquerda + preços + fornecedor ======
class _LoteRowCard extends StatelessWidget {
  final int index;
  final String codigo;
  final int qtd;
  final String validadeStr;
  final String chipText;
  final bool ativo;
  final Color borderColor;
  final Color statusColor;
  final String precoUnit;  // "Kz 1.000,00" ou "—"
  final String precoTotal; // idem
  final String? inativadoEm;
  final String fornecedor;

  final VoidCallback? onSaida;
  final VoidCallback? onEntrada;

  const _LoteRowCard({
    required this.index,
    required this.codigo,
    required this.qtd,
    required this.validadeStr,
    required this.chipText,
    required this.ativo,
    required this.borderColor,
    required this.statusColor,
    required this.precoUnit,
    required this.precoTotal,
    this.inativadoEm,
    required this.fornecedor,
    this.onSaida,
    this.onEntrada,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        children: [
          // Faixa de status à esquerda
          Container(
            width: 76,
            height: 120,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(.10),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              border: Border(right: BorderSide(color: statusColor.withOpacity(.35), width: 1)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ativo ? Icons.verified_rounded : Icons.block_rounded, color: statusColor),
                const SizedBox(height: 6),
                Text(
                  ativo ? 'ATIVO' : 'INATIVO',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
              ],
            ),
          ),

          // Conteúdo
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título + badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          codigo.isEmpty ? 'Lote s/ nº' : 'Lote $codigo',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withOpacity(.06),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: cs.onSurface.withOpacity(.28)),
                        ),
                        child: Text(
                          chipText,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _pair(Icons.event, 'Validade', validadeStr),
                      _pair(Icons.numbers, 'Qtd', '$qtd'),
                      _pair(Icons.storefront_rounded, 'Fornecedor', fornecedor),
                      _pair(Icons.attach_money_rounded, 'Preço unit.', precoUnit),
                      _pair(Icons.payments_rounded, 'Preço total', precoTotal),
                      if (!ativo && (inativadoEm?.isNotEmpty ?? false)) _pair(Icons.history, '', inativadoEm!),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (ativo)
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: onSaida,
                          icon: const Icon(Icons.remove_circle_rounded, color: Color(0xFFE53935)),
                          label: const Text('Saída', style: TextStyle(color: Color(0xFFE53935))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE53935)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: onEntrada,
                          icon: const Icon(Icons.add_circle_rounded),
                          label: const Text('Entrada'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pair(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        if (label.isNotEmpty)
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(value),
      ],
    );
  }
}

// ===== helpers visuais =====
Widget _sectionTitle(String t) {
  return Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8, top: 6),
    child: Text(t, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
  );
}

Widget _emptyBox(String msg) => Center(
      child: Padding(padding: const EdgeInsets.all(12), child: Text(msg)),
    );
