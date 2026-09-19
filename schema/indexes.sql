-- Indexes.
--
-- Oracle creates an index for a primary key and for a unique constraint on
-- its own. It does NOT create one for a foreign key, and that omission
-- costs twice:
--
--   1. Locking. Deleting or updating a key in a parent table takes a share
--      lock on the whole child table while Oracle checks for orphans, for
--      as long as the statement runs. With an index on the child's foreign
--      key column it looks up the affected rows instead. Delete one airport
--      here and, without these, Flights and Airlines are both locked.
--   2. Joins. Every procedure in this project joins Flights to Airports, to
--      Airlines and to Airplanes on exactly these columns.
--
-- Run after schema/roles_users_tables.sql.

-- Employee
CREATE INDEX idx_employee_user_id ON Employee (user_id);
CREATE INDEX idx_employee_airport_id ON Employee (airport_id);

-- Airlines
CREATE INDEX idx_airlines_base_airport_id ON Airlines (base_airport_id);

-- Airplanes
CREATE INDEX idx_airplanes_type_id ON Airplanes (type_id);
CREATE INDEX idx_airplanes_airline_id ON Airplanes (airline_id);

-- Flights. Departure and arrival are separate foreign keys to the same
-- table, so they need an index each; one on the pair would only serve
-- lookups that lead with departure.
CREATE INDEX idx_flights_departure_airport_id ON Flights (departure_airport_id);
CREATE INDEX idx_flights_arrival_airport_id ON Flights (arrival_airport_id);
CREATE INDEX idx_flights_airline_id ON Flights (airline_id);
CREATE INDEX idx_flights_airplane_id ON Flights (airplane_id);

-- Tickets
CREATE INDEX idx_tickets_flight_id ON Tickets (flight_id);
CREATE INDEX idx_tickets_passenger_id ON Tickets (passenger_id);

-- Not a foreign key, but in the predicate of every flight search:
-- sp_user_search_available_flights always filters on departure_time >
-- SYSDATE and often on a range within one day.
CREATE INDEX idx_flights_departure_time ON Flights (departure_time);
