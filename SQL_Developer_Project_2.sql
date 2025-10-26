
create table products
(product_id serial primary key,
sku varchar(50) unique not null,
name varchar(50) not null,
description text,
uom varchar(50),
cost_price numeric(10,2) default 0,
selleing_price numeric(10,2) default 0,
reorder_level int default 0,
reorder_quantity int default 0,
is_active boolean default TRUE,
created_at timestamp default current_timestamp,
updated_at timestamp default current_timestamp
);

create table warehouses
(warehouse_id serial primary key,
name varchar(255) not null,
address text,
contact varchar(100),
created_at timestamp default current_timestamp
);

create table suppliers
(supplier_id serial primary key,
name varchar(255) not null,
contact_person varchar(100),
phone varchar(50),
email varchar(100),
lead_time_days int default 7,
created_at timestamp default current_timestamp
);

create table product_suppliers (
    product_id INT references products(product_id) on delete cascade,
    supplier_id INT references suppliers(supplier_id) on delete cascade,
    supplier_sku VARCHAR(100)
);

create table stock (
    product_id INT references products(product_id)  on delete cascade,
    warehouse_id INT references warehouses(warehouse_id)  on delete cascade,
    quantity NUMERIC(18,4) default 0,
    last_updated TIMESTAMP default current_timestamp
);

create table stock_movements (
    movement_id BIGSERIAL primary key,
    product_id INT references products(product_id) on delete cascade,
    from_warehouse_id INT references warehouses(warehouse_id),
    to_warehouse_id INT references warehouses(warehouse_id),
    movement_type VARCHAR(20) check (movement_type in ('purchase','sale','adjustment','transfer')),
    quantity NUMERIC(18,4) not null,
    unit_cost NUMERIC(12,4),
    reference VARCHAR(255),
    created_by VARCHAR(100),
    created_at TIMESTAMP default current_timestamp
);

create table notifications (
    notification_id bigserial primary key,
    product_id int references products(product_id),
    warehouse_id int references warehouses(warehouse_id),
    notification_type varchar(30) check (notification_type IN ('low_stock','reorder_created','stock_adjusted')),
    message text,
    is_read boolean default FALSE,
    created_at timestamp default current_timestamp
);

-- PRODUCTS
insert into products (sku, name, description, uom, cost_price, selleing_price, reorder_level, reorder_quantity)
select
    'SKU-' || LPAD(i::text, 4, '0'),
    'Product ' || i,
    'Description for Product ' || i,
    (ARRAY['pcs','kg','litre','box'])[ceil(random()*4)],
    ROUND((50 + random() * 200)::numeric, 2),
    ROUND((100 + random() * 400)::numeric, 2),
    floor(random() * 50 + 10),
    floor(random() * 20 + 5)
from generate_series(1, 50) AS s(i);

select*from products

-- WAREHOUSES
insert into warehouses (name, address, contact)
select 
    'Warehouse ' || i,
    'Address for Warehouse ' || i,
    '+91-98' || floor(random() * 100000000)::text
from generate_series(1, 5) AS s(i);

select*from warehouses

-- SUPPLIERS
insert into suppliers (name, contact_person, phone, email, lead_time_days)
select 
    'Supplier ' || i,
    'Person ' || i,
    '+91-97' || floor(random() * 100000000)::text,
    'supplier' || i || '@mail.com',
    floor(random() * 10 + 3)
from generate_series(1, 15) AS s(i);

select*from suppliers

INSERT INTO product_suppliers (product_id, supplier_id, supplier_sku)
SELECT 
    p.product_id,
    s.supplier_id,
    'SUP-' || p.product_id || '-' || s.supplier_id
FROM products p
JOIN LATERAL (
    SELECT supplier_id FROM suppliers ORDER BY random() LIMIT (1 + FLOOR(random()*3))
) s ON true;

select*from product_suppliers

INSERT INTO stock (product_id, warehouse_id, quantity)
SELECT 
    p.product_id,
    w.warehouse_id,
    ROUND((random() * 500)::numeric, 2)
FROM products p
CROSS JOIN warehouses w
WHERE random() < 0.8;  -- 80% chance product exists in that warehouse

select*from stock


INSERT INTO stock_movements (
    product_id, from_warehouse_id, to_warehouse_id, movement_type, quantity, unit_cost, reference, created_by
)
SELECT 
    p.product_id,
    CASE WHEN random() < 0.3 THEN w1.warehouse_id ELSE NULL END,
    CASE WHEN random() < 0.3 THEN w2.warehouse_id ELSE NULL END,
    (ARRAY['purchase','sale','transfer','adjustment'])[ceil(random()*4)],
    ROUND((random() * 100)::numeric, 2),
    ROUND(p.cost_price::numeric, 2),
    'REF-' || FLOOR(random()*10000),
    (ARRAY['admin','system','user1','user2'])[ceil(random()*4)]
FROM products p
JOIN warehouses w1 ON true
JOIN warehouses w2 ON true
WHERE random() < 0.1; -- to keep around 50 movements

select*from stock_movements

INSERT INTO notifications (product_id, warehouse_id, notification_type, message)
SELECT 
    s.product_id,
    s.warehouse_id,
    (ARRAY['low_stock','reorder_created','stock_adjusted'])[ceil(random()*3)],
    'Notification for Product ' || s.product_id || ' in Warehouse ' || s.warehouse_id
FROM stock s
WHERE random() < 0.3;

select*from notifications

-- Data Analysis--
select*from products
select*from warehouses
select*from suppliers
select*from product_suppliers
select*from stock
select*from stock_movements
select*from notifications

--SECTION 1 — Inventory Overview & Summary
--View current stock by product & warehouse
select
p.name as product_name,
w.name as warehouse_name,
sum(quantity) as total_stock_product
from products as p
join
stock as s
on
p.product_id=s.product_id
join
warehouses as w
on
s.warehouse_id=w.warehouse_id
group by p.name,w.name
order by p.name asc,total_stock_product desc

--Check low-stock products
select
p.name as product_name,
w.name as warehouse_name,
p.reorder_level,
sum(s.quantity) as total_quantity
from products as p
join
stock as s
on
p.product_id=s.product_id
join
warehouses as w
on
s.warehouse_id=w.warehouse_id
group by p.name,w.name,p.reorder_level
having sum(s.quantity)<p.reorder_level

--Stock valuation
select*from products
select*from stock

select
p.name as product_name,
w.name as warehouse_name,
round(sum(p.cost_price*s.quantity)::numeric,2) as total_stock_value
from products as p
join
stock as s
on
p.product_id=s.product_id
join
warehouses as w
on
s.warehouse_id=w.warehouse_id
group by p.name,w.name
order by p.name,w.name asc

--Top 10 Most Valuable Products--
select
product_name,
total_value_of_stocks,
rnk
from
(select
p.name as product_name,
round(sum(p.cost_price*s.quantity)::numeric,2) as total_value_of_stocks,
dense_rank() over(order by sum(p.cost_price*s.quantity)desc) as rnk
from products as p
join
stock as s
on
p.product_id=s.product_id
group by p.name
) as t1
where rnk<=10

select*from products
select*from stock
select*from warehouses
select*from stock_movements
select*from notifications
select*from suppliers
select*from product_suppliers

--SECTION 2 — Supplier & Procurement Insights
--Supplier-Wise Product Count--
select
s.name,
count(ps.product_id) as total_product_counts
from suppliers as s
join
product_suppliers as ps
on
s.supplier_id=ps.supplier_id
group by s.name
order by s.name asc

--Average Lead Time of Suppliers--
select
supplier_id,
name as supplier_name,
round(avg(lead_time_days)::numeric,2) as average_lead_times
from suppliers
group by 1,2
order by 1 asc

--Top 5 Suppliers (by Total Product Value Supplied)
select
supplier_name,
total_cost_price_product,
rnk
from
(select
s.name as supplier_name,
sum(p.cost_price) as total_cost_price_product,
dense_rank() over(order by sum(p.cost_price)desc) as rnk
from suppliers as s
join
product_suppliers as ps
on
s.supplier_id=ps.supplier_id
join
products as p
on
ps.product_id=p.product_id
join
stock as st
on
p.product_id=st.product_id
group by s.name
) as t1
where rnk<=5
--SECTION 3 — Stock Movement Analytics
--Movement Type Summary
select
movement_type,
count(*) as total_products_moved,
round(sum(quantity)::numeric,0) as total_quantity
from stock_movements
group by 1

--Top 10 Products by Movement Volume
select
product_id,
product_name,
total_movements,
rnk
from
(select
p.product_id as product_id,
p.name as product_name,
count(*) as total_movements,
dense_rank() over(order by count(*)desc) as rnk
from stock_movements as s
join
products as p
on
s.product_id=p.product_id
group by 1,2
) as t1
where rnk<=10

--Most Active Warehouses in Transfers
select
sm.from_warehouse_id,
w.name as warehouse_name,
count(*) as total_transfers_made
from stock_movements as sm
left join
warehouses as w
on
sm.from_warehouse_id=w.warehouse_id
group by sm.from_warehouse_id,w.name
order by total_transfers_made desc

--SECTION 4 — Notifications & Alerts Summary
--Notification Summary by Type
select
notification_type,
count(notification_id) as total_number_of_notifications
from notifications
group by 1
order by 2 desc

-- warehouse wise
select
w.name as warehouse_name,
n.notification_type,
count(n.notification_id) as total_number_of_notifications
from notifications as n
join
warehouses as w
on
n.warehouse_id=w.warehouse_id
group by w.name,n.notification_type
order by w.name asc,total_number_of_notifications desc

--Unread Notifications
select
count(*) as total_unread_notifications
from notifications
where is_read='false'

--Top 5 Products with Most Alerts
select
product_name,
total_alerts,
rnk
from
(select
p.name as product_name,
count(*) as total_alerts,
dense_rank() over(order by count(*)desc) as rnk
from products as p
join
stock_movements as sm
on
p.product_id=sm.product_id
group by p.name
) as t1
where rnk<=5

--SECTION 5 — Profitability & Sales Potential
--Product-Wise Profit Margin %
select
product_name,
profit_margin,
rnk
from
(select
name as product_name,
concat(round((selleing_price-cost_price)::numeric/cost_price::numeric*100,2),'%') as profit_margin,
dense_rank() over(order by round((selleing_price-cost_price)::numeric/cost_price::numeric*100,2)desc) as rnk
from products 
) as t1
where rnk <=5

--Estimated Gross Profit (Based on Current Stock)
select
p.name as product_name,
round(sum((p.selleing_price-p.cost_price)*s.quantity)::numeric,2) as gross_profit
from products as p
join
stock as s
on
p.product_id=s.product_id
group by p.name
order by gross_profit desc

--Average Stock Level per Warehouse
select
w.name as warehouse_name,
round(avg(s.quantity)::numeric,2) as average_quantity
from warehouses as w
join
stock as s
on
s.warehouse_id=w.warehouse_id
group by w.name
order by w.name asc

--Warehouse-Wise Low Stock Products Count--
with low_stock_products
as 
(select
w.name as warehouse_name,
count(*) as total_low_stock_products
from warehouses as w
join
notifications as n
on
w.warehouse_id=n.warehouse_id
where notification_type='low_stock'
group by w.name
), total_products as
(select
w.name as warehouse_name,
count(*) as total_stock_products
from warehouses as w
join
notifications as n
on
w.warehouse_id=n.warehouse_id
group by w.name
)
select
lsp.warehouse_name,
lsp.total_low_stock_products,
tp.total_stock_products,
concat(round((lsp.total_low_stock_products::numeric/tp.total_stock_products::numeric)::numeric*100,2),'%') as low_stock_count_Percentage
from low_stock_products as lsp
join
total_products as tp
on
lsp.warehouse_name=tp.warehouse_name

--Products Never Moved (No Transactions)
select
product_id
from products
where product_id not in (select product_id from stock_movements)

--alternative--
select
p.product_id
--sm.movement_id
from products as p
left join
stock_movements as sm
on
p.product_id=sm.product_id
where sm.movement_id is null
order by p.product_id asc

--Stock Turnover Ratio (Approximation)
select
p.name as product_name,
round((sum(sm.quantity)::numeric/avg(s.quantity)::numeric)::numeric,2) as stock_turnover,
dense_rank() over(order by (sum(sm.quantity)::numeric/avg(s.quantity)::numeric)desc) as rnk
from stock_movements as sm
join 
stock as s
on
sm.product_id=s.product_id
join
products as p
on
s.product_id=p.product_id
group by p.name

-- Step 1: Function to check and insert notification

create or replace function fn_low_stock_trigger()
returns trigger
language plpgsql
as
$$
declare
v_reorder_level int;
v_total_stock numeric(18,4);
begin
 select
 reorder_level
 into v_reorder_level
 from products
 where product_id=new.product_id;

 select
 sum(quanity)
 into v_total_stock
 from stock
 where product_id=new.product_id;

 if v_total_stock<v_reorder_level then
  insert into notifications(product_id,warehouse_id,notification_type,message)
  values
  (         new.product_id,
            new.warehouse_id,
            'low_stock',
            concat('Low stock alert for product ID ', new.product_id,
                   ' | Current: ', v_total_stock,
                   ' | Reorder level: ', v_reorder_level
	)
 );
end if;
return new;
end;
$$;

 create trigger trg_low_stock_notifications
 after insert or update on stock
 for each row
 execute function fn_low_stock_trigger();

 

drop procedure if exists receive_purchase(p_product_id int,p_warehouse_id int,p_qty numeric,
p_unit_cost numeric,p_reference varchar,p_user varchar)
drop procedure if exists receive_purchase(p_product_id int,p_warehouse_id int,p_qty numeric,
p_unit_cost numeric,p_reference char,p_user char)
-- Store Procedure--
drop procedure if exists sp_receive_purchase(int,int,numeric,numeric,varchar,varchar)
create or replace procedure receive_purchase
(p_product_id int,
p_warehouse_id int,
p_qty numeric,
p_unit_cost numeric,
p_reference text,
p_user text)
language plpgsql
as
$$
begin
-- Step 1: Update or insert into STOCK
insert into stock(product_id, warehouse_id, quantity, last_updated)values (p_product_id,p_warehouse_id,p_qty,now())
on conflict(product_id,warehouse_id) 
do update set quantity=stock.quantity + excluded.quantity,last_updated=now();
--Step 2: Record the movement in STOCK_MOVEMENTS
insert into stock_movements(product_id,from_warehouse_id,to_warehouse_id,movement_type,quantity,unit_cost,reference,created_by)
values 
(p_product_id, NULL, p_warehouse_id, 'purchase', p_qty, p_unit_cost, p_reference, p_user);
-- Step 3: Optional - Insert a notification for restock
insert into notifications( product_id, warehouse_id, notification_type, message)
values
(p_product_id, p_warehouse_id, 'stock_adjusted', CONCAT('Stock replenished: ', p_qty, ' units added to warehouse ', p_warehouse_id) );
end;
$$;

call receive_purchase(10, 3, 2, 200, 150, 'PO_1023', 'Aman Alam');


































