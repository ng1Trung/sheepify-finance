# 🏷 Category Module

The Category module implements a simplified flat architecture for financial classification.

## 🏗 Key Components

### 1. `CategoryForm`
Handles the creation and editing of categories.
- **Icon Selector**: Choose from a curated set of LineIcons.
- **Budgeting**: Allows setting a monthly spending limit per category.
- **Type Toggle**: Define if a category is for Expense or Income.

### 2. `CategoryList`
Display components for the Category Tab:
- **Progress Tracking**: Visual indicators show how much budget remains.
- **Interactive Tiles**: Swipe or tap to edit/view details.

## 📂 Data Model: `CategoryModel`
Stored in Hive using the `kCatBox` key.
- `id`: Unique identifier.
- `name`: Human-readable name.
- `iconCode`: Unicode for the selected icon.
- `isExpense`: Boolean flag for classification.
- `budget`: Optional monthly limit.

## 📐 Architecture
- **Flat Structure**: Sheepify avoids sub-categories to keep the experience fast and focused.
- **Real-time**: Leverages `ValueListenableBuilder` to ensure any change to a category reflects immediately across the app (Diary, Picker, Stats).

---
*Sheepify Category System - Simple yet Powerful.*
