
-- creating
CREATE TABLE Students (
    Student_ID VARCHAR2(10) PRIMARY KEY,
    Student_Name VARCHAR2(50) NOT NULL,
    Student_CGPA NUMBER(3,2) NOT NULL CHECK (Student_CGPA BETWEEN 0 AND 10)
);

CREATE TABLE Companies (
    Company_ID VARCHAR2(10) PRIMARY KEY,
    Company_Name VARCHAR2(100) NOT NULL,
    CGPA_Required NUMBER(3,2) NOT NULL CHECK (CGPA_Required BETWEEN 0 AND 10)
);

CREATE TABLE Job_Offers (
    Job_ID VARCHAR2(10) PRIMARY KEY,
    Job_Name VARCHAR2(100) NOT NULL,
    Company_ID VARCHAR2(10) NOT NULL,
    CONSTRAINT fk_job_company FOREIGN KEY (Company_ID) REFERENCES Companies(Company_ID)
);

CREATE TABLE Applications (
    Student_ID VARCHAR2(10) NOT NULL,
    Job_ID VARCHAR2(10) NOT NULL,
    Status VARCHAR2(20) DEFAULT 'APPLIED',
    Application_Date DATE DEFAULT SYSDATE,
    CONSTRAINT pk_applications PRIMARY KEY (Student_ID, Job_ID),
    CONSTRAINT fk_app_student FOREIGN KEY (Student_ID) REFERENCES Students(Student_ID) ON DELETE CASCADE,
    CONSTRAINT fk_app_job FOREIGN KEY (Job_ID) REFERENCES Job_Offers(Job_ID) ON DELETE CASCADE
);


-- Sample data 
INSERT INTO Students VALUES('CSE101','Surya',8.56);
INSERT INTO Students VALUES('CSE102','Nischith',8.00);
INSERT INTO Students VALUES('CSE103','Fayaz',9.30);
INSERT INTO Students VALUES('CSE104','Ekachit',9.00);

INSERT INTO Companies VALUES('21CIG','Cigna',8.50);
INSERT INTO Companies VALUES('21AWS','Amazon',9.00);
INSERT INTO Companies VALUES('21GOG','Google',9.20);
INSERT INTO Companies VALUES('21UPG','Upgrad',9.50);

INSERT INTO Job_Offers VALUES('J101','Graduate Engineer','21CIG');
INSERT INTO Job_Offers VALUES('J102','AWS Engineer','21AWS');
INSERT INTO Job_Offers VALUES('J103','Prompt Engineer','21GOG');
INSERT INTO Job_Offers VALUES('J104','QA Associate','21UPG');



-- for adding students 

CREATE OR REPLACE PROCEDURE register_student (
    p_id   IN Students.Student_ID%TYPE,
    p_name IN Students.Student_Name%TYPE,
    p_cgpa IN Students.Student_CGPA%TYPE
) IS
BEGIN
    IF p_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Student ID required');
    END IF;
    IF p_name IS NULL THEN
        RAISE_APPLICATION_ERROR(-20002, 'Student name required');
    END IF;
    IF p_cgpa < 0 OR p_cgpa > 10 THEN
        RAISE_APPLICATION_ERROR(-20003, 'CGPA must be between 0 and 10');
    END IF;
    INSERT INTO Students (Student_ID, Student_Name, Student_CGPA) VALUES (p_id, p_name, p_cgpa);
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20004, 'Student already exists');
END register_student;
/


-- registering company details 
CREATE OR REPLACE PROCEDURE register_company (
    p_id      IN Companies.Company_ID%TYPE,
    p_name    IN Companies.Company_Name%TYPE,
    p_cgpa_req IN Companies.CGPA_Required%TYPE
) IS
BEGIN
    IF p_id IS NULL OR TRIM(p_id) = '' THEN
        RAISE_APPLICATION_ERROR(-20010, 'Company ID required');
    END IF;
    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        RAISE_APPLICATION_ERROR(-20011, 'Company name required');
    END IF;
    IF p_cgpa_req < 0 OR p_cgpa_req > 10 THEN
        RAISE_APPLICATION_ERROR(-20012, 'CGPA required must be between 0 and 10');
    END IF;
    INSERT INTO Companies (Company_ID, Company_Name, CGPA_Required) VALUES (p_id, p_name, p_cgpa_req);
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20013, 'Company already exists');
END register_company;
/

-- Function to check eligibility (either eligible or not eligible) 

CREATE OR REPLACE FUNCTION check_eligibility (
    p_student_id IN Students.Student_ID%TYPE,
    p_job_id     IN Job_Offers.Job_ID%TYPE
) RETURN VARCHAR2 IS
    v_student_cgpa Students.Student_CGPA%TYPE;
    v_company_id   Job_Offers.Company_ID%TYPE;
    v_required     Companies.CGPA_Required%TYPE;
BEGIN
    SELECT Student_CGPA INTO v_student_cgpa FROM Students WHERE Student_ID = p_student_id;
    SELECT Company_ID INTO v_company_id FROM Job_Offers WHERE Job_ID = p_job_id;
    SELECT CGPA_Required INTO v_required FROM Companies WHERE Company_ID = v_company_id;
    IF v_student_cgpa >= v_required THEN
        RETURN 'ELIGIBLE';
    ELSE
        RETURN 'NOT_ELIGIBLE';
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20020, 'Student, Job or Company not found');
END check_eligibility;
/

-- Trigger to prevent duplicate application


CREATE OR REPLACE TRIGGER trg_prevent_duplicate_application
BEFORE INSERT ON Applications
FOR EACH ROW
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM Applications
     WHERE Student_ID = :NEW.Student_ID AND Job_ID = :NEW.Job_ID;
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20040, 'Duplicate application');
    END IF;
END;
/

-- View for applications dashboard

CREATE OR REPLACE VIEW v_applications_dashboard AS
SELECT a.Student_ID, s.Student_Name, s.Student_CGPA,
       a.Job_ID, j.Job_Name, j.Company_ID, c.Company_Name,
       c.CGPA_Required, a.Status, a.Application_Date
  FROM Applications a
  JOIN Students s ON a.Student_ID = s.Student_ID
  JOIN Job_Offers j ON a.Job_ID = j.Job_ID
  JOIN Companies c ON j.Company_ID = c.Company_ID;

-- Materialized view for company data 


CREATE MATERIALIZED VIEW mv_company_stats
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT c.Company_ID,
       c.Company_Name,
       COUNT(a.Student_ID) AS Applicant_Count,
       ROUND(AVG(s.Student_CGPA),2) AS Avg_Applicant_CGPA
  FROM Companies c
  LEFT JOIN Job_Offers j ON j.Company_ID = c.Company_ID
  LEFT JOIN Applications a ON a.Job_ID = j.Job_ID
  LEFT JOIN Students s ON s.Student_ID = a.Student_ID
 GROUP BY c.Company_ID, c.Company_Name;
