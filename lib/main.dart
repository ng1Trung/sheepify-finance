import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'data/models/transaction.dart';
import 'data/models/category_model.dart';
import 'data/models/settings_model.dart';
import 'core/constants/constants.dart';
import 'presentation/screens/main_screen.dart'; // Import màn hình chính

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);
  Intl.defaultLocale = 'vi_VN';
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
    await settingsBox.put('current', AppSettings(accumulateBalance: true));
  }

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      // Áp dụng Font Quicksand cho toàn bộ App
      theme: ThemeData(
        fontFamily: 'Quicksand',
        primarySwatch: Colors.teal,
        useMaterial3: true, // Dùng Material 3 cho hiện đại
        scaffoldBackgroundColor:
            Colors.grey[100], // Nền hơi xám nhẹ cho nổi bật Card
      ),
      home: const MainScreen(),
    ),
  );
}
