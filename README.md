# 🐑 Sheepify Finance

**Sheepify** is a local-first personal finance app for daily cash-flow tracking, category discipline, and lightweight visual journaling. It is designed to stay simple enough for daily use while still feeling expressive for younger users.

---

## ✨ Key Features

### 1. Transaction Management
- **Quick Logging**: Record income/expense transactions in seconds.
- **Image Attachments**: Capture or import receipt images; Sheepify copies them into app storage so old transactions remain viewable after restarts and source-file deletion.
- **Square Capture UI**: A modern design focus on visual experience and consistency.
- **Detailed History**: Review transactions by date range in list and gallery views with independent content filters.

### 2. Category System (Flat Architecture)
- **1-Level Structure**: Simplified management, removing complex parent/child hierarchies.
- **Budgeting**: Set spending limits for each category to maintain better financial control.
- **Rich Iconography**: Customize categories with a diverse set of icons.
- **Progress Tracking**: Real-time display of remaining budget relative to actual spending.

### 3. Reporting & Statistics
- **Visual Pie Charts**: Analyze category ratios using each category's current saved color.
- **Range Summary**: Track income, expense, and balance by selected date range; content filters do not change the overview totals.
- **Income/Expense Views**: Flexible toggles for deep analysis of different cash flows.

### 4. Advanced Accumulation System (Hệ thống Tích lũy)
- **Simplified Dual Modes**: Supports **Periodic** (depositing monthly on a specific day) and **Goal** (targeting a specific Month/Year milestone).
- **Intelligent Dashboard**: Real-time duration calculation (e.g., "This goal lasts for 360 months") and automated required contribution tracking.
- **Modern Input Experience**: Replaced clunky list pickers with a compact, Apple-inspired **Wheel Picker** for Month, Year, and Day selection within a smooth bottom sheet.
- **Extended Planning**: Support for long-term goals up to the year 2100.

### 5. Design & Personalization
- **Consistent Design Tokens**: Shared spacing, radius, and typography scales are documented in [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md).
- **Curated Palettes**: Eight app palettes and a reduced category-color set keep the interface expressive without duplicate-looking colors.
- **System Theme Support**: Appearance can follow light mode, dark mode, or the device setting.
- **Refined Aesthetics**: Soft surfaces, restrained shadows, subtle palette-aware header treatments, and 16px cards keep the app disciplined without feeling sterile.
- **Lottie Notification System**: High-quality animations for category milestones.
- **Smooth Transitions**: Horizontal PageView-based navigation for Category tabs.

### 6. Privacy & Security
- **Offline-First**: All data is stored locally on your device using Hive. Your financial life never leaves your phone.
- **No Account Required**: Start tracking immediately. No email, no password, no tracking pixels.
- **Data Ownership**: You have full control over your data. Future-proof and private by design.

---

## 🛠 Tech Stack

- **Flutter**: Cross-platform development framework.
- **Hive**: High-performance NoSQL database for local-first (offline) storage.
- **LineIcons**: Minimalist and modern iconography.
- **Google Fonts**: Inter, Be Vietnam Pro, Quicksand, and Montserrat.
- **Intl**: Native support for currency formatting and date symbols (vi_VN).

---

## 📂 Project Structure (Atomic Design)

The project is organized into small, maintainable components:
- `lib/core`: Contains constants, theme, and common utilities.
- `lib/data/models`: Defines data structures (Hive Models).
- `lib/presentation/tabs`: Main application screens (Diary, Category, Stats, Settings).
- `lib/presentation/widgets`: Reusable widgets and modular sub-components.

---

## 🚀 Getting Started

1. Clone the project.
2. Run `flutter pub get`.
3. (If model changes) Run `dart run build_runner build --delete-conflicting-outputs`.
4. Launch the app: `flutter run`.

---

*Made for intentional daily money tracking.*
