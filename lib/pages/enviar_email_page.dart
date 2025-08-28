// lib/pages/enviar_email_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:url_launcher/url_launcher.dart';
import '../services/email_service.dart';

class EnviarEmailPage extends StatefulWidget {
  const EnviarEmailPage({super.key});

  @override
  State<EnviarEmailPage> createState() => _EnviarEmailPageState();
}

class _EnviarEmailPageState extends State<EnviarEmailPage> {
  Future<List<GrupoEmail>>? _future;
  final _fallbackController = TextEditingController(text: 'compras@clinica.com');

  // limite seguro para URL (mailto) — navegadores costumam cortar ~2k
  static const int _mailtoMaxLen = 1900;

  @override
  void initState() {
    super.initState();
    _future = EmailService.carregarGrupos(); // agrupa itens abaixo do mínimo por fornecedor
  }

  @override
  void dispose() {
    _fallbackController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() => _future = EmailService.carregarGrupos());
  }

  // ---------- MAILTO helpers ----------
  Uri _buildMailtoUri({
    required String to,
    required String subject,
    required String body,
  }) {
    final query = {
      'subject': subject,
      'body': body,
    }.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    return Uri.parse('mailto:$to?$query');
  }

  Future<void> _openMailto({
    required String to,
    required String subject,
    required String body,
  }) async {
    if (to.isEmpty) {
      _err('Indica um destinatário.');
      return;
    }

    final uri = _buildMailtoUri(to: to, subject: subject, body: body);

    // proteção: se a URL estourar o limite, copia texto e avisa
    if (uri.toString().length > _mailtoMaxLen) {
      await EmailService.copiarTexto(body);
      _err('Mensagem muito longa para abrir no mailto. Copiei o texto — cole no seu e-mail.');
      return;
    }

    // Tente abrir com url_launcher no modo "padrão da plataforma"
    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);

    if (!ok) {
      // Fallback extra para WEB: navegar direto para o mailto (evita bloqueio)
      if (kIsWeb) {
        html.window.location.assign(uri.toString());
        return;
      }
      _err('Não foi possível abrir o cliente de e-mail.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Enviar Email')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FutureBuilder<List<GrupoEmail>>(
            future: _future,
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Erro ao carregar: ${snap.error}'));
              }
              final grupos = (snap.data ?? []).toList();

              return Column(
                children: [
                  // Cabeçalho / ações gerais
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(children: [
                            const Text('Destinatário padrão (fallback)'),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Recarregar',
                              onPressed: _refresh,
                              icon: const Icon(Icons.refresh),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _fallbackController,
                            decoration: const InputDecoration(
                              hintText: 'usado se não houver e-mail no fornecedor',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 10),

                          if (grupos.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // Abrir mailto consolidado (um único e-mail)
                                FilledButton.icon(
                                  icon: const Icon(Icons.alternate_email),
                                  label: const Text('Abrir consolidado (mailto)'),
                                  onPressed: () async {
                                    final to = _fallbackController.text.trim();
                                    if (to.isEmpty) {
                                      _err('Indica um destinatário padrão.');
                                      return;
                                    }
                                    final subject = 'Pedido de reposição — Itens em falta';
                                    final body = EmailService.textoConsolidado(grupos); // TEXTO
                                    await _openMailto(to: to, subject: subject, body: body);
                                  },
                                ),
                                // Pré-visualizar consolidado (HTML)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: const Text('Pré-visualizar (Tudo)'),
                                  onPressed: () {
                                    final html = EmailService.previewHtmlConsolidado(grupos);
                                    _mostrarPreview(html);
                                  },
                                ),
                                // Copiar consolidado (texto)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.copy_all_outlined),
                                  label: const Text('Copiar texto (Tudo)'),
                                  onPressed: () async {
                                    await EmailService.copiarTexto(EmailService.textoConsolidado(grupos));
                                    if (mounted) _ok('Copiado (consolidado).');
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  if (grupos.isEmpty)
                    const Expanded(child: Center(child: Text('Sem itens em falta.'))),

                  // Lista por fornecedor
                  if (grupos.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: grupos.length,
                        itemBuilder: (_, i) {
                          final g = grupos[i];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(g.fornecedor, style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: cs.surfaceContainerHighest,
                                      ),
                                      child: Text(
                                        g.email ?? '(sem e-mail)',
                                        style: TextStyle(
                                          color: g.email == null ? cs.error : cs.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 8),

                                  // Tabela de itens
                                  Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(2),
                                      1: IntrinsicColumnWidth(),
                                      2: IntrinsicColumnWidth(),
                                      3: IntrinsicColumnWidth(),
                                    },
                                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                    children: [
                                      const TableRow(children: [
                                        Padding(padding: EdgeInsets.all(6), child: Text('Produto', style: TextStyle(fontWeight: FontWeight.w600))),
                                        Padding(padding: EdgeInsets.all(6), child: Text('Qtd', style: TextStyle(fontWeight: FontWeight.w600))),
                                        Padding(padding: EdgeInsets.all(6), child: Text('Mín.', style: TextStyle(fontWeight: FontWeight.w600))),
                                        Padding(padding: EdgeInsets.all(6), child: Text('Validade', style: TextStyle(fontWeight: FontWeight.w600))),
                                      ]),
                                      ...g.itens.map((p) => TableRow(children: [
                                            Padding(padding: const EdgeInsets.all(6), child: Text(p.nome)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${p.quantidade}', textAlign: TextAlign.right)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${p.minimo}', textAlign: TextAlign.right)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(p.validadeFmt)),
                                          ])),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Ações do card (por fornecedor)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.visibility_outlined),
                                        label: const Text('Pré-visualizar'),
                                        onPressed: () {
                                          final html = EmailService.previewHtmlFornecedor(g.fornecedor, g.itens);
                                          _mostrarPreview(html);
                                        },
                                      ),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.copy_all_outlined),
                                        label: const Text('Copiar (texto)'),
                                        onPressed: () async {
                                          final text = EmailService.textoFornecedor(
                                            fornecedor: g.fornecedor,
                                            itens: g.itens,
                                          );
                                          await EmailService.copiarTexto(text);
                                          if (mounted) _ok('Copiado para a área de transferência.');
                                        },
                                      ),

                                      // Abrir cliente de e-mail (mailto) por fornecedor
                                      FilledButton.icon(
                                        icon: const Icon(Icons.alternate_email),
                                        label: const Text('Abrir e-mail (mailto)'),
                                        onPressed: () async {
                                          final to = (g.email ?? _fallbackController.text.trim());
                                          if (to.isEmpty) {
                                            _err('Sem e-mail do fornecedor e sem fallback.');
                                            return;
                                          }
                                          final subject = 'Pedido de reposição — ${g.fornecedor}';
                                          final body = EmailService.textoFornecedor(
                                            fornecedor: g.fornecedor,
                                            itens: g.itens,
                                          );
                                          await _openMailto(to: to, subject: subject, body: body);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------- diálogos auxiliares ----------
  Future<void> _mostrarPreview(String html) async {
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 640),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                alignment: Alignment.centerLeft,
                child: Text('Pré-visualização', style: Theme.of(ctx).textTheme.titleMedium),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    html,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
              const Divider(height: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fechar'))],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- toasts ----------
  void _ok(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  void _err(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
}
