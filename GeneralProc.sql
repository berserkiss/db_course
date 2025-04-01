--регистрация 


CREATE OR REPLACE PROCEDURE sp_register_user (
    p_username IN VARCHAR2,
    p_user_password IN VARCHAR2,
    p_email IN VARCHAR2,
    p_passport_number IN VARCHAR2, 
    p_phone IN VARCHAR2 DEFAULT NULL,             
    p_firstname IN VARCHAR2,
    p_lastname IN VARCHAR2,
    p_birthdate IN DATE,
    p_country IN VARCHAR2 DEFAULT NULL,
    p_city IN VARCHAR2 DEFAULT NULL,
    p_street IN VARCHAR2 DEFAULT NULL
) AUTHID DEFINER
AS
    duplicate_count NUMBER;
    encrypted_user_password NVARCHAR2(2000);
    encrypted_passport_number NVARCHAR2(2000);
    encrypted_firstname NVARCHAR2(2000);
    encrypted_lastname NVARCHAR2(2000);
    encrypted_city NVARCHAR2(2000);
    encrypted_street NVARCHAR2(2000);
BEGIN
    
    encrypted_user_password := admin.pkg_crypto_utils.encrypt_data(p_user_password);
    encrypted_passport_number := admin.pkg_crypto_utils.encrypt_data(p_passport_number);

    
    IF p_firstname IS NOT NULL THEN
        encrypted_firstname := admin.pkg_crypto_utils.encrypt_data(p_firstname);
    ELSE
        encrypted_firstname := NULL;
    END IF;

    IF p_lastname IS NOT NULL THEN
        encrypted_lastname := admin.pkg_crypto_utils.encrypt_data(p_lastname);
    ELSE
        encrypted_lastname := NULL;
    END IF;

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

    
    SELECT COUNT(*)
    INTO duplicate_count
    FROM admin.Users
    WHERE username = p_username OR email = p_email OR (phone IS NOT NULL AND phone = p_phone);

    
    IF duplicate_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Username, email, or phone already exists.');
    END IF;

   
    INSERT INTO admin.Users (
        username, user_password, email, phone, firstname, lastname, birthdate,
        country, city, street, passport_number
    )
    VALUES (
        p_username, encrypted_user_password, p_email, p_phone, encrypted_firstname, encrypted_lastname, p_birthdate,
        p_country, encrypted_city, encrypted_street, encrypted_passport_number
    );

   
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('User registered successfully: ' || p_username);

EXCEPTION
    WHEN OTHERS THEN
        -- Rollback the transaction in case of error
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error during registration: ' || SQLERRM);
        RAISE;
END;
/

BEGIN
    admin.sp_register_user(
        p_username => 'jane_smith',
        p_user_password => 'password1',
        p_email => 'jane.smith@example.com',
        p_passport_number => 'AB1234567',
        p_firstname => 'Jane',
        p_lastname => 'Smith',
        p_birthdate => TO_DATE('1985-10-20', 'YYYY-MM-DD')
    );
END;
/



CREATE OR REPLACE PROCEDURE sp_login_user (
    p_username IN VARCHAR2,
    p_user_password IN VARCHAR2
) AUTHID DEFINER
AS
    v_user_id NUMBER;
    v_is_active NUMBER;
    v_encrypted_user_password NVARCHAR2(2000);
    v_encrypted_firstname NVARCHAR2(2000);
    v_encrypted_lastname NVARCHAR2(2000);
    v_encrypted_city NVARCHAR2(2000);
    v_encrypted_street NVARCHAR2(2000);
    v_encrypted_passport_number NVARCHAR2(2000);
    v_encrypted_email NVARCHAR2(2000);
    v_encrypted_phone NVARCHAR2(2000);
    v_birthdate DATE;
    v_country NVARCHAR2(2000);
    v_decrypted_user_password NVARCHAR2(2000);
    v_decrypted_firstname NVARCHAR2(2000);
    v_decrypted_lastname NVARCHAR2(2000);
    v_decrypted_city NVARCHAR2(2000);
    v_decrypted_street NVARCHAR2(2000);
    v_decrypted_passport_number NVARCHAR2(2000);
    v_masked_email NVARCHAR2(2000);
    v_masked_phone NVARCHAR2(2000);
    v_is_employee BOOLEAN := FALSE;

    -- Поля для таблицы Employee
    v_job_title NVARCHAR2(100);
    v_airport_id NUMBER;
    v_airport_name NVARCHAR2(200);
    v_hire_date DATE;
    v_salary NUMBER;
BEGIN
    -- Проверяем, существует ли пользователь
    DBMS_OUTPUT.PUT_LINE('Checking if user exists...');
    SELECT user_id
    INTO v_user_id
    FROM admin.Users
    WHERE username = p_username;

    -- Получаем данные пользователя
    DBMS_OUTPUT.PUT_LINE('Fetching user data...');
    SELECT user_password, passport_number, firstname, lastname, city, street, is_active, email, phone, birthdate, country
    INTO v_encrypted_user_password, v_encrypted_passport_number, v_encrypted_firstname,
         v_encrypted_lastname, v_encrypted_city, v_encrypted_street, v_is_active,
         v_encrypted_email, v_encrypted_phone, v_birthdate, v_country
    FROM admin.Users
    WHERE username = p_username;

    -- Проверяем активен ли аккаунт
    IF v_is_active = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Account is inactive. Please contact support.');
    END IF;

    -- Расшифровываем пароль и личные данные
    DBMS_OUTPUT.PUT_LINE('Decrypting user data...');
    v_decrypted_user_password := admin.pkg_crypto_utils.decrypt_data(v_encrypted_user_password);
    v_decrypted_firstname := admin.pkg_crypto_utils.decrypt_data(v_encrypted_firstname);
    v_decrypted_lastname := admin.pkg_crypto_utils.decrypt_data(v_encrypted_lastname);
    v_decrypted_passport_number := admin.pkg_crypto_utils.decrypt_data(v_encrypted_passport_number);

    -- Расшифровываем опциональные поля
    v_decrypted_city := CASE WHEN v_encrypted_city IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(v_encrypted_city) ELSE NULL END;
    v_decrypted_street := CASE WHEN v_encrypted_street IS NOT NULL THEN admin.pkg_crypto_utils.decrypt_data(v_encrypted_street) ELSE NULL END;

    -- Маскируем email и телефон
    v_masked_email := REGEXP_REPLACE(v_encrypted_email, '(.).+(@.+)', '\1*****\2');
    v_masked_phone := RPAD(SUBSTR(v_encrypted_phone, -4), LENGTH(v_encrypted_phone), '*');

    -- Проверяем соответствие пароля
    IF v_decrypted_user_password = p_user_password THEN
        DBMS_OUTPUT.PUT_LINE('Login successful');
        
        -- Выводим информацию о пользователе
        DBMS_OUTPUT.PUT_LINE('Username: ' || p_username);
        DBMS_OUTPUT.PUT_LINE('Email: ' || v_masked_email);
        DBMS_OUTPUT.PUT_LINE('Passport Number: ' || v_decrypted_passport_number);

        IF v_encrypted_phone IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('Phone: ' || v_masked_phone);
        ELSE
            DBMS_OUTPUT.PUT_LINE('Phone: Not Provided');
        END IF;

        DBMS_OUTPUT.PUT_LINE('First Name: ' || v_decrypted_firstname);
        DBMS_OUTPUT.PUT_LINE('Last Name: ' || v_decrypted_lastname);
        DBMS_OUTPUT.PUT_LINE('Birthdate: ' || TO_CHAR(v_birthdate, 'YYYY-MM-DD'));

        IF v_country IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('Country: ' || v_country);
        ELSE
            DBMS_OUTPUT.PUT_LINE('Country: Not Provided');
        END IF;

        IF v_decrypted_city IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('City: ' || v_decrypted_city);
        ELSE
            DBMS_OUTPUT.PUT_LINE('City: Not Provided');
        END IF;

        IF v_decrypted_street IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('Street: ' || v_decrypted_street);
        ELSE
            DBMS_OUTPUT.PUT_LINE('Street: Not Provided');
        END IF;

        -- Проверяем, является ли пользователь сотрудником
        BEGIN
            DBMS_OUTPUT.PUT_LINE('Checking if user is an employee...');
            SELECT e.job_title, e.airport_id, a.airport_name, e.hire_date, e.salary
            INTO v_job_title, v_airport_id, v_airport_name, v_hire_date, v_salary
            FROM admin.Employee e
            JOIN admin.Airports a ON e.airport_id = a.airport_id
            WHERE e.user_id = v_user_id;

            v_is_employee := TRUE;
            DBMS_OUTPUT.PUT_LINE('Employee found: ' || v_job_title);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('No Employee record found for user_id: ' || v_user_id);
                v_is_employee := FALSE;
        END;

        -- Выводим информацию о сотруднике, если он найден
        IF v_is_employee THEN
            DBMS_OUTPUT.PUT_LINE('Employee Details:');
            DBMS_OUTPUT.PUT_LINE('  Job Title: ' || v_job_title);
            DBMS_OUTPUT.PUT_LINE('  Airport: ' || v_airport_name);
            DBMS_OUTPUT.PUT_LINE('  Hire Date: ' || TO_CHAR(v_hire_date, 'YYYY-MM-DD'));
            DBMS_OUTPUT.PUT_LINE('  Salary: ' || v_salary || ' USD');
        END IF;
    ELSE
        RAISE_APPLICATION_ERROR(-20002, 'Invalid username or password.');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Пользователь не найден
        RAISE_APPLICATION_ERROR(-20002, 'Invalid username or password.');
    WHEN OTHERS THEN
        -- Логирование и обработка ошибок
        DBMS_OUTPUT.PUT_LINE('Error during login: ' || SQLERRM);
        RAISE;
END;
/



BEGIN
    admin.sp_login_user(
        p_username => 'jane_smith', -- Логин, email или телефон
        p_user_password => 'password1'
    );
END;
/

select * from Users;

--заменить на айди
--get user info
CREATE OR REPLACE PROCEDURE sp_get_user_info(
    p_user_id IN NUMBER 
) AUTHID DEFINER
AS
    user_exists NUMBER;
BEGIN
    -- Проверка на существование пользователя
    SELECT COUNT(*)
    INTO user_exists
    FROM admin.Users_View
    WHERE user_id = p_user_id;

    IF user_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'User with the specified ID does not exist.');
    END IF;

    -- Получение информации о пользователе
    FOR user_data IN (
        SELECT username, email, phone, firstname, lastname, birthdate, country, city, street, passport_number
        FROM admin.Users_View
        WHERE user_id = p_user_id
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE('Username: ' || user_data.username);
        DBMS_OUTPUT.PUT_LINE('Email: ' || user_data.email);
        
        DBMS_OUTPUT.PUT_LINE('Passport Number: ' || user_data.passport_number);

        -- Проверка на NULL для остальных полей
        IF user_data.phone IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('Phone: ' || user_data.phone);
        ELSE
            DBMS_OUTPUT.PUT_LINE('Phone: Not Provided');
        END IF;

        DBMS_OUTPUT.PUT_LINE('First Name: ' || user_data.firstname);
        DBMS_OUTPUT.PUT_LINE('Last Name: ' || user_data.lastname);
        DBMS_OUTPUT.PUT_LINE('Birthdate: ' || user_data.birthdate);

        IF user_data.country IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('Country: ' || user_data.country);
        ELSE
            DBMS_OUTPUT.PUT_LINE('Country: Not Provided');
        END IF;

        IF user_data.city IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('City: ' || user_data.city);
        ELSE
            DBMS_OUTPUT.PUT_LINE('City: Not Provided');
        END IF;

        IF user_data.street IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('Street: ' || user_data.street);
        ELSE
            DBMS_OUTPUT.PUT_LINE('Street: Not Provided');
        END IF;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('User information retrieved successfully.');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No user found with the specified ID.');
        RAISE;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
        RAISE;
END;
/

BEGIN
    admin.sp_get_user_info(4); -- Здесь указывается ID пользователя
END;


CREATE OR REPLACE PROCEDURE sp_user_search_available_flights( 
    p_departure_airport  IN VARCHAR2 DEFAULT NULL, 
    p_arrival_airport    IN VARCHAR2 DEFAULT NULL, 
    p_airline_name       IN VARCHAR2 DEFAULT NULL, 
    p_departure_country  IN VARCHAR2 DEFAULT NULL, 
    p_arrival_country    IN VARCHAR2 DEFAULT NULL,
    p_departure_date_str IN VARCHAR2 DEFAULT NULL,  
    p_arrival_date_str   IN VARCHAR2 DEFAULT NULL   
) AUTHID DEFINER
AS
    v_departure_timestamp TIMESTAMP;
    v_departure_day_start TIMESTAMP;
    v_departure_day_end   TIMESTAMP;

    v_arrival_timestamp   TIMESTAMP;
    v_arrival_day_start   TIMESTAMP;
    v_arrival_day_end     TIMESTAMP;

    v_adjusted_arrival_date_str VARCHAR2(50); 

    CURSOR flight_cursor IS
        SELECT 
            f.flight_number,
            dep_airport.airport_name AS departure_airport,
            arr_airport.airport_name AS arrival_airport,
            dep_airport.country AS departure_country,
            arr_airport.country AS arrival_country,
            f.departure_time,
            f.arrival_time,
            a.airline_name AS airline
        FROM admin.Flights f
        JOIN admin.Airports dep_airport ON f.departure_airport_id = dep_airport.airport_id
        JOIN admin.Airports arr_airport ON f.arrival_airport_id = arr_airport.airport_id
        JOIN admin.Airlines a ON f.airline_id = a.airline_id
        WHERE f.departure_time > SYSDATE
          AND (p_departure_airport IS NULL OR UPPER(dep_airport.airport_name) = UPPER(p_departure_airport))
          AND (p_arrival_airport IS NULL OR UPPER(arr_airport.airport_name) = UPPER(p_arrival_airport))
          AND (p_airline_name IS NULL OR UPPER(a.airline_name) LIKE '%' || UPPER(p_airline_name) || '%')
          AND (p_departure_country IS NULL OR UPPER(dep_airport.country) = UPPER(p_departure_country))
          AND (p_arrival_country IS NULL OR UPPER(arr_airport.country) = UPPER(p_arrival_country))
          AND (v_departure_timestamp IS NULL 
               OR (f.departure_time BETWEEN v_departure_timestamp AND v_departure_day_end))
          AND (v_arrival_timestamp IS NULL 
               OR (f.arrival_time BETWEEN v_arrival_day_start AND v_arrival_timestamp));

    flight_record flight_cursor%ROWTYPE;

BEGIN
    -- Проверка и преобразование даты вылета
    IF p_departure_date_str IS NOT NULL THEN
        BEGIN
            SELECT TO_TIMESTAMP(p_departure_date_str, 'YYYY-MM-DD HH24:MI') 
            INTO v_departure_timestamp 
            FROM dual;

            -- Проверка, что дата вылета не меньше текущей даты
            IF v_departure_timestamp < SYSTIMESTAMP THEN
                DBMS_OUTPUT.PUT_LINE('Error: Departure date and time cannot be in the past.');
                RETURN;
            END IF;

            -- Вычисление начала и конца дня для даты вылета
            v_departure_day_start := TRUNC(v_departure_timestamp);
            v_departure_day_end := v_departure_day_start + INTERVAL '1' DAY - INTERVAL '1' SECOND;

        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20001, 'Invalid departure date format.');
        END;
    END IF;

    -- Проверка и преобразование даты прилета
    IF p_arrival_date_str IS NOT NULL THEN
        BEGIN
            IF INSTR(p_arrival_date_str, ' ') = 0 THEN
                v_adjusted_arrival_date_str := p_arrival_date_str || ' 23:59';
            ELSE
                v_adjusted_arrival_date_str := p_arrival_date_str;
            END IF;

            SELECT TO_TIMESTAMP(v_adjusted_arrival_date_str, 'YYYY-MM-DD HH24:MI') 
            INTO v_arrival_timestamp 
            FROM dual;

            -- Проверка, что дата прилета не меньше текущей даты
            IF v_arrival_timestamp < SYSTIMESTAMP THEN
                DBMS_OUTPUT.PUT_LINE('Error: Arrival date and time cannot be in the past.');
                RETURN;
            END IF;

            -- Вычисление начала и конца дня для даты прилета
            v_arrival_day_start := TRUNC(v_arrival_timestamp);
            v_arrival_day_end := v_arrival_day_start + INTERVAL '1' DAY - INTERVAL '1' SECOND;

        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20002, 'Invalid arrival date format.');
        END;
    END IF;

    -- Открытие курсора и получение данных
    OPEN flight_cursor;

    FETCH flight_cursor INTO flight_record;
    IF flight_cursor%NOTFOUND THEN
        DBMS_OUTPUT.PUT_LINE('No flights found matching the criteria.');
    ELSE
        LOOP
            DBMS_OUTPUT.PUT_LINE('Flight Number: ' || flight_record.flight_number);
            DBMS_OUTPUT.PUT_LINE('Departure Airport: ' || flight_record.departure_airport || ' (' || flight_record.departure_country || ')');
            DBMS_OUTPUT.PUT_LINE('Arrival Airport: ' || flight_record.arrival_airport || ' (' || flight_record.arrival_country || ')');
            DBMS_OUTPUT.PUT_LINE('Departure Time: ' || TO_CHAR(flight_record.departure_time, 'DD.MM.YYYY HH24:MI:SS'));
            DBMS_OUTPUT.PUT_LINE('Arrival Time: ' || TO_CHAR(flight_record.arrival_time, 'DD.MM.YYYY HH24:MI:SS'));
            DBMS_OUTPUT.PUT_LINE('Airline: ' || flight_record.airline);
            DBMS_OUTPUT.PUT_LINE('---------------------------------------');

            FETCH flight_cursor INTO flight_record;
            EXIT WHEN flight_cursor%NOTFOUND;
        END LOOP;
    END IF;

    CLOSE flight_cursor;

    
END;
/




EXEC admin.sp_user_search_available_flights();

BEGIN
    sp_user_search_available_flights(
        p_departure_date_str => '2024-12-26 07:00'
    );
END;
/


CREATE OR REPLACE PROCEDURE view_available_tickets ( 
    p_flight_id IN NUMBER
) AUTHID DEFINER AS
    
    v_departure_time TIMESTAMP;
    v_ticket_found BOOLEAN := FALSE; -- Flag to check for available tickets
BEGIN
    -- Retrieve the departure time of the flight
    BEGIN
        SELECT departure_time
        INTO v_departure_time
        FROM admin.Flights
        WHERE flight_id = p_flight_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: No flight found with ID ' || p_flight_id || '.');
            RETURN; 
    END;

    -- Check if the flight has not already departed
    IF v_departure_time <= SYSTIMESTAMP THEN
        DBMS_OUTPUT.PUT_LINE('Error: The flight has already departed or is departing soon.');
        RETURN; 
    END IF;

    -- Display header
    DBMS_OUTPUT.PUT_LINE('Available tickets for Flight ID ' || p_flight_id || ':');
    DBMS_OUTPUT.PUT_LINE('-----------------------------------------------------');

    -- Loop through available tickets
    FOR ticket IN (
        SELECT 
            ticket_number,
            seat_number,
            ticket_class AS class,
            price,
            ticket_status AS status
        FROM admin.Tickets
        WHERE flight_id = p_flight_id AND ticket_status = 'Available'
    ) LOOP
        -- Set flag if at least one ticket is found
        v_ticket_found := TRUE;
        
        -- Display ticket information
        DBMS_OUTPUT.PUT_LINE(
            'Ticket Number: ' || ticket.ticket_number ||
            ', Seat: ' || ticket.seat_number ||
            ', Class: ' || ticket.class ||
            ', Price ($): ' || ticket.price ||
            ', Status: ' || ticket.status
        );
    END LOOP;

    -- If no tickets are found, display message
    IF NOT v_ticket_found THEN
        DBMS_OUTPUT.PUT_LINE('No available tickets found for Flight ID ' || p_flight_id || '.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An unexpected error occurred: ' || SQLERRM);
        RAISE; 
END view_available_tickets;
/

BEGIN
    admin.view_available_tickets(p_flight_id => 20);
END;
/

CREATE OR REPLACE PROCEDURE search_tickets (
    p_flight_id IN NUMBER,
    p_class     IN VARCHAR2,
    p_price_min IN NUMBER DEFAULT NULL,
    p_price_max IN NUMBER DEFAULT NULL
) AUTHID DEFINER AS
    v_departure_time TIMESTAMP; -- Время отправления рейса
    v_flight_exists NUMBER; -- Проверка существования рейса
    v_flight_number VARCHAR2(50); -- Номер рейса
BEGIN
    -- Проверка на существование рейса
    SELECT COUNT(*)
    INTO v_flight_exists
    FROM admin.Flights
    WHERE flight_id = p_flight_id;

    IF v_flight_exists = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: No flight found with the specified Flight ID.');
        RETURN;
    END IF;

    -- Получение номера рейса
    BEGIN
        SELECT flight_number, departure_time
        INTO v_flight_number, v_departure_time
        FROM admin.Flights
        WHERE flight_id = p_flight_id;

        IF v_departure_time <= SYSTIMESTAMP THEN
            DBMS_OUTPUT.PUT_LINE('Error: The flight has already departed or is departing soon.');
            RETURN;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: No flight found with the specified Flight ID.');
            RETURN;
    END;

    -- Вывод номера рейса
    DBMS_OUTPUT.PUT_LINE('Searching tickets for Flight Number ' || v_flight_number || ':');
    DBMS_OUTPUT.PUT_LINE('-----------------------------------------------------');

    -- Локальный флаг для проверки наличия билетов
    DECLARE
        v_tickets_found BOOLEAN := FALSE;
    BEGIN
        FOR rec IN (
            SELECT ticket_id, ticket_number, seat_number, ticket_class, price, ticket_status
            FROM admin.Tickets
            WHERE flight_id = p_flight_id
              AND ticket_class = p_class
              AND (p_price_min IS NULL OR price >= p_price_min)
              AND (p_price_max IS NULL OR price <= p_price_max)
        ) LOOP
            v_tickets_found := TRUE;

            DBMS_OUTPUT.PUT_LINE('Ticket ID: ' || rec.ticket_number ||
                                 ', Seat: ' || rec.seat_number ||
                                 ', Class: ' || rec.ticket_class ||
                                 ', Price: ' || rec.price ||
                                 ', Status: ' || rec.ticket_status);
        END LOOP;

        -- Если билеты не найдены, выводим сообщение
        IF NOT v_tickets_found THEN
            DBMS_OUTPUT.PUT_LINE('No tickets found matching the specified criteria.');
        END IF;
    END;
END search_tickets;
/



BEGIN
    admin.search_tickets(
        p_flight_id => 20,
        p_class     => 'Economy'
    );
END;
/

select * from Tickets;



CREATE OR REPLACE PROCEDURE book_ticket (
    p_user_id       IN NUMBER,
    p_flight_id     IN NUMBER,
    p_class         IN VARCHAR2,
    p_seat_number   IN VARCHAR2
) AUTHID DEFINER AS
    v_user_exists NUMBER; 
    v_departure_time TIMESTAMP;
    v_ticket_id NUMBER;
    v_ticket_number VARCHAR2(20); -- Ensure this is a VARCHAR type
    v_seat_status VARCHAR2(20);
    v_ticket_exists NUMBER;
BEGIN
    -- Validation checks
    IF p_user_id IS NULL OR p_flight_id IS NULL OR p_class IS NULL OR p_seat_number IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('Error: All parameters must be provided and cannot be NULL.');
        RETURN;
    END IF;

    -- Validate ticket class
    IF p_class NOT IN ('Economy', 'Business', 'First') THEN
        DBMS_OUTPUT.PUT_LINE('Error: Ticket class must be one of the following: Economy, Business, First.');
        RETURN;
    END IF;

    -- Check if user exists
    SELECT COUNT(*)
    INTO v_user_exists
    FROM admin.Users
    WHERE user_id = p_user_id;

    IF v_user_exists = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: No user found with the specified user ID.');
        RETURN;
    END IF;

    -- Check if flight exists
    BEGIN
        SELECT departure_time
        INTO v_departure_time
        FROM admin.Flights
        WHERE flight_id = p_flight_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Flight not found.');
            RETURN;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error while fetching flight details: ' || SQLERRM);
            RAISE;
    END;

    -- Check if flight has departed
    IF v_departure_time <= CURRENT_TIMESTAMP THEN
        DBMS_OUTPUT.PUT_LINE('Error: Cannot book a ticket for a flight that has already departed or is in progress.');
        RETURN;
    END IF;

    -- Check ticket availability and book
    BEGIN
        SELECT COUNT(*)
        INTO v_ticket_exists
        FROM admin.Tickets
        WHERE flight_id = p_flight_id AND seat_number = p_seat_number;

        IF v_ticket_exists = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Error: No ticket found for the specified seat and flight.');
            RETURN;
        END IF;

        -- Fetch ticket details
        SELECT ticket_id, ticket_number, ticket_status INTO v_ticket_id, v_ticket_number, v_seat_status
        FROM admin.Tickets
        WHERE flight_id = p_flight_id AND seat_number = p_seat_number;

        -- Ensure the seat is available
        IF v_seat_status <> 'Available' THEN
            DBMS_OUTPUT.PUT_LINE('Error: The selected seat is not available.');
            RETURN;
        END IF;

        -- Book the ticket
        UPDATE admin.Tickets
        SET passenger_id = p_user_id,
            ticket_status = 'Booked',
            purchase_date = CURRENT_TIMESTAMP
        WHERE ticket_id = v_ticket_id;

        DBMS_OUTPUT.PUT_LINE('Ticket successfully booked');

        -- Display information about the booked ticket only
        FOR ticket_data IN (
            SELECT 
                u.username,
                f.flight_number,
                t.seat_number,
                t.ticket_class,
                t.price,
                TO_CHAR(t.purchase_date, 'YYYY-MM-DD HH24:MI') AS formatted_purchase_date,
                t.ticket_status,
                dep_airports.airport_name || ' (' || dep_airports.country || ')' AS origin,
                arr_airports.airport_name || ' (' || arr_airports.country || ')' AS destination,
                TO_CHAR(f.departure_time, 'YYYY-MM-DD HH24:MI') AS departure_time,
                TO_CHAR(f.arrival_time, 'YYYY-MM-DD HH24:MI') AS arrival_time
            FROM admin.Tickets t
            JOIN admin.Flights f ON t.flight_id = f.flight_id
            JOIN admin.Airports dep_airports ON f.departure_airport_id = dep_airports.airport_id
            JOIN admin.Airports arr_airports ON f.arrival_airport_id = arr_airports.airport_id
            JOIN admin.Users u ON t.passenger_id = u.user_id
            WHERE t.passenger_id = p_user_id AND t.ticket_id = v_ticket_id
        )
        LOOP
            DBMS_OUTPUT.PUT_LINE('For user with username: ' || ticket_data.username);
            DBMS_OUTPUT.PUT_LINE('Flight Number: ' || ticket_data.flight_number);
            DBMS_OUTPUT.PUT_LINE('Seat Number: ' || NVL(ticket_data.seat_number, 'Not Assigned'));
            DBMS_OUTPUT.PUT_LINE('Class: ' || ticket_data.ticket_class);
            DBMS_OUTPUT.PUT_LINE('Price: ' || ticket_data.price || ' USD');
            DBMS_OUTPUT.PUT_LINE('Purchase Date: ' || ticket_data.formatted_purchase_date);
            DBMS_OUTPUT.PUT_LINE('Status: ' || ticket_data.ticket_status);
            DBMS_OUTPUT.PUT_LINE('Origin: ' || ticket_data.origin);
            DBMS_OUTPUT.PUT_LINE('Destination: ' || ticket_data.destination);
            DBMS_OUTPUT.PUT_LINE('Departure Time: ' || ticket_data.departure_time);
            DBMS_OUTPUT.PUT_LINE('Arrival Time: ' || ticket_data.arrival_time);
            DBMS_OUTPUT.PUT_LINE('---------------------------------------');
        END LOOP;
    END;
END book_ticket;
/




BEGIN
    -- Вызов процедуры 'book_ticket'
    book_ticket(
        p_user_id => 5, -- ID пользователя
        p_flight_id => 20, -- ID рейса
        p_class => 'Business', -- Класс билета
        p_seat_number => '20E' -- Номер места
    );
END;
/



select * from Tickets;
select * from Users;

select value
    from nls_session_parameters
    where parameter = 'NLS_NUMERIC_CHARACTERS';
    
alter session set NLS_NUMERIC_CHARACTERS = '.,';

select * from Tickets;

DESC Tickets;

--get user tickets
CREATE OR REPLACE PROCEDURE sp_get_user_tickets( 
    p_user_id IN NUMBER 
) AUTHID DEFINER
AS
    v_user_exists NUMBER; 
    ticket_found BOOLEAN := FALSE; 
BEGIN
    -- Check if user exists
    SELECT COUNT(*)
    INTO v_user_exists
    FROM admin.Users
    WHERE user_id = p_user_id;

    IF v_user_exists = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: No user found with the specified user ID.');
        RETURN;
    END IF;

    -- Fetch and display ticket information
    FOR ticket_data IN (
        SELECT 
            u.username,
            f.flight_number,
            t.seat_number,
            t.ticket_class,
            t.price,
            TO_CHAR(t.purchase_date, 'YYYY-MM-DD HH24:MI') AS formatted_purchase_date,
            t.ticket_status,
            dep_airports.airport_name || ' (' || dep_airports.country || ')' AS origin,
            arr_airports.airport_name || ' (' || arr_airports.country || ')' AS destination,
            TO_CHAR(f.departure_time, 'YYYY-MM-DD HH24:MI') AS departure_time,
            TO_CHAR(f.arrival_time, 'YYYY-MM-DD HH24:MI') AS arrival_time
        FROM admin.Tickets t
        JOIN admin.Flights f ON t.flight_id = f.flight_id
        JOIN admin.Airports dep_airports ON f.departure_airport_id = dep_airports.airport_id
        JOIN admin.Airports arr_airports ON f.arrival_airport_id = arr_airports.airport_id
        JOIN admin.Users u ON t.passenger_id = u.user_id
        WHERE t.passenger_id = p_user_id
    )
    LOOP
        ticket_found := TRUE; -- If at least one ticket is found
        DBMS_OUTPUT.PUT_LINE('User with username: ' || ticket_data.username);
        DBMS_OUTPUT.PUT_LINE('Flight Number: ' || ticket_data.flight_number);
        DBMS_OUTPUT.PUT_LINE('Seat Number: ' || NVL(ticket_data.seat_number, 'Not Assigned'));
        DBMS_OUTPUT.PUT_LINE('Class: ' || ticket_data.ticket_class);
        DBMS_OUTPUT.PUT_LINE('Price: ' || ticket_data.price || ' USD');
        DBMS_OUTPUT.PUT_LINE('Purchase Date: ' || ticket_data.formatted_purchase_date);
        DBMS_OUTPUT.PUT_LINE('Status: ' || ticket_data.ticket_status);
        DBMS_OUTPUT.PUT_LINE('Origin: ' || ticket_data.origin);
        DBMS_OUTPUT.PUT_LINE('Destination: ' || ticket_data.destination);
        DBMS_OUTPUT.PUT_LINE('Departure Time: ' || ticket_data.departure_time);
        DBMS_OUTPUT.PUT_LINE('Arrival Time: ' || ticket_data.arrival_time);
        DBMS_OUTPUT.PUT_LINE('---------------------------------------');
    END LOOP;

    IF NOT ticket_found THEN
        DBMS_OUTPUT.PUT_LINE('No tickets found for the specified user ID.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Ticket information retrieved successfully.');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Error: No user found with the specified user ID.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An unexpected error occurred: ' || SQLERRM);
        RAISE;
END;
/

-- Test the procedure
BEGIN
    admin.sp_get_user_tickets(1); 
END;
/


CREATE OR REPLACE PROCEDURE sp_cancel_ticket_booking( 
    p_user_id   IN NUMBER, 
    p_ticket_id IN NUMBER
) AUTHID DEFINER
AS
    v_user_exists NUMBER; 
    v_ticket_status VARCHAR2(20); 
    v_ticket_owner  NUMBER;       
    v_username VARCHAR2(50); 
    v_seat_number VARCHAR2(5);
    v_ticket_price NUMBER;
    v_flight_number VARCHAR2(20);
BEGIN
    -- Check if the user exists
    SELECT COUNT(*)
    INTO v_user_exists
    FROM admin.Users
    WHERE user_id = p_user_id;

    IF v_user_exists = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: No user found with the specified user ID.');
        RETURN;
    END IF;

    -- Fetch the username
    SELECT username
    INTO v_username
    FROM admin.Users
    WHERE user_id = p_user_id;

    -- Check if the ticket exists and its owner
    BEGIN
        SELECT ticket_status, passenger_id
        INTO v_ticket_status, v_ticket_owner
        FROM admin.Tickets
        WHERE ticket_id = p_ticket_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: No ticket found with the specified ticket ID.');
            RETURN;
    END;

    IF v_ticket_owner != p_user_id THEN
        DBMS_OUTPUT.PUT_LINE('Error: The ticket does not belong to the specified user.');
        RETURN;
    END IF;

    -- Check the ticket status
    IF v_ticket_status != 'Booked' THEN
        DBMS_OUTPUT.PUT_LINE('Error: The ticket is not in the "Booked" status.');
        RETURN;
    END IF;

    -- Fetch ticket details
    SELECT seat_number, price, f.flight_number
    INTO v_seat_number, v_ticket_price, v_flight_number
    FROM admin.Tickets t
    JOIN admin.Flights f ON t.flight_id = f.flight_id
    WHERE t.ticket_id = p_ticket_id;

    -- Update the ticket status to "Available"
    UPDATE admin.Tickets
    SET ticket_status = 'Available', passenger_id = NULL
    WHERE ticket_id = p_ticket_id;

    -- Output success message with details
    DBMS_OUTPUT.PUT_LINE('Ticket booking has been successfully cancelled.');
    DBMS_OUTPUT.PUT_LINE('User: ' || v_username);
    DBMS_OUTPUT.PUT_LINE('Flight Number: ' || v_flight_number);
    DBMS_OUTPUT.PUT_LINE('Seat Number: ' || v_seat_number);
    DBMS_OUTPUT.PUT_LINE('Price: ' || v_ticket_price || ' USD');
    DBMS_OUTPUT.PUT_LINE('Ticket Status: Available');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An unexpected error occurred: ' || SQLERRM);
        RAISE;
END sp_cancel_ticket_booking;
/


BEGIN
    admin.sp_cancel_ticket_booking(
        p_user_id => 1,
        p_ticket_id => 38
    ); 
END;
/



select * from Users;
select * from Tickets;