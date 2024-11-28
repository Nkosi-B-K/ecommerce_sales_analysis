USE ecommerce;

ALTER TABLE order_details CHANGE `Sub-Category` sub_category VARCHAR(25);
ALTER TABLE order_details CHANGE `Order ID` order_id VARCHAR(25);
ALTER TABLE order_list CHANGE `Order ID` order_id VARCHAR(25);
ALTER TABLE order_list CHANGE `Order Date` order_date VARCHAR(25);
ALTER TABLE order_list CHANGE `CustomerName`customer_name VARCHAR(25);
ALTER TABLE sales_target CHANGE `Month of Order Date` month_of_order VARCHAR(25);


SELECT * FROM order_list;


SELECT order_date
FROM order_list
ORDER BY order_date desc
LIMIT 10;

SELECT * FROM sales_target;

#Combining the order_detailS table with the order_list table
 CREATE VIEW combined_orders as
 SELECT d.order_id, d.amount, d.profit, d.quantity, d.category, d.sub_category, l.order_date, l.customer_name, l.state, l.city
 FROM order_details AS d
 INNER JOIN order_list AS l
 ON d.order_id = l.order_id;
 
 #Segmeneting customers based on RFM Metrics
 -- Combine the order_detail table with order_list table

-- Segmenting the customers into groups based on RFM model
CREATE VIEW customer_grouping AS
SELECT
    *,
    CASE
        WHEN (R > 4 AND R <= 5) AND (((F+M)/2 > 4) AND ((F+M)/2) <= 5) THEN 'Champions'
        WHEN (R > 2 AND R <= 5) AND (((F+M)/2 > 3) AND ((F+M)/2) <= 5) THEN 'Loyal Customers'
        WHEN (R > 3 AND R <= 5) AND (((F+M)/2 > 1) AND ((F+M)/2) <= 3) THEN 'Potential Loyalist'
        WHEN (R > 4 AND R <= 5) AND (((F+M)/2 >= 0) AND ((F+M)/2) <= 1) THEN 'New Customers'
        WHEN (R > 3 AND R <= 4) AND (((F+M)/2 >= 0) AND ((F+M)/2) <= 1) THEN 'Promising'
        WHEN (R > 2 AND R <= 3) AND (((F+M)/2 >= 2) AND ((F+M)/2) <= 3) THEN 'Customers Needing Attention'
        WHEN (R > 2 AND R <= 3) AND (((F+M)/2 > 0) AND ((F+M)/2) < 2) THEN 'About to Sleep'
        WHEN (R > 0 AND R <= 2) AND (((F+M)/2 > 2) AND ((F+M)/2) < 5) THEN 'At Risk'
        WHEN (R >= 0 AND R <= 1) AND (((F+M)/2 > 4) AND ((F+M)/2) <= 5) THEN 'Can\'t Lose Them'
        WHEN (R >= 1 AND R <= 2) AND (((F+M)/2 >= 1) AND ((F+M)/2) <= 2) THEN 'Hibernating'
        WHEN (R >= 0 AND R <= 2) AND (((F+M)/2 > 0) AND ((F+M)/2) < 2) THEN 'Lost'
    END AS customer_segment
FROM (
    SELECT 
        MAX(STR_TO_DATE(order_date, '%d-%m-%Y')) AS latest_order_date,
        Customer_Name,
        DATEDIFF(STR_TO_DATE('31-03-2019', '%d-%m-%Y'), MAX(STR_TO_DATE(order_date, '%d-%m-%Y'))) AS recency,
        COUNT(DISTINCT order_id) AS frequency,
        SUM(Amount) AS monetary,
        NTILE(5) OVER (ORDER BY DATEDIFF(STR_TO_DATE('31-03-2019', '%d-%m-%Y'), MAX(STR_TO_DATE(order_date, '%d-%m-%Y'))) DESC) AS R,
        NTILE(5) OVER (ORDER BY COUNT(DISTINCT order_id) DESC) AS F,
        NTILE(5) OVER (ORDER BY SUM(Amount) DESC) AS M
    FROM combined_orders
    GROUP BY Customer_Name
) AS rfm_table;

-- Returning the number & percentage of each customer segment
SELECT
    customer_segment,
    COUNT(DISTINCT Customer_Name) AS num_of_customers,
    ROUND(COUNT(DISTINCT Customer_Name) / (SELECT COUNT(*) FROM customer_grouping) * 100, 2) AS pct_of_customers
FROM customer_grouping
GROUP BY customer_segment
ORDER BY pct_of_customers DESC;

# Retrieving the number of orders, customers, cities and states
SELECT 	COUNT(DISTINCT order_id) AS orders_count,
		COUNT(DISTINCT customer_name) AS customers_count,
        COUNT(DISTINCT city) AS cities_count,
        COUNT(DISTINCT state) AS states_count
FROM combined_orders;

SELECT * FROM combined_orders;

#Top 5 new Customers
SELECT customer_name, state, city, SUM(amount) AS total_spent
FROM combined_orders
WHERE customer_name NOT IN (
    SELECT DISTINCT customer_name
    FROM combined_orders
    WHERE YEAR(STR_TO_DATE(order_date, "%d-%m-%Y")) = 2018
)
AND YEAR(STR_TO_DATE(order_date, "%d-%m-%Y")) = 2019
GROUP BY customer_name, state, city
ORDER BY total_spent DESC
LIMIT 5;

#Top 10 most profitable states and cities
SELECT 	State,
		City,
        SUM(profit) as total_profit,
        SUM(quantity) as total_quantity,
        COUNT(DISTINCT customer_name) as customer_count
FROM combined_orders
GROUP BY state, city
ORDER BY total_profit DESC
LIMIT 10;

#First order in each state
SELECT order_date, order_id, state, customer_name
FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY state ORDER BY state, order_id)
	AS RowNumberPerState
From combined_orders)firstorder
WHERE RowNumberPerState = 1
ORDER BY order_id;

#Sales by day
SELECT
		day_of_order,
        LPAD('*', num_of_orders, '*') AS num_of_orders,
        sales
FROM
	(SELECT
		DAYNAME(STR_TO_DATE(order_date, '%d-%m-%Y')) AS day_of_order,
        COUNT(DISTINCT order_id) as num_of_orders,
        SUM(Quantity) AS quantity,
        SUM(Amount) AS sales
	FROM combined_orders
    GROUP BY day_of_order) sales_per_day
ORDER BY sales DESC;

#Monthly profitability & monthly quantity sold
SELECT 
    CONCAT(MONTHNAME(STR_TO_DATE(order_date, '%d-%m-%Y')), "-", YEAR(STR_TO_DATE(order_date, '%d-%m-%Y'))) AS month_of_year,
    SUM(profit) AS total_profit,
    SUM(quantity) AS total_quantity
FROM combined_orders
WHERE STR_TO_DATE(order_date, '%d-%m-%Y') IS NOT NULL
GROUP BY month_of_year
ORDER BY MIN(STR_TO_DATE(order_date, '%d-%m-%Y')) ASC;

#finding the sales for each category in each month

CREATE VIEW sales_by_category AS 
SELECT CONCAT(MONTHNAME(STR_TO_DATE(order_date, '%d-%m-%Y')), "-", YEAR(STR_TO_DATE(order_date, '%d-%m-%Y'))) AS order_monthyear, 
Category,
SUM(Amount) AS Sales
FROM combined_orders
GROUP BY order_monthyear, Category;

SELECT * FROM sales_by_category;

#CHecking if the sales hit the target set for each category


CREATE VIEW sales_vs_target AS
SELECT *, CASE
			WHEN Sales > Target THEN 'Reached'
            ELSE 'Short'
            END AS reached_or_short
FROM
	(SELECT s.order_monthyear, s.category, s.sales, t.month_of_order, t.target
FROM sales_by_category AS s
INNER JOIN sales_target AS t 
ON s.category = t.category) st;
    
SELECT * FROM sales_vs_target;

#viewing the number of times the target is met and not met
SELECT h.Category, h.Reached, f.Short
FROM
	(SELECT Category, COUNT(*) AS Reached
    FROM sales_vs_target
    WHERE reached_or_short LIKE 'Reached'
    GROUP BY Category) h 
INNER JOIN
	(SELECT Category, COUNT(*) AS Short
    FROM sales_vs_target
    WHERE reached_or_short LIKE 'Short'
    GROUP BY Category) f
ON h.Category = f.Category;

#finding order quantity, profit, amount for each subcategory

CREATE VIEW order_details_by_total AS
SELECT Category, sub_category,
SUM(Quantity) AS total_order_quantity,
SUM(Profit) AS total_profit,
SUM(Amount) AS total_amount
FROM Order_details
GROUP BY category, sub_category
ORDER BY total_order_quantity desc;

SELECT * FROM order_details_by_total;

#looking into maximum cost per unit & maximum price per unit for each subcatergory

CREATE VIEW order_details_by_unit AS
SELECT 
    Category, sub_category, MAX(cost_per_unit) AS max_cost, MAX(price_per_unit) AS max_price
FROM 
    (SELECT 
        Category, 
        sub_category, 
        ROUND((Amount - Profit) / Quantity, 2) AS cost_per_unit, 
        ROUND(Amount / Quantity, 2) AS price_per_unit
     FROM order_details
    ) AS c
GROUP BY Category, sub_category
ORDER BY max_cost DESC;

SELECT * FROM order_details_by_unit;

#combining order details by unit table and order details by total table
SELECT t.category, t.sub_category, t.total_order_quantity, t.total_profit, t.total_amount, u.max_cost, u.max_price
FROM order_details_by_total AS t
INNER JOIN order_details_by_unit AS u
ON t.sub_category=u.sub_category;




