-- Примеры аналитических SQL-запросов для портфолио.
-- PostgreSQL. Демонстрационная схема:
-- sales(id, product_id, sale_date, quantity, unit_price, commission, delivery_cost)
-- products(id, name, category, purchase_price)
-- Названия полей нужно сопоставить с реальной схемой Supabase перед запуском.

-- 1. Продажи и прибыль по товарам
SELECT
    p.name AS product,
    p.category,
    SUM(s.quantity) AS units_sold,
    SUM(s.quantity * s.unit_price) AS revenue,
    SUM(s.quantity * (s.unit_price - p.purchase_price)
        - COALESCE(s.commission, 0)
        - COALESCE(s.delivery_cost, 0)) AS estimated_profit
FROM sales AS s
JOIN products AS p ON p.id = s.product_id
GROUP BY p.id, p.name, p.category
ORDER BY estimated_profit DESC;

-- 2. Динамика по месяцам
SELECT
    DATE_TRUNC('month', s.sale_date)::date AS month,
    SUM(s.quantity * s.unit_price) AS revenue,
    SUM(s.quantity * (s.unit_price - p.purchase_price)
        - COALESCE(s.commission, 0)
        - COALESCE(s.delivery_cost, 0)) AS estimated_profit
FROM sales AS s
JOIN products AS p ON p.id = s.product_id
GROUP BY 1
ORDER BY 1;

-- 3. Маржинальность категорий
WITH category_totals AS (
    SELECT
        p.category,
        SUM(s.quantity * s.unit_price) AS revenue,
        SUM(s.quantity * (s.unit_price - p.purchase_price)
            - COALESCE(s.commission, 0)
            - COALESCE(s.delivery_cost, 0)) AS estimated_profit
    FROM sales AS s
    JOIN products AS p ON p.id = s.product_id
    GROUP BY p.category
)
SELECT
    category,
    revenue,
    estimated_profit,
    ROUND(100.0 * estimated_profit / NULLIF(revenue, 0), 2) AS margin_pct
FROM category_totals
ORDER BY estimated_profit DESC;

-- 4. ABC-анализ товаров по выручке
WITH product_revenue AS (
    SELECT p.name, SUM(s.quantity * s.unit_price) AS revenue
    FROM sales AS s
    JOIN products AS p ON p.id = s.product_id
    GROUP BY p.id, p.name
),
ranked AS (
    SELECT
        name,
        revenue,
        SUM(revenue) OVER (
            ORDER BY revenue DESC, name
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / NULLIF(SUM(revenue) OVER (), 0) AS cumulative_share
    FROM product_revenue
)
SELECT
    name,
    revenue,
    ROUND(100 * cumulative_share, 2) AS cumulative_pct,
    CASE
        WHEN cumulative_share <= 0.80 THEN 'A'
        WHEN cumulative_share <= 0.95 THEN 'B'
        ELSE 'C'
    END AS abc_group
FROM ranked
ORDER BY revenue DESC, name;

-- 5. Проверка качества данных
SELECT
    COUNT(*) FILTER (WHERE product_id IS NULL) AS missing_product_id,
    COUNT(*) FILTER (WHERE sale_date IS NULL) AS missing_sale_date,
    COUNT(*) FILTER (WHERE quantity <= 0) AS nonpositive_quantity,
    COUNT(*) FILTER (WHERE unit_price < 0) AS negative_unit_price
FROM sales;
