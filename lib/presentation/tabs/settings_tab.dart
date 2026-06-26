import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/constants.dart';
import '../../data/models/settings_model.dart';
import '../../core/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart' as cropper;
import '../../core/utils/avatar_image_store.dart';
import '../../core/utils/category_image_store.dart';
import '../../core/utils/l10n.dart';
import '../../data/models/category_model.dart';
import '../../data/models/transaction.dart';
import '../../data/services/data_portability_service.dart';
import '../../data/services/notification_service.dart';
import '../widgets/common/sheep_dialogs.dart';
import '../widgets/common/sheep_notifications.dart';
import '../widgets/common/sheep_toggles.dart';
import '../widgets/common/sheep_widgets.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    return ValueListenableBuilder(
      valueListenable: Hive.box<AppSettings>(kSettingsBox).listenable(),
      builder: (context, box, _) {
        final settings = box.get('current') ?? AppSettings();

        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              SheepSpacing.page,
              20,
              SheepSpacing.page,
              32,
            ),
            children: [
              SheepCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildCardSectionTitle(
                      context,
                      l10n.locale.languageCode == 'vi' ? 'Tài khoản' : 'Account',
                    ),
                    ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: settings.avatarImageRef != null
                            ? (() {
                                final file = AvatarImageStore.resolve(settings.avatarImageRef);
                                return file != null && file.existsSync() ? FileImage(file) : null;
                              })()
                            : null,
                        child: settings.avatarImageRef == null ||
                                (() {
                                  final file = AvatarImageStore.resolve(settings.avatarImageRef);
                                  return file == null || !file.existsSync();
                                })()
                            ? const Icon(Icons.person_rounded)
                            : null,
                      ),
                      title: Text(
                        l10n.locale.languageCode == 'vi' ? 'Ảnh đại diện' : 'Avatar',
                        style: _settingsRowTitleStyle(context),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                      ),
                      onTap: () => _showAvatarActions(context, settings),
                    ),
                    _buildDivider(),
                    ListTile(
                      title: Text(
                        l10n.locale.languageCode == 'vi' ? 'Tên hiển thị' : 'Display name',
                        style: _settingsRowTitleStyle(context),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            settings.userName ?? 'Jason',
                            style: SheepTextStyles.itemMeta(context),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ],
                      ),
                      onTap: () => _showEditNameSheet(context, settings),
                    ),
                    _buildDivider(),
                    ListTile(
                      title: Text(
                        l10n.locale.languageCode == 'vi' ? 'Hiển thị số dư khả dụng' : 'Show available balance',
                        style: _settingsRowTitleStyle(context),
                      ),
                      trailing: SheepSwitch(
                        value: settings.showAvailableBalance,
                        onChanged: (val) {
                          settings.showAvailableBalance = val;
                          settings.save();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SheepCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildCardSectionTitle(
                      context,
                      l10n.get('finance_section'),
                    ),
                    ListTile(
                      title: Text(
                        l10n.accumulateBalance,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        l10n.accumulateSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.labelSmall?.color,
                        ),
                      ),
                      trailing: SheepSwitch(
                        value: settings.accumulateBalance,
                        onChanged: (val) {
                          settings.accumulateBalance = val;
                          settings.save();
                        },
                      ),
                    ),
                    _buildDivider(),
                    _buildSettingsRow(
                      context,
                      title: l10n.get('financial_cycle_start'),
                      value: _financialCycleStartLabel(
                        settings.financialCycleStartDay,
                        l10n,
                      ),
                      onTap: () =>
                          _showFinancialCycleStartPicker(context, settings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SheepCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildCardSectionTitle(
                      context,
                      l10n.get('security_data_section'),
                    ),
                    ListTile(
                      title: Text(
                        l10n.get('hide_amounts_on_launch'),
                        style: _settingsRowTitleStyle(context),
                      ),
                      trailing: SheepSwitch(
                        value: settings.hideAmounts,
                        onChanged: (val) {
                          settings.hideAmounts = val;
                          settings.save();
                        },
                      ),
                    ),
                    _buildDivider(),
                    ListTile(
                      title: Text(
                        l10n.locale.languageCode == 'vi'
                            ? 'Nhận thông báo thiết bị'
                            : 'Receive device notifications',
                        style: _settingsRowTitleStyle(context),
                      ),
                      trailing: SheepSwitch(
                        value: settings.enableNotifications,
                        onChanged: (val) async {
                          settings.enableNotifications = val;
                          await settings.save();
                          if (val) {
                            await NotificationService.requestPermissions();
                            await NotificationService.checkDailyReminderReschedule();
                          } else {
                            await NotificationService.cancelAll();
                          }
                        },
                      ),
                    ),
                    _buildDivider(),
                    _buildSettingsActionRow(
                      context,
                      title: l10n.get('backup_data'),
                      subtitle:
                          '${l10n.get('backup_data_description')}\n'
                          '${_lastBackupLabel(settings, l10n)}',
                      onTap: () => _backupData(context, settings),
                    ),
                    _buildDivider(),
                    _buildSettingsActionRow(
                      context,
                      title: l10n.get('restore_backup'),
                      subtitle: l10n.get('restore_backup_description'),
                      onTap: () => _restoreBackup(context),
                    ),
                    _buildDivider(),
                    _buildSettingsActionRow(
                      context,
                      title: l10n.get('export_data'),
                      subtitle: l10n.get('export_data_description'),
                      onTap: () => _showExportFormatSheet(context),
                    ),
                    _buildDivider(),
                    ListTile(
                      title: Text(
                        l10n.get('delete_all_data'),
                        style: _settingsRowTitleStyle(
                          context,
                        ).copyWith(color: AppColors.expense),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.expense,
                      ),
                      onTap: () => _confirmDeleteAllData(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SheepCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildCardSectionTitle(context, l10n.get('app_section')),
                    _buildSettingsRow(
                      context,
                      title: l10n.language,
                      value: _languageLabel(settings.languageCode, l10n),
                      onTap: () => _showLanguagePicker(context, settings),
                    ),
                    _buildDivider(),
                    _buildSettingsRow(
                      context,
                      title: l10n.get('week_start_day'),
                      value: _weekdayLabel(settings.weekStartDay, l10n),
                      onTap: () => _showWeekStartPicker(context, settings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SheepCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildCardSectionTitle(
                      context,
                      l10n.get('customization_section'),
                    ),
                    _buildSettingsRow(
                      context,
                      title: l10n.get('mode'),
                      value: _themeModeLabel(settings.themeMode, l10n),
                      onTap: () => _showThemeModePicker(context, settings),
                    ),
                    _buildDivider(),
                    _buildSettingsRow(
                      context,
                      title: l10n.get('color'),
                      value: _paletteDisplayName(
                        settings.themePresetName,
                        l10n,
                      ),
                      onTap: () => _showPalettePicker(context, settings),
                    ),
                    _buildDivider(),
                    _buildSettingsRow(
                      context,
                      title: l10n.font,
                      value: settings.fontFamily,
                      onTap: () => _showFontPicker(context, settings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  'Sheepify v1.1.0',
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardSectionTitle(BuildContext context, String title) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.getSectionHeader(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(color: AppColors.getBorder(brightness)),
        ),
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.getTextSecondary(brightness),
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  TextStyle _settingsRowTitleStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: AppColors.getTextPrimary(Theme.of(context).brightness),
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );
  }

  String _paletteDisplayName(String paletteName, L10n l10n) {
    switch (paletteName) {
      case 'Midnight Black':
        return l10n.get('palette_black');
      case 'Sheep Green':
        return l10n.get('palette_green');
      case 'Rose Petal':
        return l10n.get('palette_pink');
      case 'Sunset Glow':
        return l10n.get('palette_orange');
      case 'Ruby Red':
        return l10n.get('palette_red');
      case 'Golden Hour':
        return l10n.get('palette_yellow');
      case 'Deep Ocean':
        return l10n.get('palette_blue');
      case 'Lavender Night':
        return l10n.get('palette_purple');
      default:
        return paletteName;
    }
  }

  String _languageLabel(String languageCode, L10n l10n) {
    return languageCode == 'en' ? l10n.get('english') : l10n.get('vietnamese');
  }

  String _themeModeLabel(String themeMode, L10n l10n) {
    switch (themeMode) {
      case 'light':
        return l10n.get('light');
      case 'dark':
        return l10n.get('dark');
      default:
        return l10n.get('system');
    }
  }

  String _financialCycleStartLabel(int day, L10n l10n) {
    return l10n.get('day_of_month', params: {'day': day.toString()});
  }

  String _lastBackupLabel(AppSettings settings, L10n l10n) {
    final lastBackupAt = settings.lastBackupAt;
    if (lastBackupAt == null) return l10n.get('last_backup_never');

    return l10n.get(
      'last_backup_at',
      params: {
        'time': DateFormat('dd/MM/yyyy HH:mm').format(lastBackupAt.toLocal()),
      },
    );
  }

  String _weekdayLabel(int weekday, L10n l10n) {
    switch (weekday) {
      case DateTime.tuesday:
        return l10n.get('weekday_tuesday');
      case DateTime.wednesday:
        return l10n.get('weekday_wednesday');
      case DateTime.thursday:
        return l10n.get('weekday_thursday');
      case DateTime.friday:
        return l10n.get('weekday_friday');
      case DateTime.saturday:
        return l10n.get('weekday_saturday');
      case DateTime.sunday:
        return l10n.get('weekday_sunday');
      default:
        return l10n.get('weekday_monday');
    }
  }

  Widget _buildFontItem(
    BuildContext context,
    String font,
    AppSettings settings, {
    bool closeOnTap = false,
  }) {
    final isSelected = settings.fontFamily == font;
    final theme = Theme.of(context);

    // Determine the text style for this specific font
    TextStyle fontStyle;
    switch (font) {
      case 'Inter':
        fontStyle = GoogleFonts.inter();
        break;
      case 'Montserrat':
        fontStyle = GoogleFonts.montserrat();
        break;
      case 'Be Vietnam Pro':
        fontStyle = GoogleFonts.beVietnamPro();
        break;
      case 'Quicksand':
        fontStyle = GoogleFonts.quicksand();
        break;
      default:
        fontStyle = GoogleFonts.inter();
        break;
    }

    return ListTile(
      title: Text(
        font,
        style: fontStyle.copyWith(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? theme.primaryColor
              : theme.textTheme.bodyLarge?.color,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: theme.primaryColor)
          : null,
      onTap: () {
        settings.fontFamily = font;
        settings.save();
        if (closeOnTap) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  Widget _buildDivider() {
    return Builder(
      builder: (context) => Divider(
        height: 1,
        color: AppColors.getBorder(Theme.of(context).brightness),
      ),
    );
  }

  Widget _buildSettingsRow(
    BuildContext context, {
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return ListTile(
      minVerticalPadding: 14,
      title: Text(title, style: _settingsRowTitleStyle(context)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: SheepTextStyles.itemMeta(context)),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildSettingsActionRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      minVerticalPadding: 14,
      title: Text(title, style: _settingsRowTitleStyle(context)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Theme.of(context).textTheme.labelSmall?.color,
          ),
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildColorSwatch(
    BuildContext context,
    ColorPalette palette,
    AppSettings settings, {
    bool closeOnTap = false,
  }) {
    final isSelected = settings.themePresetName == palette.name;
    final selectionBorder = AppColors.getOnAccent(
      Theme.of(context).brightness,
      palette.primary,
    );
    return GestureDetector(
      onTap: () {
        settings.themePresetName = palette.name;
        settings.save();
        if (closeOnTap) {
          Navigator.of(context).pop();
        }
      },
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: palette.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? selectionBorder : Colors.transparent,
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            _paletteDisplayName(palette.name, L10n.of(context)),
            maxLines: 1,
            textAlign: TextAlign.center,
            style: SheepTextStyles.itemMeta(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showThemeModePicker(
    BuildContext context,
    AppSettings settings,
  ) {
    return _showChoiceSheet(
      context,
      title: L10n.of(context).get('theme_mode'),
      items: [
        ('system', L10n.of(context).get('system')),
        ('light', L10n.of(context).get('light')),
        ('dark', L10n.of(context).get('dark')),
      ],
      selectedValue: settings.themeMode,
      onSelected: (value) {
        settings.themeMode = value;
        settings.isDarkMode = value == 'dark';
        settings.save();
      },
    );
  }

  Future<void> _showPalettePicker(BuildContext context, AppSettings settings) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SheepSpacing.page,
            18,
            SheepSpacing.page,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                L10n.of(context).get('color'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: AppColors.palettes
                    .map(
                      (palette) => _buildColorSwatch(
                        context,
                        palette,
                        settings,
                        closeOnTap: true,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguagePicker(BuildContext context, AppSettings settings) {
    return _showChoiceSheet(
      context,
      title: L10n.of(context).language,
      items: [
        ('vi', L10n.of(context).get('vietnamese')),
        ('en', L10n.of(context).get('english')),
      ],
      selectedValue: settings.languageCode,
      onSelected: (value) {
        settings.languageCode = value;
        settings.save();
      },
    );
  }

  Future<void> _showFinancialCycleStartPicker(
    BuildContext context,
    AppSettings settings,
  ) {
    final l10n = L10n.of(context);
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SheepSpacing.page,
            18,
            SheepSpacing.page,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.get('financial_cycle_start_title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.get('financial_cycle_start_subtitle'),
                textAlign: TextAlign.center,
                style: SheepTextStyles.itemMeta(context),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 360,
                child: ListView.builder(
                  itemCount: 31,
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final isSelected = settings.financialCycleStartDay == day;
                    return ListTile(
                      title: Text(
                        _financialCycleStartLabel(day, l10n),
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () {
                        settings.financialCycleStartDay = day;
                        settings.save();
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showWeekStartPicker(
    BuildContext context,
    AppSettings settings,
  ) {
    final l10n = L10n.of(context);
    final items = [
      for (final weekday in const [
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
        DateTime.sunday,
      ])
        (weekday.toString(), _weekdayLabel(weekday, l10n)),
    ];

    return _showChoiceSheet(
      context,
      title: l10n.get('week_start_day'),
      items: items,
      selectedValue: settings.weekStartDay.toString(),
      onSelected: (value) {
        settings.weekStartDay = int.tryParse(value) ?? DateTime.monday;
        settings.save();
      },
    );
  }

  Future<void> _showFontPicker(BuildContext context, AppSettings settings) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SheepSpacing.page,
            18,
            SheepSpacing.page,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                L10n.of(context).font,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...['Inter', 'Be Vietnam Pro', 'Quicksand', 'Montserrat'].map(
                (font) =>
                    _buildFontItem(context, font, settings, closeOnTap: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChoiceSheet(
    BuildContext context, {
    required String title,
    required List<(String, String)> items,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SheepSpacing.page,
            18,
            SheepSpacing.page,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...items.map(
                (item) => ListTile(
                  title: Text(item.$2),
                  trailing: item.$1 == selectedValue
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    onSelected(item.$1);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _backupData(BuildContext context, AppSettings settings) {
    return _shareGeneratedFile(
      context,
      createFile: DataBackupService().createBackupFile,
      subject: L10n.of(context).get('backup_share_subject'),
      successMessage: L10n.of(context).get('backup_created'),
      onFileCreated: () async {
        settings.lastBackupAt = DateTime.now();
        await settings.save();
      },
    );
  }

  Future<void> _showExportFormatSheet(BuildContext context) {
    final l10n = L10n.of(context);
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SheepSpacing.page,
            18,
            SheepSpacing.page,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.get('choose_export_format'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(l10n.get('export_csv_format')),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _exportCsv(context);
                },
              ),
              _buildDivider(),
              ListTile(
                title: Text(l10n.get('export_excel_format')),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _exportExcel(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) {
    return _shareGeneratedFile(
      context,
      createFile: DataExportService().exportCsvArchive,
      subject: L10n.of(context).get('csv_share_subject'),
      successMessage: L10n.of(context).get('csv_export_created'),
    );
  }

  Future<void> _exportExcel(BuildContext context) {
    return _shareGeneratedFile(
      context,
      createFile: DataExportService().exportExcelWorkbook,
      subject: L10n.of(context).get('excel_share_subject'),
      successMessage: L10n.of(context).get('excel_export_created'),
    );
  }

  Future<void> _shareGeneratedFile(
    BuildContext context, {
    required Future<File> Function() createFile,
    required String subject,
    required String successMessage,
    Future<void> Function()? onFileCreated,
  }) async {
    final l10n = L10n.of(context);
    try {
      final file = await createFile();
      await onFileCreated?.call();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: subject,
          text: l10n.get('data_share_text'),
        ),
      );
      if (context.mounted) {
        SheepNotifications.showSuccess(context, successMessage);
      }
    } catch (error) {
      if (context.mounted) {
        SheepNotifications.showError(
          context,
          '${l10n.get('error_prefix')}: $error',
        );
      }
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final l10n = L10n.of(context);
    try {
      final file = await _pickBackupFile();
      if (file == null || !context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => SheepConfirmDialog(
          title: l10n.get('restore_backup_title'),
          content: l10n.get('restore_backup_message'),
          confirmLabel: l10n.get('restore'),
          confirmColor: Theme.of(context).colorScheme.primary,
          icon: Icons.restore_rounded,
          onConfirm: () {},
        ),
      );
      if (confirmed != true || !context.mounted) return;

      final summary = await DataRestoreService().restoreBackupFile(file);
      if (context.mounted) {
        await _showRestoreSummary(context, summary);
      }
    } catch (error) {
      if (context.mounted) {
        SheepNotifications.showError(
          context,
          '${l10n.get('error_prefix')}: $error',
        );
      }
    }
  }

  Future<File?> _pickBackupFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sheepify-backup', 'zip'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    if (picked.path != null) return File(picked.path!);

    final bytes = picked.bytes;
    if (bytes == null) return null;

    final directory = await getTemporaryDirectory();
    final fileName = picked.name.isEmpty
        ? 'sheepify_restore.sheepify-backup'
        : picked.name;
    final file = File(path.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _showRestoreSummary(
    BuildContext context,
    RestoreSummary summary,
  ) {
    final l10n = L10n.of(context);
    final brightness = Theme.of(context).brightness;
    final accent = Theme.of(context).colorScheme.primary;

    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SheepRadius.sheet),
        ),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(SheepSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.getSurface(brightness),
            borderRadius: BorderRadius.circular(SheepRadius.sheet),
            boxShadow: AppColors.getSoftShadow(brightness),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: accent, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.get('restore_complete'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: SheepTypeScale.title,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(brightness),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.get(
                  'restore_summary',
                  params: {
                    'categoriesAdded': summary.categoriesAdded.toString(),
                    'categoriesSkipped': summary.categoriesSkipped.toString(),
                    'transactionsAdded': summary.transactionsAdded.toString(),
                    'transactionsSkipped': summary.transactionsSkipped
                        .toString(),
                    'imagesRestored': summary.imagesRestored.toString(),
                  },
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: SheepTypeScale.body,
                  color: AppColors.getTextSecondary(brightness),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: AppColors.getOnAccent(brightness, accent),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SheepRadius.lg),
                    ),
                  ),
                  child: Text(
                    l10n.get('done'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAllData(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => SheepConfirmDialog(
        title: L10n.of(context).get('delete_all_data_title'),
        content: L10n.of(context).get('delete_all_data_message'),
        confirmLabel: L10n.of(context).get('delete_all'),
        confirmColor: AppColors.expense,
        icon: Icons.delete_forever_rounded,
        onConfirm: () async {
          await Hive.box<Transaction>(kMoneyBox).clear();
          await Hive.box<CategoryModel>(kCatBox).clear();
          await CategoryImageStore.deleteAll();
          if (context.mounted) {
            SheepNotifications.showSuccess(
              context,
              L10n.of(context).get('all_data_deleted'),
            );
          }
        },
      ),
    );
  }

  Future<void> _showAvatarActions(
    BuildContext context,
    AppSettings settings,
  ) async {
    final avatarFile = AvatarImageStore.resolve(settings.avatarImageRef);
    final hasAvatar = avatarFile != null && avatarFile.existsSync();
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7DDE1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                _AvatarActionTile(
                  icon: Icons.account_circle_rounded,
                  label: 'Xem ảnh đại diện',
                  enabled: hasAvatar,
                  color: theme.primaryColor,
                  onTap: () =>
                      Navigator.pop(sheetContext, _AvatarAction.preview),
                ),
                _AvatarActionTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Đổi ảnh',
                  color: theme.primaryColor,
                  onTap: () =>
                      Navigator.pop(sheetContext, _AvatarAction.change),
                ),
                _AvatarActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Xoá ảnh',
                  enabled: hasAvatar,
                  color: AppColors.expense,
                  onTap: () =>
                      Navigator.pop(sheetContext, _AvatarAction.delete),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case _AvatarAction.preview:
        _previewAvatar(context, settings);
        break;
      case _AvatarAction.change:
        await _changeAvatar(context, settings);
        break;
      case _AvatarAction.delete:
        _confirmDeleteAvatar(context, settings);
        break;
    }
  }

  void _previewAvatar(BuildContext context, AppSettings settings) {
    final avatarFile = AvatarImageStore.resolve(settings.avatarImageRef);
    if (avatarFile == null || !avatarFile.existsSync()) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.file(avatarFile, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _changeAvatar(BuildContext context, AppSettings settings) async {
    final themeColor = Theme.of(context).primaryColor;
    final oldAvatarRef = settings.avatarImageRef;
    String? newAvatarRef;

    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final cropped = await cropper.ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const cropper.CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 512,
        maxHeight: 512,
        compressFormat: cropper.ImageCompressFormat.jpg,
        compressQuality: 80,
        uiSettings: [
          cropper.AndroidUiSettings(
            toolbarTitle: 'Đổi ảnh đại diện',
            toolbarColor: themeColor,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: themeColor,
            initAspectRatio: cropper.CropAspectRatioPreset.square,
            aspectRatioPresets: const [cropper.CropAspectRatioPreset.square],
            lockAspectRatio: true,
          ),
          cropper.IOSUiSettings(
            title: 'Đổi ảnh đại diện',
            doneButtonTitle: 'Lưu',
            cancelButtonTitle: 'Huỷ',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            aspectRatioPresets: const [cropper.CropAspectRatioPreset.square],
          ),
        ],
      );
      if (cropped == null) return;

      newAvatarRef = await AvatarImageStore.saveFromSourcePath(cropped.path);
      settings.avatarImageRef = newAvatarRef;
      await settings.save();
      await AvatarImageStore.deleteStoredRef(oldAvatarRef);
      if (!context.mounted) return;
      SheepNotifications.showSuccess(context, 'Đã cập nhật ảnh đại diện');
    } catch (_) {
      await AvatarImageStore.deleteStoredRef(newAvatarRef);
      if (!context.mounted) return;
      SheepNotifications.showError(context, 'Không thể cập nhật ảnh đại diện');
    }
  }

  void _confirmDeleteAvatar(BuildContext context, AppSettings settings) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => SheepConfirmDialog(
        title: 'Xoá ảnh đại diện?',
        content: 'Ảnh đại diện hiện tại sẽ bị xoá khỏi thiết bị.',
        confirmLabel: 'Xoá ảnh',
        confirmColor: AppColors.expense,
        icon: Icons.delete_outline_rounded,
        onConfirm: () => _deleteAvatar(context, settings),
      ),
    );
  }

  Future<void> _deleteAvatar(BuildContext context, AppSettings settings) async {
    final oldAvatarRef = settings.avatarImageRef;
    if (oldAvatarRef == null || oldAvatarRef.isEmpty) return;

    try {
      settings.avatarImageRef = null;
      await settings.save();
      await AvatarImageStore.deleteStoredRef(oldAvatarRef);
      if (!context.mounted) return;
      SheepNotifications.showSuccess(context, 'Đã xoá ảnh đại diện');
    } catch (_) {
      if (!context.mounted) return;
      SheepNotifications.showError(context, 'Không thể xoá ảnh đại diện');
    }
  }

  Future<void> _showEditNameSheet(BuildContext context, AppSettings settings) {
    final controller = TextEditingController(text: settings.userName ?? 'Jason');
    final l10n = L10n.of(context);
    final brightness = Theme.of(context).brightness;
    final primaryColor = Theme.of(context).primaryColor;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return GestureDetector(
          onTap: () => FocusScope.of(sheetContext).unfocus(),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getSurface(brightness),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(SheepRadius.sheet),
              ),
            ),
            padding: EdgeInsets.only(
              top: SheepSpacing.xl,
              left: SheepSpacing.page,
              right: SheepSpacing.page,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + SheepSpacing.xl,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.locale.languageCode == 'vi' ? 'Sửa tên hiển thị' : 'Edit display name',
                          style: TextStyle(
                            fontSize: SheepTypeScale.title,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(brightness),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(sheetContext),
                          color: AppColors.getTextSecondary(brightness),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: l10n.locale.languageCode == 'vi' ? 'Nhập tên của bạn' : 'Enter your name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SheepRadius.md),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SheepRadius.md),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                      autofocus: true,
                      maxLength: 20,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final newName = controller.text.trim();
                          if (newName.isNotEmpty) {
                            settings.userName = newName;
                            if (settings.box == null) {
                              await Hive.box<AppSettings>(kSettingsBox).put('current', settings);
                            } else {
                              await settings.save();
                            }
                            if (context.mounted) {
                              SheepNotifications.showSuccess(
                                context,
                                l10n.locale.languageCode == 'vi'
                                    ? 'Đã cập nhật tên hiển thị'
                                    : 'Display name updated successfully',
                              );
                            }
                          }
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SheepRadius.lg),
                          ),
                        ),
                        child: Text(
                          l10n.locale.languageCode == 'vi' ? 'Lưu thay đổi' : 'Save changes',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: SheepTypeScale.bodyLarge,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _AvatarAction { preview, change, delete }

class _AvatarActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _AvatarActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = enabled
        ? color
        : AppColors.getTextSecondary(theme.brightness).withValues(alpha: 0.38);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(icon, color: foreground, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
