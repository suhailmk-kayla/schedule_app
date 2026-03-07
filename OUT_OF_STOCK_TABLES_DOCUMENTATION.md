# Out of Stock Tables – Design Documentation

This document explains the design and relationship between the `out_of_stocks` and `out_of_stock_sub` tables, and why having two tables is a deliberate, clever design.

---

## Overview

When a storekeeper marks an order item as out of stock, the backend stores data in **two tables**:

| Table | Role | Purpose |
|-------|------|---------|
| **out_of_stocks** | Master / Header | Records **that** an order line is out of stock (one row per OOS report) |
| **out_of_stock_sub** | Detail | Records **how** it's being handled – per supplier, per rate, per status (one or more rows per report) |

---

## Table Structure

### out_of_stocks (Master)

- **Columns**: `outos_*` (no "sub" in names)
- **Key fields**: `outos_order_sub_id` (links to `orders_sub.id`), `outos_prod_id`, `outos_qty`, `outos_available_qty`, `outos_is_compleated_flag`
- **Links to**: Order line via `outos_order_sub_id` → `orders_sub.id` → `orders.id`

### out_of_stock_sub (Detail)

- **Columns**: `outos_sub_*`
- **Key fields**: `outos_sub_outos_id` (links to `out_of_stocks.id`), `outos_sub_supp_id` (supplier), `outos_sub_rate`, `outos_sub_updated_rate`, `outos_sub_status_flag`, `outos_sub_is_checked_flag`
- **Links to**: Master via `outos_sub_outos_id` → `out_of_stocks.id`

---

## Why Two Tables? The Multiple Suppliers Scenario

The design exists to support a common business flow: **one out-of-stock item can be sourced from multiple suppliers**.

### Example Scenario

**Order:** Customer ordered **10 bags of Rice**.

**Warehouse:** Only 2 bags available. The storekeeper reports Rice as out of stock.

**Business rule:** Before telling the customer "sorry, we can't fulfill", you try to source Rice from suppliers.

### You Contact 3 Suppliers

| Supplier | Price per bag | Stock | Delivery |
|----------|---------------|-------|----------|
| Supplier A | ₹100 | 50 bags | 2 days |
| Supplier B | ₹95  | 20 bags | 1 day  |
| Supplier C | ₹110 | 100 bags | 3 days |

You create **one OOS report** for "Rice, 10 qty", but you track **three possible sourcing options** (one per supplier).

---

## How the Two Tables Store This

### out_of_stocks (1 row – the report)

| id | outos_order_sub_id | outos_prod_id | outos_qty | outos_available_qty |
|----|--------------------|---------------|-----------|---------------------|
| 46 | 207 | Rice | 10 | 2 |

**Meaning:** "Order line 207 – Rice – ordered 10, only 2 in stock. It's out of stock."

---

### out_of_stock_sub (3 rows – one per supplier option)

| id | outos_sub_outos_id | outos_sub_supp_id | outos_sub_rate | outos_sub_qty |
|----|--------------------|-------------------|----------------|---------------|
| 1 | 46 | Supplier A | 100 | 10 |
| 2 | 46 | Supplier B | 95  | 10 |
| 3 | 46 | Supplier C | 110 | 10 |

**Meaning:** "For OOS report #46, we're checking Supplier A (₹100), Supplier B (₹95), and Supplier C (₹110)." The purchaser can compare and pick one.

---

## Why Not One Table?

If you used **one table** for everything, you'd have to repeat the same OOS info for every supplier:

| id | order_sub_id | prod_id | qty | supp_id | rate |
|----|--------------|---------|-----|---------|------|
| 1 | 207 | Rice | 10 | A | 100 |
| 2 | 207 | Rice | 10 | B | 95  |
| 3 | 207 | Rice | 10 | C | 110 |

That's **data duplication** – the same order line, product, and quantity repeated 3 times.

With two tables:
- **out_of_stocks** stores "what is OOS" (once).
- **out_of_stock_sub** stores "how we might solve it" (each supplier) without repeating the OOS info.

---

## Multiple Items from Same Order

When multiple items from the **same order** are reported as OOS, you get one row per item in both tables.

**Order #10** has 3 items reported OOS:

| orders_sub.id | Product | Qty |
|---------------|---------|-----|
| 101 | Rice | 10 |
| 102 | Sugar | 5 |
| 103 | Oil | 2 |

### out_of_stocks (3 rows)

| id | outos_order_sub_id | outos_prod_id | outos_qty | outos_available_qty |
|----|--------------------|---------------|-----------|---------------------|
| 46 | 101 | Rice | 10 | 0 |
| 47 | 102 | Sugar | 5 | 0 |
| 48 | 103 | Oil | 2 | 0 |

### out_of_stock_sub (3 rows – one per report)

| id | outos_sub_outos_id | outos_sub_order_sub_id | outos_sub_prod_id | outos_sub_supp_id |
|----|--------------------|------------------------|-------------------|-------------------|
| 46 | 46 | 101 | Rice | 7 |
| 47 | 47 | 102 | Sugar | 14 |
| 48 | 48 | 103 | Oil | 7 |

`out_of_stock_sub` has the extra detail: supplier, rates, per-line status flags.

---

## Connection to Order

The link chain from out-of-stock to order:

```
out_of_stocks.outos_order_sub_id  →  orders_sub.id
orders_sub.order_sub_ordr_id      →  orders.id
```

`out_of_stock_sub` connects via its parent:

```
out_of_stock_sub.outos_sub_outos_id  →  out_of_stocks.id
out_of_stocks.outos_order_sub_id     →  orders_sub.id
```

---

## Summary

| Question | Answer |
|----------|--------|
| **out_of_stocks** = ? | "This order line is out of stock" (one row per report) |
| **out_of_stock_sub** = ? | "How we're handling it" (supplier, rate, status – can be multiple per report) |
| **Why two tables?** | To support multiple supplier options per OOS without duplicating data |
| **When 1:1?** | If you always have one supplier per OOS, you'll have one sub row per master row |
| **When 1:many?** | When you check multiple suppliers for the same OOS item |
