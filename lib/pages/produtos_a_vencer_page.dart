// lib/pages/produtos_a_vencer_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Pedir credenciais (como em ProdutosPage)
import 'package:kwalps_st/services/authz_service.dart';
import 'package:kwalps_st/services/session_service.dart';

enum _Aba { aVencer, vencidos }

class ProdutosAVencerPage extends StatefulWidget {
  const ProdutosAVencerPage({super.key});
  @override
  State<ProdutosAVencerPage> createState() => _ProdutosAVencerPageState();
}

class _ProdutosAVencerPageState extends State<ProdutosAVencerPage>
    with SingleTickerProviderStateMixin {
  final _fmt = DateFormat('dd/MM/yyyy');
  final Map<String, Map<String, dynamic>?> _produtoCache = {};
  final TextEditingController _searchCtrl = TextEditingController();

  late final TabController _tab = TabController(length: 2, vsync: this);
  bool _mostrarResolvidos = false; // interruptor simples
  String _search = '';

  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
  String _d(DateTime d) => _fmt.format(d);

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Paleta por status (bg, on, border)
  (Color bg, Color on, Color bd) _colorsFor({
    required bool vencido,
    required int diasAteVencer, // >=0 quando não vencido
    required ColorScheme cs,
  }) {
    if (vencido) {
      return (const Color(0xFFFFE5E5), const Color(0xFF7D1212), const Color(0xFFFFB3B3)); // vermelho
    }
    if (diasAteVencer <= 7) {
      return (const Color(0xFFFFEFD9), const Color(0xFF7A3F00), const Color(0xFFFFC68A)); // laranja
    }
    if (diasAteVencer <= 14) {
      return (const Color(0xFFFFF8DA), const Color(0xFF6A5600), const Color(0xFFFFE47A)); // amarelo
    }
    return (cs.surfaceContainerHighest, cs.onSurfaceVariant, cs.outlineVariant); // 15–30
  }

  // ===== Carregamento client-side =====
  Future<List<_LoteView>> _loadDataClientSide(_Aba aba) async {
    final hoje = _dayStart(DateTime.now());
    final limite = hoje.add(const Duration(days: 30)); // para "A vencer"

    final snap = await FirebaseFirestore.instance.collectionGroup('lotes').get();
    final lotes = <_LoteView>[];

    for (final d in snap.docs) {
      final data = d.data();
      final ts = data['validade'] as Timestamp?;
      final v = ts?.toDate();
      if (v == null) continue;

      final vd = _dayStart(v);
      final resolvido = (data['resolvido'] ?? false) == true;

      // Filtrar resolvidos conforme interruptor
      if (!_mostrarResolvidos && resolvido) continue;

      final isVencido = vd.isBefore(hoje) || vd.isAtSameMomentAs(hoje);
      final isAVencer = vd.isAfter(hoje) && (vd.isBefore(limite) || vd.isAtSameMomentAs(limite));

      // Regras:
      // - A Vencer: somente próximos 30 dias
      // - Vencidos: TODOS (sem limite)
      if (aba == _Aba.aVencer && !isAVencer) continue;
      if (aba == _Aba.vencidos && !isVencido) continue;

      final codigo = (data['codigo'] ?? '').toString();
      final qtd = (data['quantidade'] ?? 0) is int
          ? (data['quantidade'] as int)
          : int.tryParse('${data['quantidade']}') ?? 0;

      // Nome do produto a partir do pai (produtos/{id})
      final produtoRef = d.reference.parent.parent;
      final cacheKey = produtoRef?.path ?? '';
      Map<String, dynamic>? prod;
      if (cacheKey.isNotEmpty) {
        prod = _produtoCache[cacheKey];
        if (prod == null) {
          final doc = await produtoRef!.get();
          prod = doc.data();
          _produtoCache[cacheKey] = prod;
        }
      }
      final nome = (prod?['nome'] ?? '—').toString();

      lotes.add(
        _LoteView(
          ref: d.reference,
          nomeProduto: nome,
          codigo: codigo,
          qtd: qtd,
          validade: vd,
          resolvido: resolvido,
        ),
      );
    }

    // Ordena por validade ascendente
    lotes.sort((a, b) => a.validade.compareTo(b.validade));

    // Pesquisa
    if (_search.isNotEmpty) {
      final q = _search;
      return lotes.where((l) {
        return l.nomeProduto.toLowerCase().contains(q) ||
            l.codigo.toLowerCase().contains(q);
      }).toList();
    }

    return lotes;
  }

  // ===== Autorização (igual ao fluxo de Entrada/Saída) =====
  Future<bool> _ensureAuthorized({bool adminOnly = false}) async {
    final session = SessionService();

    // Admin-only?
    if (adminOnly) {
      if (session.adminOverride) return true;
      final cred = await _askCredenciais(context, titulo: 'Autenticar Admin');
      if (cred == null) return false;
      final res =
          await AuthzService().verifyWithRole(nome: cred.$1, chave: cred.$2);
      if (!mounted) return false;
      if (!res.ok || !res.isAdmin) {
        _toast('Apenas administrador pode realizar esta ação.', ok: false);
        return false;
      }
      await session.setAdminOverride(true, name: res.nome);
      return true;
    }

    // Admin OU Operador válido
    if (session.adminOverride || session.hasValidOperator) return true;

    final cred = await _askCredenciais(context);
    if (cred == null) return false;
    final res =
        await AuthzService().verifyWithRole(nome: cred.$1, chave: cred.$2);
    if (!mounted) return false;
    if (!res.ok) {
      _toast('Credenciais inválidas.', ok: false);
      return false;
    }
    if (res.isAdmin) {
      await session.setAdminOverride(true, name: res.nome);
    } else {
      await session.saveOrRefreshOperator(name: res.nome, key: cred.$2);
    }
    return true;
  }

  void _toast(String msg, {bool ok = true}) {
    final cs = Theme.of(context).colorScheme;
    final bg = ok ? cs.primary : cs.error;
    final fg = ok ? cs.onPrimary : cs.onError;
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
            Icon(ok ? Icons.check_circle : Icons.error_outline, color: fg),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Validades')),
      body: Column(
        children: [
          // ===== Top controls (fora do AppBar, evita sobreposição) =====
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Pesquisar por produto ou código do lote…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          // Abas + interruptor discreto
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tab,
                    isScrollable: true,
                    // tabAlignment removido p/ maior compatibilidade
                    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                    tabs: const [
                      Tab(icon: Icon(Icons.warning_amber_rounded), text: 'A vencer (até 30 dias)'),
                      Tab(icon: Icon(Icons.error_outline), text: 'Vencidos (todos)'),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Text('Mostrar resolvidos', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Transform.scale(
                      scale: 0.9, // discreto
                      child: Switch.adaptive(
                        value: _mostrarResolvidos,
                        onChanged: (v) => setState(() => _mostrarResolvidos = v),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // ===== Conteúdo
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _tabContent(aba: _Aba.aVencer, cs: cs),
                _tabContent(aba: _Aba.vencidos, cs: cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabContent({required _Aba aba, required ColorScheme cs}) {
    final hoje = _dayStart(DateTime.now());

    return FutureBuilder<List<_LoteView>>(
      future: _loadDataClientSide(aba),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Erro ao carregar: ${snap.error}', textAlign: TextAlign.center),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final lotes = snap.data ?? const <_LoteView>[];
        if (lotes.isEmpty) {
          return const Center(child: Text('Nenhum registro para esta aba.'));
        }

        // GRID de cards menores
        return LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          int cols = 1;
          if (w >= 1300) cols = 5;
          else if (w >= 1100) cols = 4;
          else if (w >= 800) cols = 3;
          else if (w >= 560) cols = 2;

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.15,
            ),
            itemCount: lotes.length,
            itemBuilder: (_, i) {
              final l = lotes[i];
              final vencido = l.validade.isBefore(hoje) || l.validade.isAtSameMomentAs(hoje);
              final dias = l.validade.difference(hoje).inDays;
              final (bg, on, bd) = _colorsFor(
                vencido: vencido,
                diasAteVencer: dias,
                cs: cs,
              );

              // Badge explícita
              String chip;
              if (vencido) {
                final diff = hoje.difference(l.validade).inDays;
                if (diff == 0) chip = 'Venceu hoje';
                else if (diff == 1) chip = 'Venceu há 1 dia';
                else chip = 'Venceu há $diff dias';
              } else {
                if (dias == 0) chip = 'Vence hoje';
                else if (dias == 1) chip = 'Amanhã';
                else chip = 'Faltam $dias dias';
              }

              return _LoteCardCompact(
                nomeProduto: l.nomeProduto,
                codigo: l.codigo,
                qtd: l.qtd,
                validade: _d(l.validade),
                chipText: chip,
                resolvido: l.resolvido,
                bg: bg,
                on: on,
                bd: bd,
                onResolver: () async {
                  // pedir credenciais (admin OU operador)
                  final ok = await _ensureAuthorized(adminOnly: false);
                  if (!ok) return;
                  try {
                    await l.ref.update({'resolvido': true});
                    if (mounted) setState(() {});
                    _toast('Marcado como resolvido.');
                  } catch (e) {
                    _toast('Erro ao resolver: $e', ok: false);
                  }
                },
                onReabrir: () async {
                  // pedir credenciais (admin OU operador)
                  final ok = await _ensureAuthorized(adminOnly: false);
                  if (!ok) return;
                  try {
                    await l.ref.update({'resolvido': false});
                    if (mounted) setState(() {});
                    _toast('Marcado como pendente.');
                  } catch (e) {
                    _toast('Erro ao reabrir: $e', ok: false);
                  }
                },
              );
            },
          );
        });
      },
    );
  }

  // ===== Diálogo de credenciais =====
  Future<(String, String)?> _askCredenciais(BuildContext context, {String titulo = 'Autenticar'}) async {
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
}

// ======= Data view model =======
class _LoteView {
  final DocumentReference<Map<String, dynamic>> ref;
  final String nomeProduto;
  final String codigo;
  final int qtd;
  final DateTime validade;
  final bool resolvido;

  _LoteView({
    required this.ref,
    required this.nomeProduto,
    required this.codigo,
    required this.qtd,
    required this.validade,
    required this.resolvido,
  });
}

// ======= Card compacto =======
class _LoteCardCompact extends StatelessWidget {
  final String nomeProduto;
  final String codigo;
  final int qtd;
  final String validade;
  final String chipText;
  final bool resolvido;

  final Color bg;
  final Color on;
  final Color bd;

  final VoidCallback onResolver;
  final VoidCallback onReabrir;

  const _LoteCardCompact({
    required this.nomeProduto,
    required this.codigo,
    required this.qtd,
    required this.validade,
    required this.chipText,
    required this.resolvido,
    required this.bg,
    required this.on,
    required this.bd,
    required this.onResolver,
    required this.onReabrir,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);

    return Material(
      color: bg,
      elevation: 0,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () {},
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: bd, width: 1.1),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título + badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nomeProduto.isEmpty ? '(sem nome)' : nomeProduto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: on,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: on.withOpacity(.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: on.withOpacity(.45)),
                    ),
                    child: Text(
                      chipText,
                      style: TextStyle(color: on, fontWeight: FontWeight.w800, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Linhas compactas
              _miniLine(icon: Icons.numbers, label: 'Lote', value: codigo.isEmpty ? '(sem nº)' : codigo, on: on),
              const SizedBox(height: 4),
              _miniLine(icon: Icons.inventory_2_rounded, label: 'Qtd', value: '$qtd', on: on),
              const SizedBox(height: 4),
              _miniLine(icon: Icons.event, label: 'Validade', value: validade, on: on),

              const Spacer(),
              // Ações Resolver/Reabrir (credenciais tratadas no caller)
              Row(
                children: [
                  if (!resolvido)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: on,
                        foregroundColor: bg,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: onResolver,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Resolver', style: TextStyle(fontWeight: FontWeight.w800)),
                    )
                  else
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: on.withOpacity(.65)),
                        foregroundColor: on,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: onReabrir,
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: const Text('Reabrir'),
                    ),
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniLine({
    required IconData icon,
    required String label,
    required String value,
    required Color on,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: on.withOpacity(.85)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label: $value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: on.withOpacity(.95)),
          ),
        ),
      ],
    );
  }
}
