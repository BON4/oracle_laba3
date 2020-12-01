--Laba 3

--№1
select * from JOB_HISTORY;

select * from JOBS;
select * from EMPLOYEES;
rollback;
--Create hon contracts

create or replace package honorary_employees as
  procedure create_honor_jobs(old_job_id varchar2);

  procedure prepare_give_honor_contract(v_employee_id EMPlOYEES.EMPLOYEE_ID%type,
                                start_cont_date JOB_HISTORY.START_DATE%type,
                                end_cont_date JOB_HISTORY.END_DATE%type);

  procedure update_honor_contract(v_employee_id EMPlOYEES.EMPLOYEE_ID%type,
                                v_employee_job_id EMPlOYEES.JOB_ID%type,
                                start_cont_date JOB_HISTORY.START_DATE%type,
                                end_cont_date JOB_HISTORY.END_DATE%type);

  procedure create_honor_contract(v_employee_id EMPlOYEES.EMPLOYEE_ID%type,
                                start_cont_date JOB_HISTORY.START_DATE%type,
                                end_cont_date JOB_HISTORY.END_DATE%type);
end honorary_employees;

create or replace package body honorary_employees is
  --Accept old_job_id and new_job_id with "HON_" sufix and add to JOBS table
  procedure create_honor_jobs(old_job_id varchar2) as
    v_column_exists number := 0;
    v_job_exist number := 0;
    new_job JOBS%ROWTYPE;
    exc_HonorName EXCEPTION;
    exc_JobNotExist exception;
    new_job_id varchar2(50);
    begin
      Select count(*) into v_job_exist
        from JOBS j
        where j.JOB_ID = old_job_id;

      if v_job_exist != 0 then
        if instr(old_job_id, 'HON_') = 0 then
          new_job_id := 'HON_' || old_job_id;
          Select count(*) into v_column_exists
          from JOBS j
          where j.JOB_ID = new_job_id;

          if v_column_exists = 0 then
            select * into new_job from JOBS where JOB_ID = old_job_id;
            insert into JOBS j values (new_job_id,
                                        'Honorary ' || new_job.JOB_TITLE,
                                        new_job.MIN_SALARY+(new_job.MIN_SALARY/100)*15,
                                        new_job.MAX_SALARY+(new_job.MAX_SALARY/100)*15);
	    commit;
          end if;
        else raise exc_HonorName;
        end if;
      else raise exc_JobNotExist;
      end if;
      exception
      when exc_HonorName then raise_application_error(-20000, 'Honorary job contracts can not be created as "honorary"');
      when exc_JobNotExist then raise_application_error(-20000, 'Given job does not exist');
    end;

  --Separate create and update honor procedures, the main procedure
  procedure prepare_give_honor_contract(v_employee_id EMPlOYEES.EMPLOYEE_ID%type,
                                start_cont_date JOB_HISTORY.START_DATE%type,
                                end_cont_date JOB_HISTORY.END_DATE%type) as
    v_count_Emp_Contracts numeric := 0;
    begin
      --Count how many contracts employee have
      Select count(*) into v_count_Emp_Contracts
        from JOB_HISTORY j
        where j.EMPLOYEE_ID = v_employee_id;

      if v_count_Emp_Contracts > 0 then
        --If some employee have many contracts we should update them all
        for v_curs in (select * from JOB_HISTORY j where j.EMPLOYEE_ID = v_employee_id) loop
          update_honor_contract(v_employee_id,v_curs.JOB_ID , start_cont_date, end_cont_date);
        end loop;
      elsif v_count_Emp_Contracts = 0 then
        --If he have nothing we should create one for him
        create_honor_contract(v_employee_id, start_cont_date, end_cont_date);
      end if;
    end;

  --Create contract
  procedure create_honor_contract(v_employee_id EMPlOYEES.EMPLOYEE_ID%type,
                                start_cont_date JOB_HISTORY.START_DATE%type,
                                end_cont_date JOB_HISTORY.END_DATE%type) as

    v_employee_job_id EMPLOYEES.JOB_ID%type;
    v_employee_department DEPARTMENTS.DEPARTMENT_ID%TYPE;
    v_employee_new_job EMPLOYEES.JOB_ID%TYPE;
    v_emp_comm_pct EMPLOYEES.COMMISSION_PCT%type;

    exc_Emp_NoContract EXCEPTION;
    begin
      --Take old job_id to create new one
        select JOB_ID into v_employee_job_id from EMPLOYEES e where e.EMPLOYEE_ID = v_employee_id;
        --If employee does not have contract we have to know from what department he is
        select DEPARTMENT_ID into v_employee_department from EMPLOYEES e where e.EMPLOYEE_ID = v_employee_id;
        --Create new Honorary contract in JOBS
        create_honor_jobs(v_employee_job_id);
        v_employee_new_job := 'HON_' || v_employee_job_id;

        insert into JOB_HISTORY values (v_employee_id,
                                        start_cont_date, end_cont_date, v_employee_new_job,
                                        v_employee_department);

        --Now we need to change JOB_ID in employees table
        update EMPLOYEES set JOB_ID = v_employee_new_job where EMPLOYEE_ID = v_employee_id;
        --Set new commission pact
        select COMMISSION_PCT into v_emp_comm_pct from EMPLOYEES where EMPLOYEE_ID = v_employee_id;
        if v_emp_comm_pct is null then
          update EMPLOYEES set COMMISSION_PCT = 0.2 where EMPLOYEE_ID = v_employee_id;
        else
          if v_emp_comm_pct < 0.2 then
            update EMPLOYEES set COMMISSION_PCT = 0.2 where EMPLOYEE_ID = v_employee_id;
          end if;
        end if;
    end;

  --Update already ageist contract to Honorary
  procedure update_honor_contract(v_employee_id EMPlOYEES.EMPLOYEE_ID%type,
                                v_employee_job_id EMPlOYEES.JOB_ID%type,
                                start_cont_date JOB_HISTORY.START_DATE%type,
                                end_cont_date JOB_HISTORY.END_DATE%type) as
    v_employee_new_job EMPLOYEES.JOB_ID%TYPE;
    v_employee_old_contract JOB_HISTORY%ROWTYPE;
    v_emp_comm_pct EMPLOYEES.COMMISSION_PCT%type;

    exc_Emp_NoContract EXCEPTION;
    begin
        --Create new Honorary contract in JOBS based on old employee contract
        select * into v_employee_old_contract from JOB_HISTORY where EMPLOYEE_ID = v_employee_id and JOB_ID = v_employee_job_id;
        create_honor_jobs(v_employee_old_contract.JOB_ID);
        v_employee_new_job := 'HON_' || v_employee_old_contract.JOB_ID;


        --Now we need to change JOB_ID in employees table
        update EMPLOYEES set JOB_ID = v_employee_new_job where EMPLOYEE_ID = v_employee_id;

        --Change JOB_ID in JOB_HISTORY
        update JOB_HISTORY set JOB_ID = v_employee_new_job, START_DATE = start_cont_date, END_DATE = end_cont_date
          where EMPLOYEE_ID = v_employee_old_contract.EMPLOYEE_ID
                and JOB_ID = v_employee_old_contract.JOB_ID
                and DEPARTMENT_ID = v_employee_old_contract.DEPARTMENT_ID;

        --Set new commission pact
        select COMMISSION_PCT into v_emp_comm_pct from EMPLOYEES where EMPLOYEE_ID = v_employee_id;
        if v_emp_comm_pct is null then
          update EMPLOYEES set COMMISSION_PCT = 0.2 where EMPLOYEE_ID = v_employee_id;
        else
          if v_emp_comm_pct < 0.2 then
            update EMPLOYEES set COMMISSION_PCT = 0.2 where EMPLOYEE_ID = v_employee_id;
          end if;
        end if;
    end;
end honorary_employees;

--ЗАПУСКАТЬ ЭТО
alter table JOBS
  modify (
JOB_ID varchar2(30),
JOB_TITLE varchar2(50)
  );

alter table EMPLOYEES
  modify (
JOB_ID varchar2(30)
  );

alter table JOB_HISTORY
  modify (
JOB_ID varchar2(30));

--ПОТОМ ЭТО
begin
  for v_curs in (select * from EMPLOYEES) loop
    if instr(v_curs.JOB_ID, 'HON_') = 0  then
      if TO_CHAR(v_curs.HIRE_DATE, 'YYYY') = '2008' then
        honorary_employees.prepare_give_honor_contract(v_curs.EMPLOYEE_ID, v_curs.HIRE_DATE, v_curs.HIRE_DATE+360);
      end if;
    end if;
  end loop;
end;
--END


--№2;
create or replace package password_module as
  v_username emp_passwords.username%type;
  v_password emp_passwords.password%type;
  procedure update_passwords;
  function validate_password (password in varchar2) return emp_passwords.password%type;
  function create_username(e_LastName in MYEMPLOYEES.LAST_NAME%TYPE, e_FirstName in MYEMPLOYEES.FIRST_NAME%TYPE) return emp_passwords.username%type;
  procedure create_password(password out varchar2);
end password_module;

create or replace package body password_module is
  procedure update_passwords as
    begin
      for v_data in (select e.EMPLOYEE_ID, e.FIRST_NAME, e.LAST_NAME from MYEMPLOYEES e) loop
        v_username := create_username(v_data.LAST_NAME, v_data.FIRST_NAME);

        v_password := validate_password(DBMS_RANDOM.STRING('a',3));

        update emp_passwords e
          set e.password = v_password,
              e.username = v_username
        where e.employee_id = v_data.EMPLOYEE_ID;

        if (sql%rowcount = 0)
          then
          insert into emp_passwords values (v_data.EMPLOYEE_ID, v_username, v_password);
        end if;
      end loop;
    end;

  function create_username(e_LastName MYEMPLOYEES.LAST_NAME%TYPE, e_FirstName MYEMPLOYEES.FIRST_NAME%TYPE)
    return emp_passwords.username%type as
    begin
      return e_LastName || '.' || lower(substr(e_FirstName, 1, 1));
    end;

  procedure create_password(password out varchar2) is
    begin
      password := DBMS_RANDOM.STRING('A', 10);
    end;

  function validate_password(password in varchar2) return emp_passwords.password%type as
      newpassword emp_passwords.password%type;
      random_char varchar2(20);
      regexp_str varchar2(1000);
    begin
      newpassword := password;
      if length(newpassword) = 0 then
        newpassword := DBMS_RANDOM.STRING('a', 1);
      end if;

      if length(newpassword) > 10 then
        newpassword := substr(newpassword, 0, 10);
      end if;

      regexp_str := '^[a-zA-Z0-9]*[@#$%_&]?[a-zA-Z0-9]*$';

      if regexp_instr(newpassword, regexp_str) > 0 then
          newpassword := regexp_replace(newpassword, '@', '');
          newpassword := regexp_replace(newpassword, '#', '');
          newpassword := regexp_replace(newpassword, '$', '');
          newpassword := regexp_replace(newpassword, '%', '');
          newpassword := regexp_replace(newpassword, '_', '');
          newpassword := regexp_replace(newpassword, '&', '');

          random_char := round(DBMS_RANDOM.VALUE(1, 6));

          if random_char = 1 then
            newpassword := newpassword || '@';
          elsif random_char = 2 then
            newpassword := newpassword || '#';
          elsif random_char = 3 then
            newpassword := newpassword || '$';
          elsif random_char = 4 then
            newpassword := newpassword || '%';
          elsif random_char = 5 then
            newpassword := newpassword || '_';
          elsif random_char = 6 then
            newpassword := newpassword || '&';
          end if;
      end if;

      if regexp_instr(newpassword, '[a-z]', 1,1,0,'c') = 0 then
        newpassword := DBMS_RANDOM.STRING('l', 1) || newpassword;
      end if;

      if regexp_instr(newpassword, '[A-Z]', 1,1,0,'c') = 0 then
        newpassword := DBMS_RANDOM.STRING('u', 1) || newpassword;
      end if;

      if regexp_instr(newpassword, '[0-9]') = 0 then
        newpassword := newpassword || round(DBMS_RANDOM.VALUE(0,9));
      end if;

      if regexp_instr(newpassword, '^[a-zA-Z].+$', 1,1,0,'c') = 0 then
        newpassword := DBMS_RANDOM.STRING('a', 1) || newpassword;
      end if;

      if length(newpassword) < 10 then
        newpassword := newpassword || DBMS_RANDOM.STRING('a', 14 - length(newpassword));
      end if;

      return newpassword;
    end;
end password_module;


--ЗАПУСКАТЬ ЭТО
create table emp_passwords(
  employee_id numeric,
  username varchar2(200),
  password varchar2(200)
);

ALTER TABLE emp_passwords
ADD CONSTRAINT myemp_fk
       		 FOREIGN KEY (employee_id)
        	  REFERENCES MYEMPLOYEES (employee_id)
              ON DELETE CASCADE;

alter session set nls_sort=BINARY;


--ПОТОМ ЭТО
begin
  password_module.update_passwords();
end;