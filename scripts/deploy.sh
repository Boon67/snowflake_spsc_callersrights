#!/bin/bash

# Deployment script for Snowflake SQL Query Application
# This script builds and deploys the application to Snowpark Container Services

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="sql-query-app"
DATABASE_NAME="SQL_QUERY_APP_DB"
SCHEMA_NAME="PUBLIC"
SERVICE_NAME="sql_query_service"
REPOSITORY_NAME="sql_query_app"
COMPUTE_POOL_NAME="sql_query_pool"
SNOW_CONNECTION="DEMO_USER"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to load configuration
load_config() {
    print_status "Loading configuration..."
    print_success "Configuration loaded successfully"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker is not running"
        exit 1
    fi
    
    # Check if Snow CLI is installed
    if ! command -v snow &> /dev/null; then
        print_error "Snow CLI is not installed or not in PATH"
        print_error "Please install Snow CLI from: https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation"
        print_error "Installation: pip install snowflake-cli-labs"
        exit 1
    fi
    
    # Check Snow CLI connection
    print_status "Testing Snow CLI connection..."
    if snow connection test --connection "$SNOW_CONNECTION" &> /dev/null; then
        print_success "Snow CLI connection '$SNOW_CONNECTION' is working"
    else
        print_error "Snow CLI connection '$SNOW_CONNECTION' failed"
        print_error "Please configure Snow CLI with: snow connection add --connection-name $SNOW_CONNECTION"
        print_error "Or update the SNOW_CONNECTION variable in this script"
        exit 1
    fi
    
    print_success "Prerequisites check completed"
}

# Function to build Docker images
build_images() {
    print_status "Building Docker images..."
    
    # Build frontend image
    print_status "Building frontend image..."
    docker build -t ${APP_NAME}/frontend:latest ./frontend
    
    # Build backend image
    print_status "Building backend image..."
    docker build -t ${APP_NAME}/backend:latest ./backend
    
    print_success "Docker images built successfully"
}

# Function to setup database
setup_database() {
    print_status "Setting up Snowflake database..."
    
    # Use Snow CLI to execute SQL script with specified connection
    print_status "Executing database setup script..."
    snow sql -f scripts/setup-database.sql --connection "$SNOW_CONNECTION"
    
    if [ $? -eq 0 ]; then
        print_success "Database setup completed using Snow CLI"
    else
        print_error "Database setup failed. Please check the SQL script and your connection."
        exit 1
    fi
}

# Function to create compute pool
create_compute_pool() {
    print_status "Creating compute pool: $COMPUTE_POOL_NAME"
    
    snow sql -q "
    CREATE COMPUTE POOL IF NOT EXISTS ${COMPUTE_POOL_NAME}
    MIN_NODES = 1
    MAX_NODES = 1
    INSTANCE_FAMILY = CPU_X64_XS;
    " --connection "$SNOW_CONNECTION"
    
    if [ $? -eq 0 ]; then
        print_success "Compute pool '$COMPUTE_POOL_NAME' created"
    else
        print_error "Failed to create compute pool '$COMPUTE_POOL_NAME'"
        exit 1
    fi
}

# Function to create image repository
create_repository() {
    print_status "Creating image repository: $REPOSITORY_NAME"
    
    snow sql -q "
    USE DATABASE ${DATABASE_NAME};
    CREATE IMAGE REPOSITORY IF NOT EXISTS ${REPOSITORY_NAME};
    " --connection "$SNOW_CONNECTION"
    
    if [ $? -eq 0 ]; then
        print_success "Image repository '$REPOSITORY_NAME' created"
    else
        print_error "Failed to create image repository '$REPOSITORY_NAME'"
        exit 1
    fi
}

# Function to push images to Snowflake
push_images() {
    print_status "Pushing images to Snowflake repository..."
    
    # Get the repository URL using Snow CLI
    REPO_URL=$(snow sql -q "
    USE DATABASE ${DATABASE_NAME};
    SHOW IMAGE REPOSITORIES LIKE '${REPOSITORY_NAME}';
    " --connection "$SNOW_CONNECTION" --format json | jq -r '.[0].repository_url' 2>/dev/null)
    
    if [ -z "$REPO_URL" ] || [ "$REPO_URL" = "null" ]; then
        print_error "Could not get repository URL. Trying alternative method..."
        # Alternative method using describe
        REPO_URL=$(snow sql -q "DESC IMAGE REPOSITORY ${REPOSITORY_NAME};" --connection "$SNOW_CONNECTION" --format json | jq -r '.[] | select(.property == "repository_url") | .value' 2>/dev/null)
    fi
    
    if [ -z "$REPO_URL" ] || [ "$REPO_URL" = "null" ]; then
        print_error "Could not get repository URL"
        print_error "Please get the repository URL manually and push images:"
        print_error "snow sql -q \"SHOW IMAGE REPOSITORIES LIKE '${REPOSITORY_NAME}';\""
        exit 1
    fi
    
    print_status "Repository URL: $REPO_URL"
    
    # Login to registry using Snow CLI credentials
    print_status "Logging into Snowflake registry..."
    
    # Get credentials from Snow CLI connection for Docker login
    # Note: For JWT authentication, we need to use a different approach
    if snow connection list --connection "$SNOW_CONNECTION" --format json | grep -q "SNOWFLAKE_JWT"; then
        print_status "Using JWT authentication - attempting automated login..."
        # For JWT, we might need a different login method or use snow CLI to manage this
        print_warning "JWT authentication detected. Please ensure Docker registry access is configured."
    else
        # For password authentication, try to extract credentials
        ACCOUNT_FROM_SNOW=$(snow connection list --connection "$SNOW_CONNECTION" --format json | jq -r '.[0].account' 2>/dev/null || echo "")
        USER_FROM_SNOW=$(snow connection list --connection "$SNOW_CONNECTION" --format json | jq -r '.[0].user' 2>/dev/null || echo "")
        
        if [ -n "$ACCOUNT_FROM_SNOW" ] && [ -n "$USER_FROM_SNOW" ]; then
            print_status "Using Snow CLI credentials for Docker login..."
            # Note: Snow CLI should handle authentication, but Docker needs explicit credentials
            print_warning "Please ensure you're authenticated to the Docker registry"
            print_warning "You may need to run: docker login $REPO_URL"
        fi
    fi
    
    # Tag and push frontend image
    print_status "Pushing frontend image..."
    docker tag ${APP_NAME}/frontend:latest ${REPO_URL}/sql_query_frontend:latest
    docker push ${REPO_URL}/sql_query_frontend:latest
    
    # Tag and push backend image
    print_status "Pushing backend image..."
    docker tag ${APP_NAME}/backend:latest ${REPO_URL}/sql_query_backend:latest
    docker push ${REPO_URL}/sql_query_backend:latest
    
    print_success "Images pushed to Snowflake repository"
}

# Function to build and push current images
build_and_push_images() {
    print_status "Building and pushing current application images..."
    
    # Build frontend v2
    print_status "Building frontend image (v2)..."
    cd frontend
    docker build --platform linux/amd64 -t sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/sql_query_app_db/public/sql_query_app/sql_query_frontend:v2 .
    
    # Build backend v4 
    print_status "Building backend image (v4)..."
    cd ../backend
    docker build --platform linux/amd64 -t sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/sql_query_app_db/public/sql_query_app/sql_query_backend:v4 .
    cd ..
    
    # Login to Snowflake registry
    print_status "Logging into Snowflake registry..."
    snow spcs image-registry login --connection "$SNOW_CONNECTION"
    
    # Push images
    print_status "Pushing frontend image..."
    docker push sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/sql_query_app_db/public/sql_query_app/sql_query_frontend:v2
    
    print_status "Pushing backend image..."
    docker push sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/sql_query_app_db/public/sql_query_app/sql_query_backend:v4
    
    print_success "Images built and pushed successfully"
}

# Function to deploy service (create or alter)
deploy_service() {
    print_status "Deploying Snowpark Container Service..."
    
    # Get the repository URL
    REPO_URL=$(snow sql -q "
    USE DATABASE ${DATABASE_NAME};
    SHOW IMAGE REPOSITORIES;
    " --connection "$SNOW_CONNECTION" --format json | jq -r '.[1][0].repository_url' 2>/dev/null)
    
    if [ -z "$REPO_URL" ] || [ "$REPO_URL" = "null" ]; then
        # Alternative method using describe - fix the repository name
        REPO_URL=$(snow sql -q "DESC IMAGE REPOSITORY SQL_QUERY_APP;" --connection "$SNOW_CONNECTION" --format json | jq -r '.[] | select(.property == "repository_url") | .value' 2>/dev/null)
    fi
    
    if [ -z "$REPO_URL" ] || [ "$REPO_URL" = "null" ]; then
        print_error "Could not get repository URL for service deployment"
        exit 1
    fi
    
    # Generate the service specification inline (no temp files)
    local service_spec="spec:
  container:
    - name: frontend
      image: sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/sql_query_app_db/public/sql_query_app/sql_query_frontend:v2
      resources:
        requests:
          memory: 512Mi
          cpu: 0.5
        limits:
          memory: 1Gi
          cpu: 1
    - name: backend
      image: sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/sql_query_app_db/public/sql_query_app/sql_query_backend:v4
      env:
        SNOWFLAKE_DATABASE: SQL_QUERY_APP_DB
        SNOWFLAKE_SCHEMA: PUBLIC
        SNOWFLAKE_WAREHOUSE: COMPUTE_WH
        SNOWFLAKE_ROLE: DOCUMENT_PROCESSOR
        NODE_ENV: production
      resources:
        requests:
          memory: 512Mi
          cpu: 0.5
        limits:
          memory: 1Gi
          cpu: 1
  endpoint:
    - name: frontend
      port: 80
      public: true
    - name: backend
      port: 3001
      public: false"
    
    # Check if service already exists
    print_status "Checking if service already exists..."
    local service_exists=$(snow sql -q "
    USE DATABASE ${DATABASE_NAME};
    USE SCHEMA ${SCHEMA_NAME};
    SHOW SERVICES LIKE '${SERVICE_NAME}';
    " --connection "$SNOW_CONNECTION" --format json 2>/dev/null | jq '. | length' 2>/dev/null)
    
    if [ "${service_exists:-0}" -gt 0 ]; then
        print_status "Service exists. Updating with ALTER SERVICE..."
        snow sql -q "
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        ALTER SERVICE ${SERVICE_NAME}
        FROM SPECIFICATION \$\$
        ${service_spec}
        \$\$;
        " --connection "$SNOW_CONNECTION"
        
        if [ $? -eq 0 ]; then
            print_success "Service updated successfully"
        else
            print_error "Failed to update service"
            exit 1
        fi
    else
        print_status "Service does not exist. Creating new service..."
        snow sql -q "
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        CREATE SERVICE ${SERVICE_NAME}
        IN COMPUTE POOL ${COMPUTE_POOL_NAME}
        FROM SPECIFICATION \$\$
        ${service_spec}
        \$\$;
        " --connection "$SNOW_CONNECTION"
        
        if [ $? -eq 0 ]; then
            print_success "Service created successfully"
        else
            print_error "Failed to create service"
            exit 1
        fi
    fi
    
    # Monitor service provisioning
    if monitor_service_provisioning; then
        print_success "Service is fully provisioned and ready!"
    else
        print_warning "Service was deployed but monitoring detected issues. Check service status manually."
    fi
}

# Function to monitor service provisioning
monitor_service_provisioning() {
    print_status "Monitoring service provisioning..."
    
    local max_attempts=30
    local attempt=1
    local service_ready=false
    local endpoint_ready=false
    
    while [ $attempt -le $max_attempts ]; do
        print_status "Checking service status (attempt $attempt/$max_attempts)..."
        
        # Check service container status
        local service_status=$(snow sql -q "SELECT SYSTEM\$GET_SERVICE_STATUS('${DATABASE_NAME}.${SCHEMA_NAME}.${SERVICE_NAME}');" --connection "$SNOW_CONNECTION" --format json 2>/dev/null)
        
        if [ $? -eq 0 ] && [ -n "$service_status" ]; then
            # Parse the status to check if all containers are ready
            local ready_count=$(echo "$service_status" | jq -r '.[0] | to_entries[0].value | fromjson | map(select(.status == "READY")) | length' 2>/dev/null || echo "0")
            local total_count=$(echo "$service_status" | jq -r '.[0] | to_entries[0].value | fromjson | length' 2>/dev/null || echo "0")
            
            # Ensure we have valid numbers
            ready_count=${ready_count:-0}
            total_count=${total_count:-0}
            
            if [ "$ready_count" = "$total_count" ] && [ "$total_count" -gt 0 ]; then
                print_success "All service containers are ready ($ready_count/$total_count)"
                service_ready=true
            else
                print_status "Service containers status: $ready_count/$total_count ready"
                
                # Show failed containers if any
                local failed_containers=$(echo "$service_status" | jq -r '.[0] | to_entries[0].value | fromjson | map(select(.status != "READY")) | .[].containerName' 2>/dev/null)
                if [ -n "$failed_containers" ]; then
                    print_warning "Containers not ready: $failed_containers"
                fi
            fi
        else
            print_status "Service status not available yet..."
        fi
        
        # Check endpoint status if service is ready
        if [ "$service_ready" = true ]; then
            print_status "Checking endpoint provisioning..."
            
            local endpoint_status=$(snow sql -q "SHOW ENDPOINTS IN SERVICE ${DATABASE_NAME}.${SCHEMA_NAME}.${SERVICE_NAME};" --connection "$SNOW_CONNECTION" --format json 2>/dev/null)
            
            if [ $? -eq 0 ] && [ -n "$endpoint_status" ]; then
                # Check if public endpoints have URLs (not "provisioning in progress")
                local public_endpoint_url=$(echo "$endpoint_status" | jq -r '.[] | select(.is_public == "true") | .ingress_url' 2>/dev/null | grep -v "progress" | head -1)
                
                if [ -n "$public_endpoint_url" ] && [ "$public_endpoint_url" != "null" ] && [ "$public_endpoint_url" != "" ]; then
                    print_success "Public endpoint is ready: https://$public_endpoint_url"
                    endpoint_ready=true
                    break
                else
                    print_status "Endpoint still provisioning..."
                fi
            else
                print_status "Endpoint status not available yet..."
            fi
        fi
        
        if [ "$service_ready" = true ] && [ "$endpoint_ready" = true ]; then
            break
        fi
        
        # Wait before next check
        sleep 20
        attempt=$((attempt + 1))
    done
    
    if [ "$service_ready" = false ]; then
        print_error "Service failed to become ready after $max_attempts attempts"
        print_status "Getting detailed service logs..."
        snow sql -q "SELECT SYSTEM\$GET_SERVICE_LOGS('${DATABASE_NAME}.${SCHEMA_NAME}.${SERVICE_NAME}', '0', 'frontend', 50);" --connection "$SNOW_CONNECTION" || true
        snow sql -q "SELECT SYSTEM\$GET_SERVICE_LOGS('${DATABASE_NAME}.${SCHEMA_NAME}.${SERVICE_NAME}', '0', 'backend', 50);" --connection "$SNOW_CONNECTION" || true
        return 1
    fi
    
    if [ "$endpoint_ready" = false ]; then
        print_warning "Service is ready but endpoint is still provisioning. This may take a few more minutes."
        print_status "You can check endpoint status later with:"
        print_status "snow sql -q \"SHOW ENDPOINTS IN SERVICE ${DATABASE_NAME}.${SCHEMA_NAME}.${SERVICE_NAME};\" --connection $SNOW_CONNECTION"
    fi
    
    return 0
}

# Function to check service status
check_service_status() {
    print_status "Checking service status..."
    
    snow sql -q "
    USE DATABASE ${DATABASE_NAME};
    SHOW SERVICES LIKE '${SERVICE_NAME}';
    " --connection "$SNOW_CONNECTION"
    
    print_status "Getting service endpoints..."
    snow sql -q "
    SHOW ENDPOINTS IN SERVICE ${SERVICE_NAME};
    " --connection "$SNOW_CONNECTION"
    
    print_status "Checking compute pool status..."
    snow sql -q "
    SHOW COMPUTE POOLS LIKE '${COMPUTE_POOL_NAME}';
    " --connection "$SNOW_CONNECTION"
}

# Function to show deployment summary
show_summary() {
    print_success "Deployment completed!"
    echo ""
    echo "=== Deployment Summary ==="
    echo "Application Name: $APP_NAME"
    echo "Database: $DATABASE_NAME"
    echo "Schema: $SCHEMA_NAME"
    echo "Service: $SERVICE_NAME"
    echo "Compute Pool: $COMPUTE_POOL_NAME"
    echo ""
    echo "=== Next Steps ==="
    echo "1. Service monitoring has completed during deployment"
    echo "2. If endpoint URL was shown above, access the application immediately"
    echo "3. If endpoint is still provisioning, wait a few minutes and check status"
    echo "4. Test the SQL query interface with sample queries"
    echo ""
    echo "=== Useful Commands ==="
    echo "Monitor service and endpoint status:"
    echo "  $0 status"
    echo ""
    echo "Check service status manually:"
    echo "  SHOW SERVICES LIKE '$SERVICE_NAME';"
    echo ""
    echo "Get service endpoints:"
    echo "  SHOW ENDPOINTS IN SERVICE $SERVICE_NAME;"
    echo ""
    echo "Service logs:"
    echo "  SELECT * FROM TABLE(SYSTEM\$GET_SERVICE_LOGS('$SERVICE_NAME', '0', 'frontend'));"
    echo "  SELECT * FROM TABLE(SYSTEM\$GET_SERVICE_LOGS('$SERVICE_NAME', '0', 'backend'));"
}

# Main deployment function
main() {
    echo "========================================="
    echo "Snowflake SQL Query Application Deployment"
    echo "========================================="
    echo ""
    
    # Read configuration and check prerequisites
    load_config
    check_prerequisites
    
    # Build and deploy
    build_images
    setup_database
    create_compute_pool
    create_repository
    push_images
    deploy_service
    
    # Show final summary
    show_summary
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "build-only")
        build_images
        ;;
    "images")
        load_config
        check_prerequisites
        build_and_push_images
        ;;
    "database-only")
        load_config
        check_prerequisites
        setup_database
        ;;
    "service-only")
        load_config
        check_prerequisites
        deploy_service
        ;;
    "status")
        load_config
        print_status "Checking service status and monitoring provisioning..."
        monitor_service_provisioning
        ;;
    "clean")
        print_status "Cleaning up Docker images..."
        docker rmi ${APP_NAME}/frontend:latest ${APP_NAME}/backend:latest 2>/dev/null || true
        print_success "Cleanup completed"
        ;;
    "help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  deploy        Full deployment (default)"
        echo "  build-only    Build Docker images only"
        echo "  images        Build and push images to Snowflake"
        echo "  service-only  Deploy service only (includes building images)"
        echo "  database-only Setup database only"
        echo "  status        Check service status and monitor provisioning"
        echo "  clean         Remove local Docker images"
        echo "  help          Show this help"
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
