# 💸 Transaction Module

This module handles the core visual experience of creating and editing financial records in Sheepify.

## 🏗 Key Components

### 1. `TransactionForm`
The main entry point for transaction creation. It manages:
- **State Synchronization**: Updates amounts, notes, and categories in real-time.
- **Date/Time Picking**: Interactive pill to select specific transaction timestamps.
- **Data Persistence**: Integration with Hive DB for local storage.

### 2. `TransactionImageArea` (Refactored)
The primary visual block of the form, designed for maximum aesthetic impact:
- **Dynamic Gradients**: Background colors transition between **Vivid Red** (Expense), **Teal Green** (Income), and **Platinum Grey** (Neutral/Unassigned).
- **Glassmorphic Action Block**: A unified translucent container for Amount and Note inputs at the bottom.
- **Smart Amount Logic**: 
  - Fades out '0' and signs when the value is zero.
  - Automatically replaces the '0' hint upon user typing.
  - Currency unit ('đ') is aligned to the text baseline for professional typography.
- **Adaptive Sizing**: Aspect ratio optimized (0.82) to balance image/icon visibility and input accessibility.

### 3. `TransactionCategoryPicker`
A bottom-sheet based selector featuring:
- **Type Toggle**: Filter categories by Income or Expense directly while browsing.
- **Real-time Updates**: Listens to Hive `categoryBox` for instant UI updates when categories are added or modified.

## 🎨 Design Principles
- **Minimalism**: Borders and heavy outlines are removed in favor of depth and translucent layers.
- **Context-Aware**: The UI only reveals Income/Expense toggles after a category is chosen.
- **Typography First**: Large, bold amounts using the `Outfit` font for clear readability.

---
*Sheepify Transaction UI - Refined for elegance.*
