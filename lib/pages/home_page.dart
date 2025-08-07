import 'package:flutter/material.dart';
import 'cadastro_produto_page.dart';
import 'produtos_em_falta_page.dart';
import 'produtos_a_vencer_page.dart';
import 'enviar_email_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Produtos em Falta',
    'Produtos a Vencer',
    'Enviar Email',
    'Cadastrar Produto',
  ];

  final List<Widget> _pages = [
    ProdutosEmFaltaPage(),
    ProdutosAVencerPage(),
    EnviarEmailPage(),
    CadastroProdutoPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'Em Falta',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'A Vencer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.email),
            label: 'Email',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box),
            label: 'Cadastrar',
          ),
        ],
      ),
    );
  }
}
