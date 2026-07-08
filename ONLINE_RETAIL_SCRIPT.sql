USE ECOMMERCE
GO
-------------------------------------------Checking for NULL Values across entire online_retail Table-----------------
------------ Results shows 1454 records for description_nulls, 135080 for customer_id_nulls --------------------------
SELECT 
    SUM(CASE WHEN InvoiceNo IS NULL THEN 1 ELSE 0 END) AS invoice_num_nulls,
    SUM(CASE WHEN StockCode IS NULL THEN 1 ELSE 0 END) AS stock_code_nulls,
    SUM(CASE WHEN [Description] IS NULL THEN 1 ELSE 0 END) AS description_nulls,
	SUM(CASE WHEN Quantity IS NULL THEN 1 ELSE 0 END) AS quantity_nulls,
    SUM(CASE WHEN InvoiceDate IS NULL THEN 1 ELSE 0 END) AS order_date_nulls,
    SUM(CASE WHEN UnitPrice IS NULL THEN 1 ELSE 0 END) AS order_time_nulls,
	SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS customer_id_nulls,
    SUM(CASE WHEN Country IS NULL THEN 1 ELSE 0 END) AS country_nulls
FROM [dbo].[online_retail];

----------------------------------------- Data Cleaning, Rename Column-------------------------------------------------
SELECT
    InvoiceNo as invoice_num,
	StockCode as stock_code,
	[Description] as [description],
	Quantity as quantity,
	CAST(InvoiceDate AS [date]) AS order_date,
    CAST(InvoiceDate AS [time]) AS order_time,
	UnitPrice as unit_price,
	CustomerID as customer_id,
	Country as country
INTO [dbo].[online_retail_uk]
FROM [dbo].[online_retail];

-----------------------------------------MISC Date Formatting---------------------------------------------------------
SELECT
    order_date,
	order_time,   
    --DATEPART(HOUR, order_time) AS [Hour],
	
    CONCAT(
		(DATENAME(WEEKDAY, order_date)),'; ',
		(DATEPART(DAY, order_date)),' ',
		(DATENAME(MONTH, order_date)),', ', 
		(DATEPART(YEAR, order_date))
		)
	AS [Date]
FROM [dbo].[online_retail_uk];

-- Removes trailing zeros from order_time column, Change Quantity Column from nvarchar(50) to int---------------------
ALTER table [dbo].[online_retail_uk] 
ALTER COLUMN order_time TIME(0); 
ALTER table [dbo].[online_retail_uk] 
Alter COLUMN quantity integer;


--------------------------ALL Records (541909)------------------------------------------------------------------------
select * FROM [dbo].[online_retail_uk];


-------------------------Checking for NULL Values across entire retail_uk Table (135,080)-----------------------------
SELECT 
    SUM(CASE WHEN invoice_num IS NULL THEN 1 ELSE 0 END) AS invoice_num_nulls,
    SUM(CASE WHEN stock_code IS NULL THEN 1 ELSE 0 END) AS stock_code_nulls,
    SUM(CASE WHEN [description] IS NULL THEN 1 ELSE 0 END) AS description_nulls,
	SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END) AS quantity_nulls,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS order_date_nulls,
    SUM(CASE WHEN order_time IS NULL THEN 1 ELSE 0 END) AS order_time_nulls,
	SUM(CASE WHEN unit_price IS NULL THEN 1 ELSE 0 END) AS unit_price_nulls,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS customer_id_nulls,
    SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END) AS country_nulls
FROM [dbo].[online_retail_uk];



----------------Scanning for NULL rows ONLY (Description & Customer_id)-----------------------------------------------
SELECT invoice_num, stock_code, [description], quantity, order_date, order_time, unit_price, customer_id, country
FROM [dbo].[online_retail_uk]
WHERE [description] is NULL or customer_id is NULL
ORDER BY [description] 

---------------Copy NULL rows ONLY into New Table (Description & Customer_id)-----------------------------------------
SELECT invoice_num, stock_code, [description], quantity, order_date, order_time, unit_price, customer_id, country
INTO online_retail_nulls
FROM [dbo].[online_retail_uk]
WHERE [description] is NULL or customer_id is NULL


--------------------Delete Rows with Null Values for Description & Customer_Id Columns Respectively-------------------
DELETE FROM [dbo].[online_retail_uk]
WHERE [description] is NULL or customer_id is NULL


------------------ Show all(38) Countries represented from Dataset including 1 unspecified ---------------------------
SELECT DISTINCT(country) FROM [dbo].[online_retail_uk]

------------------------------------------------- Distinct Stock Codes 3684 @ [dbo].[online_retail_uk]----------------
SELECT COUNT(DISTINCT(stock_code)) FROM [dbo].[online_retail_uk]


------------------------------------------ Total Numbers of Transactions 406826 --------------------------------------
SELECT COUNT(*) FROM [dbo].[online_retail_uk]


--------------------- ---------Revenue Loss Excluding Cancellation & Returns------------------------------------------
WITH oretail_revenue_loss AS (
	SELECT 
		stock_code, [description], quantity, unit_price, (unit_price * quantity) AS revenue_loss, country,
		DENSE_RANK() OVER (order by ([unit_price] * [quantity]) DESC) AS [rankings]
	FROM [dbo].[online_retail_uk] 
	WHERE [description] NOT IN ('unknown','manual','discount','postage') AND quantity < 0
)
SELECT * FROM oretail_revenue_loss
order by revenue_loss asc;

--------------------- MISCELLANOUS: Cancelled Items, Returned Items, Inventory Adjustment, Wholesale Chargebacks------
--Alter VIEW misc_tran AS
SELECT customer_id, invoice_num, stock_code, [description], quantity, ABS(unit_price * quantity) as revenue_loss, country,
	CASE
		WHEN invoice_num LIKE 'C%' THEN 'Cancelled Order'
		ELSE 'Return / Adjustment'
	END AS transaction_type
from [dbo].[online_retail_uk]
where quantity < 0

----------------------------TOP 10 FREQUENTLY RETURNED PRODUCTS with some exclusion-----------------------------------
SELECT *
FROM (
    SELECT
        stock_code,
        [description],
        ABS(SUM(quantity)) AS total_returned_qty,
        ABS(SUM(quantity * unit_price)) AS revenue_loss,
        DENSE_RANK() OVER (
            ORDER BY ABS(SUM(quantity)) DESC
        ) AS rnk
    FROM dbo.online_retail_uk
    WHERE quantity < 0
      AND [description] NOT IN ('unknown', 'manual', 'discount', 'postage')
    GROUP BY stock_code, [description]
) t
WHERE rnk <= 10
ORDER BY rnk;

----------------------------TOP 10 FREQUENTLY PURCHASED PRODUCTS with some exclusion-----------------------------------
SELECT TOP 10
    stock_code,
    [description],
    SUM(quantity) AS total_units_sold,
    SUM(unit_price * quantity) AS revenue_gain,
    country
FROM [dbo].[online_retail_uk]
WHERE 
    quantity > 0
    AND unit_price > 0
    AND [description] NOT IN ('unknown', 'manual', 'postage')
GROUP BY
    stock_code,
    [description],
    country
ORDER BY
    total_units_sold DESC;


----------------------------------- Customer Chargebacks/Forced Bank Reversal------------------------------------------
USE ECOMMERCE
SELECT
    customer_id,
    SUM(ABS(quantity * unit_price)) AS total_chargeback_loss,
    COUNT(*) AS chargeback_transactions
FROM [dbo].[online_retail_uk]
WHERE
    quantity < 0
    AND invoice_num LIKE 'C%'
GROUP BY customer_id
ORDER BY total_chargeback_loss DESC;

----------------------------------- Cancelled Orders By Customers------------------------------------------------------
SELECT customer_id, invoice_num, stock_code, quantity, ABS(unit_price * quantity) AS revenue_loss, country 
FROM [dbo].[online_retail_uk]
WHERE quantity < 0 and invoice_num like 'C%' and customer_id > 0
ORDER BY revenue_loss DESC


------------------------------NET REVENUE = GROSS SALE - REVENUE LOSS--------------------------------------------------
SELECT
    SUM(CASE WHEN quantity > 0 THEN quantity * unit_price ELSE 0 END) AS gross_sales,
    SUM(CASE WHEN quantity < 0 THEN ABS(quantity * unit_price) ELSE 0 END) AS revenue_loss,
    SUM(quantity * unit_price) AS net_revenue
FROM dbo.online_retail_uk
WHERE unit_price > 0;


-----------------------------------Top 10 Frequent Customers Per Order Count-------------------------------------------
SELECT TOP 10
    customer_id,
    COUNT(DISTINCT invoice_num) AS order_count,
    SUM(quantity * unit_price) AS total_spent,
    country
FROM online_retail_uk
WHERE customer_id > 0
  AND quantity > 0
GROUP BY customer_id, country
ORDER BY order_count DESC;


---------------------------------- RFM (Recency, Frequency, Monetary)------------------------------------------------
CREATE VIEW rfm_base_metrics AS
SELECT
    customer_id,
    -- Recency: Days between the customer's last purchase and "today"
    DATEDIFF(day, MAX(order_date), '2011-12-09') AS Recency,
    
    -- Frequency: Total distinct orders placed by the customer
    COUNT(DISTINCT invoice_num) AS Frequency,
    
    -- Monetary: Total revenue generated by the customer
    SUM(Quantity * unit_price) AS Monetary
FROM online_retail_uk
WHERE customer_id IS NOT NULL 
  AND Quantity > 0 -- Exclude returns for the clustering step
  AND unit_price > 0
GROUP BY customer_id


------------------------------------ Create VIEW for KPI Summary Gain(Key Performance Index)-----------------------
WITH KPI AS(
SELECT COUNT(customer_id) as Unique_Customers, SUM(Monetary) as Total_Revenue, AVG(Monetary) as AOV from rfm_base_metrics
WHERE customer_id != 0
)
SELECT * from KPI


-------------------- Query Clustered Customers from Python---------------------------------------------------------
USE ECOMMERCE;

SELECT
    segment_label,
    COUNT(*) AS customer_count
FROM dbo.customer_segment_assignments
GROUP BY segment_label
ORDER BY segment_label;


-- Total Revenue Loss (All)
-- Includes returned items, cancelled orders, inventory adjustments,
-- wholesale chargebacks, and reimbursements.
SELECT
    SUM(ABS(quantity * unit_price)) AS total_revenue_loss
FROM dbo.online_retail_uk
WHERE quantity < 0
  AND unit_price > 0;


-- Total Revenue (Sales Only)
-- Excludes returned items, cancelled orders, inventory adjustments,
-- wholesale chargebacks, and reimbursements.
SELECT
    SUM(quantity * unit_price) AS total_revenue_profit
FROM dbo.online_retail_uk
WHERE quantity > 0
  AND unit_price > 0;