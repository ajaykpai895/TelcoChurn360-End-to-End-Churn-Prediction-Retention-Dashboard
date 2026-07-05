import pandas as pd
import sqlite3

# Load the raw CSV (download from Kaggle: "Telco Customer Churn")
df = pd.read_csv("WA_Fn-UseC_-Telco-Customer-Churn.csv")

# Clean: TotalCharges has some blank strings for new customers -> convert to number
df["TotalCharges"] = pd.to_numeric(df["TotalCharges"], errors="coerce").fillna(0)

# Connect to (or create) a SQLite database file
conn = sqlite3.connect("churn.db")

# Push the cleaned data into a SQL table
df.to_sql("customers", conn, if_exists="replace", index=False)

print("Rows loaded into SQLite:", pd.read_sql("SELECT COUNT(*) FROM customers", conn).iloc[0,0])
query_overall = """
SELECT Churn, COUNT(*) as customers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM customers), 1) as pct
FROM customers
GROUP BY Churn;
"""
print(pd.read_sql(query_overall, conn))
query_contract = """
SELECT Contract,
       COUNT(*) as total_customers,
       SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) as churned,
       ROUND(100.0 * SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) as churn_rate_pct
FROM customers
GROUP BY Contract
ORDER BY churn_rate_pct DESC;
"""
contract_df = pd.read_sql(query_contract, conn)
print(contract_df)

contract_df.to_sql("segment_contract", conn, if_exists="replace", index=False)
segments = {
    "TechSupport": """
        SELECT TechSupport, COUNT(*) total,
               SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) churned,
               ROUND(100.0*SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END)/COUNT(*),1) churn_rate
        FROM customers GROUP BY TechSupport
    """,
    "InternetService": """
        SELECT InternetService, COUNT(*) total,
               SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) churned,
               ROUND(100.0*SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END)/COUNT(*),1) churn_rate
        FROM customers GROUP BY InternetService
    """,
    "PaymentMethod": """
        SELECT PaymentMethod, COUNT(*) total,
               SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) churned,
               ROUND(100.0*SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END)/COUNT(*),1) churn_rate
        FROM customers GROUP BY PaymentMethod
    """,
}

for name, q in segments.items():
    result = pd.read_sql(q, conn)
    print(f"\n--- {name} ---")
    print(result)
    result.to_sql(f"segment_{name.lower()}", conn, if_exists="replace", index=False)