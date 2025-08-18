// lib/models/fornecedor.dart
class Fornecedor {
  final String id;
  final String nome;
  final String? email;
  final String? telefone;
  final String? contato; // pessoa de contato
  final String? notas;

  Fornecedor({
    this.id = '',          // deixa opcional para não quebrar chamadas antigas
    required this.nome,
    this.email,
    this.telefone,
    this.contato,
    this.notas,
  });

  static String _norm(String s) => s.toLowerCase().trim();

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'nome_normalizado': _norm(nome),
        if (email != null) 'email': email,
        if (telefone != null) 'telefone': telefone,
        if (contato != null) 'contato': contato,
        if (notas != null) 'notas': notas,
        'atualizado_em': DateTime.now(),
        'criado_em': DateTime.now(),
      };

  static Fornecedor fromMap(String id, Map<String, dynamic> m) => Fornecedor(
        id: id,
        nome: (m['nome'] ?? '').toString(),
        email: ((m['email'] ?? '').toString().trim().isEmpty) ? null : (m['email'] as String),
        telefone: ((m['telefone'] ?? '').toString().trim().isEmpty) ? null : (m['telefone'] as String),
        contato: ((m['contato'] ?? '').toString().trim().isEmpty) ? null : (m['contato'] as String),
        notas: ((m['notas'] ?? '').toString().trim().isEmpty) ? null : (m['notas'] as String),
      );
}
