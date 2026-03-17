CREATE TABLE order_items(
order_item_id INT PRIMARY KEY,
order_id INT,
product_id INT,
quantity INT,
unit_price DECIMAL,
discount_amount DECIMAL,
subtotal DECIMAL
)

CREATE TABLE returns (
return_id INT PRIMARY KEY,
order_item_id INT,
return_date DATE,
return_reason TEXT,
refund_amount DECIMAL,
return_status TEXT
)

CREATE TABLE customers (
customer_id INT PRIMARY KEY,
first_name TEXT,
last_name TEXT,
email TEXT,
phone INT,
registration_date DATE,
acquisition_chanel TEXT,
city TEXT,
state TEXT,
country TEXT
);

CREATE TABLE orders (
order_id INT PRIMARY KEY,
customer_id INT,
order_date DATE,
total_amount DECIMAL,
order_status TEXT,
shipping_cost DECIMAL,
payment_method TEXT
)

CREATE TABLE categories (
category_id INT PRIMARY KEY,
category_name TEXT,
description TEXT
)

CREATE TABLE suppliers (
supplier_id INT PRIMARY KEY,
supplier_name TEXT,
contact_email TEXT,
country TEXT,
rating DECIMAL,
is_active TEXT
)

CREATE TABLE reviews (
review_id INT PRIMARY KEY,
product_id INT,
customer_id INT,
rating INT,
review_text TEXT,
review_date DATE
)

CREATE TABLE products (
product_id INT PRIMARY KEY,
product_name TEXT,
category_id INT,
supplier_id INT,
unit_price DECIMAL,
unit_cost DECIMAL,
stock_quantity INT,
is_active TEXT,
created_date DATE
)