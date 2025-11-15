# Complete API Documentation

## Overview
This document provides comprehensive documentation for all API endpoints in the Schedule Server application. The API uses Laravel Sanctum for authentication and follows RESTful principles.

**Base URL:** `{YOUR_BASE_URL}/api`  
**Authentication:** Bearer Token (Laravel Sanctum)  
**Rate Limit:** 200 requests per minute (for authenticated endpoints)

---

## Table of Contents

1. [Authentication](#authentication)
2. [User Management](#user-management)
3. [Customer Management](#customer-management)
4. [Category Management](#category-management)
5. [Unit Management](#unit-management)
6. [Product Management](#product-management)
7. [Route Management](#route-management)
8. [Car Management](#car-management)
9. [Order Management](#order-management)
10. [Out of Stock Management](#out-of-stock-management)
11. [Push Notifications](#push-notifications)
12. [Download Endpoints](#download-endpoints)

---

## Authentication

### Headers Required for Authenticated Endpoints

```
Authorization: Bearer {your_sanctum_token}
Content-Type: application/json
Accept: application/json
```

---

### 1. Register User

**Endpoint:** `POST /api/register`  
**Authentication:** Not Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `code` | string | Yes | Unique user code |
| `name` | string | Yes | User name |
| `phone_no` | string | Yes | Phone number |
| `password` | string | Yes | Password |
| `confirm_password` | string | Yes | Password confirmation |
| `cat_id` | integer | Yes | User category ID (3=SalesMan, 4=Supplier, etc.) |
| `address` | string | No | Address |
| `device_token` | string | No | Device token for push notifications |

#### Response

```json
{
  "status": 1,
  "message": "User Succesfully Added",
  "user": {
    "id": 1,
    "name": "John Doe",
    "code": "USR001",
    "phone_no": "+1234567890",
    "cat_id": 3,
    "address": "123 Main St"
  },
  "userData": {
    "id": 1,
    "name": "John Doe",
    "code": "USR001",
    "phone_no": "+1234567890",
    "address": "123 Main St"
  }
}
```

**Note:** If `cat_id` is 3 or 4, a corresponding SalesMan or Supplier record is also created.

---

### 2. Login

**Endpoint:** `POST /api/login`  
**Authentication:** Not Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `code` | string | Yes | User code |
| `password` | string | Yes | Password |
| `token` | string | No | Device token |

#### Response

**Success:**
```json
{
  "status": 1,
  "message": "User Succesfully Login",
  "data": {
    "id": 1,
    "name": "John Doe",
    "code": "USR001",
    "phone_no": "+1234567890",
    "cat_id": 3,
    "address": "123 Main St",
    "token": "1|abcdefghijklmnopqrstuvwxyz1234567890"
  }
}
```

**Already Logged In:**
```json
{
  "status": 2,
  "error": "Already logged in another device",
  "data": []
}
```

**Invalid Credentials:**
```json
{
  "status": 2,
  "message": "User code or password not correct",
  "data": []
}
```

---

### 3. Logout

**Endpoint:** `POST /api/logout`  
**Authentication:** Required

#### Response

```json
{
  "status": 1,
  "message": "User Succesfully Logout",
  "data": []
}
```

---

## User Management

### 4. Check User Login Status

**Endpoint:** `POST /api/users/check_is_active`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | integer | Yes | User ID |

#### Response

**Active:**
```json
{
  "status": 1,
  "message": "User Active",
  "data": {
    "msg": "User Active"
  }
}
```

**Inactive:**
```json
{
  "status": 0,
  "message": "User not Active",
  "data": [["User not Active"]]
}
```

---

### 5. Change Password

**Endpoint:** `POST /api/users/change_pass`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | integer | Yes | User ID |
| `password` | string | Yes | New password |
| `confirm_password` | string | Yes | Password confirmation |

#### Response

```json
{
  "status": 1,
  "message": "Password successfully Reset",
  "data": {
    "id": 1,
    "name": "John Doe"
  }
}
```

---

### 6. Update User

**Endpoint:** `POST /api/users/update_user`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | integer | Yes | User ID |
| `code` | string | Yes | Unique user code |
| `name` | string | Yes | User name |
| `phone_no` | string | Yes | Phone number |
| `address` | string | No | Address |

#### Response

```json
{
  "status": 1,
  "message": "User successfully Reset",
  "data": {
    "id": 1,
    "second_id": 5,
    "name": "John Doe"
  }
}
```

**Note:** `second_id` is the ID in SalesMan or Supplier table if applicable.

---

### 7. Delete User

**Endpoint:** `POST /api/users/delete`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | integer | Yes | User ID |

#### Response

```json
{
  "status": 1,
  "message": "User successfully Deleted",
  "data": {
    "id": 1,
    "second_id": 5,
    "name": "John Doe"
  }
}
```

**Note:** This sets the `flag` to 0 (soft delete).

---

### 8. Logout User Device

**Endpoint:** `POST /api/users/logoutUserDevice`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | integer | Yes | User ID |
| `notification` | object | No | Notification data |

#### Response

```json
{
  "status": 1,
  "message": "User Succesfully Logout",
  "data": []
}
```

---

### 9. Logout All User Devices

**Endpoint:** `POST /api/users/logoutAllUserDevice`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `notification` | object | No | Notification data |

#### Response

```json
{
  "status": 1,
  "message": "All users successfully logged out from all devices",
  "data": []
}
```

---

## Customer Management

### 10. Add Customer

**Endpoint:** `POST /api/customer/add`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `code` | string | Yes | Unique customer code |
| `name` | string | Yes | Customer name |
| `phone_no` | string | Yes | Phone number |
| `rout_id` | integer | Yes | Route ID |
| `sales_man_id` | integer | Yes | Salesman ID |
| `rating` | integer | No | Rating (default: 0) |
| `address` | string | No | Address |
| `device_token` | string | No | Device token |

#### Response

```json
{
  "status": 1,
  "message": "Customer Succesfully Added",
  "data": {
    "id": 1,
    "name": "Customer Name",
    "code": "CUST001",
    "phone_no": "+1234567890",
    "rout_id": 1,
    "sales_man_id": 1,
    "rating": 5,
    "address": "123 Main St",
    "device_token": ""
  }
}
```

---

### 11. Update Customer

**Endpoint:** `POST /api/customer/update`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | integer | Yes | Customer ID |
| `code` | string | Yes | Unique customer code |
| `name` | string | Yes | Customer name |
| `phone_no` | string | Yes | Phone number |
| `rout_id` | integer | Yes | Route ID |
| `sales_man_id` | integer | Yes | Salesman ID |
| `rating` | integer | No | Rating |
| `address` | string | No | Address |

#### Response

```json
{
  "status": 1,
  "message": "Customer successfully updated",
  "data": {
    "id": 1,
    "name": "Customer Name"
  }
}
```

---

### 12. Update Customer Flag

**Endpoint:** `POST /api/customer/update_flag`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | integer | Yes | Customer ID |
| `flag` | integer | Yes | Flag value |

#### Response

```json
{
  "status": 1,
  "message": "Customer flag successfully updated",
  "data": {
    "id": 1,
    "name": "Customer Name"
  }
}
```

---

## Category Management

### 13. Add Category

**Endpoint:** `POST /api/category/add`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Unique category name |
| `remark` | string | No | Remarks |

#### Response

```json
{
  "status": 1,
  "message": "Category Succesfully Added",
  "data": {
    "id": 1,
    "name": "Category Name",
    "remark": "Some remarks"
  }
}
```

---

### 14. Update Category

**Endpoint:** `POST /api/category/update`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | integer | Yes | Category ID |
| `name` | string | Yes | Unique category name |

#### Response

```json
{
  "status": 1,
  "message": "Category successfully updated",
  "data": {
    "id": 1,
    "name": "Category Name"
  }
}
```

---

### 15. Add Sub Category

**Endpoint:** `POST /api/sub_category/add`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Unique sub-category name |
| `category_id` | integer | Yes | Parent category ID |
| `remark` | string | No | Remarks |

#### Response

```json
{
  "status": 1,
  "message": "Sub Category Succesfully Added",
  "data": {
    "id": 1,
    "name": "Sub Category Name",
    "cat_id": 1,
    "remark": "Some remarks"
  }
}
```

---

### 16. Update Sub Category

**Endpoint:** `POST /api/sub_category/update`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | integer | Yes | Sub-category ID |
| `cat_id` | integer | Yes | Parent category ID |
| `name` | string | Yes | Unique sub-category name (unique within category) |

#### Response

```json
{
  "status": 1,
  "message": "Sub-Category successfully updated",
  "data": {
    "id": 1,
    "cat_id": 1,
    "name": "Sub Category Name"
  }
}
```

---

### 17. Add User Category

**Endpoint:** `POST /api/user_category/add`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Unique user category name |
| `permission_json` | string | No | JSON permissions |

#### Response

```json
{
  "status": 1,
  "message": "User Category Succesfully Added",
  "data": {
    "id": 1,
    "name": "Admin",
    "permission_json": "{}"
  }
}
```

---

## Unit Management

### 18. Add Unit

**Endpoint:** `POST /api/unit/add`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Unique unit name |
| `code` | string | Yes | Unique unit code |
| `display_name` | string | Yes | Unique display name |
| `type` | string | No | Unit type |
| `base_id` | integer | No | Base unit ID (default: 1) |
| `base_qty` | decimal | No | Base quantity (default: 1) |

#### Response

```json
{
  "status": 1,
  "message": "Unit Succesfully Added",
  "data": {
    "id": 1,
    "name": "Kilogram",
    "code": "KG",
    "display_name": "kg",
    "type": "",
    "base_id": 1,
    "base_qty": 1.0
  }
}
```

---

### 19. Update Unit

**Endpoint:** `POST /api/unit/update`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | integer | Yes | Unit ID |
| `name` | string | Yes | Unique unit name |
| `display_name` | string | Yes | Display name |

#### Response

```json
{
  "status": 1,
  "message": "Unit successfully updated",
  "data": {
    "id": 1,
    "name": "Kilogram",
    "display_name": "kg"
  }
}
```

---

### 20. Add Product Unit

**Endpoint:** `POST /api/product_unit/add`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `prd_id` | integer | Yes | Product ID |
| `base_unit_id` | integer | Yes | Base unit ID |
| `derived_unit_id` | integer | Yes | Derived unit ID |

#### Response

```json
{
  "status": 1,
  "message": "Product Unit Succesfully Added",
  "data": {
    "id": 1,
    "prd_id": 1,
    "base_unit_id": 1,
    "derived_unit_id": 2
  }
}
```

---

## Product Management

### 21. Add Product

**Endpoint:** `POST /api/products/add`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Unique product name |
| `code` | string | Yes | Unique product code |
| `photo` | string | No | Base64 image with data URI prefix |
| `barcode` | string | No | Barcode |
| `sub_name` | string | No | Sub-name |
| `brand` | string | No | Brand name |
| `sub_brand` | string | No | Sub-brand |
| `category_id` | integer | No | Category ID |
| `sub_category_id` | integer | No | Sub-category ID |
| `default_supp_id` | integer | No | Default supplier ID |
| `auto_sendto_supplier_flag` | integer | No | Auto-send flag (default: 0) |
| `base_unit_id` | integer | No | Base unit ID |
| `price` | string | No | Price |
| `mrp` | string | No | Maximum Retail Price |
| `retail_price` | string | No | Retail price |
| `fitting_charge` | string | No | Fitting charge |
| `note` | string | No | Notes |

**Photo Format:** `data:image/{type};base64,{base64_string}`  
**Supported Types:** jpg, jpeg, png, gif

#### Response

```json
{
  "status": 1,
  "message": "Product Succesfully Added",
  "product": {
    "id": 1,
    "name": "Product Name",
    "code": "PROD001",
    "barcode": "1234567890",
    "sub_name": "Sub Name",
    "brand": "Brand Name",
    "sub_brand": "Sub Brand",
    "category_id": 1,
    "sub_category_id": 2,
    "default_supp_id": 5,
    "auto_sendto_supplier_flag": 0,
    "base_unit_id": 3,
    "default_unit_id": 3,
    "price": "100.00",
    "mrp": "150.00",
    "retail_price": "120.00",
    "fitting_charge": "10.00",
    "note": "Product notes",
    "photo": "http://yourdomain.com/LaravelProject/public/uploads/products/filename.jpeg"
  },
  "productUnit": {
    "id": 1,
    "prd_id": 1,
    "base_unit_id": 3,
    "derived_unit_id": 3
  }
}
```

**Note:** A ProductUnit record is automatically created.

---

### 22. Update Product

**Endpoint:** `POST /api/products/update`  
**Authentication:** Required

#### Request Parameters

Same as Add Product, plus:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | integer | Yes | Product ID |

#### Response

```json
{
  "status": 1,
  "message": "Product Succesfully Added",
  "product": {
    "id": 1,
    "name": "Updated Product Name",
    "code": "PROD001",
    ...
  }
}
```

---

### 23. Add All Products

**Endpoint:** `POST /api/products/add_all_items`  
**Authentication:** Required

#### Request Body

Array of product objects (same structure as Add Product):

```json
[
  {
    "name": "Product 1",
    "code": "PROD001",
    ...
  },
  {
    "name": "Product 2",
    "code": "PROD002",
    ...
  }
]
```

#### Response

```json
{
  "status": 1,
  "message": "Products Succesfully Added"
}
```

---

### 24. Add Product Car

**Endpoint:** `POST /api/product_cars/add`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `data` | array | Yes | Array of product-car mappings |

**Data Structure:**
```json
{
  "data": [
    {
      "product_id": 1,
      "car_brand_id": 1,
      "car_name_id": 1,
      "car_model_id": 1,
      "car_version_id": 1
    }
  ]
}
```

#### Response

```json
{
  "status": 1,
  "message": "Car Product Succesfully Added",
  "data": [
    {
      "id": 1,
      "product_id": 1,
      "car_brand_id": 1,
      "car_name_id": 1,
      "car_model_id": 1,
      "car_version_id": 1
    }
  ]
}
```

**Note:** Duplicate combinations are skipped.

---

## Route Management

### 25. Add Route

**Endpoint:** `POST /api/route/add`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Unique route name |
| `code` | string | No | Route code |
| `salesman_id` | integer | Yes | Salesman ID |

#### Response

```json
{
  "status": 1,
  "message": "Route Succesfully Added",
  "data": {
    "id": 1,
    "name": "Route Name",
    "code": "RT001",
    "salesman_id": 1
  }
}
```

---

### 26. Update Route

**Endpoint:** `POST /api/route/update`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | integer | Yes | Route ID |
| `name` | string | Yes | Unique route name |

#### Response

```json
{
  "status": 1,
  "message": "Route successfully updated",
  "data": {
    "id": 1,
    "name": "Updated Route Name"
  }
}
```

---

## Car Management

### 27. Add Car

**Endpoint:** `POST /api/cars/add`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `car_brand_id` | integer | Yes | Car brand ID (-1 to create new) |
| `brand_name` | string | Conditional | Required if car_brand_id is -1 |
| `car_name_id` | integer | Yes | Car name ID (-1 to create new) |
| `car_name` | string | Conditional | Required if car_name_id is -1 |
| `carModels` | array | No | Array of car models |

**Car Models Structure:**
```json
{
  "car_brand_id": 1,
  "car_name_id": 1,
  "carModels": [
    {
      "car_model_id": -1,
      "model_name": "Model Name",
      "versions": [
        {
          "version_name": "Version Name"
        }
      ]
    }
  ]
}
```

#### Response

```json
{
  "status": 1,
  "message": "Car added successfully",
  "carBrand": {
    "id": 1,
    "brand_name": "Toyota"
  },
  "carName": {
    "id": 1,
    "car_brand_id": 1,
    "car_name": "Camry"
  },
  "models": [
    {
      "id": 1,
      "car_brand_id": 1,
      "car_name_id": 1,
      "model_name": "2023",
      "versions": [
        {
          "id": 1,
          "car_brand_id": 1,
          "car_name_id": 1,
          "car_model_id": 1,
          "version_name": "LE"
        }
      ]
    }
  ]
}
```

---

## Order Management

### 28. Add Order

**Endpoint:** `POST /api/orders/add`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `uuid` | string | No | UUID for order retrieval |
| `order_cust_id` | integer | No | Customer ID |
| `order_cust_name` | string | No | Customer name |
| `order_salesman_id` | integer | No | Salesman ID |
| `order_stock_keeper_id` | integer | No | Stock keeper ID |
| `order_biller_id` | integer | No | Biller ID |
| `order_checker_id` | integer | No | Checker ID |
| `order_date_time` | string | No | Order date/time |
| `order_total` | decimal | No | Order total |
| `order_freight_charge` | decimal | No | Freight charge |
| `order_note` | string | No | Order notes |
| `order_approve_flag` | integer | No | Approval flag |
| `items` | array | Yes | Order items |
| `notification` | object | No | Notification data |

**Items Structure:**
```json
{
  "items": [
    {
      "order_sub_prd_id": 1,
      "order_sub_unit_id": 1,
      "order_sub_car_id": 1,
      "order_sub_rate": 100.00,
      "order_sub_date_time": "2025-01-27 10:00:00",
      "order_sub_update_rate": 100.00,
      "order_sub_qty": 5,
      "order_sub_available_qty": 3,
      "order_sub_unit_base_qty": 5,
      "order_sub_ordr_flag": 0,
      "order_sub_is_checked_flag": 0,
      "order_sub_note": "Item note",
      "order_sub_narration": "Narration",
      "order_sub_cust_id": 1,
      "order_sub_salesman_id": 1,
      "order_sub_stock_keeper_id": 1
    }
  ]
}
```

#### Response

```json
{
  "status": 1,
  "message": "Order Succesfully Added",
  "data": {
    "id": 1,
    "uuid": "unique-uuid",
    "order_inv_no": 1001,
    "order_cust_id": 1,
    "order_cust_name": "Customer Name",
    "order_salesman_id": 1,
    "order_stock_keeper_id": 1,
    "order_biller_id": 1,
    "order_checker_id": 1,
    "order_date_time": "2025-01-27 10:00:00",
    "order_total": 500.00,
    "order_freight_charge": 10.00,
    "order_note": "Order notes",
    "order_approve_flag": 0,
    "created_at": "2025-01-27 10:00:00",
    "updated_at": "2025-01-27 10:00:00",
    "items": [...]
  }
}
```

**Note:** If `uuid` is provided and order exists, returns existing order. Otherwise creates new order with auto-incremented invoice number.

---

### 29. Update Order

**Endpoint:** `POST /api/orders/update_order`  
**Authentication:** Required

#### Request Parameters

Same as Add Order, plus:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `order_id` | integer | Yes | Order ID |

**Items should include `order_sub_id` for existing items.**

#### Response

Same structure as Add Order.

---

### 30. Update Order Sub

**Endpoint:** `POST /api/orders/update_order_sub`  
**Authentication:** Required

#### Request Parameters

All order sub fields (same as items in Add Order), plus:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | integer | Yes | Order sub ID |
| `notification` | object | No | Notification data |

#### Response

```json
{
  "status": 1,
  "message": "Order Sub Succesfully Updated",
  "data": {
    "id": 1,
    "order_sub_ordr_inv_id": 1001,
    "order_sub_ordr_id": 1,
    ...
  }
}
```

---

### 31. Update Biller and Checker

**Endpoint:** `POST /api/orders/update_biller_adn_checker`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `order_id` | integer | Yes | Order ID |
| `is_biller` | boolean | Yes | true for biller, false for checker |
| `user_Id` | integer | Yes | User ID |
| `order_approve_flag` | integer | No | Approval flag |
| `notification` | object | No | Notification data |

#### Response

```json
{
  "status": 1,
  "message": "Succesfully Updated",
  "data": ""
}
```

---

### 32. Update Order Flag

**Endpoint:** `POST /api/orders/update_order_flag`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `order_id` | integer | Yes | Order ID |
| `order_approve_flag` | integer | Yes | Approval flag |
| `out_of_stock_data` | array | No | Out of stock data |
| `notification` | object | No | Notification data |

**Out of Stock Data Structure:**
```json
{
  "out_of_stock_data": [
    {
      "table": 11,
      "id": 1
    }
  ]
}
```

#### Response

```json
{
  "status": 1,
  "message": "Order Approve Flag Updated",
  "data": ""
}
```

---

### 33. Update Store Keeper

**Endpoint:** `POST /api/orders/update_store_keeper`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `order_id` | integer | Yes | Order ID |
| `order_stock_keeper_id` | integer | Yes | Stock keeper ID |
| `notification` | object | No | Notification data |

#### Response

**Success:**
```json
{
  "status": 1,
  "message": "Store keeper updated Updated",
  "data": ""
}
```

**Error (Already assigned):**
```json
{
  "status": 0,
  "error": "Store keeper already checking this order",
  "data": ""
}
```

---

## Out of Stock Management

### 34. Add Out of Stock

**Endpoint:** `POST /api/out_of_stocks/add`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `uuid` | string | No | UUID for retrieval |
| `outos_order_sub_id` | integer | No | Order sub ID |
| `outos_cust_id` | integer | No | Customer ID |
| `outos_sales_man_id` | integer | No | Salesman ID |
| `outos_stock_keeper_id` | integer | No | Stock keeper ID |
| `outos_date_and_time` | string | No | Date/time |
| `outos_prod_id` | integer | No | Product ID |
| `outos_unit_id` | integer | No | Unit ID |
| `outos_car_id` | integer | No | Car ID |
| `outos_qty` | decimal | No | Quantity |
| `outos_available_qty` | decimal | No | Available quantity |
| `outos_unit_base_qty` | decimal | No | Unit base quantity |
| `outos_note` | string | No | Notes |
| `outos_narration` | string | No | Narration |
| `outos_is_compleated_flag` | integer | No | Completion flag |
| `items` | array | Yes | Out of stock items |

**Items Structure:**
```json
{
  "items": [
    {
      "outos_sub_order_sub_id": 1,
      "outos_sub_cust_id": 1,
      "outos_sub_sales_man_id": 1,
      "outos_sub_stock_keeper_id": 1,
      "outos_sub_date_and_time": "2025-01-27 10:00:00",
      "outos_sub_supp_id": 1,
      "outos_sub_prod_id": 1,
      "outos_sub_unit_id": 1,
      "outos_sub_car_id": 1,
      "outos_sub_rate": 100.00,
      "outos_sub_updated_rate": 100.00,
      "outos_sub_qty": 5,
      "outos_sub_available_qty": 3,
      "outos_sub_unit_base_qty": 5,
      "outos_sub_status_flag": 0,
      "outos_sub_is_checked_flag": 0,
      "outos_sub_note": "Note",
      "outos_sub_narration": "Narration",
      "uuid": "unique-uuid"
    }
  ]
}
```

#### Response

```json
{
  "status": 1,
  "message": "Out Of Stock Succesfully Added",
  "data": {
    "id": 1,
    "outos_order_sub_id": 1,
    "outos_cust_id": 1,
    "outos_sales_man_id": 1,
    "outos_stock_keeper_id": 1,
    "outos_date_and_time": "2025-01-27 10:00:00",
    "outos_prod_id": 1,
    "outos_unit_id": 1,
    "outos_car_id": 1,
    "outos_qty": 5,
    "outos_available_qty": 3,
    "outos_unit_base_qty": 5,
    "outos_note": "Note",
    "outos_narration": "Narration",
    "outos_is_compleated_flag": 0,
    "uuid": "unique-uuid",
    "items": [...]
  }
}
```

**Note:** Updates order sub flag to 4 (Reported).

---

### 35. Add All Out of Stock

**Endpoint:** `POST /api/out_of_stocks/add_all`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `masters` | array | Yes | Array of out of stock masters |

**Structure:** Same as Add Out of Stock, but wrapped in `masters` array.

#### Response

```json
{
  "status": 1,
  "message": "Out Of Stock Succesfully Added",
  "data": [
    {
      "id": 1,
      ...
    },
    {
      "id": 2,
      ...
    }
  ]
}
```

---

### 36. Update Out of Stock Sub

**Endpoint:** `POST /api/out_of_stock_sub/update`  
**Authentication:** Required

#### Request Parameters

All out of stock sub fields, plus:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | integer | Conditional | Required if updating existing |
| `outos_sub_outos_id` | integer | Yes | Out of stock ID |

#### Response

```json
{
  "status": 1,
  "message": "Out Of Stock Sub Succesfully Updated",
  "data": {
    "id": 1,
    "outos_sub_outos_id": 1,
    ...
  }
}
```

---

### 37. Update Completed Flag

**Endpoint:** `POST /api/out_of_stock/update_compleated_flag`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | integer | Yes | Out of stock ID |
| `is_completed_flag` | integer | Yes | Completion flag |

#### Response

```json
{
  "status": 1,
  "message": "Compleated Flag Updated",
  "data": ""
}
```

---

## Push Notifications

### 38. Send Push Notification

**Endpoint:** `POST /api/push_notification/add`  
**Authentication:** Required

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ids` | array | Yes | Array of user IDs |
| `data` | object | Yes | Notification data |
| `data_message` | string | No | Notification message |

**Structure:**
```json
{
  "ids": [
    {
      "user_id": 1,
      "silent_push": 0
    }
  ],
  "data": {
    "key": "value"
  },
  "data_message": "Notification message"
}
```

#### Response

**Success:**
```json
{
  "status": 1,
  "message": "Notification sent successfully",
  "data": ""
}
```

**Error:**
```json
{
  "status": 2,
  "message": "Notification not sent",
  "data": ""
}
```

---

## Download Endpoints

All download endpoints support pagination and filtering:

**Query Parameters:**
- `limit` (integer): Number of records per page
- `part_no` (integer): Page number (0-indexed)
- `update_date` (string): Filter by updated date (format: Y-m-d H:i:s)
- `id` (integer): Get specific record by ID

**Response Format:**
- If data exists: `{"data": [...]}`
- If no data: `{"data": [], "updated_date": "Y-m-d H:i:s"}`

---

### 39. Download Users

**Endpoint:** `GET /api/users/download`  
**Authentication:** Required

---

### 40. Download Salesmen

**Endpoint:** `GET /api/sales_man/download`  
**Authentication:** Required

---

### 41. Download Suppliers

**Endpoint:** `GET /api/suppliers/download`  
**Authentication:** Required

---

### 42. Download Customers

**Endpoint:** `GET /api/customer/download`  
**Authentication:** Required

---

### 43. Download Units

**Endpoint:** `GET /api/units/download`  
**Authentication:** Required

---

### 44. Download Categories

**Endpoint:** `GET /api/category/download`  
**Authentication:** Required

---

### 45. Download Sub Categories

**Endpoint:** `GET /api/sub_category/download`  
**Authentication:** Required

---

### 46. Download User Categories

**Endpoint:** `GET /api/user_category/download`  
**Authentication:** Required

---

### 47. Download Product Units

**Endpoint:** `GET /api/product_units/download`  
**Authentication:** Required

---

### 48. Download Products

**Endpoint:** `GET /api/products/download`  
**Authentication:** Required

**Response includes photo URLs:**
```json
{
  "data": [
    {
      "id": 1,
      "name": "Product Name",
      "code": "PROD001",
      "photo": "http://yourdomain.com/LaravelProject/public/uploads/products/filename.jpeg",
      ...
    }
  ]
}
```

---

### 49. Download Product Cars

**Endpoint:** `GET /api/product_cars/download`  
**Authentication:** Required

---

### 50. Download Routes

**Endpoint:** `GET /api/routes/download`  
**Authentication:** Required

---

### 51. Download Car Brands

**Endpoint:** `GET /api/cars/download_car_brands`  
**Authentication:** Required

---

### 52. Download Car Names

**Endpoint:** `GET /api/cars/download_car_names`  
**Authentication:** Required

---

### 53. Download Car Models

**Endpoint:** `GET /api/cars/download_car_models`  
**Authentication:** Required

---

### 54. Download Car Versions

**Endpoint:** `GET /api/cars/download_car_versions`  
**Authentication:** Required

---

### 55. Download Orders

**Endpoint:** `GET /api/orders/download_orders`  
**Authentication:** Required

**Additional Query Parameters:**
- `user_type` (integer): User type filter
- `user_id` (integer): User ID filter

**Note:** If `user_type` is 3 (Salesman), filters by `order_salesman_id`.

**Response includes items and suggestions if `id` is provided:**
```json
{
  "data": [
    {
      "id": 1,
      "order_inv_no": 1001,
      "items": [
        {
          "id": 1,
          "suggestions": [...]
        }
      ],
      ...
    }
  ]
}
```

---

### 56. Download Order Sub

**Endpoint:** `GET /api/orders/download_order_sub`  
**Authentication:** Required

**Additional Query Parameters:**
- `user_type` (integer): User type filter
- `user_id` (integer): User ID filter

**Note:** If `user_type` is 3 (Salesman), filters by `order_sub_salesman_id`.

---

### 57. Download Order Sub Suggestions

**Endpoint:** `GET /api/orders/download_order_sub_suggestions`  
**Authentication:** Required

**Additional Query Parameters:**
- `user_type` (integer): User type filter
- `user_id` (integer): User ID filter

**Note:** Filters suggestions based on order sub records for the specified user.

---

### 58. Download Out of Stocks

**Endpoint:** `GET /api/out_of_stock/download_out_of_stocks`  
**Authentication:** Required

**Additional Query Parameters:**
- `user_type` (integer): User type filter
- `user_id` (integer): User ID filter

**Note:** If `user_type` is 2 (Stock Keeper), filters by `outos_stock_keeper_id`.

---

### 59. Download Out of Stock Sub

**Endpoint:** `GET /api/out_of_stock/download_out_of_stock_sub`  
**Authentication:** Required

**Additional Query Parameters:**
- `user_type` (integer): User type filter
- `user_id` (integer): User ID filter

**Note:** 
- If `user_type` is 2 (Stock Keeper), filters by `outos_sub_stock_keeper_id`.
- If `user_type` is 4 (Supplier), filters by `outos_sub_supp_id`.

---

## Common Response Formats

### Success Response
```json
{
  "status": 1,
  "message": "Operation successful",
  "data": {...}
}
```

### Validation Error
```json
{
  "status": 0,
  "message": "validation Error",
  "data": [
    "The name field is required.",
    "The code has already been taken."
  ]
}
```

### Not Found Error
```json
{
  "status": 0,
  "message": "Resource not found"
}
```

### Authentication Error (401)
```json
{
  "message": "Unauthenticated."
}
```

---

## Important Notes

1. **Authentication:** Most endpoints require a valid Sanctum bearer token. Get the token from the login endpoint.

2. **Rate Limiting:** Authenticated endpoints are limited to 200 requests per minute.

3. **Image Upload:** Product images must be base64 encoded with data URI prefix: `data:image/{type};base64,{data}`

4. **UUID Pattern:** Orders and Out of Stock records use UUID for retrieval. If UUID exists, returns existing record instead of creating new.

5. **User Categories:**
   - `cat_id = 3`: SalesMan
   - `cat_id = 4`: Supplier
   - Other IDs: Admin or other user types

6. **Soft Deletes:** User deletion sets `flag = 0` (soft delete).

7. **Automatic Records:** 
   - Product creation automatically creates ProductUnit
   - User registration (cat_id 3 or 4) creates SalesMan or Supplier records

8. **Date Formats:** Use `Y-m-d H:i:s` format for date/time fields.

9. **Pagination:** Download endpoints use `limit` and `part_no` for pagination (0-indexed).

10. **Notifications:** Many endpoints support optional `notification` parameter for push notifications.

---

## Testing

### Example cURL Request

```bash
# Login
curl -X POST "https://yourdomain.com/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "USR001",
    "password": "password123"
  }'

# Add Product (with token)
curl -X POST "https://yourdomain.com/api/products/add" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Product Name",
    "code": "PROD001",
    "price": "100.00"
  }'
```

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-27

