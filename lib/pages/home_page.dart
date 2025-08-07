import 'package:flutter/material.dart';
import 'produtos_em_falta_page.dart';
<<<<<<< HEAD
=======
import 'produtos_a_vencer_page.dart';
>>>>>>> ba5fca845d2f2c9ce8a3dcc500dec0fd2a852dde
import 'cadastro_produto_page.dart';

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
    const ProdutosEmFaltaPage(),
<<<<<<< HEAD
    const Placeholder(), // Podes trocar depois por ProdutosAVencerPage
    const Placeholder(), // Troca por EnviarEmailPage
    const CadastroProdutoPage(),
=======
    const ProdutosAVencerPage(),
    const Placeholder(), // Enviar Email (ainda não implementado)
    const CadastroProdutoPage(),
  ];

  final List<String> _titles = [
    'Produtos em Falta',
    'Produtos a Vencer',
    'Enviar Email',
    'Cadastrar Produto',
>>>>>>> ba5fca845d2f2c9ce8a3dcc500dec0fd2a852dde
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Em Falta'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'A Vencer'),
          BottomNavigationBarItem(icon: Icon(Icons.email), label: 'Email'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Cadastrar'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
