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
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final keyManagerProvider = KeyManagerProvider(prefs);
    await keyManagerProvider.loadKeys();

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => ThemeProvider(snapshot.data!),
            ),
            ChangeNotifierProvider(
              create: (_) => KeyManagerProvider(snapshot.data!),
            ),
          ],
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return MaterialApp(
                title: 'SSH密钥管理器',
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
      },
    );
  }
}
