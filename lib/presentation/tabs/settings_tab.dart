import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:line_icons/line_icons.dart';
import '../../core/constants/constants.dart';
import '../../data/models/settings_model.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<AppSettings>(kSettingsBox).listenable(),
      builder: (context, box, _) {
        final settings = box.get('current') ?? AppSettings();

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // --- PHẦN PROFILE GIẢ LẬP ---
              Center(
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.teal,
                      child: Icon(
                        LineIcons.user,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Người dùng Sheepify',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // --- NHÓM CÀI ĐẶT TÀI CHÍNH ---
              const Text(
                'CÀI ĐẶT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(
                        LineIcons.coins,
                        color: Colors.teal,
                      ),
                      title: const Text(
                        'Cộng dồn số dư từ tháng trước',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: const Text(
                        'Số dư tháng này sẽ bao gồm cả số tiền còn lại của các tháng trước.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: settings.accumulateBalance,
                      activeColor: Colors.teal,
                      onChanged: (val) {
                        settings.accumulateBalance = val;
                        settings.save();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
