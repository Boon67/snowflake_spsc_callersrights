# Service Monitoring in Deployment Script

## Overview

The deployment script now includes comprehensive monitoring for service and endpoint provisioning, ensuring that deployments complete successfully and providing clear feedback on the deployment status.

## Monitoring Features

### 1. **Automatic Service Monitoring**
- **Integrated into deployment**: Monitoring automatically runs after service creation
- **Container status tracking**: Monitors all containers until they reach "READY" state
- **Intelligent polling**: Checks every 20 seconds for up to 30 attempts (10 minutes total)
- **Detailed feedback**: Shows progress like "2/2 containers ready"

### 2. **Endpoint Provisioning Monitoring**
- **Public endpoint detection**: Automatically detects when public endpoints are ready
- **URL extraction**: Extracts and displays the final application URL
- **Progress tracking**: Distinguishes between "provisioning" and "ready" states
- **Smart completion**: Only considers deployment complete when endpoints are accessible

### 3. **Error Handling and Diagnostics**
- **Automatic log retrieval**: Fetches container logs if services fail to start
- **Failed container identification**: Shows which specific containers are having issues
- **Graceful degradation**: Continues monitoring even if some checks fail
- **Clear error messages**: Provides actionable feedback on deployment issues

### 4. **Standalone Status Checking**
- **New command**: `./scripts/deploy.sh status` 
- **Independent monitoring**: Check service status without full deployment
- **Reusable**: Use anytime to verify service health

## Usage Examples

### During Deployment
```bash
# Full deployment with automatic monitoring
./scripts/deploy.sh deploy

# Output will show:
# ✅ Service created successfully
# 🔄 Monitoring service provisioning...
# 📊 Checking service status (attempt 1/30)...
# ✅ All service containers are ready (2/2)
# 🔄 Checking endpoint provisioning...
# ✅ Public endpoint is ready: https://xxxxx.snowflakecomputing.app
# ✅ Service is fully provisioned and ready!
```

### Standalone Monitoring
```bash
# Check status after deployment or anytime
./scripts/deploy.sh status

# Will show current service status and endpoint URLs
```

### Manual Status Checking
```bash
# Alternative manual commands (provided in deployment summary)
snow sql -q "SHOW SERVICES LIKE 'sql_query_service';" --connection DEMO_USER
snow sql -q "SHOW ENDPOINTS IN SERVICE sql_query_service;" --connection DEMO_USER
```

## Monitoring Logic

### Container Status Check
1. **Query service status** using `SYSTEM$GET_SERVICE_STATUS()`
2. **Parse JSON response** to count ready vs total containers
3. **Report progress** and identify failed containers
4. **Wait for all containers** to reach "READY" state

### Endpoint Status Check
1. **Query endpoints** using `SHOW ENDPOINTS IN SERVICE`
2. **Filter public endpoints** (those accessible externally)
3. **Check URL availability** (not "provisioning in progress")
4. **Extract final URL** and display to user

### Failure Handling
1. **Container failures**: Automatically fetch logs from failed containers
2. **Timeout handling**: After 30 attempts, report status and provide manual commands
3. **Partial success**: Service ready but endpoint still provisioning (common scenario)

## Benefits

### For Users
- **No manual checking**: Deployment script handles all monitoring
- **Clear feedback**: Always know what's happening and when it's ready
- **Immediate access**: Get the final URL as soon as it's available
- **Troubleshooting**: Automatic log collection if issues occur

### For Operations
- **Reliable deployments**: Catch issues early in the deployment process
- **Consistent process**: Same monitoring approach every time
- **Documentation**: Clear record of what happened during deployment
- **Debugging**: Automatic log collection for failed deployments

## Configuration

### Timing Settings
- **Polling interval**: 20 seconds between checks
- **Maximum attempts**: 30 attempts (10 minutes total)
- **Timeout behavior**: Graceful degradation with manual instructions

### Customization
Edit these variables in the `monitor_service_provisioning()` function:
```bash
local max_attempts=30    # Maximum number of polling attempts
sleep 20                 # Seconds between checks
```

## Error Scenarios

### Common Issues and Responses

1. **Container Won't Start**
   - Script automatically fetches container logs
   - Shows which specific container is failing
   - Provides guidance for manual troubleshooting

2. **Endpoint Takes Long to Provision**
   - Script waits up to 10 minutes for endpoints
   - Provides warning if service ready but endpoint still provisioning
   - Gives manual commands to check later

3. **Service Status Unavailable**
   - Script handles cases where status queries fail
   - Continues monitoring with appropriate warnings
   - Provides fallback instructions

## Dependencies

### Required Tools
- **jq**: For JSON parsing of service status
- **Snow CLI**: For all Snowflake operations
- **bash**: Shell scripting environment

### Snowflake Functions Used
- `SYSTEM$GET_SERVICE_STATUS()`: Container status information
- `SHOW ENDPOINTS IN SERVICE`: Endpoint provisioning status
- `SYSTEM$GET_SERVICE_LOGS()`: Container logs for debugging

This monitoring system ensures that deployments are reliable, predictable, and provide clear feedback throughout the entire provisioning process.
