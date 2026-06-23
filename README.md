# Sheepify Finance

**Sheepify** is a modern, local-first personal finance app for daily cash-flow tracking, category discipline, and lightweight visual journaling. It is designed to stay simple enough for daily use while integrating powerful **AI capabilities** to automate transaction entry.

---

## Key Features

### 1. AI-Powered Smart Entry ✨
- **Receipt & Invoice Scanning**: Snap a picture or choose from gallery. The app runs a local OCR to extract text, then securely leverages Google Gemini AI to parse the amount, date, and smartly auto-categorize it into your existing categories.
- **Voice Description**: Hold to talk or type a natural language prompt (e.g., "Mua trà sữa 50k ngày hôm qua"). The AI will parse the text and pre-fill the entire transaction form.
- **Smart Category Matching**: AI automatically matches the parsed category with the existing custom categories in your app.

### 2. Transaction Management
- **Quick Logging**: Record income and expense transactions in seconds.
- **Clean Amount Entry**: Amounts are entered and displayed as plain numbers with comma separators, without currency symbols.
- **Image Attachments & Viewer**: Attach receipts to your transactions. View images in full screen with pinch-to-zoom capabilities directly inside the app.
- **Detailed History**: Review transactions by date range in list and gallery views with independent content filters.
- **Readable Transaction Cards**: Transaction rows prioritize category, note, and amount with one-line ellipsis behavior for long notes.

### 3. Diary Views
- **List View**: Groups transactions by date with muted date headers so transaction details remain the focus.
- **Timeline View**: Calendar-style browsing with compact image stacks and subtle overflow badges for days with multiple attachments.

### 4. Category System
- **Flat Categories**: Simplified one-level category management, removing complex parent/child hierarchies.
- **Budgeting & Goals**: Set spending limits for expense categories or track periodic savings goals with rich iconography and colors.

### 5. Reporting & Statistics
- **Donut Chart Summary**: Analyze category ratios with category colors and center totals.
- **Income/Expense Views**: Toggle between expense and income analysis.
- **Category Drilldown**: Tap a category to open a bottom sheet with range-specific totals, transaction count, share of total, and one-line transaction rows.

### 6. Design & Personalization
- **Consistent Design Tokens**: Shared spacing, radius, and typography scales are documented in [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md).
- **Curated Palettes**: Eight app palettes and a reduced category-color set keep the interface expressive.
- **System Theme Support**: Appearance can follow light mode, dark mode, or the device setting.
- **Lottie Notification System**: High-quality animations for category milestones.

### 7. Privacy & Security
- **Offline-First Storage**: All transaction data is stored locally on your device using Hive. Your financial life never leaves your phone.
- **Environment Variables**: AI integration is securely implemented using environment variables (`--dart-define-from-file=.env`), ensuring API keys are never hardcoded in the source repository.
- **No Account Required**: Start tracking immediately. No email, no password, no tracking pixels.

---

## Tech Stack

- **Flutter**: Cross-platform development framework.
- **Hive**: High-performance NoSQL database for local-first storage.
- **Google ML Kit**: On-device Text Recognition (OCR) for fast, free, and secure text extraction.
- **Google Generative AI (Gemini)**: Smart parsing of OCR text and natural language.
- **fl_chart**: Donut chart visualizations for statistics.

---

## Getting Started

1. **Clone the project**
   ```bash
   git clone <repository_url>
   cd sheepify-finance
   ```

2. **Setup Environment Variables**
   Create a `.env` file in the root directory to store your Gemini API key:
   ```env
   GEMINI_API_KEY=your_gemini_api_key_here
   ```

3. **Install Dependencies**
   ```bash
   flutter pub get
   ```

4. **Generate Code (if needed)**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

5. **Run the App**
   Run the app with the environment configuration:
   ```bash
   flutter run --dart-define-from-file=.env
   ```

---

Made for intentional daily money tracking.
