import React, { useState } from 'react';
import QueryInterface from './components/QueryInterface';
import './App.css';

function App() {
  return (
    <div className="App">
      <div className="container">
        <header className="header">
          <h1>Snowflake SQL Query Interface</h1>
          <p>Execute SQL queries with Owner's Rights or Caller's Rights</p>
        </header>
        <QueryInterface />
      </div>
    </div>
  );
}

export default App;
