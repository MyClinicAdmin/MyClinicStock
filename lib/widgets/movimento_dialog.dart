import 'package:flutter/material.dart';

class MovimentoResult {
  final int quantidade;
  final String motivo;
  final String operadorNome;
  final String operadorChave;
  MovimentoResult({
    required this.quantidade,
    required this.motivo,
    required this.operadorNome,
    required this.operadorChave,
  });
}

/// Dialog versátil:
/// - requireAuth: se true, exige nome/senha; se false, pode vir presetOperador
/// - authOnly: se true, mostra só os campos de nome/senha (para login rápido)
Future<MovimentoResult?> showMovimentoDialog(
  BuildContext context, {
  required String titulo,
  String motivoLabel = 'Motivo (opcional)',
  bool requireAuth = true,
  bool authOnly = false,
  String? presetOperador,
}) async {
  final qtdCtrl = TextEditingController();
  final motivoCtrl = TextEditingController();
  final nomeCtrl = TextEditingController(text: presetOperador ?? '');
  final chaveCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool obscure = true;

  final res = await showDialog<MovimentoResult>(
    context: context,
    builder: (_) => StatefulBuilder(builder: (context, setSt) {
      return AlertDialog(
        title: Text(titulo),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (!authOnly) ...[
                TextFormField(
                  controller: qtdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantidade'),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    final n = int.tryParse(t);
                    if (n == null || n <= 0) return 'Informe uma quantidade válida';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(controller: motivoCtrl, decoration: InputDecoration(labelText: motivoLabel)),
                const Divider(height: 24),
              ],
              if (requireAuth || authOnly) ...[
                TextFormField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(labelText: 'Nome (autorizado)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: chaveCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Chave de segurança',
                    suffixIcon: IconButton(
                      onPressed: () => setSt(() => obscure = !obscure),
                      icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a chave' : null,
                ),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (!authOnly) {
                if (!formKey.currentState!.validate()) return;
              } else {
                // no auth-only, precisamos validar os campos de auth
                if (!formKey.currentState!.validate()) return;
              }
              final n = int.tryParse(qtdCtrl.text.trim()) ?? 0;
              Navigator.pop(
                context,
                MovimentoResult(
                  quantidade: n,
                  motivo: motivoCtrl.text.trim(),
                  operadorNome: nomeCtrl.text.trim(),
                  operadorChave: chaveCtrl.text.trim(),
                ),
              );
            },
            child: const Text('Confirmar'),
          ),
        ],
      );
    }),
  );

  return res;
}
