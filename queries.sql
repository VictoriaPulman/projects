-- 1. Воронка конверсий по уникальным пользователям (view -> cart -> remove_from_cart -> purchase)
WITH funnel AS (
    SELECT
        event_type,
        COUNT(DISTINCT user_id) AS unique_users,
        COUNT(*) AS total_events
    FROM "2019_Dec"
    WHERE price > 0
      AND event_type IN ('view', 'cart', 'remove_from_cart', 'purchase')
    GROUP BY event_type
)
SELECT
    event_type,
    unique_users,
    total_events,
    ROUND(100.0 * unique_users / MAX(unique_users) OVER (), 2) AS conv_from_view_pct
FROM funnel
ORDER BY unique_users DESC;

-- 2. Сравнение воронки в бюджетном (< $10) и премиальном (>= $10) сегментах
WITH segmented AS (
    SELECT
        CASE WHEN price >= 10 THEN 'Premium (>= $10)' ELSE 'Mass-market (< $10)' END AS price_segment,
        event_type,
        user_id
    FROM "2019_Dec"
    WHERE price > 0
)
SELECT
    price_segment,
    COUNT(DISTINCT CASE WHEN event_type = 'view' THEN user_id END) AS view_users,
    COUNT(DISTINCT CASE WHEN event_type = 'cart' THEN user_id END) AS cart_users,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchase_users,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) /
          NULLIF(COUNT(DISTINCT CASE WHEN event_type = 'view' THEN user_id END), 0), 2) AS cr_to_purchase_pct
FROM segmented
GROUP BY price_segment;

-- 3. ТОП-10 брендов по выручке и доле удалений из корзины (без пустых брендов)
SELECT
    brand AS brand_name,
    COUNT(DISTINCT CASE WHEN event_type = 'cart' THEN user_session END) AS cart_sessions,
    COUNT(DISTINCT CASE WHEN event_type = 'remove_from_cart' THEN user_session END) AS remove_sessions,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_session END) AS purchase_sessions,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN event_type = 'remove_from_cart' THEN user_session END) /
          NULLIF(COUNT(DISTINCT CASE WHEN event_type = 'cart' THEN user_session END), 0), 2) AS remove_rate_pct,
    ROUND(CAST(SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END) AS NUMERIC), 2) AS total_revenue
FROM "2019_Dec"
WHERE price > 0
  AND brand IS NOT NULL
  AND TRIM(brand) <> ''
GROUP BY brand
HAVING COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_session END) > 50
ORDER BY total_revenue DESC
LIMIT 10;

