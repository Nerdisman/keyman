import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssh_key_manager/providers/theme_provider.dart';
import 'package:ssh_key_manager/ui/navigation_drawer.dart' as nav;
import 'package:ssh_key_manager/ui/key_list_page.dart';
import 'package:ssh_key_manager/ui/generate_key_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    KeyListPage(),
    GenerateKeyPage(),
  ];

  void _onNavItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH密钥管理器'),
        actions: [
          IconButton(
            icon: Icon(
              Provider.of<ThemeProvider>(context).isDarkMode
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false)
                  .toggleDarkMode();
            },
            tooltip: '切换主题',
          ),
        ],
      ),
      drawer: nav.AppNavigationDrawer(
        currentIndex: _selectedIndex,
        onTap: _onNavItemSelected,
      ),
      body: _pages[_selectedIndex],
    );
  }
}
