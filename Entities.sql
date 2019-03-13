--Sequence Number Generation

CREATE SEQUENCE request_id_seq START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 999999 NOCACHE NOCYCLE;

CREATE SEQUENCE approval_id_seq START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 999999 NOCACHE NOCYCLE;

--Create Tables
CREATE TABLE leave_type (
    leave_type    CHAR(3) NOT NULL PRIMARY KEY,
    leave_level   NUMBER(2,0) NOT NULL,
    description   VARCHAR2(50) NOT NULL
);

CREATE TABLE job (
    job_id            CHAR(7) NOT NULL PRIMARY KEY,
    job_title         VARCHAR2(20) NOT NULL,
    leave_per_month   NUMBER(4,2) NOT NULL,
    hours_per_day     NUMBER(2,0) NOT NULL
);

CREATE TABLE holidays (
    holiday_id     NUMBER(3,0) NOT NULL PRIMARY KEY,
    holiday_name    VARCHAR2(40) NOT NULL,
    holiday_date   DATE NOT NULL
);

CREATE TABLE department (
    department_id     NUMBER(3,0) NOT NULL PRIMARY KEY,
    department_name   VARCHAR2(20) NOT NULL
);

CREATE TABLE location (
    location_id     NUMBER(3,0) NOT NULL PRIMARY KEY,
    location_name   VARCHAR2(20) NOT NULL,
    country         VARCHAR2(30) NOT NULL
);

CREATE TABLE employee (
    employee_id     NUMBER(6,0) NOT NULL PRIMARY KEY,
    first_name      VARCHAR2(20) NOT NULL,
    middle_name     VARCHAR2(20),
    last_name       VARCHAR2(20) NOT NULL,
    gender          CHAR(1) NOT NULL,
    hire_date       DATE NOT NULL,
    job_id          CHAR(7) NOT NULL,
    department_id   NUMBER(3,0) NOT NULL,
    manager_id      NUMBER(6,0) ,
    hr_id           NUMBER(6,0) NOT NULL ,
    date_of_birth   DATE NOT NULL,
    email           VARCHAR2(40) NOT NULL,
    phone_number    VARCHAR2(12) NOT NULL,
    address         VARCHAR2(20) NOT NULL,
    city            VARCHAR2(20) NOT NULL,
    state           VARCHAR2(20) NOT NULL,
    country         VARCHAR2(20) NOT NULL,
    CONSTRAINT fk_job_id FOREIGN KEY ( job_id )
        REFERENCES job ( job_id ),
    CONSTRAINT fk_dep_id FOREIGN KEY ( department_id )
        REFERENCES department ( department_id ),
    CONSTRAINT fk_mgr_id FOREIGN KEY ( manager_id )
        REFERENCES employee ( employee_id ),
    CONSTRAINT fk_hr_id FOREIGN KEY ( hr_id )
        REFERENCES employee ( employee_id )        
);

CREATE TABLE leave_request (
    request_id         NUMBER(6) NOT NULL PRIMARY KEY,
    employee_id        NUMBER(6) NOT NULL,
    request_date       DATE NOT NULL,
    from_date          DATE NOT NULL,
    TO_DATE            DATE NOT NULL,
    total_days         NUMBER(5) NOT NULL,
    leave_type         CHAR(3) NOT NULL,
    reason_for_leave   VARCHAR2(50) NOT NULL,
    comments           VARCHAR2(100),
    status             VARCHAR2(10) NOT NULL,
    manager_approval   VARCHAR2(10) NOT NULL,
    hr_approval        VARCHAR2(10) NOT NULL,
    CONSTRAINT leave_emp_fk FOREIGN KEY ( employee_id )
        REFERENCES employee ( employee_id ),
    CONSTRAINT leave_type_fk FOREIGN KEY ( leave_type )
        REFERENCES leave_type ( leave_type )
);

 CREATE TABLE approval (
    approval_id     NUMBER(6,0) NOT NULL PRIMARY KEY,
    request_id      NUMBER(6,0) NOT NULL,
    requested_by    NUMBER(6,0) NOT NULL,
    approval_by     NUMBER(6,0) NOT NULL,
    TOTAL_DAYS      number(6,0) not null,
    approval_date   DATE ,
    status          VARCHAR2(10) ,
    Send_email      CHAR(1),
    comments        VARCHAR2(50) ,
    CONSTRAINT fk_request_id FOREIGN KEY ( request_id )
        REFERENCES leave_request ( request_id )
);

CREATE TABLE payroll (
    employee_id    NUMBER(6,0) NOT NULL,
    month          VARCHAR2(10) NOT NULL,
    Salary_Deduction     CHAR(1) NOT NULL,
    CONSTRAINT fk_primary_key PRIMARY KEY ( employee_id,
                                            month ),
    CONSTRAINT fk_employ_payroll_id FOREIGN KEY ( employee_id )
        REFERENCES employee ( employee_id )
        
);  

CREATE TABLE ATTENDANCE (
    employee_id      NUMBER(6,0) NOT NULL,
    swipe_date       DATE NOT NULL,
    location_id      NUMBER(6,0) NOT NULL,
    swipe_in         TIMESTAMP NOT NULL,
    swipe_out        TIMESTAMP NOT NULL,
    overtime_hours   NUMBER(5,2) NOT NULL,
    CONSTRAINT fk_at_primary_key PRIMARY KEY (employee_id,swipe_date),
    CONSTRAINT fk_at_location FOREIGN KEY ( location_id )
        REFERENCES location ( location_id ),
    CONSTRAINT fk_at_employee FOREIGN KEY ( employee_id )
        REFERENCES employee ( employee_id )
);

CREATE VIEW LEAVE_BALANCE
AS
SELECT Employee_id,TotalEarnedLeave,TotalEarnedLeaveYTD,TotalAccruedLeave,TotalAccruedleaveYTD,OVERTIME_HOURS,
TotalEarnedLeave-TotalAccruedleave+OVERTIME_HOURS AS LEAVE_BALANCE FROM (
SELECT Employee_id,NVL((select sum(total_days)
    from leave_request where status = 'Approved' and employee_id=A.employee_id
    group by employee_id),0) AS TotalAccruedLeave,NVL((select sum(total_days)
    from leave_request where status = 'Approved' and employee_id=A.employee_id and request_date >= TRUNC(SYSDATE,'YY')
    group by employee_id),0) AS TotalAccruedleaveYTD,
   trunc(months_between(sysdate,A.hire_date) * B.leave_per_month) AS TotalEarnedLeave,
   trunc(months_between(sysdate, TRUNC(SYSDATE,'YY')) * B.leave_per_month) as TotalEarnedLeaveYTD
   ,NVL((SELECT SUM(OVERTIME_HOURS)/8 FROM ATTENDANCE WHERE EMPLOYEE_ID=A.EMPLOYEE_ID),0) AS OVERTIME_HOURS
FROM EMPLOYEE A,JOB B WHERE A.JOB_ID=B.JOB_ID); 

