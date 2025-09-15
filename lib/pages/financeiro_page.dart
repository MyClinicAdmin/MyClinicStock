import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FinanceiroPage extends StatefulWidget {
  const FinanceiroPage({super.key});

  @override
  State<FinanceiroPage> createState() => _FinanceiroPageState();
}

class _FinanceiroPageState extends State<FinanceiroPage> {
  DateTimeRange? _range;
  String _search = '';

  Query<Map<String, dynamic>> _baseQuery() {
    var q = FirebaseFirestore.instance
        .collection('finance_movimentos')
        .orderBy('criado_em', descending: true);

    if (_range != null) {
      final start = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
      final end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59, 999);
      q = q.where('criado_em', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
           .where('criado_em', isLessThanOrEqualTo: Timestamp.fromDate(end));
    }
    return q;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final res = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _range ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month + 1, 0),
          ),
    );
    if (res != null) setState(() => _range = res);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financeiro'),
        actions: [
          IconButton(
            tooltip: 'Exportar (breve)',
            onPressed: () {}, // TODO: export Excel/PDF no próximo passo
            icon: const Icon(Icons.file_download_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(94),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(_range == null
                          ? 'Período: todos'
                          : '${_range!.start.day.toString().padLeft(2, '0')}/${_range!.start.month.toString().padLeft(2, '0')} '
                            '– ${_range!.end.day.toString().padLeft(2, '0')}/${_range!.end.month.toString().padLeft(2, '0')}'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _range = null),
                      icon: const Icon(Icons.clear),
                      label: const Text('Limpar'),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Filtrar por produto, fornecedor, tipo…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _baseQuery().snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData) return const SizedBox();

          var docs = snap.data!.docs;

          // filtro por texto
          if (_search.isNotEmpty) {
            docs = docs.where((d) {
              final m = d.data();
              final p = (m['produto_nome'] ?? '').toString().toLowerCase();
              final f = (m['fornecedor_nome'] ?? '').toString().toLowerCase();
              final t = (m['tipo'] ?? '').toString().toLowerCase();
              return p.contains(_search) || f.contains(_search) || t.contains(_search);
            }).toList();
          }

          // totais simples do período visível
          double entradas = 0, saidas = 0;
          for (final d in docs) {
            final m = d.data();
            final tipo = (m['tipo'] ?? '').toString();
            final total = (m['total'] is num) ? (m['total'] as num).toDouble() : 0.0;
            if (tipo == 'entrada') entradas += total;
            if (tipo == 'saida') saidas += total;
          }
          final saldo = entradas - saidas;

          return Column(
            children: [
              // Resumo
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Row(
                  children: [
                    _sumCard(context, 'Entradas', entradas, cs.primary),
                    const SizedBox(width: 8),
                    _sumCard(context, 'Saídas/CMV', saidas, const Color(0xFFE53935)),
                    const SizedBox(width: 8),
                    _sumCard(context, 'Saldo', saldo, saldo >= 0 ? const Color(0xFF1DB954) : const Color(0xFFE53935)),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Lista
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final m = docs[i].data();
                    final tipo = (m['tipo'] ?? '').toString();
                    final isIn = tipo == 'entrada';
                    final title = '${isIn ? 'Entrada' : 'Saída'} — ${(m['produto_nome'] ?? '—')}';
                    final sub = <String>[
                      if ((m['fornecedor_nome'] ?? '').toString().isNotEmpty) 'Fornecedor: ${m['fornecedor_nome']}',
                      if ((m['lote_id'] ?? '').toString().isNotEmpty) 'Lote: ${m['lote_id']}',
                      'Qtd: ${m['quantidade'] ?? 0}',
                      if (isIn && m['preco_unit'] != null) 'Unit: ${m['preco_unit']}',
                      if (!isIn && m['custo_unit_saida'] != null) 'Custo unit: ${m['custo_unit_saida']}',
                      if (m['total'] != null) 'Total: ${m['total']}',
                    ].join('  •  ');

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (isIn ? cs.primary : const Color(0xFFE53935)).withOpacity(.12),
                          foregroundColor: isIn ? cs.primary : const Color(0xFFE53935),
                          child: Icon(isIn ? Icons.call_received_rounded : Icons.call_made_rounded),
                        ),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(sub),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sumCard(BuildContext context, String label, double v, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Kz ${v.toStringAsFixed(2)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
