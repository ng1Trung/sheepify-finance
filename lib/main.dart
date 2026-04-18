import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'data/models/transaction.dart';
import 'data/models/category_model.dart';
import 'data/models/settings_model.dart';
import 'core/constants/constants.dart';
import 'presentation/screens/main_screen.dart'; // Import màn hình chính

import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/utils/l10n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  // Register Adapters
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TransactionAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CategoryModelAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(AppSettingsAdapter());

  // Open Boxes
  await Hive.openBox<Transaction>(kMoneyBox);
  await Hive.openBox<CategoryModel>(kCatBox);
  final settingsBox = await Hive.openBox<AppSettings>(kSettingsBox);

  // Initialize Default Settings if empty
  if (settingsBox.isEmpty) {
    await settingsBox.put('current', AppSettings());
  }

  runApp(const SheepifyApp());
}

class SheepifyApp extends StatelessWidget {
  const SheepifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<AppSettings>(kSettingsBox).listenable(),
      builder: (context, box, _) {
        final settings = box.get('current') ?? AppSettings();
        
        // Resolve Theme
        final preset = AppColors.getPreset(settings.themePresetName);
        final theme = AppTheme.getTheme(preset, settings.fontFamily);
        
        // Resolve Locale
        final locale = Locale(settings.languageCode);

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Sheepify',
          theme: theme,
          locale: locale,
          localizationsDelegates: const [
            L10nDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
            Locale('vi', ''),
          ],
          home: const MainScreen(),
        );
      },
    );
  }
}
