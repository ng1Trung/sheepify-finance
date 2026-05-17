# 💾 Data Layer

The data layer is responsible for persistence and state management.

## 1. Technology: Hive
- **Why Hive?**: Hive is an extremely fast NoSQL database that allows direct object storage without complex SQL. It is ideal for mobile apps requiring offline-first functionality.

## 2. Models (`models/`)
- `CategoryModel`: Stores category information (Name, Icon, Type, Budget). Includes **Goal-specific fields**: `goalTypeIndex`, `targetAmount`, `targetDate`, `targetMonth`, `targetYear`, and `reminderDay`.
- `Transaction`: Stores financial records (Amount, Note, Date, Category ID, Image reference). Goal-deposits are recorded as income transactions linked to Goal categories.
- `AppSettings`: Stores user preferences, including palette, font, privacy display, and theme mode.

## 3. Transaction Images
- `TransactionImageStore` copies both camera captures and gallery imports into app-managed document storage.
- New transactions store relative image references such as `transaction_images/...` so they are portable for future sync work.
- Legacy absolute paths are migrated when the old file still exists; if the source file was already deleted before migration, the binary cannot be recovered from the stored path alone.

## 4. ID Management
- String-based IDs (typically timestamps or unique identifiers) are used to link Transactions to their respective Categories (`categoryId`).

## 5. Migration Notes
- When modifying the Model class structure, run:
  `dart run build_runner build --delete-conflicting-outputs`
- If changing the data type of existing fields (e.g., String to double), increment the Box name version (e.g., `kMoneyBox`, `kCatBox`) in `core/constants/constants.dart` to prevent data corruption.
