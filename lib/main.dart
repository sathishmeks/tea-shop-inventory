import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import 'core/constants/app_constants.dart';
import 'core/themes/app_theme.dart';
import 'core/network/network_info.dart';
import 'core/services/language_service.dart';
import 'presentation/pages/splash_page.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Initialize Language Service
  await LanguageService.init();
  
  // Initialize Supabase only if enabled
  if (AppConstants.enableSupabase && 
      AppConstants.supabaseUrl.isNotEmpty && 
      AppConstants.supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }
  
  runApp(const TeaShopApp());
}

class TeaShopApp extends StatefulWidget {
  const TeaShopApp({super.key});

  @override
  State<TeaShopApp> createState() => _TeaShopAppState();
}

class _TeaShopAppState extends State<TeaShopApp> {
  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<NetworkInfo>(
          create: (context) => NetworkInfoImpl(
            connectivity: Connectivity(),
            internetConnectionChecker: InternetConnectionChecker.instance,
          ),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        locale: LanguageService.currentLocale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: LanguageService.supportedLocales,
        home: const SplashPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
