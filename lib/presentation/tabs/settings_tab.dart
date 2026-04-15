import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:line_icons/line_icons.dart';
import '../../core/constants/constants.dart';
import '../../data/models/settings_model.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/common/sheep_widgets.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<AppSettings>(kSettingsBox).listenable(),
      builder: (context, box, _) {
        final settings = box.get('current') ?? AppSettings();

        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // --- MINIMALIST PROFILE ---
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: const CircleAvatar(
                        radius: 45,
                        backgroundColor: AppColors.primaryLight,
                        child: Icon(
                          LineIcons.user,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Người dùng Sheepify',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quản lý tài chính đơn giản',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // --- SETTINGS SECTION ---
              Text(
                'CÀI ĐẶT HỆ THỐNG',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),

              SheepCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(
                        LineIcons.coins,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Cộng dồn số dư từ tháng trước',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: const Text(
                        'Số dư tháng này sẽ bao gồm cả số dư khả dụng từ các tháng trước đó.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      value: settings.accumulateBalance,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) {
                        settings.accumulateBalance = val;
                        settings.save();
                      },
                    ),
                    // Có thể thêm các settings khác ở đây trong tương lai
                  ],
                ),
              ),

              const SizedBox(height: 30),
              Center(
                child: Text(
                  'Sheepify v1.0.0',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontSize: 10),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }
}
