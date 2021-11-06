-- Create a procedure that will provide the average salary of all employees.
DELIMITER $$
CREATE PROCEDURE avg_salary()
BEGIN
SELECT
AVG(salary)
FROM
salaries;
END$$
DELIMITER ;

CALL employees.avg_salary;

-- Create a procedure called ‘emp_info’ that uses as parameters the first and the last name of an individual, and returns their employee number.
DELIMITER $$
DROP PROCEDURE IF exists emp_info;
CREATE PROCEDURE emp_info(in p_first_name varchar(255), in p_last_name varchar(255), out p_emp_no integer)

BEGIN
SELECT
e.emp_no
INTO p_emp_no FROM
employees e
WHERE
e.first_name = p_first_name
AND e.last_name = p_last_name;
END$$

DELIMITER ;

-- Create a function called ‘emp_info’ that takes for parameters the first and last name of an employee, and returns the salary from the newest contract of that employee.
DELIMITER $$


DROP FUNCTION IF exists emp_info;
CREATE FUNCTION emp_info(p_first_name varchar(255), p_last_name varchar(255)) RETURNS decimal(10,2)

DETERMINISTIC NO SQL READS SQL DATA

BEGIN
 DECLARE v_max_from_date date;
    DECLARE v_salary decimal(10,2);
SELECT
    MAX(from_date)

INTO v_max_from_date FROM

    employees e

        JOIN

    salaries s ON e.emp_no = s.emp_no

WHERE

    e.first_name = p_first_name

        AND e.last_name = p_last_name;
SELECT

    s.salary

INTO v_salary FROM

    employees e

        JOIN

    salaries s ON e.emp_no = s.emp_no

WHERE

    e.first_name = p_first_name

        AND e.last_name = p_last_name

        AND s.from_date = v_max_from_date;
                RETURN v_salary;

END$$

DELIMITER ;

-- Join some table (employee, salary, department) to find average salary per department

select
d. dept_name, AVG(salary)
FROM
departments d
JOIN 
dept_manager dm ON d.dept_no = dm.dept_no
JOIN
salaries s ON dm.emp_no = s.emp_no
GROUP BY dept_name;

-- catatan rut: Misal mau cari nama managernya siapa, berarti kan mau nomer emp di dept_manager trus dihubungin Namanya(first dan last) di data employees(data semua karyawan termasuk manajer) pakek subquery

SELECT
e.first_name, e.last_name
FROM
employees e
WHERE
e.emp_no IN(
SELECT
dm.emp_no
FROM
dept_manager dm);

-- Extract the information about all department managers who were hired between the 1st of January 1990 and the 1st of January 2020.
SELECT 
    *
FROM
    dept_manager
WHERE
    emp_no IN (SELECT 
            emp_no
        FROM
            employees
        WHERE
            hire_date BETWEEN '1990-01-01' AND '2020-01-01');


-- Update employee table with a sign employee number 110022 as a manager to all employees from 10001 to 10020 or from one to 20 for brief. And employee number 110039 as a manager to all employees from 21 to 40 using subquery
SELECT 
    A.*
FROM
    (SELECT 
        e.emp_no AS employee_ID,
            MIN(de.dept_no) AS department_ID,
            (SELECT 
                    emp_no
                FROM
                    dept_manager
                WHERE
                    emp_no = '110022') AS manager_ID
    FROM
        employees e
    JOIN dept_emp de ON e.emp_no = de.emp_no
    WHERE
        e.emp_no <= 10020
    GROUP BY e.emp_no
    ORDER BY e.emp_no) AS A 
UNION SELECT 
    B.*
FROM
    (SELECT 
        e.emp_no AS employee_ID,
            MIN(de.dept_no) AS department_ID,
            (SELECT 
                    emp_no
                FROM
                    dept_manager
                WHERE
                    emp_no = '110039') AS manager_ID
    FROM
        employees e
    JOIN dept_emp de ON e.emp_no = de.emp_no
    WHERE
        e.emp_no BETWEEN 10021 AND 10040
    GROUP BY e.emp_no
    ORDER BY e.emp_no) AS B;
 /* a new employee has been promoted to a manager 
➢ annual salary should immediately become 20,000 dollars higher than the highest annual salary they’d ever earned until that moment 
➢ a new record in the “department manager” table 
➢ create a trigger that will apply several modifications to the “salaries” table once the relevant record in the “department manager” table has been inserted: 
• make sure that the end date of the previously highest salary contract of that employee is the one from the execution of the insert statement 
• insert a new record in the “salaries” table about the same employee that reflects their next contract as a manager
*/

CREATE TRIGGER trig_hire_date  
BEFORE INSERT ON employees
FOR EACH ROW  

BEGIN  

IF NEW.hire_date > date_format(sysdate(), '%Y-%m-%d') THEN     
SET NEW.hire_date = date_format(sysdate(), '%Y-%m-%d');    
END IF;  
END $$  

DELIMITER ;  

INSERT employees VALUES ('999904', '1970-01-31', 'John', 'Johnson', 'M', '2025-01-01');  

SELECT  
    *  
FROM  

    employees

ORDER BY emp_no DESC;

-- a breakdown between the male and female employees working in the company each year starting from 1990
SELECT
year(de.from_date) AS calendar_year, e.gender, COUNT(e.emp_no) AS num_of_employees

FROM
t_dept_emp de
JOIN
t_employees e ON de.emp_no = e.emp_no
WHERE
year(from_date) >= '1990'
GROUP BY
calendar_year, gender
ORDER BY calendar_year; 

select count(emp_no)
from t_employees;

-- the number of male managers to the number of female managers from different departments for each year, starting from 1990 

SELECT 
    d.dept_name,
    ee.gender,
    dm.emp_no,
    dm.from_date,
    dm.to_date,
    e.calendar_year,
    CASE
        WHEN YEAR(dm.to_date) >= e.calendar_year AND YEAR(dm.from_date) <= e.calendar_year THEN 1
        ELSE 0
    END AS active
FROM
    (SELECT 
        YEAR(hire_date) AS calendar_year
    FROM
        t_employees
    GROUP BY calendar_year) e
        CROSS JOIN
    t_dept_manager dm
        JOIN
    t_departments d ON dm.dept_no = d.dept_no
        JOIN 
    t_employees ee ON dm.emp_no = ee.emp_no
ORDER BY dm.emp_no, calendar_year;
 -- the average salary of female versus male employees in the entire company until year 2020
 
 SELECT 
    e.gender,
    d.dept_name,
    ROUND(AVG(s.salary), 2) AS salary,
    YEAR(s.from_date) AS calendar_year
FROM
    t_salaries s
        JOIN
    t_employees e ON s.emp_no = e.emp_no
        JOIN
    t_dept_emp de ON de.emp_no = e.emp_no
        JOIN
    t_departments d ON d.dept_no = de.dept_no
GROUP BY d.dept_no , e.gender , calendar_year
HAVING calendar_year <= 2020
ORDER BY d.dept_no;

-- stored procedure to obtain the average male and female salary per department within a certain salary range. This range be defined by two values the user can insert when calling the procedure
DROP PROCEDURE IF EXISTS filter_salary;
DELIMITER $$
CREATE PROCEDURE filter_salary (IN p_min_salary FLOAT, IN p_max_salary FLOAT)
BEGIN
SELECT 
    e.gender, d.dept_name, AVG(s.salary) as avg_salary
FROM
    t_salaries s
        JOIN
    t_employees e ON s.emp_no = e.emp_no
        JOIN
    t_dept_emp de ON de.emp_no = e.emp_no
        JOIN
    t_departments d ON d.dept_no = de.dept_no
    WHERE s.salary BETWEEN p_min_salary AND p_max_salary
GROUP BY d.dept_no, e.gender;
END$$

DELIMITER ;

CALL filter_salary(50000, 90000);


