# 🐑 Sheepify Finance

**Sheepify** is a personal finance management application designed with three core principles: **Simple - Elegant - Premium**. It helps you track your daily cash flow in the most intuitive and effective way.

---

## ✨ Key Features

### 1. Transaction Management
- **Quick Logging**: Record income/expense transactions in seconds.
- **Image Attachments**: Capture receipts or relevant images for better record-keeping.
- **Square Capture UI**: A modern design focus on visual experience and consistency.
- **Detailed History**: Review transactions filtered by month and category.

### 2. Category System (Flat Architecture)
- **1-Level Structure**: Simplified management, removing complex parent/child hierarchies.
- **Budgeting**: Set spending limits for each category to maintain better financial control.
- **Rich Iconography**: Customize categories with a diverse set of icons.
- **Progress Tracking**: Real-time display of remaining budget relative to actual spending.

### 3. Reporting & Statistics
- **Visual Pie Charts**: Analyze spending ratios by category at a glance.
- **Accumulated Balance**: Calculate wallet balance based on historical totals or monthly snapshots.
- **Income/Expense Views**: Flexible toggles for deep analysis of different cash flows.

### 4. Premium Design
- **Sheep Design System**: Custom widget system (SheepCard, SheepButton, SheepListTile) ensures consistency and elegance.
- **Micro-animations**: Smooth transitions that make the user experience feel alive.
- **Glassmorphism**: Subtle blur effects and soft shadows for a modern aesthetic.

---

## 🛠 Tech Stack

- **Flutter**: Cross-platform development framework.
- **Hive**: High-performance NoSQL database for local-first (offline) storage.
- **LineIcons**: Minimalist and modern iconography.
- **Google Fonts (Outfit)**: Modern, highly readable typography.
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

*Made with ❤️ for smart financial management.*
