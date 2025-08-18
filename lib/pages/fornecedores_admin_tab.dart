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
              final list = snapshot.data!;
              if (list.isEmpty) {
                return const Center(child: Text('Nenhum fornecedor cadastrado.'));
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
                          if (f.email != null) Text('Email: ${f.email}'),
                          if (f.telefone != null) Text('Telefone: ${f.telefone}'),
                          if (f.contato != null) Text('Contato: ${f.contato}'),
                          if (f.notas != null) Text('Notas: ${f.notas}'),
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
    await FornecedoresService().delete(f.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fornecedor removido.')),
      );
    }
  }

  Future<void> _editar(Fornecedor f) async {
    final nome = TextEditingController(text: f.nome);
    final email = TextEditingController(text: f.email ?? '');
    final telefone = TextEditingController(text: f.telefone ?? '');
    final contato = TextEditingController(text: f.contato ?? '');
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
              TextField(controller: contato, decoration: const InputDecoration(labelText: 'Contato')),
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
      await FornecedoresService().update(
        f.id,
        Fornecedor(
          id: f.id,
          nome: nome.text.trim(),
          email: email.text.trim().isEmpty ? null : email.text.trim(),
          telefone: telefone.text.trim().isEmpty ? null : telefone.text.trim(),
          contato: contato.text.trim().isEmpty ? null : contato.text.trim(),
          notas: notas.text.trim().isEmpty ? null : notas.text.trim(),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fornecedor atualizado.')),
        );
      }
    }
  }

  Future<void> _adicionarManual() async {
    final nome = TextEditingController();
    final email = TextEditingController();
    final telefone = TextEditingController();
    final contato = TextEditingController();
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
              TextField(controller: contato, decoration: const InputDecoration(labelText: 'Contato')),
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
      await FornecedoresService().add(Fornecedor(
        nome: nome.text.trim(),
        email: email.text.trim().isEmpty ? null : email.text.trim(),
        telefone: telefone.text.trim().isEmpty ? null : telefone.text.trim(),
        contato: contato.text.trim().isEmpty ? null : contato.text.trim(),
        notas: notas.text.trim().isEmpty ? null : notas.text.trim(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fornecedor adicionado.')),
        );
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
      int iContato = header.indexWhere((h) => ['contato', 'contacto', 'pessoa de contato', 'responsavel'].contains(h));
      int iNotas = header.indexWhere((h) => ['notas', 'observacao', 'observações', 'obs'].contains(h));

      if (iNome < 0) throw Exception('Não encontrei a coluna de Nome na primeira linha.');

      int count = 0;
      for (var r = 1; r < sheet.rows.length; r++) {
        final row = sheet.rows[r];
        final nome = (row.elementAt(iNome)?.value?.toString() ?? '').trim();
        if (nome.isEmpty) continue;
        final email = (iEmail >= 0 ? row.elementAt(iEmail)?.value?.toString() : '')?.trim();
        final tel = (iTel >= 0 ? row.elementAt(iTel)?.value?.toString() : '')?.trim();
        final contato = (iContato >= 0 ? row.elementAt(iContato)?.value?.toString() : '')?.trim();
        final notas = (iNotas >= 0 ? row.elementAt(iNotas)?.value?.toString() : '')?.trim();

        await FornecedoresService().upsertByNome(Fornecedor(
          nome: nome,
          email: (email?.isEmpty ?? true) ? null : email,
          telefone: (tel?.isEmpty ?? true) ? null : tel,
          contato: (contato?.isEmpty ?? true) ? null : contato,
          notas: (notas?.isEmpty ?? true) ? null : notas,
        ));
        count++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Importação concluída: $count itens.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao importar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
