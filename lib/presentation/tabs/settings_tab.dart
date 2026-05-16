import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/constants.dart';
import '../../data/models/settings_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/l10n.dart';
import '../../data/models/category_model.dart';
import '../../data/models/transaction.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              SheepCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildCardSectionTitle(context, 'TÀI CHÍNH'),
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
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SheepCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildCardSectionTitle(context, 'BẢO MẬT & DỮ LIỆU'),
                    ListTile(
                      title: Text(
                        'Ẩn tất cả số tiền khi mở app',
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
                        'Xoá toàn bộ dữ liệu',
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
                    _buildCardSectionTitle(context, 'ỨNG DỤNG'),
                    _buildSettingsRow(
                      context,
                      title: l10n.currency,
                      value: _currencyLabel(settings.currencyCode),
                      onTap: () => _showCurrencyPicker(context, settings),
                    ),
                    _buildDivider(),
                    _buildSettingsRow(
                      context,
                      title: l10n.language,
                      value: _languageLabel(settings.languageCode),
                      onTap: () => _showLanguagePicker(context, settings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SheepCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildCardSectionTitle(context, 'TUỲ CHỈNH'),
                    _buildSettingsRow(
                      context,
                      title: 'Chế độ',
                      value: settings.isDarkMode ? 'Tối' : 'Sáng',
                      onTap: () => _showThemeModePicker(context, settings),
                    ),
                    _buildDivider(),
                    _buildSettingsRow(
                      context,
                      title: 'Màu',
                      value: _paletteDisplayName(settings.themePresetName),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: Color(0xFFEAEAEA))),
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.black87,
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

  String _paletteDisplayName(String paletteName) {
    switch (paletteName) {
      case 'Midnight Black':
        return 'Đen';
      case 'Sheep Green':
        return 'Xanh lá';
      case 'Rose Petal':
        return 'Hồng';
      case 'Sunset Glow':
        return 'Cam';
      case 'Ruby Red':
        return 'Đỏ';
      case 'Golden Hour':
        return 'Vàng';
      case 'Deep Ocean':
        return 'Xanh biển';
      case 'Lavender Night':
        return 'Tím';
      default:
        return paletteName;
    }
  }

  String _currencyLabel(String currencyCode) {
    switch (currencyCode) {
      case 'USD':
        return 'USD (\$)';
      case 'EUR':
        return 'EUR (€)';
      default:
        return 'VND (đ)';
    }
  }

  String _languageLabel(String languageCode) {
    return languageCode == 'en' ? 'Tiếng Anh' : 'Tiếng Việt';
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
      case 'Roboto':
        fontStyle = GoogleFonts.roboto();
        break;
      case 'Be Vietnam Pro':
        fontStyle = GoogleFonts.beVietnamPro();
        break;
      case 'Comfortaa':
        fontStyle = GoogleFonts.comfortaa();
        break;
      case 'Lexend':
        fontStyle = GoogleFonts.lexend();
        break;
      case 'Bungee':
        fontStyle = GoogleFonts.bungee();
        break;
      case 'Righteous':
        fontStyle = GoogleFonts.righteous();
        break;
      case 'Pacifico':
        fontStyle = GoogleFonts.pacifico();
        break;
      case 'Special Elite':
        fontStyle = GoogleFonts.specialElite();
        break;
      default:
        fontStyle = GoogleFonts.quicksand();
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
    return const Divider(height: 1, color: Color(0xFFEAEAEA));
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

  Widget _buildColorSwatch(
    BuildContext context,
    ColorPalette palette,
    AppSettings settings, {
    bool closeOnTap = false,
  }) {
    final isSelected = settings.themePresetName == palette.name;
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
                color: isSelected ? Colors.black : Colors.transparent,
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            _paletteDisplayName(palette.name),
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
      title: 'Chế độ giao diện',
      items: const [('light', 'Sáng'), ('dark', 'Tối')],
      selectedValue: settings.isDarkMode ? 'dark' : 'light',
      onSelected: (value) {
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
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Màu', style: Theme.of(context).textTheme.titleLarge),
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

  Future<void> _showCurrencyPicker(BuildContext context, AppSettings settings) {
    return _showChoiceSheet(
      context,
      title: 'Tiền tệ',
      items: const [
        ('VND', 'VND (đ)'),
        ('USD', 'USD (\$)'),
        ('EUR', 'EUR (€)'),
      ],
      selectedValue: settings.currencyCode,
      onSelected: (value) {
        settings.currencyCode = value;
        settings.save();
      },
    );
  }

  Future<void> _showLanguagePicker(BuildContext context, AppSettings settings) {
    return _showChoiceSheet(
      context,
      title: 'Ngôn ngữ',
      items: const [('vi', 'Tiếng Việt'), ('en', 'Tiếng Anh')],
      selectedValue: settings.languageCode,
      onSelected: (value) {
        settings.languageCode = value;
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
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Phông chữ', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...[
                'Quicksand',
                'Inter',
                'Montserrat',
                'Roboto',
                'Be Vietnam Pro',
                'Comfortaa',
                'Lexend',
                'Bungee',
                'Righteous',
                'Pacifico',
                'Special Elite',
              ].map(
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
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
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

  Future<void> _confirmDeleteAllData(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => SheepConfirmDialog(
        title: 'Xoá toàn bộ dữ liệu?',
        content:
            'Toàn bộ giao dịch và danh mục sẽ bị xoá vĩnh viễn. Hành động này không thể hoàn tác.',
        confirmLabel: 'Xoá tất cả',
        confirmColor: AppColors.expense,
        icon: Icons.delete_forever_rounded,
        onConfirm: () async {
          await Hive.box<Transaction>(kMoneyBox).clear();
          await Hive.box<CategoryModel>(kCatBox).clear();
          if (context.mounted) {
            SheepNotifications.showSuccess(context, 'Đã xoá toàn bộ dữ liệu');
          }
        },
      ),
    );
  }
}
