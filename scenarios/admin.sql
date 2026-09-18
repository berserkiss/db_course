EXEC sp_get_all_users_decrypted;

BEGIN
    sp_get_all_employees_sorted_by_airport;
END;
/

BEGIN
    sp_add_employee_with_user(
        p_username        => 'exampleuser1',                    
        p_user_password   => 'pangelina361',          
        p_email           => 'exampleuser1@mail.ru',        
        p_passport_number => 'MC3063454',                  
        p_phone           => NULL,                       
        p_firstname       => 'Maria',                      
        p_lastname        => 'Sosnovets',                       
        p_birthdate       => '2005-03-26',                
        p_country         => NULL,                       
        p_city            => NULL,                        
        p_street          => NULL,               
        p_airport_id      => 5,                           
        p_job_title       => 'Manager',                     
        p_hire_date       => '2023-02-15',                
        p_salary          => 90000                        
    );
END;
/

BEGIN
    sp_add_employee_with_user(
        p_username        => 'exampleuser3',                    
        p_user_password   => 'pangelina363',          
        p_email           => 'exampleuser3@mail.ru',        
        p_passport_number => 'MC30634543',                  
        p_phone           => '5551234587',                       
        p_firstname       => 'Anna',                      
        p_lastname        => 'Puzyrova',                       
        p_birthdate       => '2005-03-26',                
        p_country         => 'Belarus',                       
        p_city            => 'Minsk',                        
        p_street          => 'Sverdlova',               
        p_airport_id      => 5,                           
        p_job_title       => 'Manager',                     
        p_hire_date       => '2023-02-15',                
        p_salary          => 90000                        
    );
END;
/


BEGIN
    sp_update_employee(
        p_employee_id    => 1,                  
        p_airport_id => 9,                    
        p_job_title  => 'Common Manager',       
        p_hire_date  => '2024-12-16',         
        p_salary     => 95000                 
    );
END;
/

BEGIN
    sp_delete_employee(p_employee_id => 1);
END;
/

BEGIN
    sp_add_user(
        p_username        => 'user11',
        p_user_password   => 'pass3w333343',
        p_email           => 'annaanna@example.com',
        p_passport_number => 'AB123337',
        p_phone           => '123456889',
        p_firstname       => 'John',
        p_lastname        => 'Doe',
        p_birthdate       => '1990-01-01',
        p_country         => NULL,
        p_city            => NULL,
        p_street          => NULL
    );
END;
/

BEGIN
    sp_delete_user(p_user_id => 22);
END;
/