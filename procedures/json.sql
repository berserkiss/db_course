CREATE DIRECTORY JSON_DIR AS '/opt/oracle/oradata/XE/TablesJson';

--export
CREATE OR REPLACE PROCEDURE export_users AS
    l_file UTL_FILE.FILE_TYPE;
BEGIN
    -- Открытие файла для записи
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'users.json', 'w', 32767);

    -- Итерация по строкам таблицы Users
    FOR rec IN (
        SELECT 
            user_id, username, user_password, passport_number, email, phone, 
            is_active, firstname, lastname, birthdate, country, city, street
        FROM Users
        ORDER BY user_id
    ) LOOP
        -- Запись строки JSON в файл
        UTL_FILE.PUT_LINE(
            l_file, 
            '{"user_id": ' || rec.user_id ||
            ', "username": "' || rec.username ||
            '", "user_password": "' || rec.user_password ||
            '", "passport_number": "' || rec.passport_number ||
            '", "email": "' || rec.email ||
            '", "phone": "' || rec.phone ||
            '", "is_active": ' || rec.is_active ||
            ', "firstname": "' || rec.firstname ||
            '", "lastname": "' || rec.lastname ||
            '", "birthdate": "' || TO_CHAR(rec.birthdate, 'YYYY-MM-DD') ||
            '", "country": "' || rec.country ||
            '", "city": "' || rec.city ||
            '", "street": "' || rec.street || '"}'
        );
    END LOOP;

    -- Закрытие файла
    UTL_FILE.FCLOSE(l_file);

    DBMS_OUTPUT.PUT_LINE('Экспорт таблицы Users завершен успешно.');

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        DBMS_OUTPUT.PUT_LINE('Ошибка при выполнении процедуры: ' || sqlerrm);
END export_users;
/

CREATE OR REPLACE PROCEDURE import_users AS
    l_file UTL_FILE.FILE_TYPE;
    l_json_data VARCHAR2(32767);
    v_user_id NUMBER;
    v_username VARCHAR2(50);
    v_user_password VARCHAR2(100);
    v_passport_number VARCHAR2(100);
    v_email VARCHAR2(100);
    v_phone VARCHAR2(20);
    v_is_active NUMBER(1);
    v_firstname VARCHAR2(100);
    v_lastname VARCHAR2(100);
    v_birthdate DATE;
    v_country VARCHAR2(50);
    v_city VARCHAR2(50);
    v_street VARCHAR2(100);
BEGIN
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'users.json', 'r', 32767);

    LOOP
        BEGIN
            -- Чтение строки JSON из файла
            UTL_FILE.GET_LINE(l_file, l_json_data);

            -- Извлечение данных из JSON
            SELECT 
                JSON_VALUE(l_json_data, '$.user_id') AS user_id,
                JSON_VALUE(l_json_data, '$.username') AS username,
                JSON_VALUE(l_json_data, '$.user_password') AS user_password,
                JSON_VALUE(l_json_data, '$.passport_number') AS passport_number,
                JSON_VALUE(l_json_data, '$.email') AS email,
                JSON_VALUE(l_json_data, '$.phone') AS phone,
                JSON_VALUE(l_json_data, '$.is_active') AS is_active,
                JSON_VALUE(l_json_data, '$.firstname') AS firstname,
                JSON_VALUE(l_json_data, '$.lastname') AS lastname,
                TO_DATE(JSON_VALUE(l_json_data, '$.birthdate'), 'YYYY-MM-DD') AS birthdate, -- Добавление TO_DATE
                JSON_VALUE(l_json_data, '$.country') AS country,
                JSON_VALUE(l_json_data, '$.city') AS city,
                JSON_VALUE(l_json_data, '$.street') AS street
            INTO 
                v_user_id, v_username, v_user_password, v_passport_number, v_email, 
                v_phone, v_is_active, v_firstname, v_lastname, v_birthdate, 
                v_country, v_city, v_street
            FROM DUAL;


            -- MERGE для вставки или обновления
            MERGE INTO Users u
            USING (
                SELECT 
                    v_user_id AS user_id,
                    v_username AS username,
                    v_user_password AS user_password,
                    v_passport_number AS passport_number,
                    v_email AS email,
                    v_phone AS phone,
                    v_is_active AS is_active,
                    v_firstname AS firstname,
                    v_lastname AS lastname,
                    v_birthdate AS birthdate,
                    v_country AS country,
                    v_city AS city,
                    v_street AS street
                FROM DUAL
            ) src
            ON (u.user_id = src.user_id)
            WHEN MATCHED THEN
                UPDATE SET
                    username = src.username,
                    user_password = src.user_password,
                    passport_number = src.passport_number,
                    email = src.email,
                    phone = src.phone,
                    is_active = src.is_active,
                    firstname = src.firstname,
                    lastname = src.lastname,
                    birthdate = src.birthdate,
                    country = src.country,
                    city = src.city,
                    street = src.street
            WHEN NOT MATCHED THEN
                INSERT (
                    user_id, username, user_password, passport_number, email, 
                    phone, is_active, firstname, lastname, birthdate, 
                    country, city, street
                ) VALUES (
                    src.user_id, src.username, src.user_password, src.passport_number, src.email, 
                    src.phone, src.is_active, src.firstname, src.lastname, src.birthdate, 
                    src.country, src.city, src.street
                );

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                EXIT;
            WHEN DUP_VAL_ON_INDEX THEN
                NULL;
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Ошибка при импорте Users: ' || sqlerrm || ' Данные: ' || l_json_data);
        END;
    END LOOP;

    UTL_FILE.FCLOSE(l_file);

    DBMS_OUTPUT.PUT_LINE('Импорт таблицы Users завершен успешно.');

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        DBMS_OUTPUT.PUT_LINE('Ошибка при выполнении процедуры: ' || sqlerrm);
END import_users;
/

CREATE OR REPLACE PROCEDURE export_airports AS
    l_file UTL_FILE.FILE_TYPE; -- Объявление переменной для работы с файлом
BEGIN
    -- Открытие файла на запись
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'airports.json', 'w', 32767);

    -- Итерация по строкам таблицы Airports
    FOR rec IN (
        SELECT airport_id, iata_code, airport_name, city, country
        FROM Airports
        ORDER BY airport_id
    ) LOOP
        -- Запись строки JSON в файл
        UTL_FILE.PUT_LINE(
            l_file, 
            '{"airport_id": ' || rec.airport_id ||
            ', "iata_code": "' || rec.iata_code ||
            '", "airport_name": "' || rec.airport_name ||
            '", "city": "' || NVL(rec.city, '') ||
            '", "country": "' || NVL(rec.country, '') || '"}'
        );
    END LOOP;

    -- Закрытие файла
    UTL_FILE.FCLOSE(l_file);

    DBMS_OUTPUT.PUT_LINE('Экспорт таблицы Airports завершен успешно.');

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        DBMS_OUTPUT.PUT_LINE('Ошибка при выполнении процедуры: ' || sqlerrm);
END export_airports;
/

CREATE OR REPLACE PROCEDURE import_airports AS
    l_file UTL_FILE.FILE_TYPE;
    l_json_data VARCHAR2(32767);
    v_airport_id NUMBER;
    v_iata_code CHAR(3);
    v_airport_name VARCHAR2(100);
    v_city VARCHAR2(50);
    v_country VARCHAR2(50);
BEGIN
    -- Открытие файла на чтение
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'airports.json', 'r', 32767);

    LOOP
        BEGIN
            -- Чтение строки JSON из файла
            UTL_FILE.GET_LINE(l_file, l_json_data);

            -- Извлечение данных из строки JSON
            SELECT 
                JSON_VALUE(l_json_data, '$.airport_id') AS airport_id,
                JSON_VALUE(l_json_data, '$.iata_code') AS iata_code,
                JSON_VALUE(l_json_data, '$.airport_name') AS airport_name,
                JSON_VALUE(l_json_data, '$.city') AS city,
                JSON_VALUE(l_json_data, '$.country') AS country
            INTO 
                v_airport_id, v_iata_code, v_airport_name, v_city, v_country
            FROM DUAL;

            -- MERGE для вставки или обновления
            MERGE INTO Airports a
            USING (
                SELECT 
                    v_airport_id AS airport_id,
                    v_iata_code AS iata_code,
                    v_airport_name AS airport_name,
                    v_city AS city,
                    v_country AS country
                FROM DUAL
            ) src
            ON (a.airport_id = src.airport_id)
            WHEN MATCHED THEN
                UPDATE SET
                    iata_code = src.iata_code,
                    airport_name = src.airport_name,
                    city = src.city,
                    country = src.country
            WHEN NOT MATCHED THEN
                INSERT (
                    airport_id, iata_code, airport_name, city, country
                ) VALUES (
                    src.airport_id, src.iata_code, src.airport_name, src.city, src.country
                );

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                EXIT;
            WHEN DUP_VAL_ON_INDEX THEN
                NULL;
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Ошибка при импорте Airports: ' || sqlerrm || ' Данные: ' || l_json_data);
        END;
    END LOOP;

    -- Закрытие файла
    UTL_FILE.FCLOSE(l_file);

    DBMS_OUTPUT.PUT_LINE('Импорт таблицы Airports завершен успешно.');

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        DBMS_OUTPUT.PUT_LINE('Ошибка при выполнении процедуры: ' || sqlerrm);
END import_airports;
/

CREATE OR REPLACE PROCEDURE export_employee AS
    l_file UTL_FILE.FILE_TYPE; -- Переменная для работы с файлом
BEGIN
    -- Открытие файла на запись
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'employee.json', 'w', 32767);

    -- Итерация по строкам таблицы Employee
    FOR rec IN (
        SELECT employee_id, user_id, airport_id, job_title, hire_date, salary
        FROM Employee
         ORDER BY employee_id
    ) LOOP
        -- Запись строки JSON в файл
        UTL_FILE.PUT_LINE(
            l_file, 
            '{"employee_id": ' || rec.employee_id ||
            ', "user_id": ' || rec.user_id ||
            ', "airport_id": ' || NVL(TO_CHAR(rec.airport_id), 'null') ||
            ', "job_title": "' || rec.job_title ||
            '", "hire_date": "' || TO_CHAR(rec.hire_date, 'YYYY-MM-DD') ||
            '", "salary": ' || rec.salary || '}'
        );
    END LOOP;

    -- Закрытие файла
    UTL_FILE.FCLOSE(l_file);

    DBMS_OUTPUT.PUT_LINE('Экспорт таблицы Employee завершен успешно.');

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        DBMS_OUTPUT.PUT_LINE('Ошибка при выполнении процедуры: ' || sqlerrm);
END export_employee;
/

CREATE OR REPLACE PROCEDURE import_employee AS
    l_file UTL_FILE.FILE_TYPE; -- Переменная для работы с файлом
    l_json_data VARCHAR2(32767); -- Переменная для хранения строки JSON
    v_employee_id NUMBER;
    v_user_id NUMBER;
    v_airport_id NUMBER;
    v_job_title VARCHAR2(50);
    v_hire_date DATE;
    v_salary NUMBER;
BEGIN
    -- Открытие файла на чтение
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'employee.json', 'r', 32767);

    LOOP
        BEGIN
            -- Чтение строки JSON
            UTL_FILE.GET_LINE(l_file, l_json_data);

            -- Извлечение данных из строки JSON
            SELECT 
                JSON_VALUE(l_json_data, '$.employee_id') AS employee_id,
                JSON_VALUE(l_json_data, '$.user_id') AS user_id,
                JSON_VALUE(l_json_data, '$.airport_id') AS airport_id,
                JSON_VALUE(l_json_data, '$.job_title') AS job_title,
                TO_DATE(JSON_VALUE(l_json_data, '$.hire_date'), 'YYYY-MM-DD') AS hire_date,
                JSON_VALUE(l_json_data, '$.salary') AS salary
            INTO 
                v_employee_id, v_user_id, v_airport_id, v_job_title, v_hire_date, v_salary
            FROM DUAL;

            -- Вставка или обновление данных
            MERGE INTO Employee e
            USING (
                SELECT v_employee_id AS employee_id FROM DUAL
            ) src
            ON (e.employee_id = src.employee_id)
            WHEN MATCHED THEN
                UPDATE SET 
                    user_id = v_user_id,
                    airport_id = v_airport_id,
                    job_title = v_job_title,
                    hire_date = v_hire_date,
                    salary = v_salary
            WHEN NOT MATCHED THEN
                INSERT (
                    employee_id, user_id, airport_id, job_title, hire_date, salary
                ) VALUES (
                    v_employee_id, v_user_id, v_airport_id, v_job_title, v_hire_date, v_salary
                );

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                EXIT;
            WHEN DUP_VAL_ON_INDEX THEN
                NULL;
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Ошибка при импорте Employee: ' || sqlerrm || ' Данные: ' || l_json_data);
                RETURN;
        END;
    END LOOP;

    -- Закрытие файла
    UTL_FILE.FCLOSE(l_file);

    DBMS_OUTPUT.PUT_LINE('Импорт таблицы Employee завершен успешно.');

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        DBMS_OUTPUT.PUT_LINE('Ошибка при выполнении процедуры: ' || sqlerrm);
END import_employee;
/

CREATE OR REPLACE PROCEDURE export_airplane_types AS
    l_file UTL_FILE.FILE_TYPE; -- Переменная для работы с файлом
BEGIN
    -- Открытие файла на запись
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'airplane_types.json', 'w', 32767);

    -- Итерация по строкам таблицы Airplane_Types
    FOR rec IN (
        SELECT type_id, airplane_model, manufacturer, seating_capacity, airplane_description
        FROM Airplane_Types
        ORDER BY type_id
    ) LOOP
        -- Запись строки JSON в файл
        UTL_FILE.PUT_LINE(
            l_file, 
            '{"type_id": ' || TO_CHAR(rec.type_id) || -- Явное преобразование числа в строку
            ', "airplane_model": "' || rec.airplane_model ||
            '", "manufacturer": "' || rec.manufacturer ||
            '", "seating_capacity": ' || TO_CHAR(rec.seating_capacity) || -- Явное преобразование
            ', "airplane_description": "' || NVL(rec.airplane_description, '') || '"}' -- NULL обработан через NVL
        );
    END LOOP;

    -- Закрытие файла
    UTL_FILE.FCLOSE(l_file);

    DBMS_OUTPUT.PUT_LINE('Экспорт таблицы Airplane_Types завершен успешно.');

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        DBMS_OUTPUT.PUT_LINE('Ошибка при выполнении процедуры: ' || sqlerrm);
END export_airplane_types;
/


CREATE OR REPLACE PROCEDURE import_airplane_types AS
    l_file UTL_FILE.FILE_TYPE; -- Переменная для работы с файлом
    l_json_data VARCHAR2(32767); -- Переменная для хранения строки JSON
    v_type_id NUMBER;
    v_airplane_model VARCHAR2(50);
    v_manufacturer VARCHAR2(50);
    v_seating_capacity NUMBER;
    v_airplane_description VARCHAR2(200);
BEGIN
    -- Открытие файла на чтение
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'airplane_types.json', 'r', 32767);

    LOOP
        BEGIN
            -- Чтение строки JSON
            UTL_FILE.GET_LINE(l_file, l_json_data);

            -- Извлечение данных из строки JSON
            SELECT 
                JSON_VALUE(l_json_data, '$.type_id') AS type_id,
                JSON_VALUE(l_json_data, '$.airplane_model') AS airplane_model,
                JSON_VALUE(l_json_data, '$.manufacturer') AS manufacturer,
                JSON_VALUE(l_json_data, '$.seating_capacity') AS seating_capacity,
                JSON_VALUE(l_json_data, '$.airplane_description') AS airplane_description
            INTO 
                v_type_id, v_airplane_model, v_manufacturer, v_seating_capacity, v_airplane_description
            FROM DUAL;

            -- Вставка или обновление данных
            MERGE INTO Airplane_Types t
            USING (
                SELECT v_type_id AS type_id FROM DUAL
            ) src
            ON (t.type_id = src.type_id)
            WHEN MATCHED THEN
                UPDATE SET 
                    airplane_model = v_airplane_model,
                    manufacturer = v_manufacturer,
                    seating_capacity = v_seating_capacity,
                    airplane_description = v_airplane_description
            WHEN NOT MATCHED THEN
                INSERT (
                    type_id, airplane_model, manufacturer, seating_capacity, airplane_description
                ) VALUES (
                    v_type_id, v_airplane_model, v_manufacturer, v_seating_capacity, v_airplane_description
                );

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                EXIT;
            WHEN DUP_VAL_ON_INDEX THEN
                NULL;
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Ошибка при импорте Airplane_Types: ' || sqlerrm || ' Данные: ' || l_json_data);
                RETURN;
        END;
    END LOOP;

    -- Закрытие файла
    UTL_FILE.FCLOSE(l_file);

    DBMS_OUTPUT.PUT_LINE('Импорт таблицы Airplane_Types завершен успешно.');

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        DBMS_OUTPUT.PUT_LINE('Ошибка при выполнении процедуры: ' || sqlerrm);
END import_airplane_types;
/

CREATE OR REPLACE PROCEDURE export_airlines AS
    l_file UTL_FILE.FILE_TYPE; -- Переменная для работы с файлом
BEGIN
    -- Открытие файла на запись
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'airlines.json', 'w', 32767);

    -- Итерация по строкам таблицы Airlines
    FOR rec IN (
        SELECT airline_id, iata_code, airline_name, country, base_airport_id
        FROM Airlines
        ORDER BY airline_id
    ) LOOP
        -- Запись строки JSON в файл
        UTL_FILE.PUT_LINE(
            l_file, 
            '{"airline_id": ' || TO_CHAR(rec.airline_id) || -- Явное преобразование числа
            ', "iata_code": "' || rec.iata_code ||
            '", "airline_name": "' || rec.airline_name ||
            '", "country": "' || NVL(rec.country, '') ||
            '", "base_airport_id": ' || 
            CASE 
                WHEN rec.base_airport_id IS NULL THEN 'null' -- Обработка NULL как "null" в JSON
                ELSE TO_CHAR(rec.base_airport_id) -- Преобразование числа в строку
            END || '}'
        );
    END LOOP;

    -- Закрытие файла
    UTL_FILE.FCLOSE(l_file);

    DBMS_OUTPUT.PUT_LINE('Экспорт таблицы Airlines завершен успешно.');

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        DBMS_OUTPUT.PUT_LINE('Ошибка при выполнении процедуры: ' || sqlerrm);
END export_airlines;
/


CREATE OR REPLACE PROCEDURE import_airlines AS
    l_file UTL_FILE.FILE_TYPE; -- Переменная для работы с файлом
    l_json_data VARCHAR2(32767); -- Переменная для хранения строки JSON
    v_airline_id NUMBER;
    v_iata_code CHAR(2);
    v_airline_name VARCHAR2(100);
    v_country VARCHAR2(50);
    v_base_airport_id NUMBER;
BEGIN
    -- Открытие файла на чтение
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'airlines.json', 'r', 32767);

    LOOP
        BEGIN
            -- Чтение строки JSON
            UTL_FILE.GET_LINE(l_file, l_json_data);

            -- Извлечение данных из строки JSON
            SELECT 
                JSON_VALUE(l_json_data, '$.airline_id') AS airline_id,
                JSON_VALUE(l_json_data, '$.iata_code') AS iata_code,
                JSON_VALUE(l_json_data, '$.airline_name') AS airline_name,
                JSON_VALUE(l_json_data, '$.country') AS country,
                JSON_VALUE(l_json_data, '$.base_airport_id') AS base_airport_id
            INTO 
                v_airline_id, v_iata_code, v_airline_name, v_country, v_base_airport_id
            FROM DUAL;

            -- Вставка или обновление данных
            MERGE INTO Airlines t
            USING (
                SELECT v_airline_id AS airline_id FROM DUAL
            ) src
            ON (t.airline_id = src.airline_id)
            WHEN MATCHED THEN
                UPDATE SET 
                    iata_code = v_iata_code,
                    airline_name = v_airline_name,
                    country = v_country,
                    base_airport_id = v_base_airport_id
            WHEN NOT MATCHED THEN
                INSERT (
                    airline_id, iata_code, airline_name, country, base_airport_id
                ) VALUES (
                    v_airline_id, v_iata_code, v_airline_name, v_country, v_base_airport_id
                );

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                EXIT;
            WHEN DUP_VAL_ON_INDEX THEN
                NULL;
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Ошибка при импорте Airlines: ' || sqlerrm || ' Данные: ' || l_json_data);
                RETURN;
        END;
    END LOOP;

    -- Закрытие файла
    UTL_FILE.FCLOSE(l_file);

    DBMS_OUTPUT.PUT_LINE('Импорт таблицы Airlines завершен успешно.');

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        DBMS_OUTPUT.PUT_LINE('Ошибка при выполнении процедуры: ' || sqlerrm);
END import_airlines;
/

CREATE OR REPLACE PROCEDURE export_airplanes AS
    l_file UTL_FILE.FILE_TYPE; -- Переменная для работы с файлом
BEGIN
    -- Открытие файла на запись
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'airplanes.json', 'w', 32767);

    -- Итерация по строкам таблицы Airplanes
    FOR rec IN (
        SELECT airplane_id, type_id, airline_id, tail_number, airplane_status
        FROM Airplanes
        ORDER BY airplane_id
    ) LOOP
        -- Запись строки JSON в файл
        UTL_FILE.PUT_LINE(
            l_file, 
            '{"airplane_id": ' || rec.airplane_id ||
            ', "type_id": ' || rec.type_id ||
            ', "airline_id": ' || rec.airline_id ||
            ', "tail_number": "' || rec.tail_number ||
            '", "airplane_status": "' || rec.airplane_status || '"}'
        );
    END LOOP;

    -- Закрытие файла
    UTL_FILE.FCLOSE(l_file);

    DBMS_OUTPUT.PUT_LINE('Экспорт таблицы Airplanes завершен успешно.');

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        DBMS_OUTPUT.PUT_LINE('Ошибка при выполнении процедуры: ' || sqlerrm);
END export_airplanes;
/

CREATE OR REPLACE PROCEDURE import_airplanes AS
    l_file UTL_FILE.FILE_TYPE; -- Переменная для работы с файлом
    l_json_data VARCHAR2(32767); -- Переменная для хранения строки JSON
    v_airplane_id NUMBER;
    v_type_id NUMBER;
    v_airline_id NUMBER;
    v_tail_number VARCHAR2(20);
    v_airplane_status VARCHAR2(20);
BEGIN
    -- Открытие файла на чтение
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'airplanes.json', 'r', 32767);

    LOOP
        BEGIN
            -- Чтение строки JSON
            UTL_FILE.GET_LINE(l_file, l_json_data);

            -- Извлечение данных из строки JSON
            SELECT 
                JSON_VALUE(l_json_data, '$.airplane_id') AS airplane_id,
                JSON_VALUE(l_json_data, '$.type_id') AS type_id,
                JSON_VALUE(l_json_data, '$.airline_id') AS airline_id,
                JSON_VALUE(l_json_data, '$.tail_number') AS tail_number,
                JSON_VALUE(l_json_data, '$.airplane_status') AS airplane_status
            INTO 
                v_airplane_id, v_type_id, v_airline_id, v_tail_number, v_airplane_status
            FROM DUAL;

            -- Вставка или обновление данных
            MERGE INTO Airplanes t
            USING (
                SELECT v_airplane_id AS airplane_id FROM DUAL
            ) src
            ON (t.airplane_id = src.airplane_id)
            WHEN MATCHED THEN
                UPDATE SET 
                    type_id = v_type_id,
                    airline_id = v_airline_id,
                    tail_number = v_tail_number,
                    airplane_status = v_airplane_status
            WHEN NOT MATCHED THEN
                INSERT (
                    airplane_id, type_id, airline_id, tail_number, airplane_status
                ) VALUES (
                    v_airplane_id, v_type_id, v_airline_id, v_tail_number, v_airplane_status
                );

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                EXIT;
            WHEN DUP_VAL_ON_INDEX THEN
                NULL;
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Ошибка при импорте Airplanes: ' || sqlerrm || ' Данные: ' || l_json_data);
                RETURN;
        END;
    END LOOP;

    -- Закрытие файла
    UTL_FILE.FCLOSE(l_file);

    DBMS_OUTPUT.PUT_LINE('Импорт таблицы Airplanes завершен успешно.');

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        DBMS_OUTPUT.PUT_LINE('Ошибка при выполнении процедуры: ' || sqlerrm);
END import_airplanes;
/

CREATE OR REPLACE PROCEDURE export_flights AS
    l_file UTL_FILE.FILE_TYPE; -- Переменная для работы с файлом
BEGIN
    -- Открытие файла на запись
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'flights.json', 'w', 32767);

    -- Итерация по строкам таблицы Flights
    FOR rec IN (
        SELECT 
            flight_id, flight_number, departure_airport_id, arrival_airport_id, 
            TO_CHAR(departure_time, 'YYYY-MM-DD"T"HH24:MI:SS') AS departure_time,
            TO_CHAR(arrival_time, 'YYYY-MM-DD"T"HH24:MI:SS') AS arrival_time,
            airline_id, airplane_id, flight_status
        FROM Flights
        ORDER BY flight_id
    ) LOOP
        -- Запись строки JSON в файл
        UTL_FILE.PUT_LINE(
            l_file, 
            '{"flight_id": ' || rec.flight_id ||
            ', "flight_number": "' || rec.flight_number ||
            '", "departure_airport_id": ' || rec.departure_airport_id ||
            ', "arrival_airport_id": ' || rec.arrival_airport_id ||
            ', "departure_time": "' || rec.departure_time ||
            '", "arrival_time": "' || rec.arrival_time ||
            '", "airline_id": ' || rec.airline_id ||
            ', "airplane_id": ' || rec.airplane_id ||
            ', "flight_status": "' || rec.flight_status || '"}'
        );
    END LOOP;

    -- Закрытие файла
    UTL_FILE.FCLOSE(l_file);

    DBMS_OUTPUT.PUT_LINE('Экспорт таблицы Flights завершен успешно.');

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        DBMS_OUTPUT.PUT_LINE('Ошибка при выполнении процедуры: ' || sqlerrm);
END export_flights;
/

CREATE OR REPLACE PROCEDURE import_flights AS
    l_file UTL_FILE.FILE_TYPE; -- Переменная для работы с файлом
    l_json_data VARCHAR2(32767); -- Переменная для строки JSON
    v_flight_id NUMBER;
    v_flight_number VARCHAR2(20);
    v_departure_airport_id NUMBER;
    v_arrival_airport_id NUMBER;
    v_departure_time TIMESTAMP;
    v_arrival_time TIMESTAMP;
    v_airline_id NUMBER;
    v_airplane_id NUMBER;
    v_flight_status VARCHAR2(20);
BEGIN
    -- Открытие файла на чтение
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'flights.json', 'r', 32767);

    LOOP
        BEGIN
            -- Чтение строки JSON
            UTL_FILE.GET_LINE(l_file, l_json_data);

            -- Извлечение данных из строки JSON
            SELECT 
                JSON_VALUE(l_json_data, '$.flight_id') AS flight_id,
                JSON_VALUE(l_json_data, '$.flight_number') AS flight_number,
                JSON_VALUE(l_json_data, '$.departure_airport_id') AS departure_airport_id,
                JSON_VALUE(l_json_data, '$.arrival_airport_id') AS arrival_airport_id,
                TO_TIMESTAMP(JSON_VALUE(l_json_data, '$.departure_time'), 'YYYY-MM-DD"T"HH24:MI:SS') AS departure_time,
                TO_TIMESTAMP(JSON_VALUE(l_json_data, '$.arrival_time'), 'YYYY-MM-DD"T"HH24:MI:SS') AS arrival_time,
                JSON_VALUE(l_json_data, '$.airline_id') AS airline_id,
                JSON_VALUE(l_json_data, '$.airplane_id') AS airplane_id,
                JSON_VALUE(l_json_data, '$.flight_status') AS flight_status
            INTO 
                v_flight_id, v_flight_number, v_departure_airport_id, v_arrival_airport_id, 
                v_departure_time, v_arrival_time, v_airline_id, v_airplane_id, v_flight_status
            FROM DUAL;

            -- Проверка логики и вставка/обновление
            IF v_departure_time >= v_arrival_time THEN
                RAISE_APPLICATION_ERROR(-20001, 'Время вылета не может быть позже или равно времени прилета.');
            END IF;

            -- Обновленная часть с исключением flight_number
            MERGE INTO Flights t
            USING (
                SELECT v_flight_id AS flight_id FROM DUAL
            ) src
            ON (t.flight_id = src.flight_id)
            WHEN MATCHED THEN
                UPDATE SET 
                    flight_number = v_flight_number,
                    departure_airport_id = v_departure_airport_id,
                    arrival_airport_id = v_arrival_airport_id,
                    departure_time = v_departure_time,
                    arrival_time = v_arrival_time,
                    airline_id = v_airline_id,
                    airplane_id = v_airplane_id,
                    flight_status = v_flight_status
            WHEN NOT MATCHED THEN
                INSERT (
                    flight_id, flight_number, departure_airport_id, arrival_airport_id, 
                    departure_time, arrival_time, airline_id, airplane_id, flight_status
                ) VALUES (
                    v_flight_id, v_flight_number, v_departure_airport_id, v_arrival_airport_id, 
                    v_departure_time, v_arrival_time, v_airline_id, v_airplane_id, v_flight_status
                );

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                EXIT;
            WHEN DUP_VAL_ON_INDEX THEN
                NULL;
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Ошибка при импорте Flights: ' || sqlerrm || ' Данные: ' || l_json_data);
                RETURN;
        END;
    END LOOP;

    -- Закрытие файла
    UTL_FILE.FCLOSE(l_file);

    DBMS_OUTPUT.PUT_LINE('Импорт таблицы Flights завершен успешно.');

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        DBMS_OUTPUT.PUT_LINE('Ошибка при выполнении процедуры: ' || sqlerrm);
END import_flights;
/


CREATE OR REPLACE PROCEDURE export_tickets AS
    l_file UTL_FILE.FILE_TYPE; -- Variable for working with the file
BEGIN
    -- Open the file for writing
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'tickets.json', 'w', 32767);

    -- Iterate through rows of the Tickets table
    FOR rec IN (
        SELECT 
            ticket_id, 
            ticket_number, 
            flight_id, 
            NVL(TO_CHAR(passenger_id), 'null') AS passenger_id, -- Handling NULL for passenger_id
            seat_number, 
            price, 
            purchase_date, 
            ticket_class, 
            ticket_status
        FROM Tickets
        ORDER BY ticket_id
    ) LOOP
        -- Writing JSON string to the file
        UTL_FILE.PUT_LINE(
            l_file, 
            '{"ticket_id": ' || TO_CHAR(rec.ticket_id) || -- Explicit conversion of number
            ', "ticket_number": "' || rec.ticket_number ||
            '", "flight_id": ' || TO_CHAR(rec.flight_id) ||
            ', "passenger_id": ' || rec.passenger_id || -- Already handled NVL
            ', "seat_number": "' || rec.seat_number ||
            '", "price": ' || TO_CHAR(rec.price) || -- Convert number to string
            ', "purchase_date": ' || 
                CASE
                    WHEN rec.purchase_date IS NULL THEN 'null' -- If date is NULL, insert 'null' (without quotes)
                    ELSE '"' || TO_CHAR(rec.purchase_date, 'YYYY-MM-DD"T"HH24:MI:SS') || '"'
                END ||
            ', "ticket_class": "' || rec.ticket_class ||
            '", "ticket_status": "' || rec.ticket_status || '"}'
        );
    END LOOP;

    -- Close the file
    UTL_FILE.FCLOSE(l_file);

    DBMS_OUTPUT.PUT_LINE('Export of the Tickets table completed successfully.');

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        DBMS_OUTPUT.PUT_LINE('Error occurred while executing the procedure: ' || sqlerrm);
END export_tickets;
/



CREATE OR REPLACE PROCEDURE import_tickets AS
    l_file UTL_FILE.FILE_TYPE; -- Variable for working with the file
    l_json_data VARCHAR2(32767); -- Variable for the JSON string
    v_ticket_id NUMBER;
    v_ticket_number VARCHAR2(20);
    v_flight_id NUMBER;
    v_passenger_id NUMBER;
    v_seat_number VARCHAR2(5);
    v_price NUMBER;
    v_purchase_date TIMESTAMP;
    v_ticket_class VARCHAR2(20);
    v_ticket_status VARCHAR2(20);
BEGIN
    -- Open the file for reading
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'tickets.json', 'r', 32767);

    LOOP
        BEGIN
            -- Read a JSON line from the file
            UTL_FILE.GET_LINE(l_file, l_json_data);

            -- Extract data from the JSON string
            SELECT 
                JSON_VALUE(l_json_data, '$.ticket_id') AS ticket_id,
                JSON_VALUE(l_json_data, '$.ticket_number') AS ticket_number,
                JSON_VALUE(l_json_data, '$.flight_id') AS flight_id,
                JSON_VALUE(l_json_data, '$.passenger_id') AS passenger_id,
                JSON_VALUE(l_json_data, '$.seat_number') AS seat_number,
                JSON_VALUE(l_json_data, '$.price') AS price,
                TO_TIMESTAMP(JSON_VALUE(l_json_data, '$.purchase_date'), 'YYYY-MM-DD"T"HH24:MI:SS') AS purchase_date,
                JSON_VALUE(l_json_data, '$.ticket_class') AS ticket_class,
                JSON_VALUE(l_json_data, '$.ticket_status') AS ticket_status
            INTO 
                v_ticket_id, v_ticket_number, v_flight_id, v_passenger_id, 
                v_seat_number, v_price, v_purchase_date, v_ticket_class, v_ticket_status
            FROM DUAL;

            -- Insert or update the Tickets table
            MERGE INTO Tickets t
            USING (
                SELECT v_ticket_id AS ticket_id FROM DUAL
            ) src
            ON (t.ticket_id = src.ticket_id)
            WHEN MATCHED THEN
                UPDATE SET 
                    ticket_number = v_ticket_number,
                    flight_id = v_flight_id,
                    passenger_id = v_passenger_id,
                    seat_number = v_seat_number,
                    price = v_price,
                    purchase_date = v_purchase_date,
                    ticket_class = v_ticket_class,
                    ticket_status = v_ticket_status
            WHEN NOT MATCHED THEN
                INSERT (
                    ticket_id, ticket_number, flight_id, passenger_id, 
                    seat_number, price, purchase_date, ticket_class, ticket_status
                ) VALUES (
                    v_ticket_id, v_ticket_number, v_flight_id, v_passenger_id, 
                    v_seat_number, v_price, v_purchase_date, v_ticket_class, v_ticket_status
                );

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                EXIT;
            WHEN DUP_VAL_ON_INDEX THEN
                NULL;  -- Skip duplicate entries
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error importing Tickets: ' || sqlerrm || ' Data: ' || l_json_data);
                RETURN;
        END;
    END LOOP;

    -- Close the file
    UTL_FILE.FCLOSE(l_file);

    DBMS_OUTPUT.PUT_LINE('Import of Tickets table completed successfully.');

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        DBMS_OUTPUT.PUT_LINE('Error during procedure execution: ' || sqlerrm);
END import_tickets;
/


BEGIN
    export_users;
END;
/

BEGIN
    export_airports;
END;
/

BEGIN
    export_airplane_types;
END;
/

BEGIN
    export_airlines;
END;
/

BEGIN
    export_employee;
END;
/

BEGIN
    export_airplanes;
END;
/

BEGIN
    export_flights;
END;
/

BEGIN
    export_tickets;
END;
/


BEGIN
    import_users;
END;
/

BEGIN
    import_airports;
END;
/

BEGIN
    import_airplane_types;
END;
/

BEGIN
    import_airlines;
END;
/

BEGIN
    import_employee;
END;
/

BEGIN
    import_airplanes;
END;
/

BEGIN
    import_flights;
END;
/

BEGIN
    import_tickets;
END;
/









