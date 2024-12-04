SELECT o.order_id, o.order_date, c.customer_id, c.country,
       p.product_name, od.quantity, od.unit_price,
	   od.quantity * od.unit_price AS total_sales,
	   cat.category_name
  FROM orders AS o
  JOIN order_details AS od
    ON o.order_id = od.order_id
  JOIN products AS p
    ON od.product_id = p.product_id
  JOIN categories AS cat
    ON p.category_id = cat.category_id
  JOIN customers AS c
    ON c.customer_id = o.customer_id;
