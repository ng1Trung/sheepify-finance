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
                      title: l10n.currency,
                      value: _currencyLabel(settings.currencyCode),
                      onTap: () => _showCurrencyPicker(context, settings),
                    ),
                    _buildDivider(),
                    _buildSettingsRow(
                      context,
                      title: l10n.language,
                      value: _languageLabel(settings.languageCode, l10n),
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
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
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

  Future<void> _showCurrencyPicker(BuildContext context, AppSettings settings) {
    return _showChoiceSheet(
      context,
      title: L10n.of(context).currency,
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
        title: L10n.of(context).get('delete_all_data_title'),
        content: L10n.of(context).get('delete_all_data_message'),
        confirmLabel: L10n.of(context).get('delete_all'),
        confirmColor: AppColors.expense,
        icon: Icons.delete_forever_rounded,
        onConfirm: () async {
          await Hive.box<Transaction>(kMoneyBox).clear();
          await Hive.box<CategoryModel>(kCatBox).clear();
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
}
