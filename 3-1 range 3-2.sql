
-- 3.1. ПЕРВИЧНЫЙ КЛЮЧ + SEQUENCE

-- Проверяем: уникален ли data.general.id
SELECT "data.general.id", COUNT(*)
FROM culture_data.culture_places_clubs
GROUP BY "data.general.id"
HAVING COUNT(*) > 1;

-- Создаём sequence для суррогатного PK
CREATE SEQUENCE culture_data.culture_places_clubs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- Добавляем суррогатный столбец id
ALTER TABLE culture_data.culture_places_clubs
    ADD COLUMN id BIGINT;

-- Заполняем id из sequence
UPDATE culture_data.culture_places_clubs
SET id = nextval('culture_data.culture_places_clubs_id_seq');

-- Делаем id обязательным и назначаем PK
ALTER TABLE culture_data.culture_places_clubs
    ALTER COLUMN id SET NOT NULL;

ALTER TABLE culture_data.culture_places_clubs
    ADD CONSTRAINT culture_places_clubs_pkey PRIMARY KEY (id);

-- Привязываем sequence к колонке
ALTER SEQUENCE culture_data.culture_places_clubs_id_seq
    OWNED BY culture_data.culture_places_clubs.id;

-- Автозаполнение id для будущих вставок
ALTER TABLE culture_data.culture_places_clubs
    ALTER COLUMN id SET DEFAULT nextval('culture_data.culture_places_clubs_id_seq');

-- Проверка
SELECT COUNT(*) AS total,
       COUNT(id) AS with_id,
       COUNT(DISTINCT id) AS distinct_id
FROM culture_data.culture_places_clubs;


-- 3.2. ОГРАНИЧЕНИЯ NOT NULL И UNIQUE


-- --- NOT NULL ---
-- Проверяем кандидатов
SELECT
    COUNT(*) FILTER (WHERE "data.general.name" IS NULL) AS null_name,
    COUNT(*) FILTER (WHERE "data.general.address.fullAddress" IS NULL) AS null_addr
FROM culture_data.culture_places_clubs;

-- NOT NULL: название учреждения обязательно
ALTER TABLE culture_data.culture_places_clubs
    ALTER COLUMN "data.general.name" SET NOT NULL;

-- NOT NULL: полный адрес обязателен
ALTER TABLE culture_data.culture_places_clubs
    ALTER COLUMN "data.general.address.fullAddress" SET NOT NULL;

-- --- UNIQUE ---
-- Проверяем, что data.general.id уникален
SELECT COUNT(*) AS total,
       COUNT(DISTINCT "data.general.id") AS distinct_ids
FROM culture_data.culture_places_clubs;

-- Если total = distinct_ids — можно смело создавать UNIQUE
ALTER TABLE culture_data.culture_places_clubs
    ADD CONSTRAINT uq_culture_general_id
    UNIQUE ("data.general.id");

-- Проверка, что ограничение создано
SELECT conname, contype
FROM pg_constraint
WHERE conrelid = 'culture_data.culture_places_clubs'::regclass
  AND contype IN ('p', 'u');

-- PK и UNIQUE на месте
SELECT conname, contype
FROM pg_constraint
WHERE conrelid = 'culture_data.culture_places_clubs'::regclass
ORDER BY contype;
