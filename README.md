# Snowflake SQL Query Application

A web application that runs in Snowpark Container Services (SPCS), allowing users to execute SQL queries with both Owner's Rights and Caller's Rights execution modes.

## 🎯 Features

- **🔍 Interactive SQL Interface**: Simple textarea for SQL input with syntax styling
- **🔐 Execution Modes**: Toggle between Owner's Rights and Caller's Rights execution
- **📊 Real-time Results**: View query results in formatted tables with metadata
- **🚨 Error Handling**: Comprehensive error messages and debugging information
- **📡 Connection Monitoring**: Real-time backend connection status indicator
- **🏗️ Containerized**: Runs in Snowpark Container Services for scalability
- **⚡ Modern UI**: React-based frontend with responsive design
- **🔑 SPCS OAuth Authentication**: Uses official Snowflake OAuth token method
- **👤 True Caller's Rights**: Implements SPCS ingress user token for caller's rights

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   React Web     │    │   Node.js API   │    │   Snowflake     │
│   Frontend      │◄──►│   Backend       │◄──►│   Database      │
│   (Port 80)     │    │   (Port 3001)   │    │                 │
│   + Nginx       │    │  + OAuth Token  │    │ + OAuth Token   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 🧩 Components

- **Frontend**: React application with Nginx proxy
- **Backend**: Node.js/Express API with Snowflake SDK integration
- **Database**: Snowflake database with sample data
- **SPCS Integration**: OAuth token authentication and caller's rights support

## 📋 Prerequisites

### Software Requirements

- Docker (with linux/amd64 platform support)
- Snow CLI (for deployment to Snowpark Container Services)
- Node.js 18+ (for local development)
- jq (for JSON parsing in deployment scripts)
- Access to Snowflake account with appropriate permissions

### Snow CLI Installation

```bash
# Install Snow CLI
pip install snowflake-cli-labs

# Verify installation
snow --version

# Configure connection (use JWT authentication recommended)
snow connection add
```

### Required Snowflake Permissions

Your Snowflake user needs the following privileges:
- `CREATE DATABASE`
- `CREATE SCHEMA`
- `CREATE COMPUTE POOL`
- `CREATE SERVICE`
- `CREATE IMAGE REPOSITORY`
- `USAGE` on warehouse
- `SYSADMIN` or equivalent role for SPCS operations

## 🚀 Quick Start

### 1. Deploy to Snowpark Container Services

The simplest way to get started:

```bash
# Clone the repository
git clone <repository-url>
cd snowflake_spsc_callersrights

# Deploy everything (database + images + service)
./scripts/deploy.sh deploy

# Or deploy just the service (builds and pushes images)
./scripts/deploy.sh service-only
```

### 2. Access the Application

After deployment:

1. Check service status: `./scripts/deploy.sh status`
2. Get the endpoint URL: `snow sql -q "SHOW ENDPOINTS IN SERVICE SQL_QUERY_APP_DB.PUBLIC.sql_query_service;" --connection DEMO_USER`
3. Open the URL in your browser
4. Start executing SQL queries!

## 🛠️ Development

### Local Development Setup

```bash
# Install dependencies
cd frontend && npm install
cd ../backend && npm install

# Start development servers
cd frontend && npm start  # Port 3000
cd backend && npm start   # Port 3001
```

### Environment Variables (Local)

For local development, create `.env` files:

**Frontend (.env)**:
```
REACT_APP_API_URL=http://localhost:3001
```

**Backend (.env)**:
```
SNOWFLAKE_ACCOUNT=your-account
SNOWFLAKE_USERNAME=your-username
SNOWFLAKE_PASSWORD=your-password
SNOWFLAKE_DATABASE=SQL_QUERY_APP_DB
SNOWFLAKE_SCHEMA=PUBLIC
SNOWFLAKE_WAREHOUSE=your-warehouse
SNOWFLAKE_ROLE=your-role
PORT=3001
```

## 📜 Deployment Commands

The deployment script supports multiple commands:

```bash
# Full deployment (recommended for first time)
./scripts/deploy.sh deploy

# Build and push images only
./scripts/deploy.sh images

# Deploy service only (includes building images)
./scripts/deploy.sh service-only

# Setup database objects only
./scripts/deploy.sh database-only

# Check service status and monitoring
./scripts/deploy.sh status

# Build Docker images locally
./scripts/deploy.sh build-only

# Clean up local Docker images
./scripts/deploy.sh clean

# Show help
./scripts/deploy.sh help
```

## 🔐 Authentication & Security

### SPCS OAuth Authentication (Production)

The application uses Snowflake's recommended OAuth token authentication:

- **OAuth Token**: Read from `/snowflake/session/token` (provided by SPCS)
- **Environment Variables**: `SNOWFLAKE_HOST` and `SNOWFLAKE_ACCOUNT` (provided by SPCS)
- **Automatic Fallback**: Falls back to password authentication if OAuth unavailable

### Caller's Rights Implementation

True caller's rights using SPCS ingress user tokens:

- **Owner's Rights**: Uses OAuth token only → runs as service user
- **Caller's Rights**: Uses OAuth + ingress user token → runs as logged-in user
- **Headers**: Detects `Sf-Context-Current-User` and `Sf-Context-Current-User-Token`
- **Automatic**: Backend automatically detects and uses appropriate mode

## 🧪 Testing Execution Modes

### Test Query

Use this query to verify execution modes:

```sql
SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_DATABASE(), CURRENT_SCHEMA();
```

### Expected Results

- **Owner's Rights**: Shows service user (like `SF$SERVICE$...`) + service role
- **Caller's Rights**: Shows your actual username + your default role

## 📊 Sample Data

The application creates sample data for testing:

```sql
-- Sample table
SELECT * FROM SAMPLE_DATA LIMIT 10;

-- Sample view
SELECT * FROM EMPLOYEE_SUMMARY;

-- Context function
SELECT GET_CURRENT_CONTEXT();
```

## 🔧 Configuration

### Database Configuration

Default settings (configurable in `scripts/deploy.sh`):

```bash
DATABASE_NAME="SQL_QUERY_APP_DB"
SCHEMA_NAME="PUBLIC"
SERVICE_NAME="sql_query_service"
COMPUTE_POOL_NAME="sql_query_pool"
REPOSITORY_NAME="sql_query_app"
SNOW_CONNECTION="DEMO_USER"
```

### Service Specification

The service includes:

- **Frontend**: Nginx + React (512Mi-1Gi memory, 0.5-1 CPU)
- **Backend**: Node.js + Express (512Mi-1Gi memory, 0.5-1 CPU)
- **Endpoints**: Public frontend endpoint, private backend endpoint
- **Capabilities**: `executeAsCaller: true` for caller's rights support

## 🐛 Troubleshooting

### Common Issues

**Connection Timeouts**:
- Check backend logs: `snow sql -q "SELECT SYSTEM\$GET_SERVICE_LOGS('SQL_QUERY_APP_DB.PUBLIC.sql_query_service', '0', 'backend', 50);" --connection DEMO_USER`
- Verify service status: `./scripts/deploy.sh status`

**Image Build Failures**:
- Ensure Docker is running with linux/amd64 platform support
- Check Snow CLI authentication: `snow spcs image-registry login --connection DEMO_USER`

**Service Not Ready**:
- Monitor provisioning: `./scripts/deploy.sh status`
- Check container logs for errors
- Verify compute pool is active

**Authentication Issues**:
- Verify Snow CLI connection: `snow connection test --connection DEMO_USER`
- Check Snowflake account permissions
- Ensure JWT authentication is properly configured

### Service Monitoring

Check service health:

```bash
# Service status
./scripts/deploy.sh status

# Backend logs
snow sql -q "SELECT SYSTEM\$GET_SERVICE_LOGS('SQL_QUERY_APP_DB.PUBLIC.sql_query_service', '0', 'backend', 50);" --connection DEMO_USER

# Frontend logs  
snow sql -q "SELECT SYSTEM\$GET_SERVICE_LOGS('SQL_QUERY_APP_DB.PUBLIC.sql_query_service', '0', 'frontend', 50);" --connection DEMO_USER

# Service endpoints
snow sql -q "SHOW ENDPOINTS IN SERVICE SQL_QUERY_APP_DB.PUBLIC.sql_query_service;" --connection DEMO_USER
```

## 📚 Documentation

### Key Files

- `scripts/deploy.sh` - Main deployment script
- `scripts/setup-database.sql` - Database initialization
- `frontend/src/components/QueryInterface.js` - Main UI component
- `backend/server.js` - API server with Snowflake integration
- `frontend/nginx.conf` - Nginx proxy configuration

### API Endpoints

- `GET /api/health` - Health check endpoint
- `POST /api/execute` - Execute SQL query
  - Body: `{ "query": "SQL", "useCallersRights": boolean }`
  - Response: Query results with metadata

### Environment Variables (SPCS)

Automatically provided by SPCS:
- `SNOWFLAKE_HOST` - Snowflake hostname
- `SNOWFLAKE_ACCOUNT` - Account identifier
- OAuth token in `/snowflake/session/token`

Configured by deployment:
- `SNOWFLAKE_DATABASE` - Target database
- `SNOWFLAKE_SCHEMA` - Target schema  
- `SNOWFLAKE_WAREHOUSE` - Compute warehouse
- `SNOWFLAKE_ROLE` - Service role
- `NODE_ENV` - Runtime environment

## 🎯 Future Enhancements

- [ ] Query history and saved queries
- [ ] Multiple database connections
- [ ] Enhanced SQL editor with autocomplete
- [ ] Export results to CSV/JSON
- [ ] User authentication and authorization
- [ ] Query performance analytics
- [ ] Scheduled query execution

## 📄 License

This project is licensed under the MIT License.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📞 Support

For issues and questions:
- Check the troubleshooting section
- Review service logs
- Verify Snowflake permissions
- Ensure Snow CLI is properly configured