// lib/pages/admin_page.dart
import 'package:flutter/material.dart';
import 'package:kwalps_st/services/authz_service.dart';
import 'package:kwalps_st/services/stock_service.dart';

import 'fornecedores_admin_tab.dart'; // <- nova aba

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  // Agora com 3 abas
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Autorizados'),
            Tab(text: 'Histórico'),
            Tab(text: 'Fornecedores'), // NOVO
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // --------- Aba 1: Autorizados ---------
          Column(
            children: [
              const SizedBox(height: 8),
              const Text('Gerir pessoas autorizadas', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<AuthorizedUser>>(
                  stream: AuthzService().streamAll(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Erro: ${snap.error}', textAlign: TextAlign.center),
                        ),
                      );
                    }
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final list = snap.data!;
                    if (list.isEmpty) return const Center(child: Text('Nenhuma pessoa autorizada.'));
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final u = list[i];
                        return Card(
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: cs.outline),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(u.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: u.isAdmin ? cs.primaryContainer : cs.secondaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    u.isAdmin ? 'admin' : 'operator',
                                    style: TextStyle(
                                      color: u.isAdmin ? cs.onPrimaryContainer : cs.onSecondaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(u.ativo ? 'Ativo' : 'Inativo'),
                            trailing: Wrap(
                              spacing: 6,
                              children: [
                                IconButton(
                                  tooltip: 'Renomear',
                                  onPressed: () => _renameUser(context, u),
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  tooltip: 'Resetar chave',
                                  onPressed: () => _resetKey(context, u),
                                  icon: const Icon(Icons.vpn_key),
                                ),
                                IconButton(
                                  tooltip: 'Alterar função',
                                  onPressed: () => _changeRole(context, u),
                                  icon: const Icon(Icons.badge_outlined),
                                ),
                                Switch(
                                  value: u.ativo,
                                  onChanged: (v) => AuthzService().toggleActive(u.id, v),
                                ),
                                IconButton(
                                  tooltip: 'Eliminar',
                                  onPressed: () async => await AuthzService().delete(u.id),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // --------- Aba 2: Histórico (collectionGroup "movimentos") ---------
          StreamBuilder<List<Movimento>>(
            stream: StockService().streamMovimentos(limit: 300),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Erro ao carregar histórico:\n${snap.error}', textAlign: TextAlign.center),
                  ),
                );
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final hist = snap.data!;
              if (hist.isEmpty) return const Center(child: Text('Sem movimentos registados.'));

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: hist.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final m = hist[i];
                  final isEntrada = m.tipo == 'entrada';
                  final isSaida = m.tipo == 'saida';
                  final chipColor = isEntrada
                      ? cs.primaryContainer
                      : (isSaida ? cs.errorContainer : cs.tertiaryContainer);
                  final chipOn = isEntrada
                      ? cs.onPrimaryContainer
                      : (isSaida ? cs.onErrorContainer : cs.onTertiaryContainer);

                  return Card(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: cs.outline),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: chipColor.withOpacity(0.15),
                        child: Icon(
                          isEntrada ? Icons.add_rounded : (isSaida ? Icons.remove_rounded : Icons.tune_rounded),
                          color: chipOn,
                        ),
                      ),
                      title: Text(
                        (m.produtoNome.isEmpty ? '(produto)' : m.produtoNome),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          'Operador: ${m.operador ?? '—'}',
                          if ((m.motivo ?? '').isNotEmpty) 'Motivo: ${m.motivo}',
                          'Quando: ${_fmt(m.criadoEm)}',
                        ].join('  •  '),
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(
                            label: Text(m.tipo.toUpperCase()),
                            backgroundColor: chipColor,
                            labelStyle: TextStyle(color: chipOn, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text('Qtd: ${m.quantidade}'),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // --------- Aba 3: Fornecedores ---------
          const FornecedoresAdminTab(), // NOVO
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAuthorizedDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Adicionar autorizado'),
      ),
    );
  }

  // ---------- Actions (Autorizados) ----------

  Future<void> _showAddAuthorizedDialog(BuildContext context) async {
    final nome = TextEditingController();
    final chave = TextEditingController();
    String role = 'operator';
    bool ativo = true;
    final formKey = GlobalKey<FormState>();
    bool obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nova Pessoa Autorizada'),
        content: Form(
          key: formKey,
          child: StatefulBuilder(builder: (context, setSt) {
            return Column(
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
                    labelText: 'Chave (será guardada com hash)',
                    suffixIcon: IconButton(
                      onPressed: () => setSt(() => obscure = !obscure),
                      icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().length < 4) ? 'Mínimo 4 caracteres' : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(value: 'operator', child: Text('operator (pode entrada/saída)')),
                    DropdownMenuItem(value: 'admin', child: Text('admin (gestão completa)')),
                  ],
                  onChanged: (v) => setSt(() => role = v ?? 'operator'),
                  decoration: const InputDecoration(labelText: 'Função'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: ativo,
                  onChanged: (v) => setSt(() => ativo = v),
                  title: const Text('Ativo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            );
          }),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, true);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AuthzService().addAuthorized(
        nome: nome.text.trim(),
        chave: chave.text.trim(),
        role: role,
        ativo: ativo,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pessoa autorizada adicionada.')),
        );
      }
    }
  }

  Future<void> _renameUser(BuildContext context, AuthorizedUser u) async {
    final nome = TextEditingController(text: u.nome);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renomear'),
        content: TextField(controller: nome, decoration: const InputDecoration(labelText: 'Novo nome')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok == true) {
      await AuthzService().updateAuthorized(id: u.id, novoNome: nome.text.trim());
    }
  }

  Future<void> _resetKey(BuildContext context, AuthorizedUser u) async {
    final chave = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resetar chave'),
        content: TextField(
          controller: chave,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Nova chave (mín. 4)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok == true && chave.text.trim().length >= 4) {
      await AuthzService().updateAuthorized(id: u.id, novaChave: chave.text.trim());
    }
  }

  Future<void> _changeRole(BuildContext context, AuthorizedUser u) async {
    String role = u.role;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Alterar função'),
        content: DropdownButtonFormField<String>(
          value: role,
          items: const [
            DropdownMenuItem(value: 'operator', child: Text('operator')),
            DropdownMenuItem(value: 'admin', child: Text('admin')),
          ],
          onChanged: (v) => role = v ?? 'operator',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok == true) {
      await AuthzService().updateAuthorized(id: u.id, novoRole: role);
    }
  }

  // ---------- utils ----------
  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
