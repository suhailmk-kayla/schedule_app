# schedule_frontend_flutter

An app that manages the warehouse inside a car accessories store with multiple roles

//////////////////////////////////////////
Below is the different roles and their typeid 

| Category ID | User Type | Constant Name |
|-------------|-----------|---------------|
| **1** | Admin | `UserType.ADMIN` |
| **2** | Storekeeper | `UserType.STOREKEEPER` |
| **3** | Salesman | `UserType.SALESMAN` |
| **4** | Supplier | `UserType.SUPPLIER` |
| **5** | Biller | `UserType.BILLER` |
| **6** | Checker | `UserType.CHECKER` |
| **7** | Driver | `UserType.DRIVER` |


Order flow (Normal)

1. Salesman places order
Creates order with approveFlag = NEW (0) or SEND_TO_STOREKEEPER (1)
Sends to storekeeper
2. Storekeeper receives and verifies
Order status: VERIFIED_BY_STOREKEEPER (2)
Returns to salesman
3. Salesman sends to Checker and/or Biller
After storekeeper verification, salesman can:
Send to Checker: sets approveFlag = SEND_TO_CHECKER (6)
Send to Biller: sets billerId (can happen independently or together)
4. Checker checks
When checker claims order: approveFlag = CHECKER_IS_CHECKING (7)
When checker submits: approveFlag = COMPLETED (3) (via sendCheckedReport)
5. Biller generates bill
Biller can work on the order (billerId is set)
The order is completed by the checker, not the biller
Differences from your understanding
Checker and Biller are not sequential — salesman can send to both independently.
Order is completed by the checker — when checker submits (sendCheckedReport), the order becomes COMPLETED (3).
Biller can work on the order, but completion is triggered by the checker.

//////////////////////////////////
Approval flags sequence
NEW (0) 
  ↓
SEND_TO_STOREKEEPER (1)
  ↓
VERIFIED_BY_STOREKEEPER (2)
  ↓
SEND_TO_CHECKER (6) → CHECKER_IS_CHECKING (7) → COMPLETED (3)
  OR
Biller assigned (billerId set, but approveFlag stays at 2)

////////////////////////////////

Order flow(when storekeeper marks the order as out of stock)

1. Salesman places order
Order created with approveFlag = SEND_TO_STOREKEEPER (1)
Sent to storekeeper
2. Storekeeper checks items
Storekeeper reviews items
Can mark items as "Out of Stock" (checkbox)
Sets available quantity for items
Can add notes
3. Storekeeper submits
When storekeeper clicks "Inform Updates" (OrderDetailsStorekeeper.kt line 184):
Order status: VERIFIED_BY_STOREKEEPER (2)
Out-of-stock items:
orderFlag = OUT_OF_STOCK (3L) for marked items
Creates OutOfStockMaster and OutOfStockProducts records
Notification sent to ADMIN: "Product out of stock reported"
If product has autoSend = 1 and defaultSupplierId, auto-sends to supplier
Order returns to salesman with verified status
4. Out-of-stock handling (parallel to order flow)
Admin sees out-of-stock items in OutOfStockListScreen
Supplier (if auto-sent) sees them in OutOfStockSupplierScreen
Supplier can respond with available quantity
Admin can manage out-of-stock items separately
5. Order continues normal flow
Order status: VERIFIED_BY_STOREKEEPER (2)
Salesman can:
Send to Checker
Send to Biller
Proceed with available items

Notes
Out-of-stock items are handled separately from the main order flow
The order can proceed even if some items are out of stock
Out-of-stock items can be auto-sent to supplier if configured
Admin manages out-of-stock items through the Out of Stock syst

Push Notification Payload Structure:
{
  "ids": [
    {"user_id": 123, "silent_push": 1},
    {"user_id": 456, "silent_push": 1}
  ],
  "data_message": "Product updates",
  "data": {
    "data_ids": [
      {"table": 1, "id": 789},      // Product table, product ID
      {"table": 19, "id": 790}      // ProductUnit table, product unit ID
    ],
    "show_notification": 0,
    "message": "Product updates"
  }
}

read out this doc for onesignal silent(data) notification handling

https://documentation.onesignal.com/docs/en/data-notifications