import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kwalps_st/services/stock_service.dart';
import 'package:kwalps_st/services/authz_service.dart';
import 'package:kwalps_st/services/session_service.dart';

enum FaltaFiltro { zerados, abaixoMin }

class ProdutosEmFaltaPage extends StatefulWidget {
  const ProdutosEmFaltaPage({super.key});
  @override
  State<ProdutosEmFaltaPage> createState() => _ProdutosEmFaltaPageState();
}

class _ProdutosEmFaltaPageState extends State<ProdutosEmFaltaPage> {
  FaltaFiltro _filtro = FaltaFiltro.abaixoMin;
  bool _mostrarResolvidos = false;
  String _search = '';

  // ---------- cores e rótulos do filtro
  (Color bg, Color fg, String label, IconData icon) get _badge {
    switch (_filtro) {
      case FaltaFiltro.zerados:
        return (const Color(0xFFE53935), Colors.white, 'Zerados (0)', Icons.priority_high_rounded);
      case FaltaFiltro.abaixoMin:
        return (const Color(0xFFFF9800), Colors.white, 'Abaixo do mínimo', Icons.warning_amber_rounded);
    }
  }

  // Próxima validade entre lotes (fallback: validade do produto)
  Future<String> _proximaValidade(String produtoId, dynamic fallbackTs) async {
    String _fmt(DateTime d) {
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final d2 = d.day.toString().padLeft(2, '0');
      return '$y-$m-$d2';
    }

    String fallbackStr() {
      try {
        final date = (fallbackTs as dynamic).toDate?.call();
        if (date is DateTime) return _fmt(date);
      } catch (_) {}
      return '-';
    }

    try {
      final lotesCol = FirebaseFirestore.instance
          .collection('produtos')
          .doc(produtoId)
          .collection('lotes');

      final q = await lotesCol.orderBy('validade').get();
      if (q.docs.isEmpty) return fallbackStr();

      DateTime? earliest;
      for (final d in q.docs) {
        final v = d.data()['validade'];
        if (v != null) {
          try {
            final dt = (v as dynamic).toDate?.call();
            if (dt is DateTime) {
              if (earliest == null || dt.isBefore(earliest!)) earliest = dt;
            }
          } catch (_) {}
        }
      }
      return earliest == null ? fallbackStr() : _fmt(earliest!);
    } catch (_) {
      return fallbackStr();
    }
  }

  // ---------- toasts azul/branco
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
  void _toast(String msg, {required IconData icon, required Color bg, required Color fg}) {
    final sb = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 18),
      duration: const Duration(seconds: 2),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: bg.withOpacity(.25), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Icon(icon, color: fg), const SizedBox(width: 10),
          Expanded(child: Text(msg, style: TextStyle(color: fg, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(sb);
  }

  @override
  Widget build(BuildContext context) {
    final (badgeBg, _, badgeLabel, badgeIcon) = _badge;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos em Falta'),
        actions: [
          Row(children: [
            const Text('Resolvidos', style: TextStyle(fontSize: 13)),
            Switch(
              value: _mostrarResolvidos,
              onChanged: (v) => setState(() => _mostrarResolvidos = v),
            ),
            const SizedBox(width: 6),
          ]),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                // Segmented/pílulas do filtro
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<FaltaFiltro>(
                    segments: const [
                      ButtonSegment(value: FaltaFiltro.zerados, label: Text('Zerados (0)'), icon: Icon(Icons.priority_high_rounded)),
                      ButtonSegment(value: FaltaFiltro.abaixoMin, label: Text('Abaixo do mínimo'), icon: Icon(Icons.warning_amber_rounded)),
                    ],
                    selected: {_filtro},
                    onSelectionChanged: (s) => setState(() => _filtro = s.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Busca (apenas por nome do produto)
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Pesquisar por produto…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                ),
              ],
            ),
          ),
        ),
      ),

      body: Stack(
        children: [
          // conteúdo
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('produtos').snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    _filtro == FaltaFiltro.zerados
                        ? 'Nenhum produto com stock 0.'
                        : 'Nenhum produto abaixo do mínimo.',
                  ),
                );
              }

              // ordenar por nome
              final all = snap.data!.docs.toList()
                ..sort((a, b) {
                  final na = (a.data()['nome'] ?? '').toString().toLowerCase();
                  final nb = (b.data()['nome'] ?? '').toString().toLowerCase();
                  return na.compareTo(nb);
                });

              // busca (por nome)
              final buscados = _search.isEmpty
                  ? all
                  : all.where((d) {
                      final nome = (d.data()['nome'] ?? '').toString().toLowerCase();
                      return nome.contains(_search);
                    }).toList();

              // filtro de falta + resolvidos
              final filtrados = buscados.where((d) {
                final data = d.data();
                final total = (data['quantidade_total'] ?? data['quantidade'] ?? 0) as int;
                final minimo = (data['estoque_minimo'] ?? 0) as int;
                final resolvido = (data['falta_resolvido'] ?? false) as bool;

                final match = _filtro == FaltaFiltro.zerados ? total <= 0 : total <= minimo;
                if (!match) return false;
                if (_mostrarResolvidos) return true;
                return resolvido == false; // ocultar resolvidos por padrão
              }).toList();

              if (filtrados.isEmpty) {
                return Center(
                  child: Text(
                    _filtro == FaltaFiltro.zerados
                        ? 'Nenhum produto com stock 0.'
                        : 'Nenhum produto abaixo do mínimo.',
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: filtrados.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = filtrados[i];
                  final data = d.data();

                  final produtoId = d.id;
                  final nome = (data['nome'] ?? '').toString();
                  final total = (data['quantidade_total'] ?? data['quantidade'] ?? 0) as int;
                  final minimo = (data['estoque_minimo'] ?? 0) as int;
                  final resolvido = (data['falta_resolvido'] ?? false) as bool;

                  final validadeFallback = data['validade'];

                  return Card(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título
                          Text(nome, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 6),

                          // Info (sem fornecedor)
                          FutureBuilder<String>(
                            future: _proximaValidade(produtoId, validadeFallback),
                            builder: (context, snap) {
                              final validadeStr = snap.data ?? '…';
                              return Text('Validade: $validadeStr');
                            },
                          ),
                          const SizedBox(height: 8),

                          // Chips estado/total/minimo
                          Wrap(
                            spacing: 8, runSpacing: 6, children: [
                              _chipEstado(context: context, total: total, minimo: minimo),
                              _chipInfo(context, 'Total: $total'),
                              _chipInfo(context, 'Mínimo: $minimo'),
                              if (resolvido)
                                Chip(
                                  label: const Text('Resolvido'),
                                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                                ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Ações (com RESOLVER destacado)
                          Row(
                            children: [
                              // SAÍDA – qualquer autorizado
                              IconButton.filledTonal(
                                tooltip: 'Saída (consumo)',
                                icon: const Icon(Icons.remove_rounded),
                                onPressed: () async {
                                  final qty = await _askQtd(context, title: 'Registrar SAÍDA');
                                  if (qty == null) return;

                                  final operador = await _ensureSession(context);
                                  if (operador == null) return;

                                  try {
                                    await StockService().registrarSaida(
                                      produtoId: produtoId,
                                      quantidade: qty,
                                      motivo: 'consumo',
                                      operador: operador,
                                    );
                                    if (mounted) _ok('Saída registada.');
                                  } catch (e) {
                                    if (mounted) _err('Erro: $e');
                                  }
                                },
                              ),
                              const SizedBox(width: 6),

                              // ENTRADA – qualquer autorizado
                              IconButton.filledTonal(
                                tooltip: 'Entrada (reposição)',
                                icon: const Icon(Icons.add_rounded),
                                onPressed: () async {
                                  final qty = await _askQtd(context, title: 'Registrar ENTRADA');
                                  if (qty == null) return;

                                  final operador = await _ensureSession(context);
                                  if (operador == null) return;

                                  try {
                                    await StockService().registrarEntrada(
                                      produtoId: produtoId,
                                      quantidade: qty,
                                      motivo: 'compra',
                                      operador: operador,
                                    );
                                    if (mounted) _ok('Entrada registada.');
                                  } catch (e) {
                                    if (mounted) _err('Erro: $e');
                                  }
                                },
                              ),
                              const Spacer(),

                              // RESOLVER (destacado) / REABRIR
                              if (!resolvido)
                                FilledButton.icon(
                                  icon: const Icon(Icons.check_circle_rounded),
                                  label: const Text('RESOLVER', style: TextStyle(fontWeight: FontWeight.w900)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2962FF), // azul forte para destacar
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  onPressed: () async {
                                    final nome = await _ensureSession(context);
                                    if (nome == null) return;
                                    try {
                                      await d.reference.update({
                                        'falta_resolvido': true,
                                        'falta_resolvido_at': FieldValue.serverTimestamp(),
                                        'falta_resolvido_by': nome,
                                      });
                                      if (mounted) _ok('Marcado como resolvido.');
                                    } catch (e) {
                                      if (mounted) _err('Erro ao resolver: $e');
                                    }
                                  },
                                )
                              else
                                FilledButton.tonalIcon(
                                  icon: const Icon(Icons.restore_rounded),
                                  label: const Text('REABRIR', style: TextStyle(fontWeight: FontWeight.w900)),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  onPressed: () async {
                                    final nome = await _ensureSession(context);
                                    if (nome == null) return;
                                    try {
                                      await d.reference.update({
                                        'falta_resolvido': false,
                                        'falta_resolvido_at': null,
                                        'falta_resolvido_by': null,
                                      });
                                      if (mounted) _ok('Item reaberto.');
                                    } catch (e) {
                                      if (mounted) _err('Erro: $e');
                                    }
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Selo fixo da aba atual (canto superior direito)
          Positioned(
            right: 12, top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: badgeBg, borderRadius: BorderRadius.circular(999),
                boxShadow: [BoxShadow(color: badgeBg.withOpacity(.25), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badgeIcon, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(badgeLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- helpers UI
  Widget _chipInfo(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Chip(
      backgroundColor: cs.secondaryContainer,
      side: BorderSide(color: cs.outlineVariant),
      label: Text(text, style: TextStyle(color: cs.onSecondaryContainer)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
    );
  }

  Widget _chipEstado({
    required BuildContext context,
    required int total,
    required int minimo,
  }) {
    late Color bg; late Color fg; late String label;
    if (total <= 0) {
      bg = const Color(0xFFE53935); fg = Colors.white; label = 'Zerado';
    } else if (total <= minimo) {
      bg = const Color(0xFFFF9800); fg = Colors.white; label = 'Abaixo do mínimo';
    } else {
      bg = const Color(0xFF1DB954); fg = Colors.white; label = 'OK';
    }

    return Chip(
      backgroundColor: bg,
      side: BorderSide(color: bg.withOpacity(.65)),
      label: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
    );
  }

  // ---------- diálogos & sessão
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

  Future<(String, String)?> _askCredenciais(
    BuildContext context, {
    String titulo = 'Autenticar',
  }) async {
    final nome = TextEditingController();
    final chave = TextEditingController();
    final form = GlobalKey<FormState>();
    bool obscure = true;
    return showDialog<(String, String)>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setSt) {
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
      }),
    );
  }

  /// Garante sessão válida. Se não houver, pede credenciais e ativa/renova sessão.
  Future<String?> _ensureSession(BuildContext context) async {
    final session = SessionService();
    if (session.adminOverride || session.hasValidOperator) {
      return session.adminOverride
          ? (session.adminName ?? session.operatorName ?? 'operador')
          : (session.operatorName ?? 'operador');
    }

    final cred = await _askCredenciais(context, titulo: 'Autenticar');
    if (cred == null) return null;
    final res = await AuthzService().verifyWithRole(nome: cred.$1, chave: cred.$2);
    if (!res.ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciais inválidas.')),
        );
      }
      return null;
    }
    if (res.isAdmin) {
      await session.setAdminOverride(true, name: res.nome);
    }
    await session.saveOrRefreshOperator(name: res.nome, key: cred.$2);
    return res.nome;
  }
}
