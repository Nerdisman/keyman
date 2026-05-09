import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_key_manager/providers/theme_provider.dart';
import 'package:ssh_key_manager/providers/key_manager_provider.dart';
import 'package:ssh_key_manager/ui/home_page.dart';
import 'package:provider/provider.dart';

class SSHKeyManagerApp extends StatefulWidget {
  const SSHKeyManagerApp({super.key});

  @override
  State<SSHKeyManagerApp> createState() => _SSHKeyManagerAppState();
}

class _SSHKeyManagerAppState extends State<SSHKeyManagerApp> {
  SharedPreferences? _prefs;
  ThemeProvider? _themeProvider;
  KeyManagerProvider? _keyManagerProvider;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    WidgetsFlutterBinding.ensureInitialized();
    _prefs = await SharedPreferences.getInstance();
    _themeProvider = ThemeProvider(_prefs!);
    _keyManagerProvider = await KeyManagerProvider.create();
    await _keyManagerProvider!.loadKeys();

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _prefs == null || _themeProvider == null || _keyManagerProvider == null) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _themeProvider!),
        ChangeNotifierProvider.value(value: _keyManagerProvider!),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'keyman',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              brightness: themeProvider.isDarkMode
                  ? Brightness.dark
                  : Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1E88E5),
                brightness: themeProvider.isDarkMode
                    ? Brightness.dark
                    : Brightness.light,
              ),
            ),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
