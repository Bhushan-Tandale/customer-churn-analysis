-- ============================================================
-- Telco Customer Churn Analytics: PostgreSQL Schema
-- ============================================================

DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS staging CASCADE;

-- Step 1: Staging table (all VARCHAR — avoids type mismatch on load)
CREATE TABLE staging (
    customer_id       VARCHAR(20),
    gender            VARCHAR(10),
    senior_citizen    VARCHAR(5),
    partner           VARCHAR(5),
    dependents        VARCHAR(5),
    tenure            VARCHAR(10),
    phone_service     VARCHAR(5),
    multiple_lines    VARCHAR(30),
    internet_service  VARCHAR(30),
    online_security   VARCHAR(30),
    online_backup     VARCHAR(30),
    device_protection VARCHAR(30),
    tech_support      VARCHAR(30),
    streaming_tv      VARCHAR(30),
    streaming_movies  VARCHAR(30),
    contract          VARCHAR(30),
    paperless_billing VARCHAR(5),
    payment_method    VARCHAR(50),
    monthly_charges   VARCHAR(15),
    total_charges     VARCHAR(15),
    churn             VARCHAR(5)
);

-- Import the Telco Customer.csv into staging table using PostgreSQL GUI then run below queries

CREATE TABLE customers (
    customer_id         VARCHAR(20)    PRIMARY KEY,
    gender              VARCHAR(10),
    senior_citizen      SMALLINT       CHECK (senior_citizen IN (0,1)),
    partner             BOOLEAN,
    dependents          BOOLEAN,
    tenure              INT            CHECK (tenure >= 0),
    phone_service       BOOLEAN,
    multiple_lines      VARCHAR(30),
    internet_service    VARCHAR(30),
    online_security     VARCHAR(30),
    online_backup       VARCHAR(30),
    device_protection   VARCHAR(30),
    tech_support        VARCHAR(30),
    streaming_tv        VARCHAR(30),
    streaming_movies    VARCHAR(30),
    contract            VARCHAR(30),
    paperless_billing   BOOLEAN,
    payment_method      VARCHAR(50),
    monthly_charges     NUMERIC(8,2),
    total_charges       NUMERIC(10,2),
    churn               BOOLEAN
);

-- Indexes for common filter patterns
CREATE INDEX idx_customers_churn     ON customers(churn);
CREATE INDEX idx_customers_contract  ON customers(contract);
CREATE INDEX idx_customers_internet  ON customers(internet_service);
CREATE INDEX idx_customers_tenure    ON customers(tenure);


-- Step 2: Insert with type coercion
--   • Yes/No → BOOLEAN
--   • Empty TotalCharges → NULL
INSERT INTO customers
SELECT
    customer_id,
    gender,
    senior_citizen::SMALLINT,
    CASE WHEN LOWER(partner)           = 'yes' THEN TRUE ELSE FALSE END,
    CASE WHEN LOWER(dependents)        = 'yes' THEN TRUE ELSE FALSE END,
    tenure::INT,
    CASE WHEN LOWER(phone_service)     = 'yes' THEN TRUE ELSE FALSE END,
    multiple_lines,
    internet_service,
    online_security,
    online_backup,
    device_protection,
    tech_support,
    streaming_tv,
    streaming_movies,
    contract,
    CASE WHEN LOWER(paperless_billing) = 'yes' THEN TRUE ELSE FALSE END,
    payment_method,
    NULLIF(TRIM(monthly_charges), '')::NUMERIC,
    NULLIF(TRIM(total_charges),   '')::NUMERIC,
    CASE WHEN LOWER(churn)             = 'yes' THEN TRUE ELSE FALSE END
FROM staging;

-- Testing
SELECT * FROM customers;

-- ============================================================
-- Telco Customer Churn Analytics: KPI Queries
-- ============================================================

-- ── 1. OVERALL CHURN SUMMARY ────────────────────────────────
SELECT
    COUNT(*)                                                        AS total_customers,
    SUM(churn::INT)                                                 AS churned,
    COUNT(*) - SUM(churn::INT)                                      AS retained,
    ROUND(AVG(churn::INT) * 100, 2)                                 AS churn_rate_pct,
    ROUND(AVG(monthly_charges), 2)                                  AS avg_monthly_charges,
    ROUND(AVG(tenure), 1)                                           AS avg_tenure_months,
    SUM(monthly_charges)                                            AS total_monthly_revenue,
    SUM(CASE WHEN churn THEN monthly_charges END)                   AS monthly_revenue_at_risk
FROM customers;


-- ── 2. CHURN RATE BY CONTRACT TYPE ──────────────────────────
SELECT
    contract,
    COUNT(*)                                        AS customers,
    SUM(churn::INT)                                 AS churned,
    ROUND(AVG(churn::INT) * 100, 2)                 AS churn_rate_pct,
    ROUND(AVG(monthly_charges), 2)                  AS avg_monthly_charges,
    ROUND(AVG(tenure), 1)                           AS avg_tenure_months
FROM customers
GROUP BY contract
ORDER BY churn_rate_pct DESC;


-- ── 3. CHURN BY INTERNET SERVICE ────────────────────────────
SELECT
    internet_service,
    COUNT(*)                                        AS customers,
    SUM(churn::INT)                                 AS churned,
    ROUND(AVG(churn::INT) * 100, 2)                 AS churn_rate_pct,
    ROUND(AVG(monthly_charges), 2)                  AS avg_monthly_charges
FROM customers
GROUP BY internet_service
ORDER BY churn_rate_pct DESC;


-- ── 4. CHURN BY TENURE BAND ─────────────────────────────────
SELECT
    CASE
        WHEN tenure BETWEEN  0 AND  6  THEN '0-6 months'
        WHEN tenure BETWEEN  7 AND 12  THEN '7-12 months'
        WHEN tenure BETWEEN 13 AND 24  THEN '13-24 months'
        WHEN tenure BETWEEN 25 AND 48  THEN '25-48 months'
        ELSE '49+ months'
    END                                             AS tenure_band,
    COUNT(*)                                        AS customers,
    SUM(churn::INT)                                 AS churned,
    ROUND(AVG(churn::INT) * 100, 2)                 AS churn_rate_pct,
    ROUND(AVG(monthly_charges), 2)                  AS avg_monthly_charges
FROM customers
GROUP BY
    CASE
        WHEN tenure BETWEEN  0 AND  6  THEN '0-6 months'
        WHEN tenure BETWEEN  7 AND 12  THEN '7-12 months'
        WHEN tenure BETWEEN 13 AND 24  THEN '13-24 months'
        WHEN tenure BETWEEN 25 AND 48  THEN '25-48 months'
        ELSE '49+ months'
    END
ORDER BY MIN(tenure);


-- ── 5. CHURN BY PAYMENT METHOD ──────────────────────────────
SELECT
    payment_method,
    COUNT(*)                                        AS customers,
    SUM(churn::INT)                                 AS churned,
    ROUND(AVG(churn::INT) * 100, 2)                 AS churn_rate_pct,
    ROUND(AVG(monthly_charges), 2)                  AS avg_monthly_charges
FROM customers
GROUP BY payment_method
ORDER BY churn_rate_pct DESC;


-- ── 6. CHURN BY DEMOGRAPHICS ─────────────────────────────────
SELECT
    gender,
    senior_citizen,
    partner::TEXT,
    dependents::TEXT,
    COUNT(*)                                        AS customers,
    SUM(churn::INT)                                 AS churned,
    ROUND(AVG(churn::INT) * 100, 2)                 AS churn_rate_pct
FROM customers
GROUP BY gender, senior_citizen, partner, dependents
ORDER BY churn_rate_pct DESC;


-- ── 7. REVENUE AT RISK ANALYSIS ──────────────────────────────
SELECT
    contract,
    SUM(CASE WHEN churn     THEN monthly_charges ELSE 0 END)    AS revenue_lost,
    SUM(CASE WHEN NOT churn THEN monthly_charges ELSE 0 END)    AS revenue_retained,
    ROUND(
        SUM(CASE WHEN churn THEN monthly_charges ELSE 0 END) /
        NULLIF(SUM(monthly_charges), 0) * 100, 2
    )                                                           AS pct_revenue_at_risk
FROM customers
GROUP BY contract
ORDER BY revenue_lost DESC;


-- ── 8. CHURN COHORT: TENURE × CONTRACT ──────────────────────
SELECT
    CASE
        WHEN tenure BETWEEN  0 AND  6  THEN '0-6 mo'
        WHEN tenure BETWEEN  7 AND 12  THEN '7-12 mo'
        WHEN tenure BETWEEN 13 AND 24  THEN '13-24 mo'
        WHEN tenure BETWEEN 25 AND 48  THEN '25-48 mo'
        ELSE '49+ mo'
    END                                             AS tenure_band,
    contract,
    COUNT(*)                                        AS customers,
    SUM(churn::INT)                                 AS churned,
    ROUND(AVG(churn::INT) * 100, 2)                 AS churn_rate_pct,
    ROUND(AVG(monthly_charges), 2)                  AS avg_monthly_charges
FROM customers
GROUP BY
    CASE
        WHEN tenure BETWEEN  0 AND  6  THEN '0-6 mo'
        WHEN tenure BETWEEN  7 AND 12  THEN '7-12 mo'
        WHEN tenure BETWEEN 13 AND 24  THEN '13-24 mo'
        WHEN tenure BETWEEN 25 AND 48  THEN '25-48 mo'
        ELSE '49+ mo'
    END,
    contract
ORDER BY MIN(tenure), contract;