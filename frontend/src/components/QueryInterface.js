import React, { useState, useEffect } from 'react';
import axios from 'axios';

const QueryInterface = () => {
  const [query, setQuery] = useState('-- Try these example queries:\n-- SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_DATABASE(), CURRENT_SCHEMA();\n-- SELECT * FROM SAMPLE_DATA LIMIT 10;\n-- SELECT * FROM EMPLOYEE_SUMMARY;\n\nSELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_DATABASE(), CURRENT_SCHEMA();');
  const [results, setResults] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);
  const [useCallersRights, setUseCallersRights] = useState(false);
  const [executionTime, setExecutionTime] = useState(null);
  const [backendStatus, setBackendStatus] = useState('checking'); // 'connected', 'disconnected', 'checking'

  // Check backend connection
  const checkBackendConnection = async () => {
    try {
      const response = await axios.get('/api/health', { timeout: 5000 });
      setBackendStatus('connected');
      return true;
    } catch (err) {
      console.error('Backend connection check failed:', err);
      setBackendStatus('disconnected');
      return false;
    }
  };

  // Check connection on component mount and periodically
  useEffect(() => {
    checkBackendConnection();
    
    // Check connection every 30 seconds
    const interval = setInterval(checkBackendConnection, 30000);
    
    return () => clearInterval(interval);
  }, []);

  const executeQuery = async () => {
    if (!query.trim()) {
      setError('Please enter a SQL query');
      return;
    }

    setLoading(true);
    setError(null);
    setResults(null);
    setExecutionTime(null);

    try {
      const startTime = Date.now();
      const response = await axios.post('/api/execute', {
        query: query.trim(),
        useCallersRights: useCallersRights
      });

      const endTime = Date.now();
      setExecutionTime(endTime - startTime);
      setResults(response.data);
    } catch (err) {
      console.error('Query execution error:', err);
      setError(err.response?.data?.error || 'An error occurred while executing the query');
    } finally {
      setLoading(false);
    }
  };

  const handleKeyPress = (e) => {
    if (e.ctrlKey && e.key === 'Enter') {
      executeQuery();
    }
  };

  const clearResults = () => {
    setResults(null);
    setError(null);
    setExecutionTime(null);
  };

  const formatValue = (value) => {
    if (value === null || value === undefined) {
      return 'NULL';
    }
    if (typeof value === 'object') {
      return JSON.stringify(value);
    }
    return String(value);
  };

  return (
    <div>
      <div className="query-section">
        <div className="controls">
          <div className="status-container">
            <div className="connection-status">
              <span className="status-label"><strong>Backend Status:</strong></span>
              <span className={`status-indicator ${backendStatus}`}>
                {backendStatus === 'connected' && '🟢 Connected'}
                {backendStatus === 'disconnected' && '🔴 Disconnected'}
                {backendStatus === 'checking' && '🟡 Checking...'}
              </span>
            </div>
          </div>
          
          <div className="toggle-container">
            <label htmlFor="rights-toggle">
              <strong>Execution Mode:</strong>
            </label>
            <span>{useCallersRights ? "Caller's Rights" : "Owner's Rights"}</span>
            <label className="toggle">
              <input
                id="rights-toggle"
                type="checkbox"
                checked={useCallersRights}
                onChange={(e) => setUseCallersRights(e.target.checked)}
              />
              <span className="slider"></span>
            </label>
          </div>
          
          <div style={{ display: 'flex', gap: '10px' }}>
            <button 
              className="button" 
              onClick={executeQuery}
              disabled={loading}
            >
              {loading ? 'Executing...' : 'Execute Query (Ctrl+Enter)'}
            </button>
            <button 
              className="button" 
              onClick={clearResults}
              style={{ backgroundColor: '#6b7280' }}
            >
              Clear Results
            </button>
          </div>
        </div>

        <div className="query-info">
          <strong>Execution Mode:</strong> {useCallersRights ? "Caller's Rights" : "Owner's Rights"} - 
          {useCallersRights 
            ? " Query will execute attempting to use the calling user's permissions (simulated in container)"
            : " Query will execute with the container service account's permissions (default)"
          }
        </div>

        <textarea
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={handleKeyPress}
          className="sql-textarea"
          rows="10"
          placeholder="Enter your SQL query here..."
          style={{
            width: '100%',
            fontFamily: 'Monaco, Menlo, "Ubuntu Mono", monospace',
            fontSize: '14px',
            padding: '10px',
            border: '1px solid #ddd',
            borderRadius: '4px',
            resize: 'vertical',
            minHeight: '200px'
          }}
        />
      </div>

      {loading && (
        <div className="results-section">
          <div className="loading">
            <div>Executing query...</div>
            <div style={{ marginTop: '10px', fontSize: '14px' }}>
              Mode: {useCallersRights ? "Caller's Rights" : "Owner's Rights"}
            </div>
          </div>
        </div>
      )}

      {error && (
        <div className="results-section">
          <div className="error">
            <strong>Error:</strong> {error}
          </div>
        </div>
      )}

      {results && (
        <div className="results-section">
          <div className="success">
            <strong>Query executed successfully!</strong>
            {executionTime && <span> (Execution time: {executionTime}ms)</span>}
            <div style={{ marginTop: '5px', fontSize: '14px' }}>
              Mode: {useCallersRights ? "Caller's Rights" : "Owner's Rights"}
            </div>
          </div>

          {results.data && results.data.length > 0 ? (
            <div>
              <h3>Results ({results.data.length} rows):</h3>
              <div style={{ overflowX: 'auto' }}>
                <table className="table">
                  <thead>
                    <tr>
                      {results.columns && results.columns.map((column, index) => (
                        <th key={index}>{column}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {results.data.map((row, rowIndex) => (
                      <tr key={rowIndex}>
                        {Object.values(row).map((value, colIndex) => (
                          <td key={colIndex}>{formatValue(value)}</td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          ) : (
            <div>
              <h3>Query executed successfully</h3>
              <p>No rows returned.</p>
            </div>
          )}

          {results.metadata && (
            <div style={{ marginTop: '20px', fontSize: '14px', color: '#666' }}>
              <strong>Query Metadata:</strong>
              <pre style={{ background: '#f8f9fa', padding: '10px', borderRadius: '4px', overflow: 'auto' }}>
                {JSON.stringify(results.metadata, null, 2)}
              </pre>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default QueryInterface;
