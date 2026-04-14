# 🧱 Presentation Widgets

This directory contains the Sheepify UI component system, built with a focus on high reusability.

## 1. Common Widgets (`common/`)
- `sheep_widgets.dart`: Contains the "atoms" of the app such as `SheepCard`, `SheepButton`, and `SheepListTile`. These widgets ensure consistency in shadows, border radii, and typography across the application.
- `sheep_toggles.dart`: A premium toggle/switch widget used for switching between Income and Expense modes.

## 2. Transaction Widgets (`transaction/`)
- `transaction_form.dart`: The primary transaction input screen.
- `transaction_image_area.dart`: Component managing images and amount input (Square UI).
- `transaction_category_picker.dart`: Intelligent category selection panel.

## 3. Category Widgets (`category/`)
- `category_form.dart`: Form for adding/editing categories.
- `transaction_history_sheet.dart`: Bottom sheet displaying history for a specific category.

## Design Principles (Atomic Design)
- Large widgets are composed of smaller "atomic" widgets found in the `common` directory.
- Avoid heavy data processing logic within widgets; prefer passing data down through constructors (Props).
