import 'package:app/login/auth.dart'; // ✅ Keep this one (lowercase)
import 'package:app/homepage/home_page.dart';
import 'package:app/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/profile_picture_provider.dart';
import 'providers/theme_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfilePictureProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()), // ✅ Fixed: Use (_) consistently
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Study App',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const Auth(),
            routes: {
              '/login': (context) => LoginScreen(onTap: () {}),
              '/home': (context) => const HomePage(),
            },
            onUnknownRoute: (settings) {
              if (kDebugMode) print('🔄 Unknown route: ${settings.name}');
              return MaterialPageRoute(
                builder: (context) => LoginScreen(onTap: () {}),
              );
            },
          );
        },
      ),
    );
  }
}
