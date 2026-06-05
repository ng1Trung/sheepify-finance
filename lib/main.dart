import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
import 'core/utils/transaction_image_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);
  await Hive.initFlutter();
  await TransactionImageStore.initialize();

  // Register Adapters
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TransactionAdapter());
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(CategoryModelAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(AppSettingsAdapter());

  // Open Boxes
  final moneyBox = await Hive.openBox<Transaction>(kMoneyBox);
  await Hive.openBox<CategoryModel>(kCatBox);
  final settingsBox = await Hive.openBox<AppSettings>(kSettingsBox);

  // Initialize Default Settings if empty
  if (settingsBox.isEmpty) {
    await settingsBox.put('current', AppSettings());
  }

  await _migrateLegacyTransactionImages(moneyBox);

  runApp(const SheepifyApp());
}

Future<void> _migrateLegacyTransactionImages(Box<Transaction> moneyBox) async {
  for (final tx in moneyBox.values) {
    final migratedRef = await TransactionImageStore.migrateLegacyRef(
      tx.imagePath,
    );
    if (migratedRef != tx.imagePath) {
      tx.imagePath = migratedRef;
      await tx.save();
    }
  }
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
        final palette = AppColors.getPalette(settings.themePresetName);
        final lightTheme = AppTheme.getTheme(
          palette,
          false,
          settings.fontFamily,
        );
        final darkTheme = AppTheme.getTheme(palette, true, settings.fontFamily);

        // Resolve Locale
        final locale = Locale(settings.languageCode);

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Sheepify',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: _resolveThemeMode(settings.themeMode),
          locale: locale,
          localizationsDelegates: const [
            L10nDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', ''), Locale('vi', '')],
          builder: (context, child) => GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child,
          ),
          home: const MainScreen(),
        );
      },
    );
  }
}

ThemeMode _resolveThemeMode(String mode) {
  switch (mode) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}
