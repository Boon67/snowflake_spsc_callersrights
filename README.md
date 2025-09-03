# Snowflake SQL Query Application

A web application that runs in Snowpark Container Services, allowing users to execute SQL queries with both Owner's Rights and Caller's Rights execution modes.

## Features

- **Interactive SQL Editor**: Code editor with syntax highlighting and auto-completion
- **Execution Modes**: Toggle between Owner's Rights and Caller's Rights execution
- **Real-time Results**: View query results in a formatted table
- **Error Handling**: Comprehensive error messages and debugging information
- **Containerized**: Runs in Snowpark Container Services for scalability
- **Modern UI**: React-based frontend with responsive design

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   React Web     │    │   Node.js API   │    │   Snowflake     │
│   Frontend      │◄──►│   Backend       │◄──►│   Database      │
│   (Port 80)     │    │   (Port 3001)   │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Components

- **Frontend**: React application with Ace Editor for SQL input
- **Backend**: Node.js/Express API with Snowflake SDK integration
- **Database**: Snowflake database with sample data and procedures

## Prerequisites

### Software Requirements

- Docker and Docker Compose
- Snow CLI (required for deployment to Snowpark Container Services)
- Node.js 18+ (for local development)
- jq (for JSON parsing in deployment scripts)
- Access to Snowflake account with appropriate permissions

### Snow CLI Installation

```bash
# Install Snow CLI
pip install snowflake-cli-labs

# Verify installation
snow --version

# Configure connection
snow connection add
```

### Snowflake Requirements

- Snowflake account with Container Services enabled
- Role with privileges to:
  - Create databases and schemas
  - Create and manage compute pools
  - Create and manage container services
  - Create image repositories
  - Push Docker images

## Quick Start

### 1. Snow CLI Setup

Configure Snow CLI connection:

```bash
# Add a new connection
snow connection add

# Test the connection
snow connection test

# Alternative: Use snow.toml configuration file
cp snow.toml.example snow.toml
# Edit snow.toml with your credentials
```

### 2. Environment Setup

Create a `.env` file for local development:

```bash
# Copy the example environment file
cp backend/env.example .env

# Edit with your Snowflake credentials
nano .env
```

Required environment variables:
```bash
SNOWFLAKE_ACCOUNT=your-account-identifier
SNOWFLAKE_USERNAME=your-username
SNOWFLAKE_PASSWORD=your-password
SNOWFLAKE_WAREHOUSE=your-warehouse
SNOWFLAKE_ROLE=your-role
SNOWFLAKE_DATABASE=SQL_QUERY_APP_DB
SNOWFLAKE_SCHEMA=PUBLIC
```

### 3. Deploy to Snowflake

Run the deployment script:

```bash
# Make the script executable (if not already)
chmod +x scripts/deploy.sh

# Full deployment
./scripts/deploy.sh

# Or run specific steps
./scripts/deploy.sh database-only  # Setup database only
./scripts/deploy.sh build-only     # Build images only
```

### 4. Access the Application

After deployment, get the service endpoint:

```bash
# Using Snow CLI
snow sql -q "USE DATABASE SQL_QUERY_APP_DB; SHOW ENDPOINTS IN SERVICE sql-query-service;"

# Or check service status
snow sql -q "SHOW SERVICES LIKE 'sql-query-service';"
```

Access the application using the provided URL.

## Local Development

### Backend Development

```bash
cd backend
npm install
npm run dev
```

The backend will be available at `http://localhost:3001`

### Frontend Development

```bash
cd frontend
npm install
npm start
```

The frontend will be available at `http://localhost:3000`

### Using Docker Compose

```bash
# Build and run all services
docker-compose up --build

# Run in background
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Usage

### SQL Query Interface

1. **Enter SQL Query**: Use the code editor to write your SQL query
2. **Choose Execution Mode**:
   - **Owner's Rights**: Query executes with the permissions of the procedure/function owner
   - **Caller's Rights**: Query executes with the permissions of the calling user
3. **Execute**: Click "Execute Query" or press `Ctrl+Enter`
4. **View Results**: Results appear in a formatted table below the editor

### Example Queries

```sql
-- Basic information query
SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_DATABASE(), CURRENT_SCHEMA();

-- Query sample data
SELECT * FROM SAMPLE_DATA LIMIT 10;

-- Use the summary view
SELECT * FROM EMPLOYEE_SUMMARY;

-- Test different departments
SELECT * FROM SAMPLE_DATA WHERE DEPARTMENT = 'Engineering';

-- Get context information
SELECT GET_CURRENT_CONTEXT();
```

### Owner's Rights vs Caller's Rights

**Owner's Rights (Default)**:
- Query executes with the permissions of the container service account
- This is the standard execution mode for Snowpark Container Services
- The container runs with its configured service account privileges

**Caller's Rights**:
- Query execution attempts to simulate caller's permissions within the container context
- In SPCS, this is primarily for demonstration and logging purposes
- The actual execution still uses the container's service account but with different tracking

## API Endpoints

### Backend API

- `GET /api/health` - Health check
- `GET /api/info` - Connection information
- `POST /api/execute` - Execute SQL query
- `POST /api/create-caller-rights-procedure` - Create caller's rights procedure

### Request/Response Examples

**Execute Query**:
```bash
curl -X POST http://localhost:3001/api/execute \
  -H "Content-Type: application/json" \
  -d '{
    "query": "SELECT CURRENT_USER(), CURRENT_ROLE()",
    "useCallersRights": false
  }'
```

## Deployment Details

### Snowflake Objects Created

The deployment creates the following objects:

1. **Database**: `SQL_QUERY_APP_DB`
2. **Schema**: `PUBLIC`
3. **Sample Table**: `SAMPLE_DATA` with employee information
4. **View**: `EMPLOYEE_SUMMARY` for department statistics
5. **Function**: `GET_CURRENT_CONTEXT` for debugging context information
6. **Compute Pool**: `sql-query-pool`
7. **Image Repository**: `sql-query-app`
8. **Container Service**: `sql-query-service`

### Container Specifications

**Frontend Container**:
- Nginx serving React build
- Memory: 512Mi - 1Gi
- CPU: 0.5 - 1 core

**Backend Container**:
- Node.js Express application
- Memory: 512Mi - 1Gi
- CPU: 0.5 - 1 core
- Health checks on `/api/health`

## Monitoring and Troubleshooting

### Check Service Status

```sql
-- View all services
SHOW SERVICES;

-- View specific service
SHOW SERVICES LIKE 'sql-query-service';

-- Check service endpoints
SHOW ENDPOINTS IN SERVICE sql-query-service;

-- View compute pools
SHOW COMPUTE POOLS;
```

### View Logs

```sql
-- Frontend logs
SELECT * FROM TABLE(SYSTEM$GET_SERVICE_LOGS('sql-query-service', '0', 'frontend'))
ORDER BY TIMESTAMP DESC LIMIT 100;

-- Backend logs
SELECT * FROM TABLE(SYSTEM$GET_SERVICE_LOGS('sql-query-service', '0', 'backend'))
ORDER BY TIMESTAMP DESC LIMIT 100;
```

### Common Issues

1. **Service Not Starting**: Check compute pool status and resource limits
2. **Connection Errors**: Verify Snowflake credentials and network access
3. **Permission Denied**: Ensure proper role assignments and privileges
4. **Image Pull Errors**: Verify image repository and authentication

### Restart Service

```sql
-- Stop service
ALTER SERVICE sql-query-service SUSPEND;

-- Start service
ALTER SERVICE sql-query-service RESUME;
```

## Security Considerations

1. **Environment Variables**: Store sensitive credentials securely
2. **Network Access**: Container services run in isolated environments
3. **Role-Based Access**: Use appropriate Snowflake roles and privileges
4. **Input Validation**: Backend validates SQL input for safety
5. **Error Handling**: Sensitive information is not exposed in error messages

## Customization

### Adding New Features

1. **Frontend**: Modify React components in `frontend/src/components/`
2. **Backend**: Add new endpoints in `backend/server.js`
3. **Database**: Add objects in `scripts/setup-database.sql`

### Configuration

- **Container Resources**: Modify `snowflake-spec.yml`
- **Docker Settings**: Update `Dockerfile` files
- **Database Schema**: Edit `scripts/setup-database.sql`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is provided as-is for educational and demonstration purposes.

## Support

For issues related to:
- **Snowflake**: Check Snowflake documentation and support
- **Application**: Review logs and error messages
- **Deployment**: Ensure prerequisites and permissions are correct

## Version History

- **v1.0.0**: Initial release with basic SQL execution and Owner's/Caller's Rights support
