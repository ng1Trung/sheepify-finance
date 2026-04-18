import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:line_icons/line_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/constants.dart';
import '../../data/models/settings_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/l10n.dart';
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // --- PROFILE ---
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.primaryColor.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: theme.primaryColor.withOpacity(0.1),
                        child: Icon(
                          LineIcons.user,
                          size: 40,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.userGreeting,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.userSub,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // --- GENERAL SETTINGS ---
              _buildSectionTitle(context, l10n.systemSettings),
              const SizedBox(height: 12),
              SheepCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(LineIcons.coins, color: theme.primaryColor),
                      title: Text(
                        l10n.accumulateBalance,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        l10n.accumulateSubtitle,
                        style: TextStyle(fontSize: 12, color: theme.textTheme.labelSmall?.color),
                      ),
                      value: settings.accumulateBalance,
                      activeColor: theme.primaryColor,
                      onChanged: (val) {
                        settings.accumulateBalance = val;
                        settings.save();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- THEME MODE ---
              _buildSectionTitle(context, l10n.theme),
              const SizedBox(height: 12),
              SheepCard(
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    _buildModeItem(
                      context, 
                      'Light', 
                      Icons.wb_sunny_rounded, 
                      !settings.isDarkMode, 
                      () {
                        settings.isDarkMode = false;
                        settings.save();
                      }
                    ),
                    _buildModeItem(
                      context, 
                      'Dark', 
                      Icons.nightlight_round, 
                      settings.isDarkMode, 
                      () {
                        settings.isDarkMode = true;
                        settings.save();
                      }
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- COLOR PALETTE ---
              _buildSectionTitle(context, l10n.get('colors')),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppColors.palettes.length,
                  itemBuilder: (context, index) {
                    final palette = AppColors.palettes[index];
                    final isSelected = settings.themePresetName == palette.name;
                    return GestureDetector(
                      onTap: () {
                        settings.themePresetName = palette.name;
                        settings.save();
                      },
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? palette.primary : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: AppColors.getSoftShadow(theme.brightness),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: palette.primary,
                                shape: BoxShape.circle,
                                border: isSelected ? Border.all(color: AppColors.getTextPrimary(theme.brightness).withOpacity(0.5), width: 2) : null,
                              ),
                              child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              palette.name.split(' ').last,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: AppColors.getTextPrimary(theme.brightness),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // --- LOCALIZATION & CURRENCY ---
              Row(
                children: [
                  Expanded(child: _buildSectionTitle(context, l10n.language)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSectionTitle(context, l10n.currency)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SheepCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: settings.languageCode,
                          isExpanded: true,
                          dropdownColor: theme.cardColor,
                          style: theme.textTheme.bodyMedium,
                          items: const [
                            DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                            DropdownMenuItem(value: 'en', child: Text('English')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              settings.languageCode = val;
                              settings.save();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SheepCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: settings.currencyCode,
                          isExpanded: true,
                          dropdownColor: theme.cardColor,
                          style: theme.textTheme.bodyMedium,
                          items: const [
                            DropdownMenuItem(value: 'VND', child: Text('VND (đ)')),
                            DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                            DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              settings.currencyCode = val;
                              settings.save();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- FONT SELECTOR ---
              _buildSectionTitle(context, l10n.font),
              const SizedBox(height: 12),
              SheepCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildFontItem(context, 'Quicksand', settings),
                    _buildFontItem(context, 'Inter', settings),
                    _buildFontItem(context, 'Montserrat', settings),
                    _buildFontItem(context, 'Roboto', settings),
                    _buildFontItem(context, 'Be Vietnam Pro', settings),
                    _buildFontItem(context, 'Comfortaa', settings),
                    _buildFontItem(context, 'Lexend', settings),
                    _buildFontItem(context, 'Bungee', settings),
                    _buildFontItem(context, 'Righteous', settings),
                    _buildFontItem(context, 'Pacifico', settings),
                    _buildFontItem(context, 'Special Elite', settings),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              Center(
                child: Text(
                  'Sheepify v1.1.0',
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildFontItem(BuildContext context, String font, AppSettings settings) {
    final isSelected = settings.fontFamily == font;
    final theme = Theme.of(context);
    
    // Determine the text style for this specific font
    TextStyle fontStyle;
    switch (font) {
      case 'Inter': fontStyle = GoogleFonts.inter(); break;
      case 'Montserrat': fontStyle = GoogleFonts.montserrat(); break;
      case 'Roboto': fontStyle = GoogleFonts.roboto(); break;
      case 'Be Vietnam Pro': fontStyle = GoogleFonts.beVietnamPro(); break;
      case 'Comfortaa': fontStyle = GoogleFonts.comfortaa(); break;
      case 'Lexend': fontStyle = GoogleFonts.lexend(); break;
      case 'Bungee': fontStyle = GoogleFonts.bungee(); break;
      case 'Righteous': fontStyle = GoogleFonts.righteous(); break;
      case 'Pacifico': fontStyle = GoogleFonts.pacifico(); break;
      case 'Special Elite': fontStyle = GoogleFonts.specialElite(); break;
      default: fontStyle = GoogleFonts.quicksand(); break;
    }

    return ListTile(
      title: Text(
        font, 
        style: fontStyle.copyWith(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? theme.primaryColor : theme.textTheme.bodyLarge?.color,
        )
      ),
      trailing: isSelected ? Icon(Icons.check, color: theme.primaryColor) : null,
      onTap: () {
        settings.fontFamily = font;
        settings.save();
      },
    );
  }

  Widget _buildModeItem(BuildContext context, String label, IconData icon, bool isActive, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isActive ? theme.primaryColor.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(
                icon, 
                color: isActive ? theme.primaryColor : Colors.grey,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? theme.primaryColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
