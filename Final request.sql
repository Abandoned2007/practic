-- ФИНАЛЬНАЯ ПРОВЕРКА

-- Список таблиц в схеме
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'culture_data'
ORDER BY table_name;

-- Колонки основной таблицы
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'culture_data'
  AND table_name = 'culture_places_clubs'
ORDER BY ordinal_position;

-- Итоговая статистика
SELECT
    (SELECT COUNT(*) FROM culture_data.culture_places_clubs) AS places,
    (SELECT COUNT(*) FROM culture_data.culture_places_clubs WHERE geom IS NOT NULL) AS with_geom,
    (SELECT COUNT(*) FROM culture_data.tags) AS tags,
    (SELECT COUNT(*) FROM culture_data.m2m_culture_places_clubs_tags) AS links;