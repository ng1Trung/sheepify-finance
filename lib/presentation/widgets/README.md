# 🧱 Presentation Widgets

This directory contains the Sheepify UI component system, built with a focus on high reusability.

## 1. Common Widgets (`common/`)
- `sheep_widgets.dart`: Contains the "atoms" of the app such as `SheepCard`, `SheepButton`, and **Upgraded `SheepListTile`** (which now supports Widget-based subtitles for badges).
- `sheep_toggles.dart`: Premium toggles including `SheepTypeToggle` and **`SheepTripleToggle`** (used for switching between Expense, Income, and Goal modes).

## 2. Transaction Widgets (`transaction/`)
- `transaction_form.dart`: Primary transaction input screen.
- `transaction_image_area.dart`: Component managing images and amount input.
- `transaction_category_picker.dart`: Upgraded to 3-tier selection to support **Goal** selection.

## 3. Category Widgets (`category/`)
- `category_form.dart`: Advanced form supporting **3 goal strategies** with a SMART day picker.
- `transaction_history_sheet.dart`: Displays all-time history and intelligent planning dashboards for goals.

## Design Principles (Atomic Design)
- Large widgets are composed of smaller "atomic" widgets found in the `common` directory.
- Avoid heavy data processing logic within widgets; prefer passing data down through constructors (Props).
