# 🎨 Sheepify Design System (v2.0)

This document defines the core design principles and UI conventions for the Sheepify Finance re-design. All components and screens should strictly adhere to these guidelines to ensure a premium, consistent, and "smart" financial management experience.

---

## 🌈 Color Palette
We prioritize a clean, calm interface with high legibility, controlled personalization, and reduced eye strain.

| Token | Value | Description |
| :--- | :--- | :--- |
| **Background** | `#FBFBFB` | Main app background (Off-white). |
| **Surface/Card** | `#FFFFFF` | Card backgrounds, elevated surfaces. |
| **Primary Text** | `#000000` | Absolute Black for headings and main info. |
| **Secondary Text**| `#616161` | Dark Gray for supporting info. |
| **Income (Thu)** | `#20C997` | Professional Green. |
| **Expense (Chi)** | `#EE6055` | Professional Red. |

### Accent Usage
- App palettes provide a single primary accent used for active controls, drawer branding, and a subtle header tint.
- Category colors come from a curated, non-redundant set so nearby options remain visually distinct.
- Finance semantics stay stable: income remains green and expense remains red regardless of the selected app palette.

---

## 🔡 Typography
We support four clean UI fonts: **Inter**, **Be Vietnam Pro**, **Quicksand**, and **Montserrat**. The default UI rhythm uses the same type scale regardless of the selected font.

| Style | Font Weight | Size | Letter Spacing |
| :--- | :--- | :--- | :--- |
| **Headline** | Bold | 24px | 0 |
| **Title (Card)** | SemiBold | 18px | 0 |
| **Body Large** | Medium | 16px | 0.5 |
| **Body** | Medium | 14px | 0.5 |
| **Meta** | Medium | 12px | 0 |

---

## 📐 Spacing & Radius
The design system follows a **4px/8px grid** for consistency.

### Spacing
- **Page Padding**: `12px`.
- **Scale**: `4 / 8 / 12 / 16 / 24 / 32px`.
- **Inter-component (Small)**: `8px` (between elements within a section).
- **Inter-component (Large)**: `24px` (between major sections).

### Corner Radius
- **Small**: `10px`.
- **Control**: `12px`.
- **Item**: `14px`.
- **Card**: `16px`.
- **Sheet**: `24px`.

---

## 🖱️ Interactive Elements

### Buttons
- **Height**: `48px` (Standard) or `56px` (Large/Call to Action).
- **Colors**: Primary buttons use the selected interactive accent with contrast-aware foreground text.
- **Corner Radius**: 16px (to match cards) or fully rounded.

### Header Treatment
- The top app header may use a very light vertical tint derived from the active app palette.
- The tint should fade back into the page background before the first content section so it does not compete with the screen body.

---

## 🛠 Implementation Note
When implementing in Flutter:
1. Update `AppColors` in `lib/core/theme/app_colors.dart`.
2. Update `AppTheme` in `lib/core/theme/app_theme.dart`.
3. Use `Theme.of(context).textTheme` to ensure typography consistency.
