import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kwalps_st/services/stock_service.dart';
import 'package:kwalps_st/services/authz_service.dart';
import 'package:kwalps_st/services/session_service.dart';
import 'package:kwalps_st/pages/enviar_email_page.dart';

class ProdutosPage extends StatefulWidget {
  const ProdutosPage({super.key});

  @override
  State<ProdutosPage> createState() => _ProdutosPageState();
}

class _ProdutosPageState extends State<ProdutosPage> {
  String _search = '';

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

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('produtos');
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos'),
        actions: [
          IconButton(
            tooltip: 'Enviar email aos fornecedores',
            icon: const Icon(Icons.mail_outline_rounded),
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const EnviarEmailPage()));
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Pesquisar por produto, fornecedor ou categoria…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                child: Text(
                  'Erro ao carregar produtos:\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
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
              final fa =
                  (a.data()['fornecedor'] ?? '').toString().toLowerCase();
              final fb =
                  (b.data()['fornecedor'] ?? '').toString().toLowerCase();
              final na = (a.data()['nome'] ?? '').toString().toLowerCase();
              final nb = (b.data()['nome'] ?? '').toString().toLowerCase();
              final c = fa.compareTo(fb);
              return c != 0 ? c : na.compareTo(nb);
            });

          final filtered = _search.isEmpty
              ? docs
              : docs.where((d) {
                  final data = d.data();
                  final nome = (data['nome'] ?? '').toString().toLowerCase();
                  final forn = (data['fornecedor'] ?? '').toString().toLowerCase();
                  final cat  = (data['categoria'] ?? '').toString().toLowerCase();
                  return nome.contains(_search) || forn.contains(_search) || cat.contains(_search);
                }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('Nenhum resultado.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final d = filtered[i];
              final data = d.data();
              final nome = (data['nome'] ?? '').toString();
              final categoria = (data['categoria'] ?? '').toString();
              final loteCopia = (data['lote'] ?? '').toString(); // mera cópia, se existir
              final fornecedor =
                  ((data['fornecedor'] ?? '') as String).trim().isEmpty
                      ? '(Sem fornecedor)'
                      : (data['fornecedor'] as String);
              final fornTel = (data['fornecedor_telefone'] ?? '').toString();
              final qtd = (data['quantidade'] ?? 0) as int;
              final minimo = (data['estoque_minimo'] ?? 0) as int;
              final critico = (data['critico'] ?? false) as bool;
              final validadeProduto = _tsToString(data['validade']); // fallback se não houver lotes

              return Card(
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabeçalho
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              nome,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          _chipEstado(qtd: qtd, minimo: minimo, critico: critico),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Infos
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _miniInfo(Icons.category, 'Categoria: ${categoria.isEmpty ? '-' : categoria}'),
                          _miniInfo(Icons.factory,  'Fornecedor: $fornecedor'),
                          if (fornTel.isNotEmpty) _miniInfo(Icons.phone, 'Telefone: $fornTel'),
                          if (loteCopia.isNotEmpty) _miniInfo(Icons.inventory_2, 'Lote: $loteCopia'),
                          // Próxima validade (via subcoleção lotes). Se não houver lotes, usa a validade do produto.
                          _ProximaValidadeDoProduto(
                            produtoId: d.id,
                            fallbackVal: validadeProduto,
                            miniInfoBuilder: _miniInfo,
                          ),
                          _miniInfo(Icons.numbers,  'Qtd: $qtd'),
                          _miniInfo(Icons.flag,     'Mínimo: $minimo'),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1),

                      // Barra de ações
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            // ENTRADA — APENAS ADMIN
                            FilledButton.icon(
                              onPressed: () async {
                                final session = SessionService();

                                // requer admin; se não tiver override, pedir credenciais
                                if (!session.adminOverride) {
                                  final cred = await _askCredenciais(
                                      context,
                                      titulo: 'Autenticar Admin');
                                  if (cred == null) return;

                                  final res = await AuthzService().verifyWithRole(
                                      nome: cred.$1, chave: cred.$2);
                                  if (!mounted) return;

                                  if (!res.ok || !res.isAdmin) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Apenas administrador pode lançar ENTRADA.'),
                                      ),
                                    );
                                    return;
                                  }

                                  await session.setAdminOverride(true,
                                      name: res.nome);
                                }

                                final q = await _askQtd(context,
                                    title: 'Registrar ENTRADA');
                                if (q == null) return;

                                try {
                                  await StockService().registrarEntrada(
                                    produtoId: d.id,
                                    quantidade: q,
                                    motivo: 'compra',
                                    operador:
                                        session.adminName ?? 'admin',
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Entrada registada.')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Erro: $e')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.add_circle_rounded),
                              label: const Text('Entrada'),
                            ),

                            // SAÍDA — AUTORIZADOS (com sessão 10min)
                            OutlinedButton.icon(
                              onPressed: () async {
                                final session = SessionService();

                                // Se já há admin override OU operador válido, só pergunta a quantidade
                                if (!session.adminOverride &&
                                    !session.hasValidOperator) {
                                  // pedir credenciais
                                  final cred = await _askCredenciais(context);
                                  if (cred == null) return;

                                  final res = await AuthzService()
                                      .verifyWithRole(
                                          nome: cred.$1, chave: cred.$2);
                                  if (!mounted) return;

                                  if (!res.ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Credenciais inválidas.')),
                                    );
                                    return;
                                  }

                                  if (res.isAdmin) {
                                    await session.setAdminOverride(true,
                                        name: res.nome);
                                  } else {
                                    await session.saveOrRefreshOperator(
                                        name: res.nome, key: cred.$2);
                                  }
                                }

                                final q = await _askQtd(context,
                                    title: 'Registrar SAÍDA');
                                if (q == null) return;

                                try {
                                  await StockService().registrarSaida(
                                    produtoId: d.id,
                                    quantidade: q,
                                    motivo: 'consumo',
                                    operador: session.adminOverride
                                        ? (session.adminName ?? 'admin')
                                        : (session.operatorName ?? 'operador'),
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Saída registada.')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Erro: $e')),
                                    );
                                  }
                                }
                              },
                              icon: Icon(Icons.remove_circle_rounded,
                                  color: scheme.error),
                              label: Text('Saída',
                                  style: TextStyle(color: scheme.error)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: scheme.error),
                              ),
                            ),

                            // EMAIL
                            IconButton.filledTonal(
                              tooltip: 'Abrir envio de email',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const EnviarEmailPage(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.mail_outline_rounded),
                            ),
                          ],
                        ),
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

  // ---------- Helpers UI ----------

  Widget _miniInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(text)],
    );
  }

  Widget _chipEstado({
    required int qtd,
    required int minimo,
    required bool critico,
  }) {
    final label =
        qtd <= 0 ? 'Sem stock' : (critico ? 'Abaixo do mínimo ($minimo)' : 'OK');
    final color =
        qtd <= 0 ? Colors.red : (critico ? Colors.orange : Colors.green);
    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color),
    );
  }

  // ---------- Diálogos simples ----------
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
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
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

  Future<(String, String)?> _askCredenciais(BuildContext context,
      {String titulo = 'Autenticar'}) async {
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
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: chave,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Chave',
                    suffixIcon: IconButton(
                      onPressed: () => setSt(() => obscure = !obscure),
                      icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe a chave' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
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
}

/// Mostra “Validade: … (via lote ou fallback)” e “Lotes: N” para um produto.
class _ProximaValidadeDoProduto extends StatelessWidget {
  final String produtoId;
  final String fallbackVal;
  final Widget Function(IconData, String) miniInfoBuilder;

  const _ProximaValidadeDoProduto({
    required this.produtoId,
    required this.fallbackVal,
    required this.miniInfoBuilder,
  });

  String _fmt(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
    }

  Future<(String validadeStr, int lotes)> _load() async {
    final lotesCol = FirebaseFirestore.instance
        .collection('produtos')
        .doc(produtoId)
        .collection('lotes');

    // Busca todos os lotes para contar e para achar o mais próximo (poucos documentos na prática).
    final q = await lotesCol.orderBy('validade').get();

    if (q.docs.isEmpty) {
      return (fallbackVal, 0);
    }

    // earliest
    DateTime? earliest;
    for (final d in q.docs) {
      final v = d.data()['validade'];
      if (v != null) {
        final dt = (v as dynamic).toDate?.call();
        if (dt is DateTime) {
          if (earliest == null || dt.isBefore(earliest!)) earliest = dt;
        }
      }
    }
    final validadeStr = earliest == null ? fallbackVal : _fmt(earliest!);
    return (validadeStr, q.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(String, int)>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return miniInfoBuilder(Icons.event, 'Validade: …'); // loading leve
        }
        if (!snap.hasData) {
          return miniInfoBuilder(Icons.event, 'Validade: $fallbackVal');
        }
        final (valStr, count) = snap.data!;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            miniInfoBuilder(Icons.event, 'Validade: $valStr'),
            const SizedBox(width: 12),
            miniInfoBuilder(Icons.inventory_2, 'Lotes: $count'),
          ],
        );
      },
    );
  }
}
