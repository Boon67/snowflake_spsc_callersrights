const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const snowflake = require('snowflake-sdk');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Read OAuth token from SPCS-provided file
const getSnowflakeOAuthToken = () => {
  try {
    const fs = require('fs');
    const token = fs.readFileSync('/snowflake/session/token', 'utf8').trim();
    console.log('Successfully read OAuth token from /snowflake/session/token');
    return token;
  } catch (error) {
    console.log('OAuth token file not found, falling back to other auth methods');
    return null;
  }
};

// Snowflake connection configuration using SPCS-provided credentials
const getSnowflakeConfig = (ingressUserToken = null) => {
  console.log('SPCS Environment Variables:');
  console.log(`  SNOWFLAKE_ACCOUNT: ${process.env.SNOWFLAKE_ACCOUNT}`);
  console.log(`  SNOWFLAKE_HOST: ${process.env.SNOWFLAKE_HOST}`);
  console.log(`  SNOWFLAKE_DATABASE: ${process.env.SNOWFLAKE_DATABASE}`);
  console.log(`  SNOWFLAKE_SCHEMA: ${process.env.SNOWFLAKE_SCHEMA}`);
  
  const config = {
    database: process.env.SNOWFLAKE_DATABASE || 'SQL_QUERY_APP_DB',
    schema: process.env.SNOWFLAKE_SCHEMA || 'PUBLIC',
    warehouse: process.env.SNOWFLAKE_WAREHOUSE,
    role: process.env.SNOWFLAKE_ROLE,
    clientSessionKeepAlive: true,
    clientSessionKeepAliveHeartbeatFrequency: 3600
  };
  
  // Try SPCS OAuth token first (recommended method)
  const oauthToken = getSnowflakeOAuthToken();
  if (oauthToken && process.env.SNOWFLAKE_HOST && process.env.SNOWFLAKE_ACCOUNT) {
    console.log('Using SPCS OAuth token authentication (recommended)');
    config.host = process.env.SNOWFLAKE_HOST;
    config.account = process.env.SNOWFLAKE_ACCOUNT;
    
    // For caller's rights: combine OAuth token with ingress user token
    if (ingressUserToken) {
      console.log('Using caller\'s rights with ingress user token');
      config.token = oauthToken + '.' + ingressUserToken;
    } else {
      console.log('Using owner\'s rights with OAuth token only');
      config.token = oauthToken;
    }
    config.authenticator = 'oauth';
  } else {
    // Fallback to other authentication methods
    console.log('SPCS OAuth not available, using fallback authentication');
    config.account = process.env.SNOWFLAKE_ACCOUNT;
    config.username = process.env.SNOWFLAKE_USERNAME;
    
    if (process.env.SNOWFLAKE_PASSWORD && process.env.SNOWFLAKE_PASSWORD !== '') {
      config.password = process.env.SNOWFLAKE_PASSWORD;
    } else if (process.env.SNOWFLAKE_PRIVATE_KEY) {
      config.privateKey = process.env.SNOWFLAKE_PRIVATE_KEY;
      config.authenticator = 'SNOWFLAKE_JWT';
    } else {
      config.authenticator = 'SNOWFLAKE';
    }
  }
  
  console.log(`Final connection config: host=${config.host}, account=${config.account}, authenticator=${config.authenticator}, callers_rights=${!!ingressUserToken}`);
  return config;
};

// Create Snowflake connection
const createConnection = (ingressUserToken = null) => {
  return snowflake.createConnection(getSnowflakeConfig(ingressUserToken));
};

// Connect to Snowflake with error handling
const connectToSnowflake = (connection) => {
  return new Promise((resolve, reject) => {
    console.log('About to call connection.connect()...');
    
    // Set a timeout to handle cases where callback doesn't fire
    const timeout = setTimeout(() => {
      console.log('Connection callback timeout - assuming connection is ready based on SDK logs');
      resolve(connection);
    }, 5000); // 5 second timeout
    
    connection.connect((err, conn) => {
      console.log('connection.connect() callback fired!');
      clearTimeout(timeout);
      if (err) {
        console.error('Unable to connect to Snowflake:', err);
        reject(err);
      } else {
        console.log('Successfully connected to Snowflake, resolving Promise...');
        resolve(conn);
      }
    });
    console.log('connection.connect() called, waiting for callback...');
  });
};

// Execute SQL query
const executeQuery = (connection, sqlText, useCallersRights = false) => {
  return new Promise((resolve, reject) => {
    // Prepare the SQL statement based on rights mode
    let finalSql = sqlText;
    
    // If using caller's rights, we need to execute within a stored procedure context
    // For demonstration, we'll add a comment to indicate the execution mode
    if (useCallersRights) {
      finalSql = `-- CALLER'S RIGHTS MODE\n${sqlText}`;
    } else {
      finalSql = `-- OWNER'S RIGHTS MODE\n${sqlText}`;
    }

    const startTime = Date.now();
    console.log(`Executing query: ${finalSql.substring(0, 100)}...`);
    
    connection.execute({
      sqlText: finalSql,
      timeout: 120000, // 2 minute timeout
      complete: (err, stmt, rows) => {
        const executionTime = Date.now() - startTime;
        console.log(`Query execution completed in ${executionTime}ms`);
        
        if (err) {
          console.error('Failed to execute statement:', err);
          console.error('Error code:', err.code);
          console.error('Error message:', err.message);
          reject(err);
        } else {
          console.log(`Query returned ${rows ? rows.length : 0} rows`);
          
          // Get column information
          const columns = stmt.getColumns();
          const columnNames = columns.map(col => col.getName());
          
          // Format the results
          const result = {
            data: rows || [],
            columns: columnNames,
            rowCount: rows ? rows.length : 0,
            metadata: {
              sqlText: stmt.getSqlText(),
              statementId: stmt.getStatementId(),
              executionMode: useCallersRights ? "caller's_rights" : "owner's_rights",
              columns: columns.map(col => ({
                name: col.getName(),
                type: col.getType(),
                nullable: col.isNullable(),
                scale: col.getScale(),
                precision: col.getPrecision()
              }))
            }
          };
          
          resolve(result);
        }
      }
    });
  });
};

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    service: 'snowflake-sql-backend'
  });
});

// Get connection info
app.get('/api/info', async (req, res) => {
  let connection;
  try {
    connection = createConnection();
    await connectToSnowflake(connection);
    
    const result = await executeQuery(connection, 
      'SELECT CURRENT_USER() as USER, CURRENT_ROLE() as ROLE, CURRENT_DATABASE() as DATABASE, CURRENT_SCHEMA() as SCHEMA, CURRENT_WAREHOUSE() as WAREHOUSE'
    );
    
    res.json({
      connected: true,
      connectionInfo: result.data[0],
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Connection info error:', error);
    res.status(500).json({
      connected: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  } finally {
    if (connection) {
      connection.destroy();
    }
  }
});

// Execute SQL query endpoint
app.post('/api/execute', async (req, res) => {
  console.log(`[${new Date().toISOString()}] POST /api/execute received`);
  console.log('Request body:', JSON.stringify(req.body, null, 2));
  
  // Check for SPCS ingress user headers for caller's rights
  const ingressUser = req.headers['sf-context-current-user'];
  const ingressUserToken = req.headers['sf-context-current-user-token'];
  
  console.log('SPCS Headers:');
  console.log(`  Sf-Context-Current-User: ${ingressUser || 'Not present'}`);
  console.log(`  Sf-Context-Current-User-Token: ${ingressUserToken ? 'Present' : 'Not present'}`);
  
  const { query, useCallersRights = false } = req.body;
  
  if (!query || typeof query !== 'string') {
    return res.status(400).json({
      error: 'SQL query is required and must be a string'
    });
  }

  if (query.trim().length === 0) {
    return res.status(400).json({
      error: 'SQL query cannot be empty'
    });
  }

  // Determine execution mode based on useCallersRights and availability of ingress token
  const actualUseCallersRights = useCallersRights && ingressUserToken;
  const executionMode = actualUseCallersRights ? "caller's_rights" : "owner's_rights";
  
  if (useCallersRights && !ingressUserToken) {
    console.log('Caller\'s rights requested but no ingress user token available, falling back to owner\'s rights');
  }

  console.log(`Starting database connection for ${executionMode}...`);
  let connection;
  try {
    // Create connection with or without ingress user token
    connection = createConnection(actualUseCallersRights ? ingressUserToken : null);
    console.log('Connection object created, attempting to connect to Snowflake...');
    await connectToSnowflake(connection);
    console.log('Successfully connected to Snowflake');
    
    // Set query tag to indicate execution mode
    const queryTag = actualUseCallersRights ? 'CALLERS_RIGHTS_EXECUTION' : 'OWNERS_RIGHTS_EXECUTION';
    await executeQuery(connection, `SET QUERY_TAG = '${queryTag}'`, false);
    
    console.log(`Executing query with ${executionMode}...`);
    const result = await executeQuery(connection, query, actualUseCallersRights);
    
    // Add additional metadata about the execution context
    const responseData = {
      ...result,
      metadata: {
        ...result.metadata,
        executionMode: executionMode,
        ingressUser: ingressUser || null,
        hasIngressToken: !!ingressUserToken,
        note: actualUseCallersRights 
          ? `Query executed with caller's rights as user: ${ingressUser}` 
          : "Query executed with owner's rights using service account"
      }
    };
    
    res.json(responseData);
    
  } catch (error) {
    console.error('Query execution error:', error);
    
    // Parse Snowflake errors for better user experience
    let errorMessage = error.message;
    if (error.code) {
      errorMessage = `Snowflake Error ${error.code}: ${error.message}`;
    }
    
    res.status(500).json({
      error: errorMessage,
      sqlState: error.sqlState,
      code: error.code,
      timestamp: new Date().toISOString(),
      executionMode: useCallersRights ? "caller's_rights" : "owner's_rights"
    });
  } finally {
    if (connection) {
      connection.destroy();
    }
  }
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  console.log(`[${new Date().toISOString()}] Health check requested`);
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    snowflake_account: process.env.SNOWFLAKE_ACCOUNT || 'Not configured',
    snowflake_host: process.env.SNOWFLAKE_HOST || 'Not configured'
  });
});

// Note: Stored procedure endpoints removed - the application handles 
// owner's rights vs caller's rights execution directly

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal server error',
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    path: req.originalUrl,
    timestamp: new Date().toISOString()
  });
});

// Start server
const server = app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Snowflake Account: ${process.env.SNOWFLAKE_ACCOUNT || 'Not configured'}`);
});

// Set server timeout for long-running SQL queries (5 minutes)
server.timeout = 300000; // 300 seconds = 5 minutes
server.keepAliveTimeout = 300000;
server.headersTimeout = 310000; // Should be slightly higher than keepAliveTimeout
