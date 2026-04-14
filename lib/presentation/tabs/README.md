# 📑 Presentation Tabs

This directory contains the main application screens (pages), organized as tabs within the `MainScreen`.

## 1. Diary Tab (`diary_tab.dart`)
- **Role**: Daily spending log.
- **Features**:
    - Displays transactions chronological order.
    - Groups transactions by date.
    - Allows direct deletion/editing of transactions.

## 2. Category Tab (`category_tab.dart`)
- **Role**: Category and budget management.
- **Features**:
    - Flat (1-level) view for both Income and Expenses.
    - Displays remaining budget based on actual monthly transaction data.
    - View detailed transaction history for specific categories via Bottom Sheets.

## 3. Stats Tab (`stats_tab.dart`)
- **Role**: Financial data analysis.
- **Features**:
    - Pie charts representing spending distribution.
    - Wallet balance calculations (Accumulated or monthly).
    - Ranked category list from highest to lowest spending.

## 4. Settings Tab (`settings_tab.dart`)
- **Role**: Application configuration.
- **Features**:
    - Manage display preferences (e.g., Accumulated Balance mode).
    - Version information and support details.
