# Sheepify Finance

**Sheepify** is a local-first personal finance app for daily cash-flow tracking, category discipline, and lightweight visual journaling. It is designed to stay simple enough for daily use while still feeling expressive for younger users.

---

## Key Features

### 1. Transaction Management
- **Quick Logging**: Record income and expense transactions in seconds.
- **Clean Amount Entry**: Amounts are entered and displayed as plain numbers with comma separators, without currency symbols.
- **Image Attachments**: Capture or import receipt images; Sheepify copies them into app storage so old transactions remain viewable after restarts and source-file deletion.
- **Detailed History**: Review transactions by date range in list and gallery views with independent content filters.
- **Readable Transaction Cards**: Transaction rows prioritize category, note, and amount with one-line ellipsis behavior for long notes. Displays as a compact, vertically centered single line when no note is present.

### 2. Diary Views
- **List View**: Groups transactions by date with muted date headers so transaction details remain the focus.
- **Timeline View**: Calendar-style browsing with compact image stacks and subtle overflow badges for days with multiple attachments.
- **Independent Filters**: Content filters can be changed without affecting the selected date range summary.

### 3. Category System
- **Flat Categories**: Simplified one-level category management, removing complex parent/child hierarchies.
- **Budgeting**: Set spending limits for expense categories to maintain better financial control.
- **Rich Iconography**: Customize categories with a diverse set of icons and colors.
- **Savings Goals**: Track periodic savings and target-based accumulation goals.

### 4. Reporting & Statistics
- **Donut Chart Summary**: Analyze category ratios with category colors and center totals.
- **Income/Expense Views**: Toggle between expense and income analysis.
- **Top Category List**: Shows the top five categories by amount by default, with an expandable "+x categories" control for the rest.
- **Accurate Percent Labels**: Category percentages are allocated so displayed category shares add up cleanly to 100%.
- **Category Drilldown**: Tap a category to open a bottom sheet with range-specific totals, transaction count, share of total, and one-line transaction rows.

### 5. Design & Personalization
- **Consistent Design Tokens**: Shared spacing, radius, and typography scales are documented in [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md).
- **Curated Palettes**: Eight app palettes and a reduced category-color set keep the interface expressive without duplicate-looking colors.
- **System Theme Support**: Appearance can follow light mode, dark mode, or the device setting.
- **Refined Aesthetics**: Soft surfaces, restrained shadows, subtle palette-aware header treatments, and disciplined cards keep the app focused.
- **Lottie Notification System**: High-quality animations for category milestones.

### 6. Privacy & Security
- **Offline-First**: All data is stored locally on your device using Hive. Your financial life never leaves your phone.
- **No Account Required**: Start tracking immediately. No email, no password, no tracking pixels.
- **Data Ownership**: You have full control over your data. Future-proof and private by design.

---

## Recent UI/UX Improvements

- **Today Default for FAB**: Opening the transaction creation form defaults to today's date instead of the cycle start date.
- **Pressable Submit Button**: Primary action button features a double ring (outer ring + solid inner button) for a tactile, pressable feel, with an increased gap to the photo attachment button.
- **Form Submission Guard**: The submit button remains disabled until a valid amount (>0) and a category are selected.
- **Left-Aligned Category Picker**: Items align left-to-right with ellipsis truncation and clean spacing.
- **Photo Deletion Safety**: Added confirmation dialogs when deleting photo attachments to avoid accidental loss.
- **Unified Pill Aesthetics**: Synchronized Category Pill design with the Date Pill, showing centered placeholder text when no category is selected.
- **Premium Donut Chart Styling**: Redesigned the donut chart to feature smooth rounded corners (`cornerRadius`), card-colored borders for floating segment separation, and short leader lines. Labels are dynamically aligned to prevent text clipping, and the chart center displays interactive transaction counts and selected category details.
- **Optimized Vertical Spacing**: Balanced the chart margins and top padding to fit the chart, 5 categories, and the "+x other categories" button perfectly on a single screen page.

---

## Tech Stack

- **Flutter**: Cross-platform development framework.
- **Hive**: High-performance NoSQL database for local-first storage.
- **fl_chart**: Donut chart visualizations for statistics.
- **LineIcons**: Minimalist iconography.
- **Google Fonts**: Inter, Be Vietnam Pro, Quicksand, and Montserrat.
- **Intl**: Number formatting and localized date labels.

---

## Project Structure

The project is organized into small, maintainable components:

- `lib/core`: Constants, theme, and common utilities.
- `lib/data/models`: Hive-backed data models.
- `lib/presentation/tabs`: Main application screens for Diary, Category, Stats, and Settings.
- `lib/presentation/widgets`: Reusable widgets and modular sub-components.

---

## Getting Started

1. Clone the project.
2. Run `flutter pub get`.
3. If model adapters change, run `dart run build_runner build --delete-conflicting-outputs`.
4. Launch the app with `flutter run`.

---

Made for intentional daily money tracking.
