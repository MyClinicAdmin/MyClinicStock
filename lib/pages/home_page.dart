import 'package:flutter/material.dart';
import 'package:kwalps_st/pages/cadastro_produto_page.dart';
import 'package:kwalps_st/pages/produtos_em_falta_page.dart';
import 'package:kwalps_st/pages/produtos_a_vencer_page.dart';
import 'package:kwalps_st/pages/enviar_email_page.dart';
import 'package:kwalps_st/pages/produtos_page.dart';
import 'package:kwalps_st/pages/admin_page.dart';
import 'package:kwalps_st/services/authz_service.dart';
import 'package:kwalps_st/services/session_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  // Sessão Admin
  bool _adminAuthed = false;
  String? _adminUser;

  @override
  void initState() {
    super.initState();
    _syncAdminFromSession();
  }

  Future<void> _syncAdminFromSession() async {
    final sess = SessionService();
    setState(() {
      _adminAuthed = sess.adminOverride;
      _adminUser = sess.adminName;
    });
  }

  // Destinos
  late final List<_Dest> _destinations = [
    _Dest(
      label: 'Em Falta',
      icon: Icons.warning_amber_rounded,
      builder: (_) => const ProdutosEmFaltaPage(),
    ),
    _Dest(
      label: 'A Vencer',
      icon: Icons.calendar_month,
      builder: (_) => const ProdutosAVencerPage(),
    ),
    _Dest(
      label: 'Produtos',
      icon: Icons.inventory_2_rounded,
      builder: (_) => const ProdutosPage(),
    ),
    _Dest(
      label: 'Email',
      icon: Icons.mail_outline_rounded,
      builder: (_) => const EnviarEmailPage(),
    ),
    _Dest(
      label: 'Cadastrar',
      icon: Icons.add_box_rounded,
      builder: (_) => const CadastroProdutoPage(),
    ),
    _Dest(
      label: 'Admin',
      icon: Icons.admin_panel_settings_rounded,
      builder: (_) =>
          _adminAuthed ? const AdminPage() : _AdminLockedView(onLoginTap: _openAdminLoginSheet),
    ),
  ];

  void _onSelect(int i) => setState(() => _index = i);

  // ---- Login Admin (apenas quem tem is_admin=true)
  Future<void> _openAdminLoginSheet() async {
    final nomeCtrl = TextEditingController();
    final chaveCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;
    bool loading = false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 8,
        ),
        child: StatefulBuilder(
          builder: (context, setSt) {
            return Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings_rounded),
                      const SizedBox(width: 8),
                      Text(
                        'Login de Administrador',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nomeCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nome (autorizado)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: chaveCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Chave de segurança',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () => setSt(() => obscure = !obscure),
                        icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe a chave' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: loading ? null : () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: loading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setSt(() => loading = true);
                                  final res = await AuthzService().verifyWithRole(
                                    nome: nomeCtrl.text.trim(),
                                    chave: chaveCtrl.text.trim(),
                                  );
                                  setSt(() => loading = false);
                                  if (!context.mounted) return;

                                  if (res.ok && res.isAdmin) {
                                    await SessionService()
                                        .setAdminOverride(true, name: res.nome);
                                    setState(() {
                                      _adminAuthed = true;
                                      _adminUser = res.nome;
                                    });
                                    Navigator.pop(context, true);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Apenas administrador pode entrar.'),
                                      ),
                                    );
                                  }
                                },
                          icon: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.login_rounded),
                          label: const Text('Entrar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (ok == true) {
      final adminIdx = _destinations.indexWhere((d) => d.label == 'Admin');
      if (adminIdx != -1) setState(() => _index = adminIdx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bem-vindo, ${_adminUser ?? 'Admin'}')),
        );
      }
    }
  }

  Future<void> _logoutAdmin() async {
    await SessionService().clearAdminOverride();
    await SessionService().clearOperator(); // limpa sessão de operador (10min)
    setState(() {
      _adminAuthed = false;
      _adminUser = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão de administrador terminada.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = _destinations[_index].builder(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        final fab = (_destinations[_index].label == 'Cadastrar')
            ? null
            : FloatingActionButton.extended(
                onPressed: () => setState(() {
                  _index = _destinations.indexWhere((d) => d.label == 'Cadastrar');
                }),
                icon: const Icon(Icons.add_box_rounded),
                label: const Text('Cadastrar'),
              );

        if (isWide) {
          // Desktop/Web
          return Scaffold(
            floatingActionButton: fab,
            body: Row(
              children: [
                _SideRail(
                  index: _index,
                  onSelect: _onSelect,
                  destinations: _destinations,
                  onLogoutTap:
                      (_destinations[_index].label == 'Admin' && _adminAuthed)
                          ? _logoutAdmin
                          : null,
                ),
                Expanded(child: currentPage),
              ],
            ),
          );
        }

        // Mobile/Tablet
        return Scaffold(
          body: currentPage,
          floatingActionButton: fab,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _onSelect,
            destinations: _destinations
                .map((d) => NavigationDestination(icon: Icon(d.icon), label: d.label))
                .toList(),
          ),
        );
      },
    );
  }
}

// ---------- Helpers ----------

class _Dest {
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  _Dest({required this.label, required this.icon, required this.builder});
}

class _SideRail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final List<_Dest> destinations;
  final VoidCallback? onLogoutTap;

  const _SideRail({
    super.key,
    required this.index,
    required this.onSelect,
    required this.destinations,
    this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final rail = NavigationRail(
      selectedIndex: index,
      onDestinationSelected: onSelect,
      extended: true,
      groupAlignment: -0.8,
      minExtendedWidth: 230,
      backgroundColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Icon(Icons.local_hospital_rounded, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Kwalps_st',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
            ),
          ],
        ),
      ),
      trailing: onLogoutTap == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
              child: FilledButton.tonalIcon(
                onPressed: onLogoutTap,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sair'),
              ),
            ),
      destinations: destinations
          .map(
            (d) => NavigationRailDestination(
              icon: Icon(d.icon),
              label: Text(d.label),
            ),
          )
          .toList(),
    );

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(right: BorderSide(color: cs.outline)),
      ),
      child: rail,
    );
  }
}

class _AdminLockedView extends StatelessWidget {
  final VoidCallback onLoginTap;
  const _AdminLockedView({required this.onLoginTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: cs.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Área restrita',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Faça login de administrador para gerir pessoas autorizadas.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onLoginTap,
                  icon: const Icon(Icons.admin_panel_settings_rounded),
                  label: const Text('Login de Administrador'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
