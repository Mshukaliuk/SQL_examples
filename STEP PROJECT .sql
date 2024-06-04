/* STEP PROJECT */

/* Запити
/* 1. Покажіть середню зарплату співробітників за кожен рік, до 2005 року.*/

USE employees;

SELECT 
  DISTINCT(YEAR(from_date)) AS year,
  AVG(salary) OVER (PARTITION BY YEAR(from_date)) AS avg_salary
FROM salaries
WHERE YEAR(from_date) < 2005;

/* 2. Покажіть середню зарплату співробітників по кожному відділу. Примітка: потрібно розрахувати по поточній зарплаті, та поточному відділу співробітників*/

-- OPTION 1

SET @cur = CURDATE();

SELECT
DISTINCT(Department) AS Department,
AVG(Salary) OVER (PARTITION BY Department) AS Avg_salary
FROM (
		SELECT
		d.dept_no AS Department,
		s.emp_no,
		s.salary AS Salary

		FROM salaries as s
		LEFT JOIN dept_emp AS d ON (s.emp_no=d.emp_no)
		WHERE @cur BETWEEN s.from_date AND s.to_date) AS t1
;

-- OPTION 2

WITH 
Cur_salary_emp_by_dep (Department,emp_no, Salary) 
AS 
	 ( 
     SELECT
		d.dept_no AS Department,
		s.emp_no,
		s.salary AS Salary

		FROM salaries as s
		LEFT JOIN dept_emp AS d ON (s.emp_no=d.emp_no)
		WHERE @cur BETWEEN s.from_date AND s.to_date
        )
SELECT
DISTINCT(Department) AS Department,
AVG(Salary) OVER (PARTITION BY Department) AS Avg_salary
FROM Cur_salary_emp_by_dep
;

/* 3. Покажіть середню зарплату співробітників по кожному відділу за кожний рік*/

-- OPTION 1

SET @cur = CURDATE();

SELECT
DISTINCT(Department) AS Department,
Year,
AVG(Salary) OVER (PARTITION BY Department, Year) AS Avg_salary
FROM (
		SELECT
		d.dept_no AS Department,
		s.emp_no,
		s.salary AS Salary,
        YEAR(s.from_date) AS Year
		FROM salaries as s
		LEFT JOIN dept_emp AS d ON (s.emp_no=d.emp_no) 
        )AS t1
;

-- OPTION 2 (not optimal, just for fun)

WITH Cur_salary_emp_by_dep (Department, emp_no, Salary)
AS
(
    SELECT
	d.dept_no AS Department,
	s.emp_no,
	s.salary AS Salary
    FROM salaries as s
    LEFT JOIN dept_emp AS d ON (s.emp_no = d.emp_no)
)
	SELECT
	DISTINCT(Department) AS Department,
	Avg_salary
	FROM (
			SELECT
				Department,
				AVG(Salary) OVER (PARTITION BY Department) AS Avg_salary
			FROM Cur_salary_emp_by_dep) AS t2
			;

/* 4. Покажіть відділи в яких зараз працює більше 15000 співробітників.*/

-- OPTION 1 (0.588 sec / 0.0000091 sec)

SET @cur = CURDATE();

SELECT
dept_no,
COUNT(emp_no)
FROM dept_emp
WHERE @cur BETWEEN from_date AND to_date
GROUP BY 1
HAVING COUNT(emp_no)>15000
;

-- OPTION 2 More optimal (0.386 sec / 0.0000060 sec)

WITH EmpCountByDept AS (
  SELECT
    dept_no,
    COUNT(emp_no) OVER (PARTITION BY dept_no) as count_emp_by_dep
  FROM dept_emp
  WHERE @cur BETWEEN from_date AND to_date
)

SELECT DISTINCT dept_no, count_emp_by_dep
FROM EmpCountByDept
WHERE count_emp_by_dep > 15000;
;

/* 5. Для менеджера який працює найдовше покажіть його номер, відділ, дату прийому на роботу, прізвище*/

SELECT
Dep_no, dd.dept_name AS Dep_name, Emp_no, Name, Surname, Hire_date

FROM (
SELECT
ee.first_name AS Name,
ee.last_name AS Surname,
ee.hire_date AS Hire_date, 
dm.emp_no AS Emp_no,
dm.dept_no AS Dep_no,

TIMESTAMPDIFF(DAY, dm.from_date, dm.to_date) AS expirience
FROM dept_manager AS dm
LEFT JOIN  employees AS ee ON(dm.emp_no=ee.emp_no)
ORDER BY expirience DESC
LIMIT 1) AS t

LEFT JOIN departments AS dd ON(t.Dep_no=dd.dept_no)
;

/* 6. Покажіть топ-10 діючих співробітників компанії з найбільшою різницею між їх зарплатою і середньою зарплатою в їх відділі.*/

SET @cur = CURDATE();

WITH 
Av_salary_by_departments (Department, Avg_salary) 
AS 
	 ( 
		SELECT
		DISTINCT(Department) AS Department,
		AVG(Salary) OVER (PARTITION BY Department) AS Avg_salary
		FROM (
				SELECT
				d.dept_no AS Department,
				s.emp_no,
				s.salary AS Salary

				FROM salaries as s
				LEFT JOIN dept_emp AS d ON (s.emp_no=d.emp_no)
				WHERE @cur BETWEEN s.from_date AND s.to_date) AS t1
	)
    ,
    Av_salary_by_emp (Department, Emp_salary, emp_no) 
AS 
	 ( 
		SELECT
		DISTINCT(Department) AS Department,
		Salary AS Emp_salary,
        emp_no
		FROM (
				SELECT
				d.dept_no AS Department,
				s.emp_no,
				s.salary AS Salary

				FROM salaries as s
				LEFT JOIN dept_emp AS d ON (s.emp_no=d.emp_no)
				WHERE @cur BETWEEN s.from_date AND s.to_date) AS t2
	)    
    
SELECT
e.emp_no,
d.Department, 
d.Avg_salary,
e.Emp_salary,  
ABS(d.Avg_salary-e.Emp_salary) AS Diff_sal

FROM Av_salary_by_departments AS d
LEFT JOIN Av_salary_by_emp AS e ON (d.Department=e.Department)
ORDER BY Diff_sal DESC
LIMIT 10
    ;

/* 7. Для кожного відділу покажіть другого по порядку менеджера. Необхідно вивести відділ, прізвище ім’я менеджера, дату прийому на роботу менеджера і дату коли він став менеджером відділу*/

SELECT
dept_no,
first_name,
last_name,
hire_date,
from_date AS Man_start_day

FROM (
			SELECT
			emp_no,
			dept_no,
			from_date,
			to_date,
			RANK()  OVER (PARTITION BY dept_no ORDER BY EXTRACT(YEAR FROM from_date)) AS Man_Rank
			FROM  dept_manager
		) AS t1
        
INNER JOIN employees AS e ON (t1.emp_no=e.emp_no)
WHERE Man_Rank = 2
;

/* Дизайн бази даних:*/

/* 1. Створіть базу даних для управління курсами. База має включати наступні таблиці:
- students: student_no, teacher_no, course_no, student_name, email, birth_date.
- teachers: teacher_no, teacher_name, phone_no
- courses: course_no, course_name, start_date, end_date */

/* Planning stage
3 students: student_no (PRIMARY KEY), teacher_no (FOREIGN KEY), course_no (FOREIGN KEY), student_name, email, birth_date.
1 teachers: teacher_no (PRIMARY KEY), teacher_name, phone_no
2 courses: course_no (PRIMARY KEY), course_name, start_date, end_date */


CREATE DATABASE IF NOT EXISTS School_db;
USE School_db;

CREATE TABLE IF NOT EXISTS teachers (
    teacher_no INT AUTO_INCREMENT, 
    teacher_name VARCHAR(255) NOT NULL, 
    phone_no VARCHAR(255), 
    PRIMARY KEY(teacher_no)
    );

CREATE TABLE IF NOT EXISTS courses (
    course_no INT AUTO_INCREMENT, 
    course_name VARCHAR(255) NOT NULL, 
    start_date DATE, 
    end_date DATE,
    PRIMARY KEY(course_no)
    );

CREATE TABLE IF NOT EXISTS students (
	student_no INT, 
    teacher_no INT, 
    course_no INT, 
    student_name VARCHAR(255) NOT NULL, 
    email VARCHAR(255), 
    birth_date DATE,
    FOREIGN KEY (teacher_no) REFERENCES teachers (teacher_no),
    FOREIGN KEY (course_no) REFERENCES courses (course_no)
    );
SHOW TABLES;

/* 2. Додайте будь-які данні (7-10 рядків) в кожну таблицю.*/
START TRANSACTION;

INSERT INTO teachers(teacher_no, teacher_name, phone_no)
VALUES
(1001,'Anna K.', '8-065-278-35-53');

INSERT INTO teachers(teacher_name, phone_no)
VALUES
('Olga T.', '8-061-345-11-23'),
('Olexands P.', '8-055-452-34-89'),
('Anton S.', '8-044-211-56-76'),
('Serhiy S.', '8-68-368-09-30'),
('Petro P.', '8-011-029-30-40'),
('Maria T.', '8-026-938-44-71'),
('Nazar A.', '8-081-244-73-00')
;

INSERT INTO courses(course_name, start_date, end_date)
VALUES
('SQL', '2022-02-01', DATE_ADD(start_date, INTERVAL 5 MONTH)),
('English', '2022-02-01', DATE_ADD(start_date, INTERVAL 3 MONTH)),
('Spanish', '2022-02-01', DATE_ADD(start_date, INTERVAL 12 MONTH)),
('Python', '2022-02-01', DATE_ADD(start_date, INTERVAL 1 YEAR)),
('Math', '2022-02-01', DATE_ADD(start_date, INTERVAL 5 YEAR)),
('Statistic', '2022-02-01', DATE_ADD(start_date, INTERVAL 13 MONTH)),
('Art','2022-02-01', DATE_ADD(start_date, INTERVAL 3 YEAR))
;

INSERT INTO students(student_no, teacher_no, course_no, student_name, email, birth_date)
VALUES
(2001, 1001, 15, 'Inna T.', 'InnaT@gmail.com', '1953-09-02'),
(2002, 1001, 15, 'Olga N.', 'OlgaN@gmail.com', '1953-09-02'),
(2003, 1003, 18, 'Olena S.', 'OlenaS@gmail.com', '1953-09-02'),
(2004, 1003, 18, 'Petro D.', 'PetroD@gmail.com', '1953-09-02'),
(2005, 1001, 15, 'Petro P.', 'PetroP@gmail.com', '1953-09-02'),
(2006, 1005, 19, 'Nazar A.', 'NazarA@gmail.com', '1953-09-02'),
(2007, 1005, 19, 'Serhiy S.', 'SerhiyS@gmail.com', '1953-09-02'),
(2008, 1001, 15, 'Olga T.', 'OlgaT@gmail.com', '1953-09-02'),
(2009, 1007, 20, 'Anna K.', 'AnnaK@gmail.com', '1953-09-02'),
(2010, 1007, 20, 'Alex T.', 'AlexT@gmail.com', '1953-09-02')
;

SELECT * FROM students;
SELECT * FROM courses;
SELECT * FROM teachers;

COMMIT; # ROLLBACK/COMMIT;

/* 3. По кожному викладачу покажіть кількість студентів з якими він працював */

SELECT 
t.teacher_name AS Teacher,
COUNT(s.student_no) AS Num_of_students
FROM students AS s
LEFT JOIN teachers AS t ON(s.teacher_no=t.teacher_no)
GROUP BY Teacher
;

/* 4. Спеціально зробіть 3 дубляжі в таблиці students (додайте ще 3 однакові рядки) */

-- OPTION 1

INSERT INTO students(student_no, teacher_no, course_no, student_name, email, birth_date)
VALUES
(2001, 1001, 15, 'Inna T.', 'InnaT@gmail.com', '1953-09-02'),
(2001, 1001, 15, 'Inna T.', 'InnaT@gmail.com', '1953-09-02'),
(2001, 1001, 15, 'Inna T.', 'InnaT@gmail.com', '1953-09-02');

-- OPTION 2

INSERT INTO students (student_no, teacher_no, course_no, student_name, email, birth_date)
SELECT student_no, teacher_no, course_no, student_name, email, birth_date
FROM students
WHERE student_no=2001;

/* 5. Напишіть запит який виведе дублюючі рядки в таблиці students. */

SELECT *, COUNT(student_no) as duplicate_count
FROM students
GROUP BY 1,2,3,4,5,6
HAVING duplicate_count > 1;