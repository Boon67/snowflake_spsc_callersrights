# Deployment Guide

This guide provides detailed instructions for deploying the Snowflake SQL Query Application to Snowpark Container Services.

## Prerequisites

### Snowflake Account Requirements

1. **Account Setup**:
   - Snowflake account with Container Services enabled
   - ACCOUNTADMIN role access (for initial setup)
   - Appropriate compute credits and storage

2. **Required Privileges**:
   ```sql
   -- Role should have these privileges
   GRANT CREATE DATABASE ON ACCOUNT TO ROLE your_role;
   GRANT CREATE COMPUTE POOL ON ACCOUNT TO ROLE your_role;
   GRANT CREATE SERVICE ON ACCOUNT TO ROLE your_role;
   GRANT CREATE IMAGE REPOSITORY ON ACCOUNT TO ROLE your_role;
   ```

3. **Network Configuration**:
   - Outbound network access for Docker image pulls
   - Appropriate firewall rules if using private connectivity

### Local Environment

1. **Required Software**:
   ```bash
   # Docker (required)
   docker --version  # Should be 20.10+ or newer
   
   # Snow CLI (required)
   snow --version
   
   # jq (required for JSON parsing)
   jq --version
   
   # Git (for cloning)
   git --version
   ```

2. **Install Snow CLI**:
   ```bash
   # Install Snow CLI
   pip install snowflake-cli-labs
   
   # Verify installation
   snow --version
   
   # Configure connection
   snow connection add
   ```

3. **Snow CLI Configuration**:
   ```bash
   # Configure Snow CLI connection
   snow connection add
   
   # Test the connection
   snow connection test
   
   # Optional: Use configuration file
   cp snow.toml.example snow.toml
   # Edit snow.toml with your credentials
   ```

4. **Environment Variables** (for local development):
   ```bash
   export SNOWFLAKE_ACCOUNT=your-account-identifier
   export SNOWFLAKE_USERNAME=your-username
   export SNOWFLAKE_PASSWORD=your-password
   export SNOWFLAKE_WAREHOUSE=your-warehouse
   export SNOWFLAKE_ROLE=your-role
   ```

## Step-by-Step Deployment

### 1. Clone and Prepare

```bash
# Clone the repository
git clone <repository-url>
cd snowflake_spsc_callersrights

# Make scripts executable
chmod +x scripts/deploy.sh
chmod +x scripts/local-development.sh
```

### 2. Configure Snow CLI

```bash
# Configure Snow CLI connection
snow connection add --connection-name deployment \
  --account your-account \
  --user your-username \
  --password your-password \
  --warehouse your-warehouse \
  --role your-role \
  --database SQL_QUERY_APP_DB \
  --schema PUBLIC

# Test the connection
snow connection test --connection deployment
```

### 3. Configure Environment (for local development)

```bash
# Copy environment template
cp backend/env.example .env

# Edit with your credentials
nano .env
```

Required configuration:
```bash
SNOWFLAKE_ACCOUNT=abc12345.us-east-1
SNOWFLAKE_USERNAME=your_username
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
SNOWFLAKE_ROLE=SYSADMIN
SNOWFLAKE_DATABASE=SQL_QUERY_APP_DB
SNOWFLAKE_SCHEMA=PUBLIC
```

### 4. Run Deployment

#### Full Automated Deployment

```bash
# Full deployment (recommended)
./scripts/deploy.sh
```

This will:
1. Build Docker images
2. Setup Snowflake database and schema
3. Create compute pool
4. Create image repository
5. Push images to Snowflake
6. Create and start the service

#### Manual Step-by-Step Deployment

If you prefer manual control:

```bash
# Step 1: Build images only
./scripts/deploy.sh build-only

# Step 2: Setup database only
./scripts/deploy.sh database-only

# Step 3: Complete the deployment
./scripts/deploy.sh
```

### 5. Verify Deployment

```bash
# Check service status using Snow CLI
snow sql -q "USE DATABASE SQL_QUERY_APP_DB; SHOW SERVICES LIKE 'sql-query-service';"

# Get service endpoints
snow sql -q "SHOW ENDPOINTS IN SERVICE sql-query-service;"

# Check compute pool
snow sql -q "SHOW COMPUTE POOLS LIKE 'sql-query-pool';"

# Check service logs
snow sql -q "SELECT * FROM TABLE(SYSTEM\$GET_SERVICE_LOGS('sql-query-service', '0', 'frontend')) ORDER BY TIMESTAMP DESC LIMIT 10;"
```

## Manual Deployment Steps

If the automated script doesn't work in your environment, follow these manual steps:

### 1. Build Docker Images

```bash
# Build frontend
cd frontend
docker build -t sql-query-app/frontend:latest .

# Build backend
cd ../backend
docker build -t sql-query-app/backend:latest .
cd ..
```

### 2. Setup Database

Execute the SQL script in Snowflake:

```sql
-- Connect to Snowflake and run
-- File: scripts/setup-database.sql
-- (Copy and paste the contents or use SnowSQL)
```

### 3. Create Compute Pool

```sql
CREATE COMPUTE POOL sql-query-pool
MIN_NODES = 1
MAX_NODES = 3
INSTANCE_FAMILY = CPU_X64_XS;
```

### 4. Create Image Repository

```sql
USE DATABASE SQL_QUERY_APP_DB;
CREATE IMAGE REPOSITORY sql-query-app;

-- Get repository URL
SHOW IMAGE REPOSITORIES LIKE 'sql-query-app';
```

### 5. Push Images

```bash
# Get the repository URL from previous step
REPO_URL="your-account.registry.snowflakecomputing.com/sql_query_app_db/public/sql-query-app"

# Tag and push frontend
docker tag sql-query-app/frontend:latest ${REPO_URL}/sql-query-frontend:latest
docker push ${REPO_URL}/sql-query-frontend:latest

# Tag and push backend
docker tag sql-query-app/backend:latest ${REPO_URL}/sql-query-backend:latest
docker push ${REPO_URL}/sql-query-backend:latest
```

### 6. Create Service

Update `snowflake-spec.yml` with your repository URL, then:

```sql
USE DATABASE SQL_QUERY_APP_DB;
USE SCHEMA PUBLIC;

CREATE SERVICE sql-query-service
IN COMPUTE POOL sql-query-pool
FROM SPECIFICATION_FILE='snowflake-spec.yml';
```

## Post-Deployment Configuration

### 1. Service Management

```sql
-- Check service status
SHOW SERVICES;

-- View service details
DESC SERVICE sql-query-service;

-- Suspend service
ALTER SERVICE sql-query-service SUSPEND;

-- Resume service
ALTER SERVICE sql-query-service RESUME;

-- Drop service (if needed)
DROP SERVICE sql-query-service;
```

### 2. Monitoring

```sql
-- View service logs (frontend)
SELECT * FROM TABLE(SYSTEM$GET_SERVICE_LOGS('sql-query-service', '0', 'frontend'))
ORDER BY TIMESTAMP DESC LIMIT 100;

-- View service logs (backend)
SELECT * FROM TABLE(SYSTEM$GET_SERVICE_LOGS('sql-query-service', '0', 'backend'))
ORDER BY TIMESTAMP DESC LIMIT 100;

-- Check service events
SELECT * FROM TABLE(SYSTEM$GET_SERVICE_EVENTS('sql-query-service'))
ORDER BY TIMESTAMP DESC;
```

### 3. Accessing the Application

```sql
-- Get the public endpoint
SHOW ENDPOINTS IN SERVICE sql-query-service;
```

The output will show the public URL where you can access the application.

## Troubleshooting

### Common Issues

1. **Service Won't Start**
   ```sql
   -- Check compute pool status
   SHOW COMPUTE POOLS;
   
   -- Check for resource constraints
   DESC COMPUTE POOL sql-query-pool;
   ```

2. **Image Pull Errors**
   ```sql
   -- Verify repository exists
   SHOW IMAGE REPOSITORIES;
   
   -- Check image tags
   SHOW IMAGES IN IMAGE REPOSITORY sql-query-app;
   ```

3. **Permission Issues**
   ```sql
   -- Check current role privileges
   SHOW GRANTS TO ROLE current_role();
   
   -- Grant necessary permissions
   GRANT USAGE ON COMPUTE POOL sql-query-pool TO ROLE your_role;
   ```

4. **Network Connectivity**
   ```sql
   -- Check service status
   SELECT * FROM TABLE(SYSTEM$GET_SERVICE_STATUS('sql-query-service'));
   ```

### Log Analysis

```sql
-- Search for specific errors
SELECT * FROM TABLE(SYSTEM$GET_SERVICE_LOGS('sql-query-service', '0', 'backend'))
WHERE MESSAGE ILIKE '%error%'
ORDER BY TIMESTAMP DESC;

-- Check container startup
SELECT * FROM TABLE(SYSTEM$GET_SERVICE_LOGS('sql-query-service', '0', 'frontend'))
WHERE MESSAGE ILIKE '%starting%'
ORDER BY TIMESTAMP;
```

### Performance Tuning

1. **Scale Compute Pool**:
   ```sql
   ALTER COMPUTE POOL sql-query-pool SET MIN_NODES = 2 MAX_NODES = 5;
   ```

2. **Adjust Container Resources**:
   Edit `snowflake-spec.yml` and redeploy:
   ```yaml
   resources:
     requests:
       memory: 1Gi
       cpu: 1
     limits:
       memory: 2Gi
       cpu: 2
   ```

## Security Considerations

### 1. Network Security

```sql
-- Create network policy (if needed)
CREATE NETWORK POLICY container_policy
ALLOWED_IP_LIST = ('192.168.1.0/24')
BLOCKED_IP_LIST = ('0.0.0.0/0');

-- Apply to service account
ALTER USER service_user SET NETWORK_POLICY = 'container_policy';
```

### 2. Role-Based Access

```sql
-- Create dedicated role for the service
CREATE ROLE sql_query_app_role;

-- Grant minimal necessary privileges
GRANT USAGE ON DATABASE SQL_QUERY_APP_DB TO ROLE sql_query_app_role;
GRANT USAGE ON SCHEMA SQL_QUERY_APP_DB.PUBLIC TO ROLE sql_query_app_role;
GRANT SELECT ON ALL TABLES IN SCHEMA SQL_QUERY_APP_DB.PUBLIC TO ROLE sql_query_app_role;
```

### 3. Environment Variables

Never hardcode sensitive information in the container images. Use Snowflake's environment variable features:

```yaml
env:
  SNOWFLAKE_PASSWORD: !get_env SNOWFLAKE_PASSWORD
```

## Maintenance

### 1. Updates

```bash
# Build new images
./scripts/deploy.sh build-only

# Push updated images
# (Push to same tags to trigger update)

# Restart service
snowsql -q "ALTER SERVICE sql-query-service SUSPEND;"
snowsql -q "ALTER SERVICE sql-query-service RESUME;"
```

### 2. Backup

```sql
-- Backup service specification
SELECT GET_DDL('SERVICE', 'sql-query-service');

-- Backup database objects
SELECT GET_DDL('DATABASE', 'SQL_QUERY_APP_DB');
```

### 3. Cleanup

```bash
# Clean up local Docker images
./scripts/deploy.sh clean

# Drop Snowflake objects (if needed)
snowsql -q "DROP SERVICE sql-query-service;"
snowsql -q "DROP COMPUTE POOL sql-query-pool;"
snowsql -q "DROP DATABASE SQL_QUERY_APP_DB;"
```

## Best Practices

1. **Use specific image tags** instead of `latest` for production
2. **Monitor resource usage** and adjust compute pool size accordingly
3. **Implement proper logging** and monitoring
4. **Test deployments** in a staging environment first
5. **Keep credentials secure** using Snowflake's secret management
6. **Regular health checks** to ensure service availability
7. **Document any custom modifications** for future reference

## Support

For deployment issues:

1. Check the service logs first
2. Verify all prerequisites are met
3. Ensure proper network connectivity
4. Contact Snowflake support for platform-specific issues
