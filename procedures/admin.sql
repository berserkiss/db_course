--package for encryption
CREATE OR REPLACE TRIGGER trg_flight_number_generation
BEFORE INSERT OR UPDATE ON Flights
FOR EACH ROW
BEGIN
    -- Проверяем, что значение flight_id в пределах допустимого диапазона
    IF :NEW.flight_id > 999999 THEN
         DBMS_OUTPUT.PUT_LINE('Error: ticket_id exceeds the maximum allowed value.');
        RAISE_APPLICATION_ERROR(-20001, 'flight_id exceeds the maximum allowed value.');
    END IF;

    -- Генерация номера рейса
    :NEW.flight_number := 'FLIGHT-' || LPAD(TO_CHAR(:NEW.flight_id), 6, '0');
END;
/

CREATE OR REPLACE TRIGGER trg_ticket_number_generation
BEFORE INSERT OR UPDATE ON Tickets
FOR EACH ROW
BEGIN
    -- Проверка, что ticket_id не превышает допустимое значение
    IF :NEW.ticket_id > 999999 THEN
        -- Вывод ошибки через DBMS_OUTPUT
        DBMS_OUTPUT.PUT_LINE('Error: ticket_id exceeds the maximum allowed value.');
        -- Исключение
        RAISE_APPLICATION_ERROR(-20001, 'ticket_id exceeds the maximum allowed value.');
    ELSE
        -- Генерация номера билета
        :NEW.ticket_number := 'TICKET-' || LPAD(:NEW.ticket_id, 6, '0');
    END IF;
END;
/



CREATE OR REPLACE PACKAGE pkg_crypto_utils AUTHID DEFINER AS
    FUNCTION encrypt_data(p_data IN NVARCHAR2) RETURN NVARCHAR2;
    FUNCTION decrypt_data(p_encrypted_data IN NVARCHAR2) RETURN NVARCHAR2;
END pkg_crypto_utils;
/

CREATE OR REPLACE PACKAGE BODY pkg_crypto_utils AS
    ctype CONSTANT PLS_INTEGER := DBMS_CRYPTO.ENCRYPT_AES256
                                  + DBMS_CRYPTO.CHAIN_CBC
                                  + DBMS_CRYPTO.PAD_PKCS5;

    -- Read from admin.crypto_config rather than written here. A key beside
    -- the data it protects, in a file that goes into version control, is
    -- the one arrangement that guarantees both are disclosed together.
    -- See schema/crypto_key.example.sql.
    FUNCTION data_key RETURN RAW IS
        l_key_base64 VARCHAR2(200);
    BEGIN
        SELECT key_value INTO l_key_base64
        FROM admin.crypto_config
        WHERE key_name = 'DATA_KEY';

        RETURN UTL_ENCODE.BASE64_DECODE(UTL_I18N.STRING_TO_RAW(l_key_base64, 'AL32UTF8'));
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20100,
                'No DATA_KEY in admin.crypto_config - run schema/crypto_key.sql first.'
            );
    END data_key;

    FUNCTION encrypt_data(p_data IN NVARCHAR2) RETURN NVARCHAR2 IS
        l_encrypted_data RAW(2000);
        l_base64_data NVARCHAR2(2000);
    BEGIN
        -- Преобразуем входные данные в RAW
        l_encrypted_data := DBMS_CRYPTO.ENCRYPT(
            UTL_I18N.STRING_TO_RAW(p_data, 'AL32UTF8'),
            ctype,
            data_key
        );

        -- Кодируем зашифрованные данные в Base64
        l_base64_data := UTL_I18N.RAW_TO_CHAR(UTL_ENCODE.BASE64_ENCODE(l_encrypted_data), 'AL32UTF8');

        RETURN l_base64_data;
    END encrypt_data;

    FUNCTION decrypt_data(p_encrypted_data IN NVARCHAR2) RETURN NVARCHAR2 IS
        l_encrypted_data RAW(2000);
        l_decrypted_data RAW(2000);
        l_plain_text NVARCHAR2(2000);
    BEGIN
        -- Декодируем Base64 в RAW
        l_encrypted_data := UTL_ENCODE.BASE64_DECODE(UTL_I18N.STRING_TO_RAW(p_encrypted_data, 'AL32UTF8'));

        -- Дешифруем данные
        l_decrypted_data := DBMS_CRYPTO.DECRYPT(
            l_encrypted_data,
            ctype,
            data_key
        );

        -- Преобразуем RAW в текст
        l_plain_text := UTL_I18N.RAW_TO_NCHAR(l_decrypted_data, 'AL32UTF8');

        RETURN l_plain_text;
    END decrypt_data;
END pkg_crypto_utils;
/


--view for masking

CREATE OR REPLACE VIEW Users_View AS
SELECT 
    user_id, -- ID пользователя
    username,
    -- Маскировка email (оставляем первую букву и домен)
    REGEXP_REPLACE(email, '(.).+(@.+)', '\1*****\2') AS email,
    -- Маскировка phone (оставляем последние 4 цифры, остальные заменяются на *)
    RPAD(SUBSTR(phone, -4), LENGTH(phone), '*') AS phone,
    is_active,
    admin.pkg_crypto_utils.decrypt_data(firstname) AS firstname,
    admin.pkg_crypto_utils.decrypt_data(lastname) AS lastname,
    -- Маскировка даты рождения в формате xx.xx.yy
    TO_CHAR(birthdate, '"xx.xx."YY') AS birthdate,
    country,
    -- Дешифровка города только если он не NULL
    CASE 
        WHEN city IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(city) 
        ELSE NULL 
    END AS city,
    -- Дешифровка улицы только если она не NULL
    CASE 
        WHEN street IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(street) 
        ELSE NULL 
    END AS street,
    -- Дешифровка номера паспорта
    admin.pkg_crypto_utils.decrypt_data(passport_number) AS passport_number
FROM Users;


CREATE OR REPLACE VIEW Users_View AS
SELECT 
    user_id, -- ID пользователя
    username,
    -- Маскировка email (оставляем первую букву и домен)
    REGEXP_REPLACE(email, '(.).+(@.+)', '\1*****\2') AS email,
    -- Маскировка phone (оставляем последние 4 цифры, остальные заменяются на *)
    RPAD(SUBSTR(phone, -4), LENGTH(phone), '*') AS phone,
    is_active,
    admin.pkg_crypto_utils.decrypt_data(firstname) AS firstname,
    admin.pkg_crypto_utils.decrypt_data(lastname) AS lastname,
    -- Маскировка даты рождения в формате xx.xx.yy
    TO_CHAR(birthdate, '"xx.xx."YY') AS birthdate,
    country,
    -- Дешифровка города только если он не NULL
    CASE 
        WHEN city IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(city) 
        ELSE NULL 
    END AS city,
    -- Дешифровка улицы только если она не NULL
    CASE 
        WHEN street IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(street) 
        ELSE NULL 
    END AS street,
    -- Дешифровка номера паспорта
    admin.pkg_crypto_utils.decrypt_data(passport_number) AS passport_number
FROM Users;


CREATE OR REPLACE PROCEDURE sp_get_all_users_decrypted
AUTHID DEFINER AS 
BEGIN
    FOR user_data IN (
        SELECT user_id, 
               username, 
               user_password AS password,
               email,
               admin.pkg_crypto_utils.decrypt_data(passport_number) AS decrypted_passport_number,
               -- Проверяем, не является ли firstname NULL, если нет - расшифровываем
               CASE 
                   WHEN firstname IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(firstname) 
                   ELSE NULL 
               END AS decrypted_firstname,
               -- То же самое для lastname
               CASE 
                   WHEN lastname IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(lastname) 
                   ELSE NULL 
               END AS decrypted_lastname,
               birthdate, 
               -- Если country NULL, заменяем на 'n/a'
               NVL(country, 'n/a') AS country,
               -- Проверяем на NULL для city перед расшифровкой и заменяем на 'n/a' при необходимости
               NVL(
                   CASE 
                       WHEN city IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(city) 
                       ELSE NULL 
                   END, 'n/a'
               ) AS decrypted_city,
               -- То же самое для street
               NVL(
                   CASE 
                       WHEN street IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(street) 
                       ELSE NULL 
                   END, 'n/a'
               ) AS decrypted_street,
               -- Если phone NULL, заменяем на 'n/a'
               NVL(phone, 'n/a') AS phone
        FROM admin.Users
    )
    LOOP
        -- Выводим расшифрованные данные для каждого пользователя
        DBMS_OUTPUT.PUT_LINE('User ID: ' || user_data.user_id);
        DBMS_OUTPUT.PUT_LINE('Username: ' || user_data.username);
        DBMS_OUTPUT.PUT_LINE('Password: ' || user_data.password);
        DBMS_OUTPUT.PUT_LINE('Email: ' || user_data.email);
        DBMS_OUTPUT.PUT_LINE('Passport Number: ' || user_data.decrypted_passport_number);
        DBMS_OUTPUT.PUT_LINE('First Name: ' || user_data.decrypted_firstname);
        DBMS_OUTPUT.PUT_LINE('Last Name: ' || user_data.decrypted_lastname);
        DBMS_OUTPUT.PUT_LINE('Birthdate: ' || user_data.birthdate);
        DBMS_OUTPUT.PUT_LINE('Country: ' || user_data.country);
        DBMS_OUTPUT.PUT_LINE('City: ' || user_data.decrypted_city);
        DBMS_OUTPUT.PUT_LINE('Street: ' || user_data.decrypted_street);
        DBMS_OUTPUT.PUT_LINE('Phone: ' || user_data.phone);
        DBMS_OUTPUT.PUT_LINE('---------------------------------');
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('All users data retrieved successfully.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
        RAISE;
END;
/



EXEC sp_get_all_users_decrypted;


CREATE OR REPLACE PROCEDURE sp_add_employee_with_user (
    p_username        IN VARCHAR2,  -- Имя пользователя
    p_user_password   IN VARCHAR2,  -- Пароль
    p_email           IN VARCHAR2,  -- Email
    p_passport_number IN VARCHAR2,  -- Номер паспорта
    p_phone           IN VARCHAR2 DEFAULT NULL, -- Телефон
    p_firstname       IN VARCHAR2,  -- Имя
    p_lastname        IN VARCHAR2,  -- Фамилия
    p_birthdate       IN VARCHAR2,  -- Дата рождения (строка в формате 'YYYY-MM-DD')
    p_country         IN VARCHAR2 DEFAULT NULL, -- Страна
    p_city            IN VARCHAR2 DEFAULT NULL, -- Город
    p_street          IN VARCHAR2 DEFAULT NULL, -- Улица
    p_airport_id      IN NUMBER,    -- ID аэропорта
    p_job_title       IN VARCHAR2,  -- Должность
    p_hire_date       IN VARCHAR2,  -- Дата найма (строка в формате 'YYYY-MM-DD')
    p_salary          IN NUMBER     -- Зарплата
)
AUTHID DEFINER
AS
    v_user_id NUMBER; -- ID зарегистрированного пользователя
    v_airport_name NVARCHAR2(100); -- Название аэропорта
    v_duplicate_count NUMBER;
    v_hire_date DATE;
    v_birth_date DATE;

    encrypted_passport_number VARCHAR2(200);
    encrypted_firstname       VARCHAR2(100);
    encrypted_lastname        VARCHAR2(100);
    encrypted_city            VARCHAR2(50);
    encrypted_street          VARCHAR2(100);
BEGIN
    -- Преобразование строковых дат в формат DATE
    BEGIN
        v_hire_date := TO_DATE(p_hire_date, 'YYYY-MM-DD');
        v_birth_date := TO_DATE(p_birthdate, 'YYYY-MM-DD');
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001, 'Invalid date format. Use "YYYY-MM-DD".');
    END;

    -- Проверка существования аэропорта
    BEGIN
        SELECT airport_name
        INTO v_airport_name
        FROM admin.Airports
        WHERE airport_id = p_airport_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'Airport with ID ' || p_airport_id || ' does not exist.');
    END;

    -- Проверка на дубликаты
    BEGIN
        SELECT COUNT(*)
        INTO v_duplicate_count
        FROM admin.Users
        WHERE username = p_username 
           OR email = p_email 
           OR PHONE = p_phone 
           OR passport_number = CAST(admin.pkg_crypto_utils.encrypt_data(p_passport_number) AS VARCHAR2(200));

        IF v_duplicate_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Username, email,phone or passport number already exists.');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20005, 'Error during duplicate check: ' || SQLERRM);
    END;

    -- Шифрование обязательных полей
    encrypted_passport_number := admin.pkg_crypto_utils.encrypt_data(p_passport_number);
    encrypted_firstname := admin.pkg_crypto_utils.encrypt_data(p_firstname);
    encrypted_lastname := admin.pkg_crypto_utils.encrypt_data(p_lastname);

    -- Шифрование необязательных полей
    IF p_city IS NOT NULL THEN
        encrypted_city := admin.pkg_crypto_utils.encrypt_data(p_city);
    ELSE
        encrypted_city := NULL;
    END IF;

    IF p_street IS NOT NULL THEN
        encrypted_street := admin.pkg_crypto_utils.encrypt_data(p_street);
    ELSE
        encrypted_street := NULL;
    END IF;

    -- Добавление пользователя в Users
    INSERT INTO admin.Users (
        username, user_password, email, phone, firstname, lastname, birthdate,
        country, city, street, passport_number
    )
    VALUES (
        p_username, 
        admin.pkg_crypto_utils.encrypt_data(p_user_password), 
        p_email, 
        p_phone, 
        encrypted_firstname, 
        encrypted_lastname, 
        v_birth_date,
        p_country, 
        encrypted_city, 
        encrypted_street, 
        encrypted_passport_number
    )
    RETURNING user_id INTO v_user_id;

    -- Проверка на дубликат сотрудника
    SELECT COUNT(*)
    INTO v_duplicate_count
    FROM admin.Employee
    WHERE user_id = v_user_id;

    IF v_duplicate_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'User with ID ' || v_user_id || ' is already an employee.');
    END IF;

    -- Добавление сотрудника в Employee
    INSERT INTO admin.Employee (
        user_id, airport_id, job_title, hire_date, salary
    ) VALUES (
        v_user_id, p_airport_id, p_job_title, v_hire_date, p_salary
    );

    -- Подтверждаем транзакцию
    COMMIT;

    -- Вывод информации о сотруднике
    -- Вывод информации о сотруднике
    DBMS_OUTPUT.PUT_LINE('Employee successfully added:');
    DBMS_OUTPUT.PUT_LINE('---------------------------------');
    FOR emp_info IN (
        SELECT 
            e.user_id,
            u.username,
            u.email,
            admin.pkg_crypto_utils.decrypt_data(u.passport_number) AS passport_number,
            CASE 
                WHEN u.firstname IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(u.firstname)
                ELSE NULL
            END AS firstname,
            CASE 
                WHEN u.lastname IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(u.lastname)
                ELSE NULL
            END AS lastname,
            u.birthdate,
            u.country,
            CASE 
                WHEN u.city IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(u.city)
                ELSE NULL
            END AS city,
            CASE 
                WHEN u.street IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(u.street)
                ELSE NULL
            END AS street,
            u.phone,
            e.employee_id,
            e.job_title,
            e.hire_date,
            e.salary,
            a.airport_id,
            a.airport_name,
            a.city AS airport_city,
            a.country AS airport_country
        FROM admin.Employee e
        JOIN admin.Airports a ON e.airport_id = a.airport_id
        LEFT JOIN admin.Users u ON e.user_id = u.user_id
        WHERE e.user_id = v_user_id
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('User ID: ' || emp_info.user_id);
        DBMS_OUTPUT.PUT_LINE('Username: ' || emp_info.username);
        DBMS_OUTPUT.PUT_LINE('Firstname: ' || NVL(emp_info.firstname, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Lastname: ' || NVL(emp_info.lastname, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Birthdate: ' || TO_CHAR(emp_info.birthdate, 'YYYY-MM-DD'));
        DBMS_OUTPUT.PUT_LINE('Email: ' || NVL(emp_info.email, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Phone: ' || NVL(emp_info.phone, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Country: ' || NVL(emp_info.country, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('City: ' || NVL(emp_info.city, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Street: ' || NVL(emp_info.street, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Passport Number: ' || NVL(emp_info.passport_number, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Employee ID: ' || emp_info.employee_id);
        DBMS_OUTPUT.PUT_LINE('Job Title: ' || emp_info.job_title);
        DBMS_OUTPUT.PUT_LINE('Hire Date: ' || TO_CHAR(emp_info.hire_date, 'YYYY-MM-DD'));
        DBMS_OUTPUT.PUT_LINE('Salary: ' || emp_info.salary);
        DBMS_OUTPUT.PUT_LINE('Airport ID: ' || emp_info.airport_id);
        DBMS_OUTPUT.PUT_LINE('Airport Name: ' || emp_info.airport_name);
        DBMS_OUTPUT.PUT_LINE('Airport City: ' || emp_info.airport_city);
        DBMS_OUTPUT.PUT_LINE('Airport Country: ' || emp_info.airport_country);
        DBMS_OUTPUT.PUT_LINE('---------------------------------');
    END LOOP;


EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error during employee addition: ' || SQLERRM);
        RAISE;
END;
/


CREATE OR REPLACE PROCEDURE sp_update_employee (
    p_employee_id IN NUMBER,
    p_airport_id IN NUMBER,
    p_job_title IN VARCHAR2 DEFAULT NULL,
    p_hire_date IN VARCHAR2 DEFAULT NULL,
    p_salary IN NUMBER DEFAULT NULL
) AUTHID DEFINER
AS
    v_employee_exists NUMBER;
    v_airport_exists NUMBER;
    v_user_link_exists NUMBER; -- Проверка связи с таблицей Users
    v_hire_date DATE;
BEGIN
    -- Проверяем, существует ли работник с таким employee_id
    SELECT COUNT(*)
    INTO v_employee_exists
    FROM admin.Employee
    WHERE employee_id = p_employee_id;

    IF v_employee_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Employee with the specified employee_id does not exist.');
    END IF;

    -- Проверяем, существует ли связь с таблицей Users
    SELECT COUNT(*)
    INTO v_user_link_exists
    FROM admin.Employee e
    JOIN admin.Users u ON e.user_id = u.user_id
    WHERE e.employee_id = p_employee_id;

    IF v_user_link_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'No corresponding user found for the specified employee_id.');
    END IF;

    -- Проверяем, существует ли аэропорт с таким airport_id
    SELECT COUNT(*)
    INTO v_airport_exists
    FROM admin.Airports
    WHERE airport_id = p_airport_id;

    IF v_airport_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Airport with the specified airport_id does not exist.');
    END IF;

        -- Преобразуем дату из строки в тип DATE, если она передана
    IF p_hire_date IS NOT NULL THEN
        -- Проверка на формат даты
        BEGIN
            v_hire_date := TO_DATE(p_hire_date, 'YYYY-MM-DD');
        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20003, 'Invalid date format. Use YYYY-MM-DD.');
        END;
    
        -- Проверка, чтобы дата не была больше текущей даты
        IF v_hire_date > SYSDATE THEN
            RAISE_APPLICATION_ERROR(-20004, 'Hire date cannot be greater than the current date.');
        END IF;
    END IF;


    -- Выводим старые значения сотрудника
    DBMS_OUTPUT.PUT_LINE('Existing employee details:');
    FOR old_emp IN (
        SELECT e.employee_id, e.airport_id, e.job_title, e.hire_date, e.salary, 
               a.airport_name, a.city AS airport_city, a.country AS airport_country
        FROM admin.Employee e
        JOIN admin.Airports a ON e.airport_id = a.airport_id
        WHERE e.employee_id = p_employee_id
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('---------------------------------');
        DBMS_OUTPUT.PUT_LINE('Employee ID: ' || old_emp.employee_id);
        DBMS_OUTPUT.PUT_LINE('Airport ID: ' || old_emp.airport_id);
        DBMS_OUTPUT.PUT_LINE('Airport Name: ' || old_emp.airport_name);
        DBMS_OUTPUT.PUT_LINE('Airport City: ' || old_emp.airport_city);
        DBMS_OUTPUT.PUT_LINE('Airport Country: ' || old_emp.airport_country);
        DBMS_OUTPUT.PUT_LINE('Job Title: ' || old_emp.job_title);
        DBMS_OUTPUT.PUT_LINE('Hire Date: ' || old_emp.hire_date);
        DBMS_OUTPUT.PUT_LINE('Salary: ' || old_emp.salary);
        DBMS_OUTPUT.PUT_LINE('---------------------------------');
    END LOOP;

    -- Выполняем обновление данных сотрудника
    UPDATE admin.Employee
    SET 
        airport_id = p_airport_id, -- Всегда обновляется
        job_title = NVL(p_job_title, job_title), -- Оставляем старое значение, если p_job_title = NULL
        hire_date = NVL(v_hire_date, hire_date), -- Оставляем старое значение, если p_hire_date = NULL
        salary = NVL(p_salary, salary) -- Оставляем старое значение, если p_salary = NULL
    WHERE employee_id = p_employee_id;

    COMMIT;

    -- Выводим обновленные значения сотрудника
    DBMS_OUTPUT.PUT_LINE('Updated employee details:');
    FOR new_emp IN (
        SELECT e.employee_id, e.airport_id, e.job_title, e.hire_date, e.salary, 
               a.airport_name, a.city AS airport_city, a.country AS airport_country
        FROM admin.Employee e
        JOIN admin.Airports a ON e.airport_id = a.airport_id
        WHERE e.employee_id = p_employee_id
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('---------------------------------');
        DBMS_OUTPUT.PUT_LINE('Employee ID: ' || new_emp.employee_id);
        DBMS_OUTPUT.PUT_LINE('Airport ID: ' || new_emp.airport_id);
        DBMS_OUTPUT.PUT_LINE('Airport Name: ' || new_emp.airport_name);
        DBMS_OUTPUT.PUT_LINE('Airport City: ' || new_emp.airport_city);
        DBMS_OUTPUT.PUT_LINE('Airport Country: ' || new_emp.airport_country);
        DBMS_OUTPUT.PUT_LINE('Job Title: ' || new_emp.job_title);
        DBMS_OUTPUT.PUT_LINE('Hire Date: ' || new_emp.hire_date);
        DBMS_OUTPUT.PUT_LINE('Salary: ' || new_emp.salary);
        DBMS_OUTPUT.PUT_LINE('---------------------------------');
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Employee information updated successfully.');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error during update: ' || SQLERRM);
        RAISE;
END;
/



CREATE OR REPLACE PROCEDURE sp_delete_employee (
    p_employee_id IN NUMBER -- ID сотрудника для удаления
)
AUTHID DEFINER
AS
    v_employee_exists   NUMBER;  -- Флаг существования сотрудника
    v_user_link_exists  NUMBER;  -- Флаг связи сотрудника с пользователем
    v_user_id           NUMBER;  -- ID пользователя
    v_ticket_link       NUMBER;  -- Флаг связи пользователя с билетами
BEGIN
    -- Проверка существования сотрудника
    SELECT COUNT(*)
    INTO v_employee_exists
    FROM admin.Employee
    WHERE employee_id = p_employee_id;

    IF v_employee_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Employee with the specified employee_id does not exist.');
    END IF;

    -- Получаем user_id сотрудника
    BEGIN
        SELECT e.user_id
        INTO v_user_id
        FROM admin.Employee e
        WHERE e.employee_id = p_employee_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20004, 'No corresponding user found for the specified employee_id.');
    END;

    -- Проверка существования пользователя в таблице Users
    SELECT COUNT(*)
    INTO v_user_link_exists
    FROM admin.Users u
    WHERE u.user_id = v_user_id;

    IF v_user_link_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'The user linked to this employee_id does not exist in Users.');
    END IF;

    -- Проверка связи пользователя с билетами (Tickets)
    SELECT COUNT(*)
    INTO v_ticket_link
    FROM admin.Tickets t
    WHERE t.passenger_id = v_user_id;

    IF v_ticket_link > 0 THEN
        DBMS_OUTPUT.PUT_LINE('User linked to employee has associated tickets.');
        DBMS_OUTPUT.PUT_LINE('Updating passenger_id to NULL and ticket status to ''Available'' in Tickets table...');

        -- Обновление поля passenger_id на NULL и статуса билета на 'Available'
        UPDATE admin.Tickets
        SET passenger_id = NULL,
            ticket_status = 'Available'
        WHERE passenger_id = v_user_id;

        DBMS_OUTPUT.PUT_LINE('Passenger ID in associated tickets has been set to NULL and ticket status updated to ''Available''.');
    END IF;

    -- Вывод информации о сотруднике перед удалением
    DBMS_OUTPUT.PUT_LINE('Deleting employee details:');
    DBMS_OUTPUT.PUT_LINE('---------------------------------');

    FOR emp_info IN (
        SELECT 
            e.employee_id,
            u.user_id,
            u.username,
            u.email,
            admin.pkg_crypto_utils.decrypt_data(u.passport_number) AS passport_number,
            CASE 
                WHEN u.firstname IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(u.firstname)
                ELSE NULL
            END AS firstname,
            CASE 
                WHEN u.lastname IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(u.lastname)
                ELSE NULL
            END AS lastname,
            u.birthdate,
            u.country,
            CASE 
                WHEN u.city IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(u.city)
                ELSE NULL
            END AS city,
            CASE 
                WHEN u.street IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(u.street)
                ELSE NULL
            END AS street,
            u.phone,
            e.job_title,
            e.hire_date,
            e.salary,
            a.airport_id,
            a.airport_name,
            a.city AS airport_city,
            a.country AS airport_country
        FROM admin.Employee e
        JOIN admin.Users u ON e.user_id = u.user_id
        JOIN admin.Airports a ON e.airport_id = a.airport_id
        WHERE e.employee_id = p_employee_id
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('Employee ID: ' || emp_info.employee_id);
        DBMS_OUTPUT.PUT_LINE('User ID: ' || emp_info.user_id);
        DBMS_OUTPUT.PUT_LINE('Username: ' || emp_info.username);
        DBMS_OUTPUT.PUT_LINE('Firstname: ' || NVL(emp_info.firstname, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Lastname: ' || NVL(emp_info.lastname, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Birthdate: ' || TO_CHAR(emp_info.birthdate, 'YYYY-MM-DD'));
        DBMS_OUTPUT.PUT_LINE('Email: ' || NVL(emp_info.email, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Phone: ' || NVL(emp_info.phone, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Country: ' || NVL(emp_info.country, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('City: ' || NVL(emp_info.city, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Street: ' || NVL(emp_info.street, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Passport Number: ' || NVL(emp_info.passport_number, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Job Title: ' || emp_info.job_title);
        DBMS_OUTPUT.PUT_LINE('Hire Date: ' || TO_CHAR(emp_info.hire_date, 'YYYY-MM-DD'));
        DBMS_OUTPUT.PUT_LINE('Salary: ' || emp_info.salary);
        DBMS_OUTPUT.PUT_LINE('Airport ID: ' || emp_info.airport_id);
        DBMS_OUTPUT.PUT_LINE('Airport Name: ' || emp_info.airport_name);
        DBMS_OUTPUT.PUT_LINE('Airport City: ' || emp_info.airport_city);
        DBMS_OUTPUT.PUT_LINE('Airport Country: ' || emp_info.airport_country);
        DBMS_OUTPUT.PUT_LINE('---------------------------------');
    END LOOP;

    -- Удаление сотрудника из таблицы Employee
    DELETE FROM admin.Employee
    WHERE employee_id = p_employee_id;

    -- Удаление пользователя из таблицы Users
    DELETE FROM admin.Users
    WHERE user_id = v_user_id;

    -- Подтверждение транзакции
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Employee with Employee ID ' || p_employee_id || ' and associated user have been successfully deleted.');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error during employee deletion: ' || SQLERRM);
        RAISE;
END;
/





CREATE OR REPLACE PROCEDURE sp_get_all_employees_sorted_by_airport
AUTHID DEFINER
AS
    v_count_records NUMBER := 0; -- Счётчик записей
BEGIN
    DBMS_OUTPUT.PUT_LINE('List of all employees sorted by Airport ID:');
    DBMS_OUTPUT.PUT_LINE('---------------------------------');

    FOR emp_info IN (
        SELECT 
            e.employee_id,
            u.user_id,
            u.username,
            u.email,
            admin.pkg_crypto_utils.decrypt_data(u.passport_number) AS passport_number,
            CASE 
                WHEN u.firstname IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(u.firstname)
                ELSE NULL
            END AS firstname,
            CASE 
                WHEN u.lastname IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(u.lastname)
                ELSE NULL
            END AS lastname,
            u.birthdate,
            u.country,
            CASE 
                WHEN u.city IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(u.city)
                ELSE NULL
            END AS city,
            CASE 
                WHEN u.street IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(u.street)
                ELSE NULL
            END AS street,
            u.phone,
            e.job_title,
            e.hire_date,
            e.salary,
            a.airport_id,
            a.airport_name,
            a.city AS airport_city,
            a.country AS airport_country
        FROM admin.Employee e
        JOIN admin.Users u ON e.user_id = u.user_id
        JOIN admin.Airports a ON e.airport_id = a.airport_id
        ORDER BY a.airport_id ASC
    ) LOOP
        v_count_records := v_count_records + 1; -- Увеличиваем счётчик записей
        
        -- Вывод информации о сотруднике
        DBMS_OUTPUT.PUT_LINE('Employee ID: ' || emp_info.employee_id);
        DBMS_OUTPUT.PUT_LINE('User ID: ' || emp_info.user_id);
        DBMS_OUTPUT.PUT_LINE('Username: ' || emp_info.username);
        DBMS_OUTPUT.PUT_LINE('Firstname: ' || NVL(emp_info.firstname, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Lastname: ' || NVL(emp_info.lastname, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Birthdate: ' || TO_CHAR(emp_info.birthdate, 'YYYY-MM-DD'));
        DBMS_OUTPUT.PUT_LINE('Email: ' || NVL(emp_info.email, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Phone: ' || NVL(emp_info.phone, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Country: ' || NVL(emp_info.country, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('City: ' || NVL(emp_info.city, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Street: ' || NVL(emp_info.street, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Passport Number: ' || NVL(emp_info.passport_number, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Job Title: ' || emp_info.job_title);
        DBMS_OUTPUT.PUT_LINE('Hire Date: ' || TO_CHAR(emp_info.hire_date, 'YYYY-MM-DD'));
        DBMS_OUTPUT.PUT_LINE('Salary: ' || emp_info.salary);
        DBMS_OUTPUT.PUT_LINE('Airport ID: ' || emp_info.airport_id);
        DBMS_OUTPUT.PUT_LINE('Airport Name: ' || emp_info.airport_name);
        DBMS_OUTPUT.PUT_LINE('Airport City: ' || emp_info.airport_city);
        DBMS_OUTPUT.PUT_LINE('Airport Country: ' || emp_info.airport_country);
        DBMS_OUTPUT.PUT_LINE('---------------------------------');
    END LOOP;

    -- Если записей не найдено
    IF v_count_records = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No employees found in the system.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error retrieving employees: ' || SQLERRM);
        RAISE;
END;
/


BEGIN
    sp_get_all_employees_sorted_by_airport;
END;
/

CREATE OR REPLACE PROCEDURE sp_delete_user (
    p_user_id IN NUMBER -- ID пользователя для удаления
)
AUTHID DEFINER
AS
    v_user_exists   NUMBER; -- Флаг существования пользователя
    v_employee_link NUMBER; -- Флаг связи пользователя с таблицей Employee
    v_ticket_link   NUMBER; -- Флаг связи пользователя с билетами
BEGIN
    -- Проверка существования пользователя в таблице Users
    SELECT COUNT(*)
    INTO v_user_exists
    FROM admin.Users
    WHERE user_id = p_user_id;

    IF v_user_exists = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: User with the specified user_id does not exist.');
        RAISE_APPLICATION_ERROR(-20001, 'User with the specified user_id does not exist.');
    END IF;

    -- Проверка связи пользователя с таблицей Employee
    SELECT COUNT(*)
    INTO v_employee_link
    FROM admin.Employee e
    WHERE e.user_id = p_user_id;

    IF v_employee_link > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: The specified user is linked to an employee.');
        DBMS_OUTPUT.PUT_LINE('Use the procedure sp_delete_employee to delete this user.');
        RAISE_APPLICATION_ERROR(-20002, 
            'The specified user is linked to an employee. Use the procedure sp_delete_employee to delete this user.');
    END IF;

    -- Проверка связи пользователя с билетами (Tickets)
    SELECT COUNT(*)
    INTO v_ticket_link
    FROM admin.Tickets t
    WHERE t.passenger_id = p_user_id;

    IF v_ticket_link > 0 THEN
        DBMS_OUTPUT.PUT_LINE('User has associated tickets. Updating passenger_id to NULL in Tickets table...');

        -- Обновление поля passenger_id на NULL
        UPDATE admin.Tickets
        SET passenger_id = NULL,
        ticket_status = 'Available'
        WHERE passenger_id = p_user_id;

        DBMS_OUTPUT.PUT_LINE('Passenger ID in associated tickets has been successfully set to NULL.');
    END IF;

    -- Вывод информации о пользователе перед удалением
    DBMS_OUTPUT.PUT_LINE('Deleting user details:');
    DBMS_OUTPUT.PUT_LINE('---------------------------------');

    FOR user_info IN (
        SELECT 
            u.user_id,
            u.username,
            u.email,
            admin.pkg_crypto_utils.decrypt_data(u.passport_number) AS passport_number,
            CASE 
                WHEN u.firstname IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(u.firstname)
                ELSE NULL
            END AS firstname,
            CASE 
                WHEN u.lastname IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(u.lastname)
                ELSE NULL
            END AS lastname,
            u.birthdate,
            u.country,
            CASE 
                WHEN u.city IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(u.city)
                ELSE NULL
            END AS city,
            CASE 
                WHEN u.street IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(u.street)
                ELSE NULL
            END AS street,
            u.phone
        FROM admin.Users u
        WHERE u.user_id = p_user_id
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('User ID: ' || user_info.user_id);
        DBMS_OUTPUT.PUT_LINE('Username: ' || user_info.username);
        DBMS_OUTPUT.PUT_LINE('Firstname: ' || NVL(user_info.firstname, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Lastname: ' || NVL(user_info.lastname, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Birthdate: ' || TO_CHAR(user_info.birthdate, 'YYYY-MM-DD'));
        DBMS_OUTPUT.PUT_LINE('Email: ' || NVL(user_info.email, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Phone: ' || NVL(user_info.phone, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Country: ' || NVL(user_info.country, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('City: ' || NVL(user_info.city, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Street: ' || NVL(user_info.street, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Passport Number: ' || NVL(user_info.passport_number, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('---------------------------------');
    END LOOP;

    -- Удаление пользователя из таблицы Users
    DELETE FROM admin.Users
    WHERE user_id = p_user_id;

    -- Подтверждение транзакции
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('User with User ID ' || p_user_id || ' has been successfully deleted.');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error during user deletion: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END;
/



BEGIN
    sp_delete_user(p_user_id => 50);
END;
/


CREATE OR REPLACE PROCEDURE sp_add_user (
    p_username        IN VARCHAR2,  -- Имя пользователя
    p_user_password   IN VARCHAR2,  -- Пароль
    p_email           IN VARCHAR2,  -- Email
    p_passport_number IN VARCHAR2,  -- Номер паспорта
    p_phone           IN VARCHAR2 DEFAULT NULL, -- Телефон
    p_firstname       IN VARCHAR2,  -- Имя
    p_lastname        IN VARCHAR2,  -- Фамилия
    p_birthdate       IN VARCHAR2,  -- Дата рождения (строка в формате 'YYYY-MM-DD')
    p_country         IN VARCHAR2 DEFAULT NULL, -- Страна
    p_city            IN VARCHAR2 DEFAULT NULL, -- Город
    p_street          IN VARCHAR2 DEFAULT NULL -- Улица
)
AUTHID DEFINER
AS
    v_user_id NUMBER; -- ID зарегистрированного пользователя
    v_duplicate_count NUMBER;
    v_birth_date DATE;

    -- Переменные для шифрования
    encrypted_passport_number VARCHAR2(200);
    encrypted_firstname       VARCHAR2(100);
    encrypted_lastname        VARCHAR2(100);
    encrypted_city            VARCHAR2(50);
    encrypted_street          VARCHAR2(100);
BEGIN
    -- Преобразование строки даты рождения в формат DATE
    BEGIN
        v_birth_date := TO_DATE(p_birthdate, 'YYYY-MM-DD');
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001, 'Invalid date format for birthdate. Use "YYYY-MM-DD".');
    END;

    -- Проверка на дубликаты по username, email или паспорту
    BEGIN
        SELECT COUNT(*)
        INTO v_duplicate_count
        FROM admin.Users
        WHERE username = p_username 
           OR email = p_email
           OR phone =  p_phone 
           OR passport_number = CAST(admin.pkg_crypto_utils.encrypt_data(p_passport_number) AS VARCHAR2(200));

        IF v_duplicate_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Username, email, phone or passport number already exists.');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20005, 'Error during duplicate check: ' || SQLERRM);
    END;

    -- Шифрование обязательных полей
    encrypted_passport_number := admin.pkg_crypto_utils.encrypt_data(p_passport_number);
    encrypted_firstname := admin.pkg_crypto_utils.encrypt_data(p_firstname);
    encrypted_lastname := admin.pkg_crypto_utils.encrypt_data(p_lastname);

    -- Шифрование необязательных полей
    IF p_city IS NOT NULL THEN
        encrypted_city := admin.pkg_crypto_utils.encrypt_data(p_city);
    ELSE
        encrypted_city := NULL;
    END IF;

    IF p_street IS NOT NULL THEN
        encrypted_street := admin.pkg_crypto_utils.encrypt_data(p_street);
    ELSE
        encrypted_street := NULL;
    END IF;

    -- Добавление пользователя в таблицу Users
    INSERT INTO admin.Users (
        username, user_password, email, phone, firstname, lastname, birthdate,
        country, city, street, passport_number
    )
    VALUES (
        p_username, 
        admin.pkg_crypto_utils.encrypt_data(p_user_password), 
        p_email, 
        p_phone, 
        encrypted_firstname, 
        encrypted_lastname, 
        v_birth_date,
        p_country, 
        encrypted_city, 
        encrypted_street, 
        encrypted_passport_number
    )
    RETURNING user_id INTO v_user_id;

    -- Подтверждаем транзакцию
    COMMIT;

    -- Вывод информации о новом пользователе
    DBMS_OUTPUT.PUT_LINE('User successfully added:');
    DBMS_OUTPUT.PUT_LINE('---------------------------------');
    DBMS_OUTPUT.PUT_LINE('User ID: ' || v_user_id);
    DBMS_OUTPUT.PUT_LINE('Username: ' || p_username);
    DBMS_OUTPUT.PUT_LINE('Email: ' || NVL(p_email, 'N/A'));
    DBMS_OUTPUT.PUT_LINE('Phone: ' || NVL(p_phone, 'N/A'));
    DBMS_OUTPUT.PUT_LINE('Birthdate: ' || TO_CHAR(v_birth_date, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE('Country: ' || NVL(p_country, 'N/A'));
    DBMS_OUTPUT.PUT_LINE('City: ' || NVL(p_city, 'N/A'));
    DBMS_OUTPUT.PUT_LINE('Street: ' || NVL(p_street, 'N/A'));
    DBMS_OUTPUT.PUT_LINE('---------------------------------');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error during user addition: ' || SQLERRM);
        RAISE;
END sp_add_user;
/


select * from Employee;
select * from Users;
select * from Tickets;




