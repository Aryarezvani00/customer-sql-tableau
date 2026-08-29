set sql_safe_updates = 0;

-- =====================================================
-- STEP 1: Data Cleaning
-- Renaming columns and creating a clean view with proper
-- data types (dates, numeric amounts)
-- =====================================================

alter table sales_transactions
rename column `transaction id` to transaction_id;

alter table sales_transactions
rename column `product id` to product_id;

alter table sales_transactions
rename column `product name` to product_name;

alter table sales_transactions
rename column `product category` to product_category;

alter table sales_transactions
rename column `customer id` to customer_id;

create view clean_sales_transactions as
select
	transaction_id,
    str_to_date(date, '%d-%m-%Y') as clean_date,
    product_id,
    product_name,
    product_category,
    quantity,
    cast(replace(ppu, ',','') as unsigned) as ppu,
    cast(replace(amount, ',','') as unsigned) as clean_amount,
    customer_id,
    region
from sales_transactions;

/*
1. Who are our most valuable customers?
•	Total spending 
•	Number of transactions 
•	Average transaction value 
*/

select 
	customer_id,
	sum(clean_amount) as total_spending,
	count(*) as num_of_transactions,
	round(avg(clean_amount),2) as average_transaction_value
from clean_sales_transactions
group by customer_id
order by total_spending desc;

/*
2. Who are our most loyal customers?
•	Number of transactions 
•	Number of months with purchases 
•	Length of relationship
*/

SELECT
    customer_id,
    num_of_transactions,
    months_with_purchases,
    relationship_in_months,
    round(
        (num_of_transactions / max(num_of_transactions)over() +
            months_with_purchases / max(months_with_purchases)over() +
            relationship_in_months / max(relationship_in_months)over()) / 3,3)as loyalty_score
from (
select
	customer_id,
    count(*) as num_of_transactions,
    count(distinct date_format(clean_date, '%Y-%m')) as months_with_purchases,
    timestampdiff(month,min(clean_date),max(clean_date)) as relationship_in_months,
    timestampdiff(day,max(clean_date),'2026-01-01') as days_since_last_purchase,
    round(count(*) / nullif(timestampdiff(month,min(clean_date),max(clean_date)),0),2) as transactions_per_month
from clean_sales_transactions
group by customer_id
having days_since_last_purchase < 90 -- leaving inactive customers out
order by num_of_transactions desc
)as customers
order by loyalty_score desc;

/*
3. Which customers are at risk?
•	Days since customer's most recent purchase
•	Also consider purchase frequency
•	And value of the customer
*/

select
	customer_id,
    days_since_last_purchase,
    transactions_per_month,
    total_spending
from (select
			a.*,
			avg(transactions_per_month) over() as avg_transactions_per_month
    from (
        select
            customer_id,
            timestampdiff(day, max(clean_date), '2026-01-01') as days_since_last_purchase,
            round(count(*) /nullif(timestampdiff(month, min(clean_date), max(clean_date)),0),2) as transactions_per_month,
            sum(clean_amount) as total_spending
        from clean_sales_transactions
        group by customer_id
        having days_since_last_purchase < 90
           and transactions_per_month is not null
    ) as a
) as b
where transactions_per_month > avg_transactions_per_month
order by days_since_last_purchase desc;


-- A full list of customers

select
	*,
    round(
        (num_of_transactions / max(num_of_transactions)over() +
            months_with_purchases / max(months_with_purchases)over() +
            relationship_in_months / max(relationship_in_months)over()) / 3,3)as loyalty_score
from
(
select
	customer_id,
    timestampdiff(day, max(clean_date), '2026-01-01') as days_since_last_purchase,
    round(count(*) /nullif(timestampdiff(month, min(clean_date), max(clean_date)),0),2) as transactions_per_month,
    sum(clean_amount) as total_spending,
    round(avg(clean_amount),2) as average_transaction_value,
    count(*) as num_of_transactions,
    timestampdiff(month,min(clean_date),max(clean_date)) as relationship_in_months,
	count(distinct date_format(clean_date, '%Y-%m')) as months_with_purchases
from
	clean_sales_transactions
group by
	customer_id
)as customers
order by 4 desc;
