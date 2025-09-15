// lib/pages/admin_page.dart
import 'package:flutter/material.dart';
import 'package:kwalps_st/services/authz_service.dart';
import 'package:kwalps_st/services/stock_service.dart' as stock;

import 'fornecedores_admin_tab.dart';
import 'produtos_admin_tab.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  // 4 abas
  late final TabController _tab = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ===================== DIÁLOGOS BONITOS (Sucesso/Erro/Confirmação) =====================

  Future<void> _showResultDialog({
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: color),
              const SizedBox(height: 12),
              Text(
                title ?? (ok ? 'Sucesso' : 'Ocorreu um erro'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
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

  Future<bool> _confirm({
    required String title,
    required String message,
    IconData icon = Icons.help_outline_rounded,
    Color? color,
    String cancelText = 'Cancelar',
    String confirmText = 'Confirmar',
  }) async {
    final cs = Theme.of(context).colorScheme;
    final icColor = color ?? cs.primary;

    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: icColor),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(cancelText),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(confirmText),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
    return res == true;
  }

  // ======================================================================

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
            Tab(text: 'Fornecedores'),
            Tab(text: 'Produtos'),
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
                                  onChanged: (v) async {
                                    try {
                                      await AuthzService().toggleActive(u.id, v);
                                      await _showResultDialog(
                                        ok: true,
                                        title: 'Atualizado',
                                        message: v ? 'Utilizador ativado.' : 'Utilizador desativado.',
                                      );
                                    } catch (e) {
                                      await _showResultDialog(
                                        ok: false,
                                        title: 'Falha',
                                        message: 'Não foi possível alterar o estado.\n$e',
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Eliminar',
                                  onPressed: () async {
                                    final ok = await _confirm(
                                      title: 'Eliminar autorizado',
                                      message: 'Remover "${u.nome}"? Esta ação não pode ser desfeita.',
                                      icon: Icons.delete_forever_rounded,
                                      color: cs.error,
                                      confirmText: 'Eliminar',
                                    );
                                    if (!ok) return;

                                    try {
                                      await AuthzService().delete(u.id);
                                      await _showResultDialog(
                                        ok: true,
                                        title: 'Eliminado',
                                        message: 'A pessoa "${u.nome}" foi removida com sucesso.',
                                      );
                                    } catch (e) {
                                      await _showResultDialog(
                                        ok: false,
                                        title: 'Falha ao eliminar',
                                        message: '$e',
                                      );
                                    }
                                  },
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

          // --------- Aba 2: Histórico ---------
          StreamBuilder<List<stock.Movimento>>(
            stream: stock.StockService().streamMovimentos(limit: 300),
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
          // ⚠️ No formulário de fornecedor, remova o campo "Contacto".
          //    Use apenas: Nome, Email e Telefone.
          const FornecedoresAdminTab(),

          // --------- Aba 4: Produtos ---------
          const ProdutosAdminTab(),
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
      try {
        await AuthzService().addAuthorized(
          nome: nome.text.trim(),
          chave: chave.text.trim(),
          role: role,
          ativo: ativo,
        );
        if (mounted) {
          await _showResultDialog(
            ok: true,
            title: 'Adicionado',
            message: 'Pessoa autorizada adicionada com sucesso.',
          );
        }
      } catch (e) {
        if (mounted) {
          await _showResultDialog(
            ok: false,
            title: 'Falha ao adicionar',
            message: '$e',
          );
        }
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
      try {
        await AuthzService().updateAuthorized(id: u.id, novoNome: nome.text.trim());
        await _showResultDialog(ok: true, title: 'Atualizado', message: 'Nome atualizado.');
      } catch (e) {
        await _showResultDialog(ok: false, title: 'Falha ao atualizar', message: '$e');
      }
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
    if (ok == true) {
      final nova = chave.text.trim();
      if (nova.length < 4) {
        await _showResultDialog(ok: false, title: 'Inválido', message: 'A chave deve ter ao menos 4 caracteres.');
        return;
      }
      try {
        await AuthzService().updateAuthorized(id: u.id, novaChave: nova);
        await _showResultDialog(ok: true, title: 'Chave redefinida', message: 'A nova chave foi aplicada.');
      } catch (e) {
        await _showResultDialog(ok: false, title: 'Falha ao redefinir', message: '$e');
      }
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
      try {
        await AuthzService().updateAuthorized(id: u.id, novoRole: role);
        await _showResultDialog(ok: true, title: 'Função atualizada', message: 'As permissões foram alteradas.');
      } catch (e) {
        await _showResultDialog(ok: false, title: 'Falha ao atualizar função', message: '$e');
      }
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
