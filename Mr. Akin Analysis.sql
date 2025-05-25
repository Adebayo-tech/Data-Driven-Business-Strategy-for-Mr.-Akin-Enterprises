-- Basic information needed to see how well
-- Mr. Akin's bussiness is doing, which are;
-- Revenue, Profit, Cost, Profit Margin,
-- Total Quantity Sold, Total Qunatity in stock...
-- Find Revenue, Cost and Profit, Total quantity
-- sold, total qunatity in stock and profit margin
WITH data1 AS (
    SELECT
    o.order_id,
    p.price,
    p.cost,
    oi.quantity,
    oi.discount
    FROM orders o
    JOIN order_items oi
    ON o.order_id = oi.order_id
    JOIN products p
    ON p.product_id = oi.product_id
),
data2 AS (
    SELECT
    order_id,
    SUM((price * quantity)-discount) AS Revenue,
    SUM(cost * quantity) AS Total_cost,
    SUM(quantity) Total_quantity
    FROM data1
    GROUP BY order_id
)
SELECT
SUM(Revenue) AS Total_Revenue,
SUM(Total_cost) AS Total_Cost,
SUM(Total_quantity) AS Total_Quantity,
(SELECT SUM(stock_quantity) FROM products) AS Total_quantity_in_stock,
ROUND(SUM(Revenue-Total_cost),0) AS Profit,
CONCAT(ROUND((Revenue-Total_cost)*100/Revenue,2),"%") AS Profit_margin
FROM data2;

--Insights
-- A Revenue of 364,819,805 was generated which
-- reflects strong revenue generation.
-- A total of 246,802,271 was spent, and a profit
-- of 118,017,533 was made genarating a profit
-- margin of 54.73% suggesting a strong bussiness.
-- A total 9,965 stocks are sold with 5,370 stocks
-- remaining in the store as for 2025-01-01.

-- Regional(state) Analysis

-- What does each state generates in terms of;
-- revenue,
-- percentage of quantity sold,
--  and profit margin
WITH info AS (
    SELECT
    c.state,
    p.price,
    p.cost,
    oi.quantity,
    oi.discount
    FROM orders o
    JOIN order_items oi
    ON o.order_id = oi.order_id
    JOIN products p
    ON p.product_id = oi.product_id
    JOIN customers c
    ON c.customer_id = o.customer_id
),
Revenue AS (
    SELECT
    state,
    SUM(cost) Total_cost,
    SUM((price*quantity)-discount) Revenue,
    SUM(((price*quantity)-discount)-cost) Profit,
    SUM(quantity) Quantity_sold,
    (SELECT SUM(quantity) FROM info) Total_Quantity_Sold
    FROM info
    GROUP BY state
)
SELECT
state,
Revenue,
Profit,
CONCAT(ROUND(Profit/Revenue*100,2),"%") Profit_margin,
Quantity_sold,
CONCAT(ROUND(CAST(Quantity_sold AS REAL)*100/
    Total_Quantity_Sold,2),"%") PercentageOfQuantitySold
FROM Revenue
ORDER BY 2 DESC;


-- Top 3 products by quantity sold from each region
SELECT * 
FROM (
SELECT 
  state,
  product_name,
  SUM(quantity) Total_Quantity,
  ROW_NUMBER() OVER (PARTITION BY state ORDER BY SUM(quantity)DESC) Ranks 
FROM customers c
JOIN orders o 
  ON c.customer_id = o.customer_id
JOIN order_items oi
  ON o.order_id = oi.order_id
JOIN products p
  ON oi.product_id = p.product_id
GROUP BY c.state, p.product_name
) t
WHERE Ranks <= 3;

-- RFM Analysis
WITH data AS (
    SELECT c.customer_id,
    CONCAT(first_name," ",last_name) Customer_name,
    c.phone,
    o.order_id,
    o.order_date,
    oi.unit_price,
    oi.quantity
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
),
Data2 AS (
    SELECT customer_id,
    customer_name,
    phone,
    order_id,
    order_date,
    SUM(quantity*unit_price) Total_sales,
    (SELECT MAX(order_date) FROM data) max_date,
    (SELECT MAX(order_date) FROM data WHERE customer_id = t1.customer_id) cus_las
    FROM data t1
    GROUP BY 1,2
),
RFM_data AS (
    SELECT
    customer_id,
    customer_name,
    phone,
    order_id,
    order_date,
    Total_sales,
    julianday(max_date) - julianday(cus_las) Recency,
    COUNT(DISTINCT order_id) Frequency,
    SUM(Total_sales) Monetary
    FROM Data2
    GROUP BY 1
),
final_metrics AS (
    SELECT
    customer_id,
    customer_name,
    phone,
    order_id,
    NTILE(4) OVER(ORDER BY Recency DESC) R,
    NTILE(4) OVER(ORDER BY Frequency ASC) F,
    NTILE(4) OVER(ORDER BY Monetary ASC) M
    FROM RFM_data
    ORDER BY 5,6,7
)
SELECT
Customer_id,
customer_name,
phone,
RFM_score,
CASE
WHEN RFM_score = "111" OR RFM_score = "122" OR RFM_score = "133"
THEN "New & Developing Customers"
WHEN RFM_score = "222" OR RFM_score = "233"
THEN "Core Regular Customers"
WHEN RFM_score = "311" OR RFM_score = "322" OR RFM_score = "333"
THEN "High Potential But Dormant Customers"
WHEN RFM_score = "411" OR RFM_score = "422" OR RFM_score = "433"
THEN "Lost Customers"
WHEN RFM_score = "211"
THEN "Mid Value One Time Buyers"
WHEN RFM_score = "144" OR RFM_score = "244" OR RFM_score = "344" OR RFM_score = "444"
THEN "Strategic Focus Customers"
END Segment
FROM (
    SELECT *,
    CONCAT(R,F,M) AS RFM_score
    FROM final_metrics) t;
    
    
    
-- Market Basket Analysis 
WITH products_info AS (
    SELECT *
    FROM orders o
    JOIN order_items oi
    ON o.order_id = oi.order_id
    JOIN products p
    ON oi.product_id = p.product_id
),
Basket AS (
    SELECT
    t1.product_name LHS,
    t2.product_name RHS
    FROM products_info t1
    JOIN products_info t2
    ON t1.order_id = t2.order_id
    AND t1.product_name > t2.product_name
),
Frequency AS (
    SELECT
    LHS,
    RHS,
    COUNT(*) AS frequency,
    (SELECT COUNT(DISTINCT order_id)
        FROM orders) Total_Transaction
    FROM Basket
    GROUP BY LHS,RHS
),
Support AS(
    SELECT *,
    ROUND(CAST(frequency AS REAL)*100/Total_Transaction,2) Support
    FROM Frequency),
Frequencies AS (
    SELECT
    Product_name,
    COUNT(DISTINCT order_id) AS Product_frequency
    FROM products_info
    GROUP BY product_name
),
Metrics AS (
    SELECT
    s.LHS,
    s.RHS,
    s.frequency,
    s.Total_transaction,
    s.support,
    f.Product_frequency LHS_freq,
    r.product_frequency RHS_freq,
    ROUND(CAST(f.Product_frequency AS REAL)*100/s.Total_Transaction,2) LHS_Support,
    ROUND(CAST(r.Product_frequency AS REAL)*100/s.Total_Transaction,2) RHS_Support
    FROM Support s
    JOIN Frequencies f
    ON s.LHS = f.Product_name
    JOIN Frequencies r ON s.RHS = r.Product_name
),
Final_Calc AS(
    SELECT *,
    ROUND(frequency*100/LHS_freq,2) confidence,
    ROUND(support*100/(LHS_Support*RHS_Support),2) Lift
    FROM Metrics
)
SELECT
LHS,
RHS,
Frequency,
Total_Transaction,
support AS "Support(%)",
Confidence AS "Confidence(%)",
Lift AS "Lift Ratio"
FROM Final_Calc
ORDER BY 7,6,5 DESC; 
