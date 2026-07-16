import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'screens/auth_wrapper.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (details) {
    developer.log(
      'Widget build error',
      name: 'TravelHub',
      error: details.exception,
      stackTrace: details.stack,
    );

    return const _SafeWidgetError();
  };

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const TravelApp());
}

class _SafeWidgetError extends StatelessWidget {
  const _SafeWidgetError();

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFFF3FAF8),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 44,
                    color: Color(0xFFB42318),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Không thể hiển thị nội dung này',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF102326),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Vui lòng quay lại và thử mở lại màn hình.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF647A7D),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TravelApp extends StatelessWidget {
  const TravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TravelHub',

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      // Sử dụng giao diện và định dạng ngày của Việt Nam.
      locale: const Locale('vi', 'VN'),

      supportedLocales: const [
        Locale('vi', 'VN'),
        Locale('en'),
      ],

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const AuthWrapper(),
    );
  }
}
