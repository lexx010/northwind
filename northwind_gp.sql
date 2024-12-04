SELECT table_name AS name,
       table_type AS type
  FROM information_schema.tables
 WHERE table_schema = 'public' AND table_type IN ('BASE TABLE', 'VIEW');
 
 
SELECT *
  FROM information_schema.columns
  WHERE table_name = 'orders';
  
 SELECT *
   FROM orders
   LIMIT 5;
 
 
SELECT *
  FROM information_schema.columns
  WHERE table_name = 'customers';
  
 SELECT *
   FROM customers
   LIMIT 5;
  
SELECT *
  FROM information_schema.columns
  WHERE table_name = 'employees';
  
 SELECT *
   FROM employees
   LIMIT 10;


-- Combine orders and customers
--Analizing data that exists in both tables, for example, the query below retrieves all orders that are linked to  a customer, in addition it shows the customers` country. 

SELECT o.order_id, o.order_date,o.shipped_date, c.company_name, c.country
  FROM orders AS o
  JOIN customers AS c
    ON o.customer_id = c.customer_id;
    

--Combine order_details, products, and orders tables to get detailed order information, including the product name and quantity.
SELECT 
    o.order_id,
    o.order_date,
    p.product_name,
    od.quantity
FROM 
    orders AS o
JOIN 
    order_details AS od 
    ON o.order_id = od.order_id
JOIN 
    products AS p 
    ON od.product_id = p.product_id;


--Combine employees and orders tables to see who is responsible for each order.
SELECT o.order_id, o.order_date, e.first_name, e.last_name, e.title
  FROM orders AS o
  JOIN employees AS e
    ON o.employee_id = e.employee_id;



--3. Ranking Employee Sales Performance
-- --rank employees based on their total sales amount


WITH Employee_Sales AS (
    SELECT e.employee_id, e.first_name, e.last_name,
           SUM(od.unit_price * od.quantity * (1 - od.discount)) AS total_sales
      FROM orders AS o
      JOIN employees AS e
        ON o.employee_id = e.employee_id
      JOIN order_details AS od
        ON od.order_id =  o.order_id
      GROUP BY e.employee_id
)

SELECT employee_id, first_name, last_name,
       RANK() OVER(ORDER BY total_sales DESC) AS Sales_Rank
  FROM Employee_Sales;

-- 4 Running Total of Monthly Sales
WITH Monthly_Sales AS (
	SELECT DATE_TRUNC('month', o.order_date)::DATE AS "Month",
       	   SUM(od.unit_price * od.quantity * (1 - od.discount)) AS total_sales
  	  FROM orders AS o
      JOIN order_details As od
        ON o.order_id =od.order_id
     GROUP BY DATE_TRUNC('month', o.order_date)
)

SELECT "Month",
        SUM(total_sales) OVER(ORDER BY "Month") AS Running_Total
  FROM Monthly_Sales
  ORDER BY "Month";

-- 5 Month-Over-Month Sales Growth
-- CTE to calculate total sales for each month	   
WITH Monthly_Sales AS (
    SELECT
        EXTRACT(YEAR FROM o.order_date) AS year,
        EXTRACT(MONTH FROM o.order_date) AS month,
        SUM(od.unit_price * od.quantity * (1 - od.discount)) AS total_sales
    FROM
        orders AS o
    JOIN
        order_details AS od 
	  ON o.order_id = od.order_id
    GROUP BY
        EXTRACT(YEAR FROM o.order_date),
        EXTRACT(MONTH FROM o.order_date)
),
-- CTE to get total sales of the previous month using LAG()
Sales_WithLag AS (
    SELECT
        year,
        month,
        total_sales,
        LAG(Total_Sales) OVER (ORDER BY year, month) AS prev_month_sales
    FROM
        Monthly_Sales
)

-- Main query to calculate the month-over-month sales growth rate
SELECT
    year,
    month,
    total_sales,
    prev_month_sales,
    CASE 
        WHEN prev_month_sales IS NULL THEN NULL
        ELSE (total_sales / prev_month_sales - 1) * 100
    END AS sales_growth_rate
FROM
    Sales_WithLag
ORDER BY
    year, month;
	   
--6  Identifying High-Value Customers
WITH Order_Values AS (
    SELECT o.order_id, o.customer_id,
           SUM(od.unit_price * od.quantity * (1 - od.discount)) AS order_value
      FROM orders AS o
	  JOIN order_details As od
        ON o.order_id =od.order_id
	  GROUP BY o.customer_id, o.order_id
)
SELECT customer_id, order_id, order_value,
  CASE
      WHEN order_value > (SELECT AVG(order_value) 
	                        FROM Order_Values) THEN 'Above Average'
	  ELSE 'Below Average'
  END AS "Value Category"
  FROM Order_Values
  LIMIT 10;
    
--Percentage of Sales for Each Category
WITH Category_Sales AS (
    SELECT c.category_id, c.category_name,
           SUM(od.unit_price * od.quantity * (1 - od.discount)) AS total_sales
      FROM categories AS c
	  JOIN products As p
        ON c.category_id =p.category_id
	  JOIN order_details AS od
	    ON p.product_id = od.product_id
	  GROUP BY c.category_id
)
SELECT category_id, category_name, 
       ROUND((total_sales::numeric / SUM(total_sales::numeric) OVER()) * 100, 2) AS sales_percentage
  FROM Category_Sales;

--8 Top Products Per Category
WITH Product_Sales AS (
	SELECT p.product_id, p.product_name,c.category_id, c.category_name,
		   SUM(od.unit_price * od.quantity * (1 - od.discount)) AS total_sales
	  FROM products AS p 
	  JOIN categories AS c
		ON p.category_id = c.category_id
	  JOIN order_details AS od
		ON p.product_id = od.product_id
	  GROUP BY c.category_id, p.product_id
),
Ranked_Products AS (
    SELECT product_id, product_name,category_id, category_name, total_sales,
	ROW_NUMBER() OVER (PARTITION BY category_id
	                   ORDER BY total_sales DESC) AS rn
	  FROM Product_Sales
)
SELECT category_id,product_id, product_name, total_sales, rn
  FROM Ranked_Products
  WHERE rn <= 3
  ORDER BY category_id, rn;



-- 9Identify the top 20% of customers by total purchase volume
WITH Customer_Purchases  AS (
   SELECT c.customer_id, c.company_name,
          SUM(od.quantity * od.unit_price) AS total_purchase
     FROM customers AS c
	 JOIN orders AS o
	   ON c.customer_id = o.customer_id
	 JOIN order_details AS od
	   ON o.order_id = od.order_id
	 GROUP BY c.customer_id, c.company_name
),
Ranked_Customers AS (
    SELECT customer_id, 
           company_name, 
           total_purchase,
           PERCENT_RANK() OVER (ORDER BY total_purchase DESC) AS purchase_rank
    FROM Customer_Purchases
)

SELECT customer_id, company_name, total_purchase,
       PERCENT_RANK() OVER(ORDER BY total_purchase DESC ) AS purchase_rank
  FROM Ranked_Customers
  WHERE purchase_rank <= 0.2
  ORDER BY total_purchase DESC;

