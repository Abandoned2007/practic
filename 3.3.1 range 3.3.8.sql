
-- 3.3.1. УДАЛЕНИЕ ВСЕГО, КРОМЕ ВОЛОГОДСКОЙ ОБЛАСТИ

-- Смотрим, какие регионы есть в данных
SELECT DISTINCT "data.general.locale.name"
FROM culture_data.culture_places_clubs
LIMIT 50;

-- Удаляем всё, что не Вологодская область
DELETE FROM culture_data.culture_places_clubs
WHERE "data.general.locale.name" NOT LIKE '%Вологодская%'
   OR "data.general.locale.name" IS NULL;

-- Проверка
SELECT COUNT(*) FROM culture_data.culture_places_clubs;
SELECT DISTINCT "data.general.locale.name"
FROM culture_data.culture_places_clubs;


-- 3.3.2. POSTGIS + КОЛОНКА geom

-- Устанавливаем расширение PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- Проверяем версию
SELECT PostGIS_Version();

-- Добавляем колонку geom
ALTER TABLE culture_data.culture_places_clubs
    ADD COLUMN geom geometry(Point, 4326);


-- 3.3.3 – 3.3.4. ЗАПОЛНЕНИЕ geom ИЗ JSONB

-- Смотрим пример mapPosition
SELECT "data.general.address.mapPosition"
FROM culture_data.culture_places_clubs
WHERE "data.general.address.mapPosition" IS NOT NULL
LIMIT 5;

-- Заполняем geom через ST_GeomFromGeoJSON
UPDATE culture_data.culture_places_clubs
SET geom = ST_GeomFromGeoJSON("data.general.address.mapPosition"::text)
WHERE "data.general.address.mapPosition" IS NOT NULL
  AND "data.general.address.mapPosition"::text <> ''
  AND "data.general.address.mapPosition"::text <> 'null';

-- Проверка: сколько строк получили геометрию
SELECT
    COUNT(*) AS total,
    COUNT(geom) AS with_geom,
    COUNT(*) - COUNT(geom) AS without_geom
FROM culture_data.culture_places_clubs;

-- Проверка SRID
SELECT ST_SRID(geom), COUNT(*)
FROM culture_data.culture_places_clubs
WHERE geom IS NOT NULL
GROUP BY 1;


-- 3.3.5. ТАБЛИЦА tags

CREATE TABLE culture_data.tags (
    id          BIGSERIAL PRIMARY KEY,          -- PK + sequence
    name        VARCHAR(255) NOT NULL UNIQUE,   -- название тега
    created_at  TIMESTAMPTZ DEFAULT NOW(),      -- дата добавления
    description TEXT                            -- описание
);

-- Проверка
SELECT * FROM culture_data.tags;


-- 3.3.6. ЗАПОЛНЕНИЕ tags ИЗ JSONB-МАССИВА

-- Проверяем тип данных в data.general.tags
SELECT jsonb_typeof("data.general.tags"), COUNT(*)
FROM culture_data.culture_places_clubs
GROUP BY 1;

-- Вставляем уникальные теги (в файле теги — объекты {id, name, sysName})
INSERT INTO culture_data.tags (name)
SELECT DISTINCT elem->>'name'
FROM culture_data.culture_places_clubs c
CROSS JOIN LATERAL jsonb_array_elements(c."data.general.tags") AS elem
WHERE c."data.general.tags" IS NOT NULL
  AND jsonb_typeof(c."data.general.tags") = 'array'
  AND elem->>'name' IS NOT NULL
ON CONFLICT (name) DO NOTHING;

-- Проверка
SELECT COUNT(*) AS total_tags FROM culture_data.tags;
SELECT * FROM culture_data.tags LIMIT 20;


-- 3.3.7. M2M-ТАБЛИЦА

CREATE TABLE culture_data.m2m_culture_places_clubs_tags (
    culture_place_id BIGINT NOT NULL
        REFERENCES culture_data.culture_places_clubs(id) ON DELETE CASCADE,
    tag_id           BIGINT NOT NULL
        REFERENCES culture_data.tags(id) ON DELETE CASCADE,
    PRIMARY KEY (culture_place_id, tag_id)
);

-- Заполняем связями
INSERT INTO culture_data.m2m_culture_places_clubs_tags (culture_place_id, tag_id)
SELECT DISTINCT
    c.id,
    t.id
FROM culture_data.culture_places_clubs c
CROSS JOIN LATERAL jsonb_array_elements(c."data.general.tags") AS elem
JOIN culture_data.tags t ON t.name = elem->>'name'
WHERE c."data.general.tags" IS NOT NULL
  AND jsonb_typeof(c."data.general.tags") = 'array'
ON CONFLICT DO NOTHING;

-- Проверка
SELECT COUNT(*) AS total_links
FROM culture_data.m2m_culture_places_clubs_tags;

-- Сколько тегов у каждого учреждения (топ-20)
SELECT c.id, c."data.general.name", COUNT(m.tag_id) AS tag_count
FROM culture_data.culture_places_clubs c
LEFT JOIN culture_data.m2m_culture_places_clubs_tags m
       ON m.culture_place_id = c.id
GROUP BY c.id, c."data.general.name"
ORDER BY tag_count DESC
LIMIT 20;


-- 3.3.8. ИНДЕКСЫ НА M2M-ТАБЛИЦЕ

CREATE INDEX idx_m2m_culture_place_id
    ON culture_data.m2m_culture_places_clubs_tags (culture_place_id);

CREATE INDEX idx_m2m_tag_id
    ON culture_data.m2m_culture_places_clubs_tags (tag_id);

-- Проверка индексов
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'culture_data'
  AND tablename = 'm2m_culture_places_clubs_tags';

