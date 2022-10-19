-- Inspecting the data
SELECT *
FROM payment_practices


-- Checking for unique values
SELECT
	DISTINCT YEAR(Start_date) AS YEAR
FROM 
	payment_practices
-- The UK government gave the rule of public payment reports starting from April 2017 but i can see earlier years.



-- Next is to filter these years since they are just 31 reports out of the 62,003
SELECT
	DISTINCT YEAR(Start_date) AS YEAR
FROM
	payment_practices
WHERE
	Start_date >= '2017-01-01'



-- End date 
SELECT
	DISTINCT YEAR(End_date) AS YEAR
FROM
	payment_practices
-- The reporting period i.e Start_date and End_date is between 2017 and 2022



-- Filing date
SELECT
	DISTINCT YEAR(filing_date) AS YEAR
FROM
	payment_practices
-- Filing period was from 2017 and 2022


SELECT
	DISTINCT Average_time_to_pay
FROM
	payment_practices
ORDER BY 1
-- NULL values also present. Minimum day to pay was '0 days' while Maximun is '1120 days'



SELECT
	DISTINCT Payments_made_in_the_reporting_period
FROM
	payment_practices
-- NULL value was present. Cleaning it can distort the whole analysis for now. So i will create a different category for NULL values.

-- The presense of NULL values in payment made in the reporting period while average time to pay and other metrics was included didn't make sense since you can provides metrics when you make payment so as regards this, i will input 'True' for every NULL values that has a metrics.

UPDATE payment_practices
SET Payments_made_in_the_reporting_period = 'True'
WHERE Payments_made_in_the_reporting_period IS NULL AND Average_time_to_pay IS NOT NULL

-- 'NULL' values now present, are businesses that did not enter into any qualifying contracts in the reporting period.
-- 'True' means they entered into qualifying contract in the reporting period
-- 'False' means they entered into qualifying contracts in the reporting period, but did not make any payments.


UPDATE payment_practices
SET Participates_in_payment_codes = 'Yes'
WHERE Participates_in_payment_codes = 'True'

UPDATE payment_practices
SET Participates_in_payment_codes = 'No'
WHERE Participates_in_payment_codes = 'False'
-- Table updated...



-- Analysis

-- How many reports has been filed since 2017 by order of year?
SELECT
	COALESCE(CAST(YEAR(Filing_date) AS VARCHAR), 'Total') AS Year,
	COUNT(DISTINCT Company) AS Company_Count,
	COUNT(Report_ID) AS Report_Count
FROM
	payment_practices
WHERE Start_date >= '2017-01-01'
GROUP BY ROLLUP(
	YEAR(Filing_date))
-- A total of 61,972 reports since 2017 and a total of 9359 companies



-- Reports of payment made by UK businesses within and outside the reporting period?
SELECT
	COALESCE(CAST(YEAR(filing_date) AS VARCHAR), 'Total') AS YEAR,
    COUNT(CASE WHEN Payments_made_in_the_reporting_period = 'True' THEN 1 END) AS True, -- 'True' means they entered into qualifying contract in the reporting period
    COUNT(CASE WHEN Payments_made_in_the_reporting_period = 'False' THEN 1 END) AS False, -- 'False' means they entered into qualifying contracts in the reporting period, but did not make any payments.
    COUNT(CASE WHEN Payments_made_in_the_reporting_period IS NULL THEN 1 END) AS No_Report -- 'NULL' are businesses that did not enter into any qualifying contracts in the reporting period.
FROM
	payment_practices
	payment_practices
WHERE Start_date >= '2017-01-01'
GROUP BY ROLLUP(
	YEAR(filing_date))
-- There is a trend from 2017 to 2022


-- Yearly participation in Payment Codes
SELECT
     YEAR,
	 Total_Companies,
	 LAG(Total_Companies) OVER(ORDER BY Year) AS Last_Year_Company_Count,
	 Total_Companies - LAG(Total_Companies) OVER(ORDER BY Year) AS YOY_Difference
FROM (
SELECT
	YEAR(Filing_date) AS Year,
	COUNT(DISTINCT Company) AS Total_Companies
FROM
	payment_practices
WHERE
	Participates_in_payment_codes = 'Yes'
GROUP BY
	YEAR(Filing_date)) T3 
--


-- What was the yearly average invoice percentage paid on certain number of days by UK businesses?
 SELECT
	YEAR(filing_date) AS YEAR,
	AVG(Invoices_paid_within_30_days) AS Percentage_paid_within_30days,
    AVG(Invoices_paid_between_31_and_60_days) AS Percentage_paid_between_31_and_60_days,
    AVG(Invoices_paid_later_than_60_days) AS Percentage_paid_later_than_60_days
FROM
	payment_practices
WHERE Start_date >= '2017-01-01'
GROUP BY
	YEAR(filing_date)
ORDER BY
	YEAR(filing_date)
--

-- Come up with a credibility score for Uk businesses that can be trusted to make payment on time?
-- I will be giving the standard pay back time which is 

-- Uk businesses scored based on if they make payments according to agreement within the reporting period
SELECT
	 YEAR(filing_date) AS Year,
	 Company_number,
	 Company,
     CASE 
		 WHEN(Payments_made_in_the_reporting_period = 'True' AND Invoices_not_paid_within_agreed_terms = 0 AND Participates_in_payment_codes = 'Yes') THEN 5
		 WHEN(Payments_made_in_the_reporting_period = 'True' AND Invoices_not_paid_within_agreed_terms = 0 AND Participates_in_payment_codes = 'No') THEN 4 -- Businesses that pays all invoices according to agreement
		 WHEN(Payments_made_in_the_reporting_period = 'True' AND Invoices_not_paid_within_agreed_terms BETWEEN 1 AND 5 AND Participates_in_payment_codes = 'Yes') THEN 3
		 WHEN(Payments_made_in_the_reporting_period = 'True' AND Invoices_not_paid_within_agreed_terms BETWEEN 1 AND 5 AND Participates_in_payment_codes = 'No') THEN 2 -- Businesses that pays 95% within agreed terms
		 WHEN(Payments_made_in_the_reporting_period = 'False' AND Invoices_not_paid_within_agreed_terms BETWEEN 0 AND 100) THEN 0 -- Businesses that are defaults from previous reporting period
		 WHEN(Payments_made_in_the_reporting_period = 'True' AND Invoices_not_paid_within_agreed_terms >5 AND Participates_in_payment_codes = 'Yes' OR Participates_in_payment_codes = 'NO') THEN 0 -- Businesses that owes 6% to 100% of payment
		 END AS Points
FROM payment_practices
WHERE Start_date >= '2017-01-01' -- 'NULL' values are businesses that did not enter into any qualifying contracts in the reporting period.