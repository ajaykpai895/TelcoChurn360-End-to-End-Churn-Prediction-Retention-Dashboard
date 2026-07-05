SELECT
    CASE
        WHEN tenure <= 12 THEN '0-1 year'
        WHEN tenure <= 24 THEN '1-2 years'
        WHEN tenure <= 48 THEN '2-4 years'
        ELSE '4+ years'
    END AS tenure_bucket,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS churn_rate_pct
FROM customers
GROUP BY tenure_bucket
ORDER BY churn_rate_pct DESC;
SELECT
    CASE
        WHEN MonthlyCharges < 35 THEN 'Low ($0-35)'
        WHEN MonthlyCharges < 70 THEN 'Medium ($35-70)'
        WHEN MonthlyCharges < 90 THEN 'High ($70-90)'
        ELSE 'Very High ($90+)'
    END AS charge_bucket,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS churn_rate_pct
FROM customers
GROUP BY charge_bucket
ORDER BY churn_rate_pct DESC;
SELECT
    Contract,
    InternetService,
    TechSupport,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS churn_rate_pct
FROM customers
GROUP BY Contract, InternetService, TechSupport
HAVING COUNT(*) >= 30          -- ignore tiny segments, not statistically meaningful
ORDER BY churn_rate_pct DESC
LIMIT 15;
SELECT
    Contract,
    COUNT(*) AS churned_customers,
    ROUND(SUM(MonthlyCharges), 2) AS monthly_revenue_lost,
    ROUND(SUM(MonthlyCharges) * 12, 2) AS annual_revenue_lost
FROM customers
WHERE Churn = 'Yes'
GROUP BY Contract
ORDER BY annual_revenue_lost DESC;
DROP VIEW IF EXISTS risk_score_baseline;

CREATE VIEW risk_score_baseline AS
SELECT
    customerID,
    Contract,
    tenure,
    MonthlyCharges,
    TechSupport,
    InternetService,
    Churn,
    (
        CASE WHEN Contract = 'Month-to-month' THEN 3 ELSE 0 END +
        CASE WHEN tenure <= 12 THEN 2 ELSE 0 END +
        CASE WHEN TechSupport = 'No' THEN 1 ELSE 0 END +
        CASE WHEN InternetService = 'Fiber optic' THEN 1 ELSE 0 END +
        CASE WHEN MonthlyCharges >= 70 THEN 1 ELSE 0 END
    ) AS rule_risk_score          -- max possible score = 8
FROM customers;

-- check it works
SELECT * FROM risk_score_baseline ORDER BY rule_risk_score DESC LIMIT 10;
SELECT
    rule_risk_score,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS actual_churn_rate
FROM risk_score_baseline
GROUP BY rule_risk_score
ORDER BY rule_risk_score DESC;
DROP VIEW IF EXISTS customer_master;

CREATE VIEW customer_master AS
SELECT
    c.*,
    r.rule_risk_score
FROM customers c
JOIN risk_score_baseline r ON c.customerID = r.customerID;

SELECT * FROM customer_master LIMIT 5;
SELECT name, type FROM sqlite_master WHERE type IN ('table','view') ORDER BY type, name;
