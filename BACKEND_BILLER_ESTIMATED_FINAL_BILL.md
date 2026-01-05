# Backend Implementation: Estimated Bill vs Final Bill for Biller Module

## Overview

The biller module needs to display order details in two separate tabs:
1. **Estimated Bill Tab**: Shows the order state when salesman sends it to checker/biller (after storekeeper verification)
2. **Final Bill Tab**: Shows the order state after checker completes the order (with possible quantity modifications)

## Current System Context

### Order Workflow
1. **Storekeeper Verification**: Storekeeper verifies order items, sets available quantities
   - Order status: `order_approve_flag = 2` (VERIFIED_BY_STOREKEEPER)
   - OrderSub quantities: `order_sub_qty` and `order_sub_available_qty` are set

2. **Salesman Sends to Checker/Biller**: Salesman sends order to both checker and biller
   - Order status: `order_approve_flag = 6` (SEND_TO_CHECKER)
   - OrderSub quantities: Still the same as from storekeeper verification
   - **This is the "Estimated Bill" state**

3. **Checker Completes**: Checker may modify item quantities, then completes the order
   - Order status: `order_approve_flag = 3` (COMPLETED)
   - OrderSub quantities: `order_sub_qty` may be changed (overwrites original value)
   - The original quantities are lost (only change is logged in notes)
   - **This is the "Final Bill" state**

### Problem Statement

Currently, when the checker modifies quantities, the original estimated quantities are overwritten and lost. The biller needs to see both:
- The estimated quantities (from step 2, before checker changes)
- The final quantities (from step 3, after checker changes)

## Database Changes Required

### Add New Columns to `order_sub` Table

Add the following columns to store estimated quantities:

```sql
ALTER TABLE order_sub 
ADD COLUMN estimated_qty REAL DEFAULT 0.0,
ADD COLUMN estimated_available_qty REAL DEFAULT 0.0,
ADD COLUMN estimated_total REAL DEFAULT 0.0;
```

**Column Descriptions:**
- `estimated_qty`: Stores the `order_sub_qty` value when order is sent to checker/biller (estimated bill state)
- `estimated_available_qty`: Stores the `order_sub_available_qty` value when order is sent to checker/biller
- `estimated_total`: Optional - calculated total for estimated bill (rate × estimated_qty)

### Migration File Structure

Create a migration file: `YYYY_MM_DD_HHMMSS_add_estimated_fields_to_order_sub.php`

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::table('order_sub', function (Blueprint $table) {
            $table->decimal('estimated_qty', 10, 2)->default(0.00)->after('order_sub_qty');
            $table->decimal('estimated_available_qty', 10, 2)->default(0.00)->after('estimated_qty');
            $table->decimal('estimated_total', 10, 2)->default(0.00)->after('estimated_available_qty');
        });
    }

    public function down()
    {
        Schema::table('order_sub', function (Blueprint $table) {
            $table->dropColumn(['estimated_qty', 'estimated_available_qty', 'estimated_total']);
        });
    }
};
```

## Backend Logic Changes

### 1. Populate Estimated Fields When Order is Sent to Checker/Biller

**Location**: `OrderController::updateBillerChecker()` method (or wherever orders are sent to checker/biller)

**When to Populate**:
- When `order_approve_flag` changes to `SEND_TO_CHECKER` (6)
- OR when `order_biller_id` is set for the first time (when order is sent to biller)

**Logic**:
```php
// When order is sent to checker/biller (approve_flag = 6 or biller_id is set)
// For each order_sub in this order:
$orderSub->estimated_qty = $orderSub->order_sub_qty; // Current quantity
$orderSub->estimated_available_qty = $orderSub->order_sub_available_qty; // Current available qty
$orderSub->estimated_total = $orderSub->order_sub_update_rate * $orderSub->order_sub_qty; // Calculated total
$orderSub->save();
```

**Implementation Points**:
1. Check if estimated fields are already populated (to avoid overwriting on subsequent updates)
2. Only populate if `estimated_qty = 0` (not already set) OR if explicitly sending to checker/biller for the first time
3. This should happen in the `updateBillerChecker()` method when `is_biller = true` or `approve_flag = 6`

### 2. Update Order Model

Add the new fields to the `OrderSub` model's `$fillable` array:

```php
protected $fillable = [
    // ... existing fields
    'estimated_qty',
    'estimated_available_qty',
    'estimated_total',
];
```

### 3. API Endpoint Changes

**Endpoint**: Order details endpoint used by biller (likely `api/orders/{id}` or similar)

**Response Changes**:
- Include both estimated and final quantities in the response
- Add a flag or separate structure to indicate estimated vs final data

**Suggested Response Structure**:
```json
{
    "status": 1,
    "data": {
        "order": {
            "id": 123,
            "order_id": 456,
            "order_approve_flag": 3,
            // ... other order fields
        },
        "items": [
            {
                "order_sub_id": 789,
                "product_name": "Product Name",
                "order_sub_qty": 8.0,  // Final quantity (after checker)
                "order_sub_available_qty": 0.0,
                "estimated_qty": 10.0,  // Estimated quantity (before checker)
                "estimated_available_qty": 10.0,
                "estimated_total": 500.00,  // estimated_qty × rate
                "final_total": 400.00,  // order_sub_qty × rate
                "order_sub_update_rate": 50.00,
                // ... other fields
            }
        ],
        "estimated_bill_total": 5000.00,  // Sum of all estimated_total
        "final_bill_total": 4500.00  // Sum of all final totals
    }
}
```

### 4. Backfill Existing Data (Optional but Recommended)

For existing orders that are already completed but don't have estimated quantities:

**Option A**: Set estimated = final (for completed orders)
```php
// Migration or seeder: For orders with approve_flag = 3 (COMPLETED)
// where estimated_qty = 0, set estimated = current qty
DB::table('order_sub')
    ->join('orders', 'order_sub.order_id', '=', 'orders.id')
    ->where('orders.order_approve_flag', 3)
    ->where('order_sub.estimated_qty', 0)
    ->update([
        'order_sub.estimated_qty' => DB::raw('order_sub.order_sub_qty'),
        'order_sub.estimated_available_qty' => DB::raw('order_sub.order_sub_available_qty'),
        'order_sub.estimated_total' => DB::raw('order_sub.order_sub_update_rate * order_sub.order_sub_qty'),
    ]);
```

**Option B**: Leave as 0 (estimated quantities only for new orders going forward)

## Implementation Checklist

- [ ] Create migration file to add estimated columns to `order_sub` table
- [ ] Run migration on development database
- [ ] Update `OrderSub` model to include new fields in `$fillable`
- [ ] Modify `updateBillerChecker()` or relevant method to populate estimated fields when order is sent to checker/biller
- [ ] Add logic to prevent overwriting estimated fields if already set
- [ ] Update order details API endpoint to return estimated quantities
- [ ] Add calculated totals (estimated_bill_total, final_bill_total) to API response
- [ ] Test with existing orders
- [ ] Create backfill script for existing completed orders (optional)
- [ ] Update API documentation

## Key Implementation Details

### When to Populate Estimated Fields

**Trigger Points**:
1. When `order_approve_flag` is set to `SEND_TO_CHECKER` (6) for the first time
2. When `order_biller_id` is set (when `is_biller = true` in `updateBillerChecker`)
3. Only populate if `estimated_qty = 0` (to avoid overwriting)

**Code Location**:
- Primary: `OrderController::updateBillerChecker()` method
- Also check: Any other method that sets `approve_flag = 6` or sets `biller_id`

### Calculation Logic

```php
// Estimated quantities (from storekeeper verification state)
$estimated_qty = $orderSub->order_sub_qty;
$estimated_available_qty = $orderSub->order_sub_available_qty;
$estimated_total = $orderSub->order_sub_update_rate * $orderSub->order_sub_qty;

// Final quantities (from checker completion state)
$final_qty = $orderSub->order_sub_qty; // May have been modified by checker
$final_total = $orderSub->order_sub_update_rate * $orderSub->order_sub_qty;
```

### Preventing Overwrites

```php
// Only populate estimated fields if not already set
if ($orderSub->estimated_qty == 0 && 
    ($order->order_approve_flag == 6 || $order->order_biller_id != -1)) {
    // Populate estimated fields
}
```

## Testing Scenarios

1. **New Order Flow**:
   - Storekeeper verifies → quantities set
   - Salesman sends to checker/biller → estimated fields populated
   - Checker modifies quantities → final quantities updated, estimated preserved
   - Biller views → sees both estimated and final

2. **Existing Completed Orders**:
   - Test backfill script (if implemented)
   - Verify API returns estimated = final for these orders

3. **Edge Cases**:
   - Order sent to checker/biller multiple times (should not overwrite estimated)
   - Orders that go directly to completion without intermediate steps
   - Orders with zero quantities

## API Endpoint Changes Summary

**Endpoint**: `GET api/orders/{id}` (or biller-specific endpoint)

**Changes**:
1. Include `estimated_qty`, `estimated_available_qty`, `estimated_total` in each order_sub item
2. Add `estimated_bill_total` and `final_bill_total` at order level
3. Maintain backward compatibility (existing fields unchanged)

## Notes

- Estimated quantities represent the "as-verified-by-storekeeper" state
- Final quantities represent the "as-completed-by-checker" state
- The frontend will display these in two separate tabs
- Estimated fields should only be populated once (when first sent to checker/biller)
- This feature is specifically for the biller role to compare estimated vs final bills


