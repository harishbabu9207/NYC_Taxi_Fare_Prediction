--Triggers
/
create or replace TRIGGER ATTENDANCE_TRG
  BEFORE INSERT ON ATTENDANCE
  FOR EACH ROW
  DECLARE 
  diff number;
  hrs number;
BEGIN

SELECT A.HOURS_PER_DAY INTO hrs FROM JOB A,EMPLOYEE B WHERE EMPLOYEE_ID=:NEW.EMPLOYEE_ID AND A.JOB_ID=B.JOB_ID;

SELECT TO_NUMBER(SUBSTR(:NEW.SWIPE_OUT - :NEW.SWIPE_IN,12,2))-hrs INTO diff FROM DUAL;

:NEW.OVERTIME_HOURS  := diff;

END;
/
create or replace trigger REQUEST_PK_TRG  
   before insert on LEAVE_REQUEST
   for each row 
begin  
   if inserting then 
      if :NEW."REQUEST_ID" is null then 
         select REQUEST_ID_SEQ.nextval into :NEW."REQUEST_ID" from dual; 
      end if; 
   end if; 
end;
/
create or replace TRIGGER REQUEST_TRG BEFORE
    INSERT ON leave_request
    FOR EACH ROW
DECLARE
    diff   NUMBER;
    holi   NUMBER;
    mgr varchar2(10);
    hr varchar2(10);
     mgr1 NUMBER;
    hr1 NUMBER;
    leave number;
begin
if inserting then
diff:=0;
holi:=0;
SELECT
    COUNT(*)
INTO diff
FROM
    (
        SELECT
            TO_CHAR(:new.from_date + (level - 1),'fmday') dt
        FROM
            dual
        CONNECT BY
            level <=:new.TO_DATE -:new.from_date + 1
    )
WHERE
    dt NOT IN (
        'saturday',
        'sunday'
    );

SELECT COUNT(*) into holi from HOLIDAYS WHERE HOLIDAY_DATE BETWEEN :NEW.TO_DATE and :NEW.FROM_DATE;
diff := diff - holi;
leave :=0;

SELECT trunc(months_between(sysdate,A.hire_date) * B.leave_per_month) - NVL((select sum(C.total_days)
    from approval C where C.status = 'Approved' and C.requested_by=A.employee_id and 
    not exists(SELECT 'X' FROM APPROVAL B WHERE B.REQUEST_ID=C.REQUEST_ID AND B.STATUS='Pending')
    group by c.requested_by),0) +NVL((SELECT SUM(OVERTIME_HOURS)/8 FROM ATTENDANCE WHERE EMPLOYEE_ID=A.EMPLOYEE_ID),0) INTO leave
FROM EMPLOYEE A,JOB B WHERE A.JOB_ID=B.JOB_ID AND A.EMPLOYEE_ID=:NEW.EMPLOYEE_ID;

if leave-diff>0 then

:new.total_days := diff;
:new.status :='Pending';
:new.request_date := sysdate;
SELECT DECODE(Leave_Level,'2','Pending','NA') into hr from LEAVE_TYPE WHERE LEAVE_TYPE =:NEW.LEAVE_TYPE;
:new.manager_approval :='Pending';
:new.hr_approval :=hr;
SELECT MANAGER_ID,HR_ID INTO mgr1,hr1 from employee where employee_id=:NEW.EMPLOYEE_ID;
if nvl(mgr1,hr1)=hr1 and :new.hr_Approval<>'NA' then
:New.manager_approval :='Skipped';
end if;
else
RAISE_APPLICATION_ERROR (-20000,'No Leave Balance'); 
end if;

END IF; 
end;
/
create or replace TRIGGER REQUEST_TRG1
  AFTER INSERT ON LEAVE_REQUEST
  FOR EACH ROW
  declare 
  hr number; 
  mgr number;
BEGIN
SELECT MANAGER_ID,HR_ID INTO mgr,hr from employee where employee_id=:NEW.EMPLOYEE_ID;
IF :New.manager_approval <>'Skipped' THEN
INSERT INTO approval (REQUEST_ID,REQUESTED_BY,APPROVAL_BY,TOTAL_DAYS,STATUS)
VALUES (:NEW.REQUEST_ID,:NEW.EMPLOYEE_ID, nvl(mgr,hr),:new.TOTAL_DAYS,'Pending');
end if;
if :new.hr_Approval='Pending' then
INSERT INTO approval (REQUEST_ID,REQUESTED_BY,APPROVAL_BY,TOTAL_DAYS,STATUS)
VALUES (:NEW.REQUEST_ID,:NEW.EMPLOYEE_ID,hr,:new.TOTAL_DAYS,'Pending');
end if;
END;
/
create or replace trigger APR_SEQ_TRG  
   before insert on APPROVAL
   for each row 
begin  
   if inserting then 
      if :NEW."APPROVAL_ID" is null then 
         select APPROVAL_ID_SEQ.nextval into :NEW."APPROVAL_ID" from dual; 
      end if; 
   end if; 
end;
/
create or replace TRIGGER apr_trg BEFORE
    UPDATE ON APPROVAL
    FOR EACH ROW
DECLARE
    exist   CHAR(1);
BEGIN
IF  (:NEW.STATUS ='Approved' or  :NEW.STATUS ='Rejected') then
 :NEW.APPROVAL_DATE:=SYSDATE;
  :NEW.SEND_EMAIL:='Y';
end if;
    SELECT DISTINCT
        'X'
    INTO exist
    FROM
        leave_request a,
        employee b
    WHERE
        a.employee_id = b.employee_id
        and a.employee_id<>:old.approval_by
        AND b.hr_id =:old.approval_by
        AND a.request_id =:new.request_id
        AND a.manager_approval = 'Pending' AND A.HR_APPROVAL='Pending';
    IF exist = 'X' THEN
        raise_application_error(-20000,'Manager Approval Pending');
    END IF;
EXCEPTION
    WHEN no_data_found THEN
        dbms_output.put_line('1');
END;
/
create or replace TRIGGER APPROVAL_TRG
  AFTER UPDATE ON APPROVAL
  FOR EACH ROW
BEGIN
UPDATE LEAVE_REQUEST A SET A.HR_APPROVAL=:NEW.STATUS
WHERE REQUEST_ID=:NEW.REQUEST_ID and A.HR_APPROVAL='Pending' AND A.MANAGER_APPROVAL in('Approved','Skipped') ;
UPDATE LEAVE_REQUEST A SET A.MANAGER_APPROVAL=:NEW.STATUS
WHERE REQUEST_ID=:NEW.REQUEST_ID and A.MANAGER_APPROVAL='Pending';
UPDATE LEAVE_REQUEST SET STATUS='Approved' where MANAGER_APPROVAL in('Approved','Skipped')
AND HR_APPROVAL in('Approved','NA');
UPDATE LEAVE_REQUEST SET STATUS='Rejected' where (MANAGER_APPROVAL='Rejected' OR HR_APPROVAL in('Rejected'));
INSERT INTO PAYROLL 
SELECT A.EMPLOYEE_ID,to_char(sysdate,'YYYY-Mon'),'Y' from leave_request A where A.REQUEST_ID=:NEW.REQUEST_ID and 
A.leave_type IN('SBA','LOA') AND A.STATUS='Approved' 
AND NOT EXISTS(SELECT 'X' FROM PAYROLL C WHERE C.EMPLOYEE_ID=A.EMPLOYEE_ID AND C.MONTH=to_char(sysdate,'YYYY-Mon'));
END;
/