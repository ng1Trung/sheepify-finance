# 🎨 Sheepify Design System (v2.0)

This document defines the core design principles and UI conventions for the Sheepify Finance re-design. All components and screens should strictly adhere to these guidelines to ensure a premium, consistent, and "smart" financial management experience.

---

## 🌈 Color Palette
We prioritize a clean, professional look with high legibility and reduced eye strain.

| Token | Value | Description |
| :--- | :--- | :--- |
| **Background** | `#FBFBFB` | Main app background (Off-white). |
| **Surface/Card** | `#FFFFFF` | Card backgrounds, elevated surfaces. |
| **Primary Text** | `#000000` | Absolute Black for headings and main info. |
| **Secondary Text**| `#616161` | Dark Gray for supporting info. |
| **Income (Thu)** | `#20C997` | Professional Green. |
| **Expense (Chi)** | `#EE6055` | Professional Red. |

---

## 🔡 Typography
We use **Quicksand** as our primary font for its rounded, friendly yet professional character.

| Style | Font Weight | Size | Letter Spacing |
| :--- | :--- | :--- | :--- |
| **Headline** | Bold | 24px | 0 |
| **Title (Card)** | SemiBold | 18px | 0 |
| **Body** | Medium | 14px | 0.5 |

---

## 📐 Spacing & Radius
The design system follows a **4px/8px grid** for consistency.

### Spacing
- **Page Padding**: `16px` or `24px`.
- **Inter-component (Small)**: `8px` (between elements within a section).
- **Inter-component (Large)**: `24px` (between major sections).

### Corner Radius
- **Card Border Radius**: `16px` (Modern, rounded aesthetic).

---

## 🖱️ Interactive Elements

### Buttons
- **Height**: `48px` (Standard) or `56px` (Large/Call to Action).
- **Colors**: Primary buttons use **Absolute Black (`#000000`)** with white text.
- **Corner Radius**: 16px (to match cards) or fully rounded.

---

## 🛠 Implementation Note
When implementing in Flutter:
1. Update `AppColors` in `lib/core/theme/app_colors.dart`.
2. Update `AppTheme` in `lib/core/theme/app_theme.dart`.
3. Use `Theme.of(context).textTheme` to ensure typography consistency.
