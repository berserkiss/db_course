CREATE OR REPLACE PROCEDURE sp_analyze_tickets_and_routes (
    p_airport_id        IN NUMBER,
    p_period_start_str  IN VARCHAR2,
    p_period_end_str    IN VARCHAR2
) AUTHID DEFINER
AS
    v_period_start TIMESTAMP;
    v_period_start_output VARCHAR2(50);

    v_period_end TIMESTAMP;
    v_period_end_output VARCHAR2(50);

    v_airport_name VARCHAR2(100);
    v_ticket_count NUMBER := 0;

    -- Cursor declaration with explicit fetch variables
    TYPE c_ticket_analysis_type IS REF CURSOR;
    c_ticket_analysis c_ticket_analysis_type;

    v_departure_airport VARCHAR2(100);
    v_arrival_airport   VARCHAR2(100);
    v_sold_tickets      NUMBER;

BEGIN
    -- Convert period dates and determine the output format
    BEGIN
        -- Handle period start
        IF p_period_start_str IS NOT NULL THEN
            BEGIN
                v_period_start := TO_TIMESTAMP(p_period_start_str, 'YYYY-MM-DD HH24:MI');
                IF INSTR(p_period_start_str, ' ') = 0 THEN
                    -- Only a date provided; set output as start of the day
                    v_period_start := TRUNC(v_period_start);
                    v_period_start_output := TO_CHAR(v_period_start, 'YYYY-MM-DD HH24:MI') || ' (Start of Day)';
                ELSE
                    -- Full timestamp provided
                    v_period_start_output := TO_CHAR(v_period_start, 'YYYY-MM-DD HH24:MI');
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('Error: Invalid start date format.');
                    RAISE;
            END;
        END IF;

        -- Handle period end
        IF p_period_end_str IS NOT NULL THEN
            BEGIN
                v_period_end := TO_TIMESTAMP(p_period_end_str, 'YYYY-MM-DD HH24:MI');
                IF INSTR(p_period_end_str, ' ') = 0 THEN
                    -- Only a date provided; set output as end of the day
                    v_period_end := TRUNC(v_period_end) + INTERVAL '1' DAY - INTERVAL '1' SECOND;
                    v_period_end_output := TO_CHAR(v_period_end, 'YYYY-MM-DD HH24:MI') || ' (End of Day)';
                ELSE
                    -- Full timestamp provided
                    v_period_end_output := TO_CHAR(v_period_end, 'YYYY-MM-DD HH24:MI');
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('Error: Invalid end date format.');
                    RAISE;
            END;
        END IF;

        -- Validate that start date is earlier than end date
        IF v_period_start > v_period_end THEN
            DBMS_OUTPUT.PUT_LINE('Error: Start date cannot be later than end date.');
            RAISE_APPLICATION_ERROR(-20001, 'Start date cannot be later than end date.');
        END IF;
    END;

    -- Retrieve airport name
    BEGIN
        SELECT a.airport_name
        INTO v_airport_name
        FROM admin.Airports a
        WHERE a.airport_id = p_airport_id;

        DBMS_OUTPUT.PUT_LINE('Analysis for Airport: ' || v_airport_name);
        DBMS_OUTPUT.PUT_LINE('Analysis Period Start: ' || v_period_start_output);
        DBMS_OUTPUT.PUT_LINE('Analysis Period End: ' || v_period_end_output);

    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: Invalid airport ID.');
            RAISE;
    END;

    -- Open cursor for ticket analysis
    BEGIN
        OPEN c_ticket_analysis FOR
            SELECT 
                dep_airport.airport_name AS departure_airport,
                arr_airport.airport_name AS arrival_airport,
                COUNT(t.ticket_id) AS sold_tickets
            FROM admin.Tickets t
            JOIN admin.Flights f ON t.flight_id = f.flight_id
            JOIN admin.Airports dep_airport ON f.departure_airport_id = dep_airport.airport_id
            JOIN admin.Airports arr_airport ON f.arrival_airport_id = arr_airport.airport_id
            WHERE t.ticket_status IN ('Booked', 'Completed')
              AND (t.purchase_date BETWEEN v_period_start AND v_period_end)
              AND (f.departure_airport_id = p_airport_id OR f.arrival_airport_id = p_airport_id)
            GROUP BY dep_airport.airport_name, arr_airport.airport_name;

        -- Fetch results and display
        LOOP
            FETCH c_ticket_analysis INTO v_departure_airport, v_arrival_airport, v_sold_tickets;
            EXIT WHEN c_ticket_analysis%NOTFOUND;

            DBMS_OUTPUT.PUT_LINE('From: ' || v_departure_airport || ' -> To: ' || v_arrival_airport);
            DBMS_OUTPUT.PUT_LINE('Sold Tickets: ' || v_sold_tickets);
            v_ticket_count := v_ticket_count + v_sold_tickets;
        END LOOP;
        CLOSE c_ticket_analysis;

        -- Check if no tickets were sold
        IF v_ticket_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('No tickets sold for the specified period and airport.');
        ELSE
            -- Output the total number of tickets
            DBMS_OUTPUT.PUT_LINE('Total Tickets Sold During The Period: ' || v_ticket_count);
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: Failed to analyze tickets and routes.');
            RAISE;
    END;
END sp_analyze_tickets_and_routes;
/




CREATE OR REPLACE PROCEDURE sp_analyze_routes (
    p_airport_id IN NUMBER
) AUTHID DEFINER
AS
    v_airport_name VARCHAR2(100);
    v_ticket_count NUMBER := 0;

    -- Cursor declaration with explicit fetch variables
    TYPE c_ticket_analysis_type IS REF CURSOR;
    c_ticket_analysis c_ticket_analysis_type;

    v_departure_airport VARCHAR2(100);
    v_departure_country VARCHAR2(100);
    v_arrival_airport   VARCHAR2(100);
    v_arrival_country   VARCHAR2(100);
    v_sold_tickets      NUMBER;

BEGIN
    -- Retrieve the name of the airport
    BEGIN
        SELECT a.airport_name
        INTO v_airport_name
        FROM admin.Airports a
        WHERE a.airport_id = p_airport_id;

        DBMS_OUTPUT.PUT_LINE('Analysis for airport: ' || v_airport_name);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: Invalid airport ID.');
            RAISE; -- Re-throw the exception
    END;

    -- Open cursor for ticket analysis
    BEGIN
        OPEN c_ticket_analysis FOR
            SELECT 
                dep_airport.airport_name AS departure_airport,
                dep_airport.country AS departure_country,
                arr_airport.airport_name AS arrival_airport,
                arr_airport.country AS arrival_country,
                COUNT(t.ticket_id) AS sold_tickets
            FROM admin.Tickets t
            JOIN admin.Flights f ON t.flight_id = f.flight_id
            JOIN admin.Airports dep_airport ON f.departure_airport_id = dep_airport.airport_id
            JOIN admin.Airports arr_airport ON f.arrival_airport_id = arr_airport.airport_id
            WHERE t.ticket_status IN ('Booked', 'Completed')
              AND (f.departure_airport_id = p_airport_id OR f.arrival_airport_id = p_airport_id)
            GROUP BY 
                dep_airport.airport_name, dep_airport.country, 
                arr_airport.airport_name, arr_airport.country
            ORDER BY COUNT(t.ticket_id) DESC;

        -- Fetch data from cursor
        LOOP
            FETCH c_ticket_analysis INTO 
                v_departure_airport, v_departure_country, 
                v_arrival_airport, v_arrival_country, 
                v_sold_tickets;
            EXIT WHEN c_ticket_analysis%NOTFOUND;

            DBMS_OUTPUT.PUT_LINE('From: ' || v_departure_airport || ' (' || v_departure_country || ') ' || 
                                 ' -> To: ' || v_arrival_airport || ' (' || v_arrival_country || ')');
            DBMS_OUTPUT.PUT_LINE('Sold Tickets: ' || v_sold_tickets);
            v_ticket_count := v_ticket_count + v_sold_tickets;
        END LOOP;
        CLOSE c_ticket_analysis;

        -- Check if no tickets were sold
        IF v_ticket_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('No tickets sold for the specified airport.');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: Failed to analyze tickets and routes.');
            RAISE; -- Re-throw the exception
    END;
END sp_analyze_routes;
/



CREATE OR REPLACE PROCEDURE sp_analyze_popular_routes (
    p_airport_id IN NUMBER
) AUTHID DEFINER
AS
    v_airport_name VARCHAR2(100);
    v_departure_airport VARCHAR2(100);
    v_departure_country VARCHAR2(100);
    v_arrival_airport   VARCHAR2(100);
    v_arrival_country   VARCHAR2(100);
    v_ticket_count      NUMBER := 0;
    v_rank              NUMBER := 1;

    -- Cursor declaration for ordered results
    TYPE c_popular_routes_type IS REF CURSOR;
    c_popular_routes c_popular_routes_type;

BEGIN
    -- Get the name of the specified airport
    BEGIN
        SELECT a.airport_name
        INTO v_airport_name
        FROM admin.Airports a
        WHERE a.airport_id = p_airport_id;

        DBMS_OUTPUT.PUT_LINE('Most Popular Routes for Airport: ' || v_airport_name);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Invalid airport ID.');
            RAISE;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: Could not retrieve airport name.');
            RAISE;
    END;

    -- Open cursor to retrieve routes ordered by sold tickets in descending order
    BEGIN
        OPEN c_popular_routes FOR
            SELECT 
                dep_airport.airport_name AS departure_airport,
                dep_airport.country AS departure_country,
                arr_airport.airport_name AS arrival_airport,
                arr_airport.country AS arrival_country
            FROM admin.Tickets t
            JOIN admin.Flights f ON t.flight_id = f.flight_id
            JOIN admin.Airports dep_airport ON f.departure_airport_id = dep_airport.airport_id
            JOIN admin.Airports arr_airport ON f.arrival_airport_id = arr_airport.airport_id
            WHERE t.ticket_status IN ('Booked', 'Completed')
              AND (f.departure_airport_id = p_airport_id OR f.arrival_airport_id = p_airport_id)
            GROUP BY 
                dep_airport.airport_name, dep_airport.country, 
                arr_airport.airport_name, arr_airport.country
            ORDER BY COUNT(t.ticket_id) DESC; -- Order by ticket count in descending order

        -- Fetch results and display
        LOOP
            FETCH c_popular_routes INTO 
                v_departure_airport, v_departure_country, 
                v_arrival_airport, v_arrival_country;
            EXIT WHEN c_popular_routes%NOTFOUND;

            DBMS_OUTPUT.PUT_LINE(v_rank || ') From: ' || v_departure_airport || ' (' || v_departure_country || ') -> To: ' 
                                 || v_arrival_airport || ' (' || v_arrival_country || ')');
            v_rank := v_rank + 1;
        END LOOP;
        CLOSE c_popular_routes;

        -- Check if no routes exist
        IF v_rank = 1 THEN
            DBMS_OUTPUT.PUT_LINE('No routes found for the specified airport.');
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: Failed to analyze popular routes.');
            RAISE;
    END;
END sp_analyze_popular_routes;
/




CREATE OR REPLACE PROCEDURE sp_view_regular_users
(p_airport_id NUMBER)
AUTHID DEFINER
IS
    CURSOR regular_users_cur IS
        SELECT uv.*
        FROM admin.Users_View uv
        WHERE uv.user_id NOT IN (SELECT user_id FROM Employee)
        ORDER BY uv.user_id; -- Сортируем пользователей по user_id (или любому другому полю)

    CURSOR tickets_cur (p_user_id NUMBER) IS
        SELECT t.ticket_number, 
               t.seat_number, 
               t.price, 
               t.ticket_class, 
               f.flight_number, 
               f.departure_time, 
               f.arrival_time, 
               da.airport_name AS departure_airport, 
               aa.airport_name AS arrival_airport
        FROM admin.Tickets t
        JOIN admin.Flights f ON t.flight_id = f.flight_id
        JOIN admin.Airports da ON f.departure_airport_id = da.airport_id
        JOIN admin.Airports aa ON f.arrival_airport_id = aa.airport_id
        WHERE t.passenger_id = p_user_id
          AND t.ticket_status = 'Booked'
          AND f.departure_time > SYSDATE
          AND (f.departure_airport_id = p_airport_id OR f.arrival_airport_id = p_airport_id)
        ORDER BY f.departure_time; -- Сортируем билеты по времени вылета

    v_user regular_users_cur%ROWTYPE;
    v_ticket tickets_cur%ROWTYPE;
    v_ticket_exists BOOLEAN := FALSE; -- Флаг для проверки наличия билетов
BEGIN
    -- Обходим всех обычных пользователей
    OPEN regular_users_cur;
    LOOP
        FETCH regular_users_cur INTO v_user;
        EXIT WHEN regular_users_cur%NOTFOUND;

        -- Выводим информацию о пользователе
        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE('User ID: ' || v_user.user_id);
        DBMS_OUTPUT.PUT_LINE('Username: ' || v_user.username);
        DBMS_OUTPUT.PUT_LINE('Email: ' || v_user.email);
        DBMS_OUTPUT.PUT_LINE('Phone: ' ||  NVL(v_user.phone, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('First Name: ' || v_user.firstname);
        DBMS_OUTPUT.PUT_LINE('Last Name: ' || v_user.lastname);
        DBMS_OUTPUT.PUT_LINE('Birthdate: ' || v_user.birthdate);
        DBMS_OUTPUT.PUT_LINE('Country: ' || v_user.country);
        DBMS_OUTPUT.PUT_LINE('City: ' || NVL(v_user.city, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Street: ' || NVL(v_user.street, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Passport Number: ' || v_user.passport_number);
        DBMS_OUTPUT.PUT_LINE('Active: ' || CASE v_user.is_active WHEN 1 THEN 'Yes' ELSE 'No' END);
        
        -- Проверяем наличие забронированных билетов
        OPEN tickets_cur(v_user.user_id);
        LOOP
            FETCH tickets_cur INTO v_ticket;
            EXIT WHEN tickets_cur%NOTFOUND;

            -- Выводим информацию о билете и рейсе
            v_ticket_exists := TRUE; -- Билеты найдены, устанавливаем флаг
            DBMS_OUTPUT.PUT_LINE('  ---------------------------------------------');
            DBMS_OUTPUT.PUT_LINE('  Ticket Number: ' || v_ticket.ticket_number);
            DBMS_OUTPUT.PUT_LINE('  Seat Number: ' || v_ticket.seat_number);
            DBMS_OUTPUT.PUT_LINE('  Price: ' || v_ticket.price);
            DBMS_OUTPUT.PUT_LINE('  Class: ' || v_ticket.ticket_class);
            DBMS_OUTPUT.PUT_LINE('  Flight Number: ' || v_ticket.flight_number);
            DBMS_OUTPUT.PUT_LINE('  Departure Time: ' || TO_CHAR(v_ticket.departure_time, 'YYYY-MM-DD HH24:MI:SS'));
            DBMS_OUTPUT.PUT_LINE('  Arrival Time: ' || TO_CHAR(v_ticket.arrival_time, 'YYYY-MM-DD HH24:MI:SS'));
            DBMS_OUTPUT.PUT_LINE('  Departure Airport: ' || v_ticket.departure_airport);
            DBMS_OUTPUT.PUT_LINE('  Arrival Airport: ' || v_ticket.arrival_airport);
        END LOOP;

        IF NOT v_ticket_exists THEN
            -- Если билетов нет, выводим сообщение
            DBMS_OUTPUT.PUT_LINE('  No booked tickets for this user.');
        END IF;

        CLOSE tickets_cur;
    END LOOP;
    CLOSE regular_users_cur;
END;
/




CREATE OR REPLACE PROCEDURE SP_ADD_TICKET_FOR_AIRPORT_FLIGHT (
    p_seat_number       IN VARCHAR2,
    p_ticket_class      IN VARCHAR2,
    p_price             IN NUMBER,
    p_flight_id         IN NUMBER,
    p_airport_id        IN NUMBER
) 
AUTHID DEFINER
IS
    v_flight_id         NUMBER;
    v_seating_capacity  NUMBER; -- Вместимость самолета
    v_ticket_count      NUMBER; -- Количество билетов на рейс
    v_airplane_id       NUMBER; -- ID самолета
    v_airport_name      VARCHAR2(100);
    v_flight_number     VARCHAR2(20);
    v_departure_time    TIMESTAMP;
BEGIN
    -- Проверяем существует ли указанный аэропорт
    BEGIN
        SELECT airport_name
        INTO v_airport_name
        FROM admin.Airports
        WHERE airport_id = p_airport_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Airport with ID ' || p_airport_id || ' does not exist.');
            RAISE_APPLICATION_ERROR(-20001, 'Airport does not exist.');
    END;

    -- Проверяем существует ли рейс с данным p_flight_id и связан ли он с указанным аэропортом
    BEGIN
        SELECT flight_number, departure_time, airplane_id
        INTO v_flight_number, v_departure_time, v_airplane_id
        FROM admin.Flights
        WHERE flight_id = p_flight_id
          AND (departure_airport_id = p_airport_id OR arrival_airport_id = p_airport_id);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Flight with ID ' || p_flight_id || ' does not exist or is not associated with the specified airport.');
            RAISE_APPLICATION_ERROR(-20002, 'Flight does not exist for the given airport.');
    END;

    -- Проверяем, что время отправки рейса больше текущего времени
    IF v_departure_time <= SYSTIMESTAMP THEN
        DBMS_OUTPUT.PUT_LINE('Error: Flight departure time must be in the future.');
        RAISE_APPLICATION_ERROR(-20003, 'Flight departure time must be in the future.');
    END IF;

    -- Получаем вместимость самолета
    BEGIN
        SELECT at.seating_capacity
        INTO v_seating_capacity
        FROM admin.Airplane_Types at
        JOIN admin.Airplanes a ON at.type_id = a.type_id
        WHERE a.airplane_id = v_airplane_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Airplane not found for the flight.');
            RAISE_APPLICATION_ERROR(-20007, 'Airplane not found for the flight.');
    END;

    -- Подсчитываем количество билетов на рейс
    SELECT COUNT(*)
    INTO v_ticket_count
    FROM Tickets
    WHERE flight_id = p_flight_id;

    -- Проверяем, не превышает ли количество билетов вместимость самолета
    IF v_ticket_count >= v_seating_capacity THEN
        DBMS_OUTPUT.PUT_LINE('Error: Seating capacity exceeded for flight ' || v_flight_number || '.');
        RAISE_APPLICATION_ERROR(-20008, 'Seating capacity exceeded.');
    END IF;

    -- Проверяем, что класс билета допустим
    IF p_ticket_class NOT IN ('Economy', 'Business', 'First') THEN
        DBMS_OUTPUT.PUT_LINE('Error: Invalid ticket class ' || p_ticket_class || '.');
        RAISE_APPLICATION_ERROR(-20004, 'Invalid ticket class.');
    END IF;

    -- Выводим информацию о билете, который будет добавлен
    DBMS_OUTPUT.PUT_LINE('Adding ticket for airport: ' || v_airport_name);
    DBMS_OUTPUT.PUT_LINE('Flight number: ' || v_flight_number);
    DBMS_OUTPUT.PUT_LINE('Seat number: ' || p_seat_number);
    DBMS_OUTPUT.PUT_LINE('Ticket class: ' || p_ticket_class);
    DBMS_OUTPUT.PUT_LINE('Ticket price: ' || p_price);

    -- Добавляем билет в таблицу Tickets
    BEGIN
        INSERT INTO admin.Tickets (
            ticket_number, 
            flight_id, 
            passenger_id, 
            seat_number, 
            price, 
            ticket_class, 
            ticket_status
        ) VALUES (
            NULL,  -- ticket_number будет сгенерирован триггером
            p_flight_id,
            NULL,  -- Не передаем passenger_id, так как он может быть установлен позже
            p_seat_number,
            p_price,
            p_ticket_class,
            'Available'
        );
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Ticket added successfully for flight ' || v_flight_number || ' with seat ' || p_seat_number);
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            -- Обрабатываем ошибку уникальности и выводим в DBMS_OUTPUT
            DBMS_OUTPUT.PUT_LINE('Error: A ticket with the same seat number already exists for this flight.');
            ROLLBACK;  -- Откат транзакции в случае ошибки уникальности
            RAISE_APPLICATION_ERROR(-20005, 'A ticket with the same seat number already exists for this flight.');
        WHEN OTHERS THEN
            -- Обработка всех других ошибок
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
            ROLLBACK;  -- Откат транзакции в случае других ошибок
            RAISE_APPLICATION_ERROR(-20006, 'Error in adding ticket: ' || SQLERRM);
    END;

EXCEPTION
    WHEN OTHERS THEN
        -- Общая обработка ошибок
        DBMS_OUTPUT.PUT_LINE('Unexpected error: ' || SQLERRM);
        ROLLBACK;  -- Откат транзакции при неожиданной ошибке
        RAISE_APPLICATION_ERROR(-20000, 'Unexpected error: ' || SQLERRM);
END;
/





CREATE OR REPLACE PROCEDURE SP_GET_FLIGHTS_AND_TICKETS_FOR_AIRPORT (
    p_airport_id IN NUMBER
)
AUTHID DEFINER
IS
    CURSOR flights_cur IS
        SELECT f.flight_id,
               f.flight_number,
               f.departure_time,
               f.arrival_time,
               da.airport_name AS departure_airport,
               aa.airport_name AS arrival_airport
        FROM admin.Flights f
        JOIN admin.Airports da ON f.departure_airport_id = da.airport_id
        JOIN admin.Airports aa ON f.arrival_airport_id = aa.airport_id
        WHERE (f.departure_airport_id = p_airport_id 
               OR f.arrival_airport_id = p_airport_id)
          AND f.departure_time > SYSDATE; -- Фильтрация по аэропорту и будущим рейсам

    CURSOR tickets_cur (p_flight_id NUMBER) IS
        SELECT t.ticket_number,
               t.seat_number,
               t.price,
               t.ticket_class,
               f.flight_number,
               f.departure_time,
               f.arrival_time,
               da.airport_name AS departure_airport,
               aa.airport_name AS arrival_airport
        FROM admin.Tickets t
        JOIN admin.Flights f ON t.flight_id = f.flight_id
        JOIN admin.Airports da ON f.departure_airport_id = da.airport_id
        JOIN admin.Airports aa ON f.arrival_airport_id = aa.airport_id
        WHERE f.flight_id = p_flight_id
          AND f.departure_time > SYSDATE;

    v_flight flights_cur%ROWTYPE;
    v_ticket tickets_cur%ROWTYPE;
    v_ticket_exists BOOLEAN := FALSE; -- Флаг для проверки наличия билетов
    v_airport_name VARCHAR2(100);
    v_flights_found BOOLEAN := FALSE; -- Флаг для проверки наличия рейсов
BEGIN
    -- Получаем имя аэропорта для вывода
    BEGIN
        SELECT airport_name
        INTO v_airport_name
        FROM admin.Airports
        WHERE airport_id = p_airport_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('No airport found with ID ' || p_airport_id);
            RETURN;
    END;

    -- Выводим информацию о аэропорте
    DBMS_OUTPUT.PUT_LINE('=================================================');
    DBMS_OUTPUT.PUT_LINE('Airport ID: ' || p_airport_id);
    DBMS_OUTPUT.PUT_LINE('Airport Name: ' || v_airport_name);
    DBMS_OUTPUT.PUT_LINE('=================================================');

    -- Обрабатываем все рейсы, связанные с переданным аэропортом
    OPEN flights_cur;
    LOOP
        FETCH flights_cur INTO v_flight;
        EXIT WHEN flights_cur%NOTFOUND;

        -- Если рейс найден, устанавливаем флаг в TRUE
        v_flights_found := TRUE;

        -- Выводим информацию о рейсе
        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE('Flight ID: ' || v_flight.flight_id);
        DBMS_OUTPUT.PUT_LINE('Flight Number: ' || v_flight.flight_number);
        DBMS_OUTPUT.PUT_LINE('Departure Time: ' || TO_CHAR(v_flight.departure_time, 'YYYY-MM-DD HH24:MI:SS'));
        DBMS_OUTPUT.PUT_LINE('Arrival Time: ' || TO_CHAR(v_flight.arrival_time, 'YYYY-MM-DD HH24:MI:SS'));
        DBMS_OUTPUT.PUT_LINE('Departure Airport: ' || v_flight.departure_airport);
        DBMS_OUTPUT.PUT_LINE('Arrival Airport: ' || v_flight.arrival_airport);

        -- Проверяем наличие забронированных билетов для данного рейса
        OPEN tickets_cur(v_flight.flight_id);
        v_ticket_exists := FALSE;  -- Сброс флага на начало
        LOOP
            FETCH tickets_cur INTO v_ticket;
            EXIT WHEN tickets_cur%NOTFOUND;

            -- Выводим информацию о билете
            v_ticket_exists := TRUE; -- Билеты найдены, устанавливаем флаг
            DBMS_OUTPUT.PUT_LINE('  ---------------------------------------------');
            DBMS_OUTPUT.PUT_LINE('  Ticket Number: ' || v_ticket.ticket_number);
            DBMS_OUTPUT.PUT_LINE('  Seat Number: ' || v_ticket.seat_number);
            DBMS_OUTPUT.PUT_LINE('  Price: ' || v_ticket.price);
            DBMS_OUTPUT.PUT_LINE('  Class: ' || v_ticket.ticket_class);
            DBMS_OUTPUT.PUT_LINE('  Departure Time: ' || TO_CHAR(v_ticket.departure_time, 'YYYY-MM-DD HH24:MI:SS'));
            DBMS_OUTPUT.PUT_LINE('  Arrival Time: ' || TO_CHAR(v_ticket.arrival_time, 'YYYY-MM-DD HH24:MI:SS'));
            DBMS_OUTPUT.PUT_LINE('  Departure Airport: ' || v_ticket.departure_airport);
            DBMS_OUTPUT.PUT_LINE('  Arrival Airport: ' || v_ticket.arrival_airport);
        END LOOP;

        -- Если билетов нет, выводим соответствующее сообщение
        IF NOT v_ticket_exists THEN
            DBMS_OUTPUT.PUT_LINE('  No tickets for this flight.');
        END IF;

        CLOSE tickets_cur;
    END LOOP;
    CLOSE flights_cur;

    -- Если рейсы не найдены, выводим сообщение
    IF NOT v_flights_found THEN
        DBMS_OUTPUT.PUT_LINE('No flights found for this airport.');
    END IF;
END;
/




CREATE OR REPLACE PROCEDURE SP_EDIT_TICKET (
    p_ticket_id         IN NUMBER,
    p_seat_number       IN VARCHAR2 DEFAULT NULL,
    p_ticket_class      IN VARCHAR2 DEFAULT NULL,
    p_price             IN NUMBER DEFAULT NULL,
    p_flight_id         IN NUMBER,
    p_airport_id        IN NUMBER  -- Параметр для аэропорта
)
AUTHID DEFINER
IS
    v_flight_id         NUMBER;
    v_airport_name      VARCHAR2(100);
    v_departure_time    TIMESTAMP;
    v_flight_number     VARCHAR2(20);
    v_exists_ticket     NUMBER := 0;

    -- Переменные для данных билета до изменений
    v_old_seat_number   VARCHAR2(10);
    v_old_ticket_class  VARCHAR2(20);
    v_old_price         NUMBER;

    -- Переменные для данных билета после изменений
    v_new_seat_number   VARCHAR2(10);
    v_new_ticket_class  VARCHAR2(20);
    v_new_price         NUMBER;
BEGIN
    -- Проверяем, существует ли билет с указанным ID, и выбираем текущие данные
    BEGIN
        SELECT seat_number, ticket_class, price, flight_id
        INTO v_old_seat_number, v_old_ticket_class, v_old_price, v_flight_id
        FROM admin.Tickets
        WHERE ticket_id = p_ticket_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Ticket with ID ' || p_ticket_id || ' does not exist.');
            RAISE_APPLICATION_ERROR(-20001, 'Ticket does not exist.');
    END;

    -- Получаем название аэропорта
    BEGIN
        SELECT airport_name
        INTO v_airport_name
        FROM admin.Airports
        WHERE airport_id = p_airport_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20008, 'Airport does not exist.');
    END;

    -- Проверяем, существует ли рейс с данным p_flight_id и связан ли он с указанным аэропортом
    BEGIN
        SELECT flight_number, departure_time
        INTO v_flight_number, v_departure_time
        FROM admin.Flights
        WHERE flight_id = p_flight_id
          AND (departure_airport_id = p_airport_id OR arrival_airport_id = p_airport_id);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'Flight does not exist for the given airport.');
    END;

    -- Проверяем, что время отправки рейса больше текущего времени
    IF v_departure_time <= SYSTIMESTAMP THEN
        RAISE_APPLICATION_ERROR(-20003, 'Flight departure time must be in the future.');
    END IF;

    -- Проверяем, что класс билета допустим, если он передан
    IF p_ticket_class IS NOT NULL AND p_ticket_class NOT IN ('Economy', 'Business', 'First') THEN
        RAISE_APPLICATION_ERROR(-20004, 'Invalid ticket class.');
    END IF;

    -- Проверяем, что новый номер места уникален для указанного рейса, если он передан
    IF p_seat_number IS NOT NULL THEN
        SELECT COUNT(*)
        INTO v_exists_ticket
        FROM admin.Tickets
        WHERE flight_id = p_flight_id
          AND seat_number = p_seat_number
          AND ticket_status != 'Cancelled'
          AND ticket_id != p_ticket_id; -- Исключаем текущий билет

        IF v_exists_ticket > 0 THEN
            RAISE_APPLICATION_ERROR(-20005, 'A ticket with the same seat number already exists for this flight.');
        END IF;
    END IF;

    -- Вывод данных билета до изменений
    DBMS_OUTPUT.PUT_LINE('--- Ticket Information Before Update ---');
    DBMS_OUTPUT.PUT_LINE('Ticket ID: ' || p_ticket_id);
    DBMS_OUTPUT.PUT_LINE('Flight Number: ' || v_flight_number);
    DBMS_OUTPUT.PUT_LINE('Seat Number: ' || v_old_seat_number);
    DBMS_OUTPUT.PUT_LINE('Ticket Class: ' || v_old_ticket_class);
    DBMS_OUTPUT.PUT_LINE('Price: ' || v_old_price);

    -- Обновляем информацию о билете
    BEGIN
        UPDATE admin.Tickets
        SET seat_number   = NVL(p_seat_number, seat_number),
            ticket_class  = NVL(p_ticket_class, ticket_class),
            price         = NVL(p_price, price)
        WHERE ticket_id = p_ticket_id;

        -- Коммит обновления
        COMMIT;

        -- Присваиваем новые данные для отображения после обновления
        v_new_seat_number := NVL(p_seat_number, v_old_seat_number);
        v_new_ticket_class := NVL(p_ticket_class, v_old_ticket_class);
        v_new_price := NVL(p_price, v_old_price);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20007, 'Error in updating ticket: ' || SQLERRM);
    END;

    -- Вывод данных билета после изменений
    DBMS_OUTPUT.PUT_LINE('--- Ticket Information After Update ---');
    DBMS_OUTPUT.PUT_LINE('Ticket ID: ' || p_ticket_id);
    DBMS_OUTPUT.PUT_LINE('Flight Number: ' || v_flight_number);
    DBMS_OUTPUT.PUT_LINE('Seat Number: ' || v_new_seat_number);
    DBMS_OUTPUT.PUT_LINE('Ticket Class: ' || v_new_ticket_class);
    DBMS_OUTPUT.PUT_LINE('Price: ' || v_new_price);
    DBMS_OUTPUT.PUT_LINE('Airport: ' || v_airport_name);
    DBMS_OUTPUT.PUT_LINE('Ticket updated successfully.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Unexpected error: ' || SQLERRM);
        RAISE_APPLICATION_ERROR(-20000, 'Unexpected error: ' || SQLERRM);
END SP_EDIT_TICKET;
/





CREATE OR REPLACE PROCEDURE SP_DELETE_TICKET (
    p_ticket_id         IN NUMBER,
    p_flight_id         IN NUMBER,
    p_airport_id        IN NUMBER
)
AUTHID DEFINER
IS
    v_airport_name      VARCHAR2(100);  -- Название аэропорта
    v_departure_airport NUMBER;
    v_arrival_airport   NUMBER;
    v_ticket_info       Tickets%ROWTYPE; -- Полная информация о билете
    v_flight_number     VARCHAR2(50);    -- Номер рейса
BEGIN
    -- Проверяем, существует ли аэропорт
    BEGIN
        SELECT airport_name
        INTO v_airport_name
        FROM admin.Airports
        WHERE airport_id = p_airport_id;

        -- Выводим ID и название аэропорта
        DBMS_OUTPUT.PUT_LINE('Airport ID: ' || p_airport_id);
        DBMS_OUTPUT.PUT_LINE('Airport Name: ' || v_airport_name);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Airport with ID ' || p_airport_id || ' does not exist.');
            RAISE_APPLICATION_ERROR(-20001, 'Airport does not exist.');
    END;

    -- Проверяем, существует ли рейс и связан ли он с указанным аэропортом
    BEGIN
        SELECT departure_airport_id, arrival_airport_id, flight_number
        INTO v_departure_airport, v_arrival_airport, v_flight_number
        FROM admin.Flights
        WHERE flight_id = p_flight_id;

        IF v_departure_airport != p_airport_id AND v_arrival_airport != p_airport_id THEN
            DBMS_OUTPUT.PUT_LINE('Error: Flight with ID ' || p_flight_id || ' is not associated with airport ID ' || p_airport_id || '.');
            RAISE_APPLICATION_ERROR(-20002, 'Flight is not associated with the specified airport.');
        END IF;

        -- Выводим ID и номер рейса
        DBMS_OUTPUT.PUT_LINE('Flight ID: ' || p_flight_id);
        DBMS_OUTPUT.PUT_LINE('Flight Number: ' || v_flight_number);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Flight with ID ' || p_flight_id || ' does not exist.');
            RAISE_APPLICATION_ERROR(-20003, 'Flight does not exist.');
    END;

    -- Проверяем, существует ли билет и связан ли он с указанным рейсом
    BEGIN
        SELECT *
        INTO v_ticket_info
        FROM admin.Tickets
        WHERE ticket_id = p_ticket_id AND flight_id = p_flight_id;

        -- Выводим ID и номер билета
        DBMS_OUTPUT.PUT_LINE('Ticket ID: ' || p_ticket_id);
        DBMS_OUTPUT.PUT_LINE('Ticket Number: ' || v_ticket_info.ticket_number);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Ticket with ID ' || p_ticket_id || ' does not exist for flight ID ' || p_flight_id || '.');
            RAISE_APPLICATION_ERROR(-20004, 'Ticket does not exist for the specified flight.');
    END;

    -- Удаляем билет
    BEGIN
        DELETE FROM admin.Tickets
        WHERE ticket_id = p_ticket_id;

                DBMS_OUTPUT.PUT_LINE('Ticket successfully deleted.');
                DBMS_OUTPUT.PUT_LINE('Details of Deleted Ticket:');
                DBMS_OUTPUT.PUT_LINE(
            'Ticket Details: ' || 
            'Ticket ID: ' || v_ticket_info.ticket_id || ', ' || 
            'Ticket Number: ' || v_ticket_info.ticket_number || ', ' || 
            'Seat Number: ' || v_ticket_info.seat_number || ', ' || 
            'Price: ' || v_ticket_info.price || ', ' || 
            'Class: ' || v_ticket_info.ticket_class || ', ' || 
            'Status: ' || v_ticket_info.ticket_status || ', ' || 
            'Passenger ID: ' || v_ticket_info.passenger_id
        );       


        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error occurred while deleting ticket: ' || SQLERRM);
            RAISE_APPLICATION_ERROR(-20005, 'Error occurred while deleting ticket: ' || SQLERRM);
    END;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Unexpected error occurred: ' || SQLERRM);
        RAISE_APPLICATION_ERROR(-20006, 'Unexpected error occurred: ' || SQLERRM);
END;
/





CREATE OR REPLACE PROCEDURE sp_delete_flight (
    p_flight_id   IN NUMBER,  -- ID рейса, который нужно удалить
    p_airport_id  IN NUMBER   -- ID аэропорта, с которым должен быть связан рейс
)
AUTHID DEFINER
IS
    v_airport_count NUMBER;       -- Проверка существования аэропорта
    v_airport_name  VARCHAR2(100); -- Название аэропорта
    v_departure_airport_id NUMBER;
    v_arrival_airport_id   NUMBER;
    v_flight_number VARCHAR2(20);
    v_ticket_info Tickets%ROWTYPE;
    v_passenger_id_display VARCHAR2(20);
BEGIN
    -- Проверяем существование аэропорта
    SELECT COUNT(*)
    INTO v_airport_count
    FROM admin.Airports
    WHERE airport_id = p_airport_id;

    IF v_airport_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: Airport with ID ' || p_airport_id || ' does not exist.');
        RAISE_APPLICATION_ERROR(-20001, 'Airport does not exist.');
    END IF;

    -- Получаем название аэропорта
    SELECT airport_name
    INTO v_airport_name
    FROM admin.Airports
    WHERE airport_id = p_airport_id;

    -- Проверяем, связан ли рейс с указанным аэропортом
    BEGIN
        SELECT departure_airport_id, arrival_airport_id, flight_number
        INTO v_departure_airport_id, v_arrival_airport_id, v_flight_number
        FROM admin.Flights
        WHERE flight_id = p_flight_id;

        IF v_departure_airport_id != p_airport_id AND v_arrival_airport_id != p_airport_id THEN
            DBMS_OUTPUT.PUT_LINE('Error: Flight with ID ' || p_flight_id || ' is not associated with airport ID ' || p_airport_id || '.');
            RAISE_APPLICATION_ERROR(-20002, 'Flight is not associated with the given airport.');
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Flight with ID ' || p_flight_id || ' does not exist.');
            RAISE_APPLICATION_ERROR(-20003, 'Flight does not exist.');
    END;

    -- Выводим информацию об аэропорте и рейсе
    DBMS_OUTPUT.PUT_LINE('Airport Name: ' || v_airport_name || ', Airport ID: ' || p_airport_id);
    DBMS_OUTPUT.PUT_LINE('Flight Number: ' || v_flight_number || ', Flight ID: ' || p_flight_id);

    -- Проверяем и удаляем связанные билеты
    FOR v_ticket_info IN (
        SELECT *
        FROM admin.Tickets
        WHERE flight_id = p_flight_id
        ORDER BY ticket_number -- Сортировка билетов по номеру
    ) LOOP
        -- Проверяем passenger_id на NULL
        IF v_ticket_info.passenger_id IS NULL THEN
            v_passenger_id_display := 'N/A';
        ELSE
            v_passenger_id_display := TO_CHAR(v_ticket_info.passenger_id);
        END IF;

        -- Вывод информации о билете
        DBMS_OUTPUT.PUT_LINE(
            'Deleting Ticket: ' ||
            'Ticket ID: ' || v_ticket_info.ticket_id || ', ' ||
            'Ticket Number: ' || v_ticket_info.ticket_number || ', ' ||
            'Seat Number: ' || v_ticket_info.seat_number || ', ' ||
            'Price: ' || v_ticket_info.price || ', ' ||
            'Class: ' || v_ticket_info.ticket_class || ', ' ||
            'Status: ' || v_ticket_info.ticket_status || ', ' ||
            'Passenger ID: ' || v_passenger_id_display
        );

        DELETE FROM Tickets WHERE ticket_id = v_ticket_info.ticket_id;
    END LOOP;

    -- Удаляем сам рейс
    DELETE FROM admin.Flights
    WHERE flight_id = p_flight_id;

    DBMS_OUTPUT.PUT_LINE('Flight with ID ' || p_flight_id || ' has been successfully deleted.');

    COMMIT; -- Подтверждаем изменения

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Unexpected error: ' || SQLERRM);
        ROLLBACK; -- Откатываем изменения в случае ошибки
        RAISE_APPLICATION_ERROR(-20004, 'Unexpected error occurred: ' || SQLERRM);
END sp_delete_flight;
/




CREATE OR REPLACE PROCEDURE sp_add_flight (
    p_departure_airport_id  IN NUMBER,    -- ID аэропорта вылета
    p_arrival_airport_id    IN NUMBER,    -- ID аэропорта прилета
    p_departure_time        IN VARCHAR2,  -- Время вылета в формате VARCHAR
    p_arrival_time          IN VARCHAR2,  -- Время прилета в формате VARCHAR
    p_flight_status         IN VARCHAR2,  -- Статус рейса (e.g., Scheduled, Delayed)
    p_airplane_id           IN NUMBER,    -- ID самолета
    p_airline_id            IN NUMBER     -- ID авиалинии
)
AUTHID DEFINER
IS
    v_departure_date          DATE;
    v_arrival_date            DATE;
    v_departure_airport_name  VARCHAR2(100);
    v_arrival_airport_name    VARCHAR2(100);
    v_airplane_model          VARCHAR2(100);
    v_airplane_manufacturer   VARCHAR2(100);
    v_airline_name            VARCHAR2(100);
    v_flight_id               NUMBER;
    v_flight_number           VARCHAR2(20);
BEGIN
    -- Проверяем, что аэропорт вылета и прилета не совпадают
    IF p_departure_airport_id = p_arrival_airport_id THEN
        DBMS_OUTPUT.PUT_LINE('Error: Departure and arrival airports cannot be the same.');
        RAISE_APPLICATION_ERROR(-20003, 'Departure and arrival airports cannot be the same.');
    END IF;

    -- Преобразуем время вылета и прилета в тип DATE
    BEGIN
        v_departure_date := TO_DATE(p_departure_time, 'YYYY-MM-DD HH24:MI');
        v_arrival_date := TO_DATE(p_arrival_time, 'YYYY-MM-DD HH24:MI');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: Invalid date format. Please use "YYYY-MM-DD HH24:MI".');
            RAISE_APPLICATION_ERROR(-20001, 'Invalid date format.');
    END;

    -- Проверяем, что время вылета больше текущего времени
    IF v_departure_date <= SYSDATE THEN
        DBMS_OUTPUT.PUT_LINE('Error: Departure time must be in the future.');
        RAISE_APPLICATION_ERROR(-20002, 'Departure time is in the past.');
    END IF;

    -- Получаем название аэропорта вылета
    BEGIN
        SELECT airport_name
        INTO v_departure_airport_name
        FROM admin.Airports
        WHERE airport_id = p_departure_airport_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Departure airport with ID ' || p_departure_airport_id || ' does not exist.');
            RAISE_APPLICATION_ERROR(-20004, 'Departure airport does not exist.');
    END;

    -- Получаем название аэропорта прилета
    BEGIN
        SELECT airport_name
        INTO v_arrival_airport_name
        FROM admin.Airports
        WHERE airport_id = p_arrival_airport_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Arrival airport with ID ' || p_arrival_airport_id || ' does not exist.');
            RAISE_APPLICATION_ERROR(-20005, 'Arrival airport does not exist.');
    END;

    -- Проверяем существование самолета
    BEGIN
        SELECT airplane_model, manufacturer
        INTO v_airplane_model, v_airplane_manufacturer
        FROM admin.Airplane_Types
        WHERE type_id = (SELECT type_id FROM Airplanes WHERE airplane_id = p_airplane_id);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Airplane with ID ' || p_airplane_id || ' does not exist.');
            RAISE_APPLICATION_ERROR(-20006, 'Airplane does not exist.');
    END;

    -- Проверяем существование авиалинии
    BEGIN
        SELECT airline_name
        INTO v_airline_name
        FROM admin.Airlines
        WHERE airline_id = p_airline_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Airline with ID ' || p_airline_id || ' does not exist.');
            RAISE_APPLICATION_ERROR(-20007, 'Airline does not exist.');
    END;

    -- Проверяем корректность времени вылета и прилета
    IF v_departure_date >= v_arrival_date THEN
        DBMS_OUTPUT.PUT_LINE('Error: Departure time must be earlier than arrival time.');
        RAISE_APPLICATION_ERROR(-20010, 'Invalid departure and arrival times.');
    END IF;

    -- Добавляем рейс и возвращаем сгенерированный ID рейса
    INSERT INTO admin.Flights (
        departure_airport_id,
        arrival_airport_id,
        departure_time,
        arrival_time,
        flight_status,
        airplane_id,
        airline_id
    ) VALUES (
        p_departure_airport_id,
        p_arrival_airport_id,
        v_departure_date,
        v_arrival_date,
        p_flight_status,
        p_airplane_id,
        p_airline_id
    )
    RETURNING flight_id INTO v_flight_id;

    -- Получаем номер рейса, если он генерируется автоматически
    BEGIN
        SELECT flight_number
        INTO v_flight_number
        FROM admin.Flights
        WHERE flight_id = v_flight_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Failed to retrieve flight number for flight ID ' || v_flight_id);
            RAISE_APPLICATION_ERROR(-20012, 'Failed to retrieve flight number.');
    END;

    -- Вывод информации о рейсе
    DBMS_OUTPUT.PUT_LINE('Flight has been successfully added:');
    DBMS_OUTPUT.PUT_LINE('Flight Number: ' || v_flight_number);
    DBMS_OUTPUT.PUT_LINE('Departure Airport: ' || v_departure_airport_name || ' (ID: ' || p_departure_airport_id || ')');
    DBMS_OUTPUT.PUT_LINE('Arrival Airport: ' || v_arrival_airport_name || ' (ID: ' || p_arrival_airport_id || ')');
    DBMS_OUTPUT.PUT_LINE('Departure Time: ' || TO_CHAR(v_departure_date, 'YYYY-MM-DD HH24:MI'));
    DBMS_OUTPUT.PUT_LINE('Arrival Time: ' || TO_CHAR(v_arrival_date, 'YYYY-MM-DD HH24:MI'));
    DBMS_OUTPUT.PUT_LINE('Status: ' || p_flight_status);
    DBMS_OUTPUT.PUT_LINE('Airplane ID: ' || p_airplane_id);
    DBMS_OUTPUT.PUT_LINE('Airplane Model: ' || v_airplane_model);
    DBMS_OUTPUT.PUT_LINE('Airplane Manufacturer: ' || v_airplane_manufacturer);
    DBMS_OUTPUT.PUT_LINE('Airline ID: ' || p_airline_id);
    DBMS_OUTPUT.PUT_LINE('Airline Name: ' || v_airline_name);

    -- Подтверждаем транзакцию
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Unexpected error: ' || SQLERRM);
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20011, 'Unexpected error occurred: ' || SQLERRM);
END sp_add_flight;
/




CREATE OR REPLACE PROCEDURE sp_update_flight ( 
    p_flight_id               IN NUMBER,        -- ID рейса
    p_new_departure_airport_id IN NUMBER DEFAULT NULL,     -- Новый ID аэропорта вылета
    p_new_arrival_airport_id   IN NUMBER DEFAULT NULL,     -- Новый ID аэропорта прилета
    p_new_departure_time      IN VARCHAR2 DEFAULT NULL,     -- Новое время вылета
    p_new_arrival_time        IN VARCHAR2 DEFAULT NULL      -- Новое время прилета
)
AUTHID DEFINER
IS
    -- Старые данные рейса
    v_flight_status           VARCHAR2(20);
    v_flight_number           VARCHAR2(20); 
    v_old_departure_airport_id    NUMBER;
    v_old_arrival_airport_id      NUMBER;
    v_old_departure_time          DATE;
    v_old_arrival_time            DATE;

    -- Новые значения
    v_new_departure_airport_id    NUMBER;
    v_new_arrival_airport_id      NUMBER;
    v_new_departure_time          DATE;
    v_new_arrival_time            DATE;

    -- Названия аэропортов
    v_old_departure_airport_name  VARCHAR2(100);
    v_old_arrival_airport_name    VARCHAR2(100);
    v_new_departure_airport_name  VARCHAR2(100);
    v_new_arrival_airport_name    VARCHAR2(100);
BEGIN
    -- Получаем текущие данные рейса
    BEGIN
        SELECT flight_status, flight_number, departure_airport_id, arrival_airport_id, departure_time, arrival_time
        INTO v_flight_status, v_flight_number, v_old_departure_airport_id, v_old_arrival_airport_id, v_old_departure_time, v_old_arrival_time
        FROM admin.Flights
        WHERE flight_id = p_flight_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Flight does not exist.');
    END;

    -- Получаем названия старых аэропортов
    SELECT airport_name INTO v_old_departure_airport_name FROM admin.Airports WHERE airport_id = v_old_departure_airport_id;
    SELECT airport_name INTO v_old_arrival_airport_name FROM admin.Airports WHERE airport_id = v_old_arrival_airport_id;

    -- Обрабатываем новые данные
    v_new_departure_airport_id := COALESCE(p_new_departure_airport_id, v_old_departure_airport_id);
    v_new_arrival_airport_id   := COALESCE(p_new_arrival_airport_id, v_old_arrival_airport_id);

    IF p_new_departure_time IS NOT NULL THEN
        v_new_departure_time := TO_DATE(p_new_departure_time, 'YYYY-MM-DD HH24:MI');
    ELSE
        v_new_departure_time := v_old_departure_time;
    END IF;

    IF p_new_arrival_time IS NOT NULL THEN
        v_new_arrival_time := TO_DATE(p_new_arrival_time, 'YYYY-MM-DD HH24:MI');
    ELSE
        v_new_arrival_time := v_old_arrival_time;
    END IF;

    -- Проверка на одинаковые аэропорты
    IF v_new_departure_airport_id = v_new_arrival_airport_id THEN
        RAISE_APPLICATION_ERROR(-20009, 'Departure and arrival airports cannot be the same.');
    END IF;

    -- Получаем названия новых аэропортов
    SELECT airport_name INTO v_new_departure_airport_name FROM admin.Airports WHERE airport_id = v_new_departure_airport_id;
    SELECT airport_name INTO v_new_arrival_airport_name FROM admin.Airports WHERE airport_id = v_new_arrival_airport_id;

    -- Обновляем рейс
    UPDATE admin.Flights
    SET departure_airport_id = v_new_departure_airport_id,
        arrival_airport_id   = v_new_arrival_airport_id,
        departure_time       = v_new_departure_time,
        arrival_time         = v_new_arrival_time
    WHERE flight_id = p_flight_id;

    -- Вывод старой информации о рейсе
    DBMS_OUTPUT.PUT_LINE('--- Old Flight Information ---');
    DBMS_OUTPUT.PUT_LINE('Flight Number: ' || v_flight_number);
    DBMS_OUTPUT.PUT_LINE('Flight ID: ' || p_flight_id);
    DBMS_OUTPUT.PUT_LINE('Old Departure Airport: ' || v_old_departure_airport_id || ' - ' || v_old_departure_airport_name);
    DBMS_OUTPUT.PUT_LINE('Old Arrival Airport: ' || v_old_arrival_airport_id || ' - ' || v_old_arrival_airport_name);
    DBMS_OUTPUT.PUT_LINE('Old Departure Time: ' || TO_CHAR(v_old_departure_time, 'YYYY-MM-DD HH24:MI'));
    DBMS_OUTPUT.PUT_LINE('Old Arrival Time: ' || TO_CHAR(v_old_arrival_time, 'YYYY-MM-DD HH24:MI'));

    -- Вывод новой информации о рейсе
    DBMS_OUTPUT.PUT_LINE('--- New Flight Information ---');
    DBMS_OUTPUT.PUT_LINE('Flight Number: ' || v_flight_number);
    DBMS_OUTPUT.PUT_LINE('Flight ID: ' || p_flight_id);
    DBMS_OUTPUT.PUT_LINE('New Departure Airport: ' || v_new_departure_airport_id || ' - ' || v_new_departure_airport_name);
    DBMS_OUTPUT.PUT_LINE('New Arrival Airport: ' || v_new_arrival_airport_id || ' - ' || v_new_arrival_airport_name);
    DBMS_OUTPUT.PUT_LINE('New Departure Time: ' || TO_CHAR(v_new_departure_time, 'YYYY-MM-DD HH24:MI'));
    DBMS_OUTPUT.PUT_LINE('New Arrival Time: ' || TO_CHAR(v_new_arrival_time, 'YYYY-MM-DD HH24:MI'));

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20008, 'Unexpected error occurred: ' || SQLERRM);
END sp_update_flight;
/






CREATE OR REPLACE PROCEDURE sp_view_airport_employees (
    p_airport_id IN NUMBER
) AUTHID DEFINER
AS
    v_airport_name NVARCHAR2(200);
    v_employee_count NUMBER;
BEGIN
    -- Проверяем, существует ли аэропорт с указанным ID
    BEGIN
        SELECT airport_name
        INTO v_airport_name
        FROM admin.Airports
        WHERE airport_id = p_airport_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Airport with the specified ID does not exist.');
    END;

    -- Считаем количество сотрудников, связанных с этим аэропортом
    SELECT COUNT(*)
    INTO v_employee_count
    FROM admin.Employee
    WHERE airport_id = p_airport_id;

    -- Если сотрудников нет, выводим сообщение
    IF v_employee_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No employees are associated with the airport: ' || v_airport_name);
    ELSE
        DBMS_OUTPUT.PUT_LINE('List of employees for the airport: ' || v_airport_name);

        -- Извлекаем и отображаем информацию о сотрудниках через представление Users_View
        FOR employee_rec IN (
            SELECT uv.firstname, uv.lastname, uv.email, uv.phone, e.job_title, e.hire_date, e.salary
            FROM admin.Employee e
            JOIN admin.Users_View uv ON e.user_id = uv.user_id
            WHERE e.airport_id = p_airport_id
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('-------------------------------------');
            DBMS_OUTPUT.PUT_LINE('Name: ' || employee_rec.firstname || ' ' || employee_rec.lastname);
            DBMS_OUTPUT.PUT_LINE('Email: ' || employee_rec.email);
            DBMS_OUTPUT.PUT_LINE('Phone: ' || employee_rec.phone);
            DBMS_OUTPUT.PUT_LINE('Job Title: ' || employee_rec.job_title);
            DBMS_OUTPUT.PUT_LINE('Hire Date: ' || TO_CHAR(employee_rec.hire_date, 'YYYY-MM-DD'));
            DBMS_OUTPUT.PUT_LINE('Salary: ' || employee_rec.salary || ' USD');
        END LOOP;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        RAISE;
END;
/


BEGIN
    admin.sp_view_airport_employees(p_airport_id => 1);
END;












