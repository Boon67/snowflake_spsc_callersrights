-- Setup script for SQL Query Application Database
-- This script creates the necessary database, schema, and supporting objects

-- Create database if it doesn't exist
CREATE DATABASE IF NOT EXISTS SQL_QUERY_APP_DB
COMMENT = 'Database for SQL Query Application with Owner/Caller Rights support';

-- Use the database
USE DATABASE SQL_QUERY_APP_DB;

-- Create schema
CREATE SCHEMA IF NOT EXISTS PUBLIC
COMMENT = 'Public schema for SQL Query Application';

-- Use the schema
USE SCHEMA PUBLIC;

-- Create a sample table for testing
CREATE TABLE IF NOT EXISTS SAMPLE_DATA (
    ID NUMBER AUTOINCREMENT PRIMARY KEY,
    NAME VARCHAR(100),
    DEPARTMENT VARCHAR(50),
    SALARY NUMBER(10,2),
    HIRE_DATE DATE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'Sample table for testing SQL queries';

-- Insert some sample data
INSERT INTO SAMPLE_DATA (NAME, DEPARTMENT, SALARY, HIRE_DATE) VALUES
('John Doe', 'Engineering', 95000.00, '2022-01-15'),
('Jane Smith', 'Marketing', 78000.00, '2022-03-20'),
('Bob Johnson', 'Sales', 82000.00, '2021-11-10'),
('Alice Williams', 'Engineering', 105000.00, '2020-08-05'),
('Charlie Brown', 'HR', 65000.00, '2023-02-14'),
('Diana Prince', 'Engineering', 98000.00, '2022-07-30'),
('Eve Adams', 'Finance', 88000.00, '2021-12-01'),
('Frank Miller', 'Sales', 79000.00, '2023-01-18');

-- Create a view for testing
CREATE OR REPLACE VIEW EMPLOYEE_SUMMARY 
COMMENT = 'Summary view of employees by department'
AS
SELECT 
    DEPARTMENT,
    COUNT(*) AS EMPLOYEE_COUNT,
    AVG(SALARY) AS AVG_SALARY,
    MIN(HIRE_DATE) AS EARLIEST_HIRE,
    MAX(HIRE_DATE) AS LATEST_HIRE
FROM SAMPLE_DATA
GROUP BY DEPARTMENT;

-- Note: Stored procedures removed - the application container will handle
-- owner's rights vs caller's rights execution directly through connection context

-- Create a function to demonstrate owner's rights vs caller's rights
CREATE OR REPLACE FUNCTION GET_CURRENT_CONTEXT()
RETURNS OBJECT
LANGUAGE SQL
COMMENT = 'Function to get current execution context'
AS
$$
    OBJECT_CONSTRUCT(
        'current_user', CURRENT_USER(),
        'current_role', CURRENT_ROLE(),
        'current_database', CURRENT_DATABASE(),
        'current_schema', CURRENT_SCHEMA(),
        'current_warehouse', CURRENT_WAREHOUSE(),
        'session_id', CURRENT_SESSION()
    )
$$;

-- Grant necessary permissions
-- Note: In a real deployment, you would set up proper roles and permissions
GRANT USAGE ON DATABASE SQL_QUERY_APP_DB TO PUBLIC;
GRANT USAGE ON SCHEMA SQL_QUERY_APP_DB.PUBLIC TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA SQL_QUERY_APP_DB.PUBLIC TO PUBLIC;
GRANT SELECT ON ALL VIEWS IN SCHEMA SQL_QUERY_APP_DB.PUBLIC TO PUBLIC;
GRANT USAGE ON ALL FUNCTIONS IN SCHEMA SQL_QUERY_APP_DB.PUBLIC TO PUBLIC;
GRANT USAGE ON ALL PROCEDURES IN SCHEMA SQL_QUERY_APP_DB.PUBLIC TO PUBLIC;

-- Show summary of created objects
SELECT 'Database setup completed successfully' AS STATUS;

SELECT 'Created Objects:' AS INFO;
SHOW TABLES IN SCHEMA SQL_QUERY_APP_DB.PUBLIC;
SHOW VIEWS IN SCHEMA SQL_QUERY_APP_DB.PUBLIC;
SHOW PROCEDURES IN SCHEMA SQL_QUERY_APP_DB.PUBLIC;
SHOW FUNCTIONS IN SCHEMA SQL_QUERY_APP_DB.PUBLIC;
