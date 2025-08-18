import 'package:flutter/material.dart';

Future<_QtdResult?> showQtdDialog(
  BuildContext context, {
  required String title,
  String motivoLabel = 'Motivo (opcional)',
  int initial = 1,
}) async {
  final qtdCtrl = TextEditingController(text: initial.toString());
  final motivoCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: qtdCtrl,
              decoration: const InputDecoration(labelText: 'Quantidade'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe a quantidade';
                final n = int.tryParse(v.trim());
                if (n == null || n <= 0) return 'Quantidade inválida';
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: motivoCtrl,
              decoration: InputDecoration(labelText: motivoLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(context, true);
          },
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );

  if (ok == true) {
    return _QtdResult(
      quantidade: int.parse(qtdCtrl.text.trim()),
      motivo: motivoCtrl.text.trim(),
    );
  }
  return null;
}

class _QtdResult {
  final int quantidade;
  final String motivo;
  _QtdResult({required this.quantidade, required this.motivo});
}
