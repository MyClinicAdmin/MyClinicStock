import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kwalps_st/services/stock_service.dart';
import 'package:kwalps_st/services/authz_service.dart';
import 'package:kwalps_st/services/session_service.dart';

enum FaltaFiltro { semEstoque, critico }

class ProdutosEmFaltaPage extends StatefulWidget {
  const ProdutosEmFaltaPage({super.key});
  @override
  State<ProdutosEmFaltaPage> createState() => _ProdutosEmFaltaPageState();
}

class _ProdutosEmFaltaPageState extends State<ProdutosEmFaltaPage> {
  FaltaFiltro _filtro = FaltaFiltro.critico;
  String _search = '';

  Query<Map<String, dynamic>> _buildQuery() {
    final col = FirebaseFirestore.instance.collection('produtos');
    switch (_filtro) {
      case FaltaFiltro.semEstoque:
        return col.where('quantidade', isLessThanOrEqualTo: 0);
      case FaltaFiltro.critico:
        return col.where('critico', isEqualTo: true);
    }
  }

  String _validadeToString(dynamic v) {
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final query = _buildQuery();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos em Falta'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<FaltaFiltro>(
                value: _filtro,
                dropdownColor: cs.surface,
                onChanged: (v) => setState(() => _filtro = v ?? FaltaFiltro.critico),
                items: const [
                  DropdownMenuItem(
                    value: FaltaFiltro.critico,
                    child: Text('Filtro: Crítico (≤ mínimo)'),
                  ),
                  DropdownMenuItem(
                    value: FaltaFiltro.semEstoque,
                    child: Text('Filtro: Sem stock (≤ 0)'),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Pesquisar por produto ou fornecedor…',
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
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Text(
                _filtro == FaltaFiltro.semEstoque
                    ? 'Nenhum produto com stock ≤ 0.'
                    : 'Nenhum produto abaixo do mínimo.',
              ),
            );
          }

          final docs = snap.data!.docs.toList()
            ..sort((a, b) {
              final fa = (a.data()['fornecedor'] ?? '').toString().toLowerCase();
              final fb = (b.data()['fornecedor'] ?? '').toString().toLowerCase();
              final na = (a.data()['nome'] ?? '').toString().toLowerCase();
              final nb = (b.data()['nome'] ?? '').toString().toLowerCase();
              final cmpF = fa.compareTo(fb);
              return cmpF != 0 ? cmpF : na.compareTo(nb);
            });

          final filtrados = _search.isEmpty
              ? docs
              : docs.where((d) {
                  final data = d.data();
                  final nome = (data['nome'] ?? '').toString().toLowerCase();
                  final forn = (data['fornecedor'] ?? '').toString().toLowerCase();
                  return nome.contains(_search) || forn.contains(_search);
                }).toList();

          if (filtrados.isEmpty) {
            return const Center(child: Text('Nenhum resultado para a pesquisa.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filtrados.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = filtrados[i];
              final data = d.data();
              final nome = (data['nome'] ?? '').toString();
              final fornecedor = ((data['fornecedor'] ?? '') as String).trim().isEmpty
                  ? '(Sem fornecedor)'
                  : (data['fornecedor'] as String);
              final qtd = (data['quantidade'] ?? 0) as int;
              final minimo = (data['estoque_minimo'] ?? 0) as int;
              final validade = _validadeToString(data['validade']);
              final critico = (data['critico'] ?? false) as bool;

              return Card(
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: cs.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  title: Text(nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text('Fornecedor: $fornecedor'),
                      Text('Validade: $validade'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _chipEstado(context: context, qtd: qtd, minimo: minimo, critico: critico),
                          _chipInfo(context, 'Qtd: $qtd'),
                          _chipInfo(context, 'Mínimo: $minimo'),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
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
                              produtoId: d.id,
                              quantidade: qty,
                              motivo: 'consumo',
                              operador: operador,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Saída registada.')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text('Erro: $e')));
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      // ENTRADA – também qualquer autorizado (não exige admin)
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
                              produtoId: d.id,
                              quantidade: qty,
                              motivo: 'compra',
                              operador: operador,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Entrada registada.')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text('Erro: $e')));
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
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
    required int qtd,
    required int minimo,
    required bool critico,
  }) {
    final cs = Theme.of(context).colorScheme;

    late Color bg; late Color fg; late String label;
    if (qtd <= 0) {
      bg = cs.errorContainer; fg = cs.onErrorContainer; label = 'Sem stock';
    } else if (critico) {
      bg = cs.tertiaryContainer; fg = cs.onTertiaryContainer; label = 'Abaixo do mínimo ($minimo)';
    } else {
      bg = cs.primaryContainer; fg = cs.onPrimaryContainer; label = 'OK';
    }

    return Chip(
      backgroundColor: bg,
      side: BorderSide(color: cs.outlineVariant),
      label: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
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

  /// Garante sessão válida. Se não houver, pede credenciais, valida,
  /// ativa override se for admin e sempre renova sessão 10min.
  Future<String?> _ensureSession(BuildContext context) async {
    final session = SessionService();
    if (session.adminOverride || session.hasValidOperator) {
      return session.adminOverride
          ? (session.adminName ?? session.operatorName ?? 'operador')
          : (session.operatorName ?? 'operador');
    }

    final cred = await _askCredenciais(context, titulo: 'Autenticar');
    if (cred == null) return null;
    final res =
        await AuthzService().verifyWithRole(nome: cred.$1, chave: cred.$2);
    if (!res.ok) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Credenciais inválidas.')));
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
