DECLARE
    v_counter NUMBER := 0; -- Счетчик для количества вставок
BEGIN
    -- Используем APPEND для ускорения вставки
    FOR i IN 1..100000 LOOP
        -- Пакетная вставка (используется BULK COLLECT и FORALL)
        INSERT /*+ APPEND */ INTO Airplane_Types (
            airplane_model, 
            manufacturer, 
            seating_capacity, 
            airplane_description
        ) VALUES (
            'Model_' || TO_CHAR(i), -- Динамическое имя модели (например: Model_1, Model_2, ...)
            'Manufacturer_' || TO_CHAR(MOD(i, 50) + 1), -- 50 уникальных производителей
            MOD(i, 300) + 100, -- Вместимость от 100 до 400 мест
            'Description for airplane model ' || TO_CHAR(i) -- Описание
        );
    END LOOP;

    -- Заключительный коммит
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('100,000 rows successfully inserted into Airplane_Types table.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error during insert: ' || SQLERRM);
END;
/

DECLARE
    TYPE t_airplane_model IS TABLE OF VARCHAR2(100);
    TYPE t_manufacturer IS TABLE OF VARCHAR2(100);
    TYPE t_seating_capacity IS TABLE OF NUMBER;
    TYPE t_airplane_description IS TABLE OF VARCHAR2(400);

    v_airplane_model t_airplane_model := t_airplane_model(); -- Инициализация коллекций
    v_manufacturer t_manufacturer := t_manufacturer();
    v_seating_capacity t_seating_capacity := t_seating_capacity();
    v_airplane_description t_airplane_description := t_airplane_description();
BEGIN
    -- Заполнение коллекций данными
    FOR i IN 1..100000 LOOP
        v_airplane_model.EXTEND;
        v_manufacturer.EXTEND;
        v_seating_capacity.EXTEND;
        v_airplane_description.EXTEND;

        v_airplane_model(v_airplane_model.COUNT) := 'Model_' || TO_CHAR(i);
        v_manufacturer(v_manufacturer.COUNT) := 'Manufacturer_' || TO_CHAR(MOD(i, 50) + 1);
        v_seating_capacity(v_seating_capacity.COUNT) := MOD(i, 300) + 100;
        v_airplane_description(v_airplane_description.COUNT) := 'Description for airplane model ' || TO_CHAR(i);
    END LOOP;

    -- Пакетная вставка
    FORALL i IN 1..v_airplane_model.COUNT
        INSERT INTO Airplane_Types (
            airplane_model, 
            manufacturer, 
            seating_capacity, 
            airplane_description
        ) VALUES (
            v_airplane_model(i),
            v_manufacturer(i),
            v_seating_capacity(i),
            v_airplane_description(i)
        );

    COMMIT;
END;
/

ALTER SESSION ENABLE PARALLEL DML;

DELETE FROM Airplane_Types
WHERE type_id > 10;

COMMIT;

select * from Airplane_Types where type_id = 10000;

CREATE INDEX idx_airplane_model ON Airplane_Types (airplane_model);
CREATE INDEX idx_manufacturer ON Airplane_Types (manufacturer);




