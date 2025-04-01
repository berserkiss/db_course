BEGIN
    admin.sp_view_airport_employees(p_airport_id => 2);
END;

BEGIN
    admin.sp_view_regular_users(3); 
END;
/


EXEC admin.SP_GET_FLIGHTS_AND_TICKETS_FOR_AIRPORT(1);


BEGIN
    admin.sp_add_flight(
        p_departure_airport_id => 2,
        p_arrival_airport_id   => 1,
        p_departure_time       => '2024-12-22 12:00',
        p_arrival_time         => '2024-12-26 17:30',
        p_flight_status        => 'Scheduled',
        p_airplane_id          => 1,
        p_airline_id           => 5
    );
END;
/

BEGIN
    admin.sp_update_flight(
        p_flight_id => 20,                 
        p_new_departure_airport_id => 4,  
        p_new_departure_time => '2025-01-03 08:10' 
    );
END;
/

BEGIN
    admin.sp_delete_flight(
        p_flight_id   => 10, 
        p_airport_id  => 1  
    );
END;
/

BEGIN
    admin.sp_add_ticket_for_airport_flight(
        p_flight_id => 25,           
        p_seat_number => '16F',       
        p_ticket_class => 'Economy',  
        p_price => 250,            
        p_airport_id => 1             
    );
END;
/


BEGIN
    admin.SP_EDIT_TICKET(
        p_ticket_id    => 20,            
        p_seat_number  => '12N',          
        p_ticket_class => 'Economy',     
        p_price        => NULL,            
        p_flight_id    => 20,            
        p_airport_id   => 2             
    );
END;
/

BEGIN
    admin.sp_delete_ticket(
        p_ticket_id => 40,     
        p_flight_id => 20,      
        p_airport_id => 2       
    );
END;
/


BEGIN
    admin.sp_analyze_tickets_and_routes(
        p_airport_id        => 3,
        p_period_start_str  => '2024-01-01 08:30',
        p_period_end_str    => '2024-12-19 18:50'
    );
END;
/

BEGIN
    admin.sp_analyze_routes(3); 
END;
/

BEGIN
    admin.sp_analyze_popular_routes(2); 
END;
/