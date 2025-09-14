// lib/pages/fornecedores_admin_tab.dart
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/fornecedor.dart';
import '../services/fornecedores_service.dart';

class FornecedoresAdminTab extends StatefulWidget {
  const FornecedoresAdminTab({super.key});

  @override
  State<FornecedoresAdminTab> createState() => _FornecedoresAdminTabState();
}

class _FornecedoresAdminTabState extends State<FornecedoresAdminTab> {
  final _svc = FornecedoresService();

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ===================== Diálogos grandes e visíveis =====================

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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Importar Excel (.xlsx)'),
                onPressed: _importarExcel,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Adicionar fornecedor'),
                onPressed: _adicionarManual,
              ),
              const Spacer(),
              // Barra de pesquisa
              SizedBox(
                width: 360,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Pesquisar por nome, email ou telefone…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<Fornecedor>>(
            stream: _svc.streamAll(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erro: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var list = snapshot.data!;
              if (_query.isNotEmpty) {
                list = list.where((f) {
                  final nome = f.nome.toLowerCase();
                  final email = (f.email ?? '').toLowerCase();
                  final tel = (f.telefone ?? '').toLowerCase();
                  return nome.contains(_query) || email.contains(_query) || tel.contains(_query);
                }).toList();
              }
              if (list.isEmpty) {
                return const Center(child: Text('Nenhum fornecedor encontrado.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final f = list[i];
                  return Card(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: cs.outline),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(f.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (f.email != null && f.email!.trim().isNotEmpty) Text('Email: ${f.email}'),
                          if (f.telefone != null && f.telefone!.trim().isNotEmpty) Text('Telefone: ${f.telefone}'),
                          if (f.notas != null && f.notas!.trim().isNotEmpty) Text('Notas: ${f.notas}'),
                        ],
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            tooltip: 'Editar',
                            onPressed: () => _editar(f),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            tooltip: 'Apagar',
                            onPressed: () => _apagar(f),
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
    );
  }

  Future<void> _apagar(Fornecedor f) async {
    final ok = await _confirm(
      title: 'Eliminar fornecedor',
      message: 'Deseja realmente remover "${f.nome}"?\nEsta ação não pode ser desfeita.',
      icon: Icons.delete_forever_rounded,
      color: Theme.of(context).colorScheme.error,
      confirmText: 'Eliminar',
    );
    if (!ok) return;

    try {
      await FornecedoresService().delete(f.id);
      if (mounted) {
        await _showResultDialog(
          ok: true,
          title: 'Fornecedor removido',
          message: 'O fornecedor "${f.nome}" foi eliminado com sucesso.',
        );
      }
    } catch (e) {
      if (mounted) {
        await _showResultDialog(
          ok: false,
          title: 'Falha ao eliminar',
          message: '$e',
        );
      }
    }
  }

  Future<void> _editar(Fornecedor f) async {
    final nome = TextEditingController(text: f.nome);
    final email = TextEditingController(text: f.email ?? '');
    final telefone = TextEditingController(text: f.telefone ?? '');
    final notas = TextEditingController(text: f.notas ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar fornecedor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nome, decoration: const InputDecoration(labelText: 'Nome')),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: telefone, decoration: const InputDecoration(labelText: 'Telefone')),
              // REMOVIDO: Contato
              TextField(controller: notas, decoration: const InputDecoration(labelText: 'Notas')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );

    if (ok == true) {
      try {
        await FornecedoresService().update(
          f.id,
          Fornecedor(
            id: f.id,
            nome: nome.text.trim(),
            email: email.text.trim().isEmpty ? null : email.text.trim(),
            telefone: telefone.text.trim().isEmpty ? null : telefone.text.trim(),
            // contato removido
            notas: notas.text.trim().isEmpty ? null : notas.text.trim(),
          ),
        );
        if (mounted) {
          await _showResultDialog(
            ok: true,
            title: 'Atualizado',
            message: 'Fornecedor atualizado com sucesso.',
          );
        }
      } catch (e) {
        if (mounted) {
          await _showResultDialog(
            ok: false,
            title: 'Falha ao atualizar',
            message: '$e',
          );
        }
      }
    }
  }

  Future<void> _adicionarManual() async {
    final nome = TextEditingController();
    final email = TextEditingController();
    final telefone = TextEditingController();
    final notas = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Novo fornecedor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nome, decoration: const InputDecoration(labelText: 'Nome')),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: telefone, decoration: const InputDecoration(labelText: 'Telefone')),
              // REMOVIDO: Contato
              TextField(controller: notas, decoration: const InputDecoration(labelText: 'Notas')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );

    if (ok == true) {
      try {
        await FornecedoresService().add(
          Fornecedor(
            nome: nome.text.trim(),
            email: email.text.trim().isEmpty ? null : email.text.trim(),
            telefone: telefone.text.trim().isEmpty ? null : telefone.text.trim(),
            // contato removido
            notas: notas.text.trim().isEmpty ? null : notas.text.trim(),
          ),
        );
        if (mounted) {
          await _showResultDialog(
            ok: true,
            title: 'Adicionado',
            message: 'Fornecedor adicionado com sucesso.',
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

  Future<void> _importarExcel() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final Uint8List? bytes = res.files.single.bytes;
    if (bytes == null) return;

    try {
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first]!;
      final header = sheet.rows.first
          .map((e) => (e?.value?.toString() ?? '').toLowerCase().trim())
          .toList();

      int iNome = header.indexWhere((h) => ['nome', 'fornecedor', 'razão social', 'razao social'].contains(h));
      int iEmail = header.indexWhere((h) => ['email', 'e-mail', 'mail'].contains(h));
      int iTel = header.indexWhere((h) => ['telefone', 'telemovel', 'celular', 'contacto', 'contato'].contains(h));
      // contato será IGNORED, mesmo que exista
      int iNotas = header.indexWhere((h) => ['notas', 'observacao', 'observações', 'obs'].contains(h));

      if (iNome < 0) throw Exception('Não encontrei a coluna de Nome na primeira linha.');

      int count = 0;
      for (var r = 1; r < sheet.rows.length; r++) {
        final row = sheet.rows[r];
        final nome = (row.elementAt(iNome)?.value?.toString() ?? '').trim();
        if (nome.isEmpty) continue;
        final email = (iEmail >= 0 ? row.elementAt(iEmail)?.value?.toString() : '')?.trim();
        final tel = (iTel >= 0 ? row.elementAt(iTel)?.value?.toString() : '')?.trim();
        // contato ignorado
        final notas = (iNotas >= 0 ? row.elementAt(iNotas)?.value?.toString() : '')?.trim();

        await FornecedoresService().upsertByNome(
          Fornecedor(
            nome: nome,
            email: (email?.isEmpty ?? true) ? null : email,
            telefone: (tel?.isEmpty ?? true) ? null : tel,
            // contato removido
            notas: (notas?.isEmpty ?? true) ? null : notas,
          ),
        );
        count++;
      }

      if (mounted) {
        await _showResultDialog(
          ok: true,
          title: 'Importação concluída',
          message: '$count fornecedor(es) importado(s) com sucesso.',
        );
      }
    } catch (e) {
      if (mounted) {
        await _showResultDialog(
          ok: false,
          title: 'Falha ao importar',
          message: '$e',
        );
      }
    }
  }
}
