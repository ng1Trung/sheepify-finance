import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/transaction.dart';
import 'models/category_model.dart';
import 'constants.dart';
import 'main_screen.dart'; // Import màn hình chính

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);
  Intl.defaultLocale = 'vi_VN';
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TransactionAdapter());
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(CategoryModelAdapter());
  }

  await Hive.openBox<Transaction>(kMoneyBox);
  await Hive.openBox<CategoryModel>(kCatBox);

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
