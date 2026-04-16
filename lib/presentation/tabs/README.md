# 📑 Presentation Tabs

This directory contains the main application screens (pages), organized as tabs within the `MainScreen`.

## 1. Diary Tab (`diary_tab.dart`)
- **Role**: Daily spending log.
- **Features**:
    - Displays transactions in chronological order.
    - **Goal Isolation**: Goal-related deposits are identified with a badge and excluded from balance/summary totals to ensure disposable income accuracy.
    - Allows direct deletion/editing of transactions.

## 2. Category Tab (`category_tab.dart`)
- **Role**: Budget and Goal management.
- **Features**:
    - Unified view for Expenses, Income, and **Goals**.
    - Rich progress bars for 3 goal types: Monthly, Short-term, and Long-term.
    - Intelligent dashboards in category details for planning financial milestones.

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
