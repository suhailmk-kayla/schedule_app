# Order Tables Reference

This document summarizes the key tables involved in the order workflow (converted from the KMP SQLDelight schema) and their operational flags.

## Orders

- **Purpose:** Master record for each order (customer, totals, workflow state). Temp and draft orders also live here before submission.
- **Schema:** `lib/repositories/local/database_helper.dart` (`_createOrdersTable`)
  - `orderId`, `invoiceNo`, `UUID`, `customerId`, `customerName`, `salesmanId`, `storeKeeperId`, `billerId`, `checkerId`, `dateAndTime`, `note`, `total`, `freightCharge`, `approveFlag`, `createdDateTime`, `updatedDateTime`, `flag`, `isProcessFinish`

### Orders flag values (`Orders.flag`)

| Value | Meaning                      | Notes                                                                                            |
|-------|------------------------------|--------------------------------------------------------------------------------------------------|
| 0     | Deleted / inactive           | Soft deleted rows.                                                                               |
| 1     | Active / confirmed order     | Order has been sent to storekeeper and appears in main lists.                                   |
| 2     | Temp order                   | Order being created in “Create Order” flow; excluded from main lists.                           |
| 3     | Draft order                  | Saved draft that can be reopened and edited later.                                               |

Most queries in `composeApp/src/commonMain/sqldelight/com/foms/schedule/Orders.sq` use filters such as `flag > 0 AND flag != 2` to hide temp orders but include drafts.

### Order approval workflow (`approveFlag`, `OrderApprovalFlag.kt`)

| Value | Meaning                    |
|-------|----------------------------|
| 0     | NEW                        |
| 1     | SEND_TO_STOREKEEPER        |
| 2     | VERIFIED_BY_STOREKEEPER    |
| 3     | COMPLETED                  |
| 4     | REJECTED                   |
| 5     | CANCELLED                  |
| 6     | SEND_TO_CHECKER            |
| 7     | CHECKER_IS_CHECKING        |

## OrderSub

- **Purpose:** Line items for an order (product, unit, quantity, per-line status). Used for both temp/draft and confirmed orders.
- **Schema:** `database_helper.dart` (`_createOrderSubTable`)
  - `orderSubId`, `orderId`, `productId`, `unitId`, `rate`, `updateRate`, `quantity`, `availQty`, `unitBaseQty`, `note`, `narration`, `orderFlag`, `isCheckedflag`, `flag`

### OrderSub flag fields

- `flag` — Active/deleted marker:
  - `0` = deleted/temp
  - `1` = active line
  - `2` = temp line (during creation)
- `orderFlag` — Per-line workflow (`OrderSubFlag.kt`):

| Value | Meaning          |
|-------|------------------|
| 0     | NEW (temp)       |
| 1     | NOT_CHECKED      |
| 2     | IN_STOCK         |
| 3     | OUT_OF_STOCK     |
| 4     | REPORTED         |
| 5     | NOT_AVAILABLE    |
| 6     | CANCELLED        |
| 7     | REPLACED         |

- `isCheckedflag` — `0` = unchecked, `1` = checked by storekeeper.

### Query usage (from `OrderSub.sq`)

- `getTempOrdersSubAndDetails` → `orderFlag == 0` (temp/draft).
- `getOrdersSubAndDetails` → `orderFlag != 0` (confirmed orders).
- `getOrdersSub` → `flag = 1`.
- `getExistOrderSub` → prevents duplicate product lines (`flag = 1 AND orderId = ? AND productId = ? …`).

## OrderSubEditCache

- **Purpose:** Holds edited versions of order subs when modifying already-approved orders. Prevents overwriting original lines until sync completes.
- **Schema:** Identical to `OrderSub`.
- **Usage:** When `Orders.approveFlag != 0`, edits are stored here. On sync, cached rows are pushed to the server and then cleared (see `OrderSubEditCache.sq` and related repository methods).

## PackedSubs

- **Purpose:** Tracks how many units of a given order sub have been packed during fulfillment.
- **Schema:** `database_helper.dart` (`_createPackedSubsTable`)
  - `orderSubId` (unique), `quantity`.
- **Usage:** Links to `OrderSub.orderSubId`. Storekeeper updates `PackedSubs.quantity` as items are packed.

## Relationships & Lifecycle

```
Orders (flag = 2 temp) ─┐
                        ├─> OrderSub (orderFlag = 0 NEW)
Orders (flag = 3 draft) ┘

Orders (flag = 1 active) ──> OrderSub (orderFlag >= 1)

OrderSub.orderSubId ──> PackedSubs.orderSubId (optional packing data)
OrderSub edits for approved orders ──> OrderSubEditCache
```

- Temp orders and drafts use `Orders.flag` 2/3 with `OrderSub.orderFlag = 0`.
- Confirmed orders use `Orders.flag = 1` with non-zero `OrderSub.orderFlag`.
- Editing approved orders: original `OrderSub` remains untouched; new versions land in `OrderSubEditCache`.
- Packing progress per line is tracked in `PackedSubs`.

Use this document as a quick reference when porting KMP logic or debugging order workflow flags.

