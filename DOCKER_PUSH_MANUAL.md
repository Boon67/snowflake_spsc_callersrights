# Manual Docker Image Push for JWT Authentication

Since you're using JWT authentication, Docker registry authentication requires special handling. Here are the manual steps to push your images to Snowflake:

## Current Status
✅ **Compute Pool Created**: `sql_query_pool` (STARTING state)
✅ **Image Repository Created**: `SQL_QUERY_APP` 
✅ **Docker Images Built**: Both frontend and backend images ready
✅ **Repository URL**: `sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/sql_query_app_db/public/sql_query_app`

## Manual Steps for Docker Push

### Option 1: Using Username/Password Authentication
If you have a password-based user for the container registry:

```bash
# Login to Snowflake Docker registry
docker login sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com -u YOUR_USERNAME

# Tag images (already done)
docker tag sql-query-app/frontend:latest sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/sql_query_app_db/public/sql_query_app/sql_query_frontend:latest
docker tag sql-query-app/backend:latest sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/sql_query_app_db/public/sql_query_app/sql_query_backend:latest

# Push images
docker push sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/sql_query_app_db/public/sql_query_app/sql_query_frontend:latest
docker push sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/sql_query_app_db/public/sql_query_app/sql_query_backend:latest
```

### Option 2: Using OAuth Token
If you can generate an OAuth token:

```bash
# Get OAuth token (this would need to be implemented)
TOKEN=$(your_oauth_token_generation_method)

# Login with token
echo $TOKEN | docker login sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com -u oauth --password-stdin

# Push images (same as above)
```

### Option 3: Alternative - Upload via Snowflake CLI (Future)
If Snow CLI supports image upload in future versions:

```bash
# This might be available in future Snow CLI versions
snow spcs image-repository push sql_query_frontend:latest SQL_QUERY_APP_DB.PUBLIC.sql_query_app/sql_query_frontend:latest
```

## After Images Are Pushed

Once the images are successfully pushed, continue with service creation:

```bash
# Update the service spec file with correct repository URL
sed "s|/sql_query_app/repository/|sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/sql_query_app_db/public/sql_query_app/|g" snowflake-spec.yml > temp-spec.yml

# Create the service
snow sql -q "
USE DATABASE SQL_QUERY_APP_DB;
USE SCHEMA PUBLIC;
CREATE SERVICE sql_query_service
IN COMPUTE POOL sql_query_pool
FROM SPECIFICATION_FILE='temp-spec.yml';
" --connection DEMO_USER

# Check service status
snow sql -q "SHOW SERVICES LIKE 'sql_query_service';" --connection DEMO_USER

# Get service endpoints
snow sql -q "SHOW ENDPOINTS IN SERVICE sql_query_service;" --connection DEMO_USER
```

## Current Repository Information

- **Repository Name**: `SQL_QUERY_APP`
- **Full URL**: `sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/sql_query_app_db/public/sql_query_app`
- **Images to Push**:
  - `sql_query_frontend:latest`
  - `sql_query_backend:latest`

## Next Steps

1. Resolve Docker registry authentication for JWT user
2. Push the two Docker images
3. Create the Snowpark Container Service
4. Access the application via the service endpoint

The application is ready for deployment once the Docker registry authentication is resolved.
