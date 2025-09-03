#!/bin/bash

# Local development setup script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to check if Node.js is installed
check_node() {
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed"
        print_warning "Please install Node.js 18 or later from https://nodejs.org/"
        exit 1
    fi
    
    NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        print_error "Node.js version 18 or later is required. Current version: $(node --version)"
        exit 1
    fi
    
    print_success "Node.js $(node --version) is installed"
}

# Function to check if npm is installed
check_npm() {
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed"
        exit 1
    fi
    
    print_success "npm $(npm --version) is available"
}

# Function to setup environment file
setup_env() {
    if [ ! -f ".env" ]; then
        if [ -f "backend/env.example" ]; then
            print_status "Creating .env file from template..."
            cp backend/env.example .env
            print_warning "Please edit .env file with your Snowflake credentials:"
            print_warning "nano .env"
        else
            print_status "Creating .env file..."
            cat > .env << EOF
# Snowflake Connection Configuration
SNOWFLAKE_ACCOUNT=your-account-identifier
SNOWFLAKE_USERNAME=your-username
SNOWFLAKE_PASSWORD=your-password
SNOWFLAKE_DATABASE=SQL_QUERY_APP_DB
SNOWFLAKE_SCHEMA=PUBLIC
SNOWFLAKE_WAREHOUSE=your-warehouse
SNOWFLAKE_ROLE=your-role

# Server Configuration
PORT=3001
NODE_ENV=development
EOF
            print_warning "Please edit .env file with your Snowflake credentials"
        fi
    else
        print_success ".env file already exists"
    fi
}

# Function to install backend dependencies
setup_backend() {
    print_status "Setting up backend..."
    
    cd backend
    
    if [ ! -d "node_modules" ]; then
        print_status "Installing backend dependencies..."
        npm install
    else
        print_status "Backend dependencies already installed"
    fi
    
    cd ..
    print_success "Backend setup completed"
}

# Function to install frontend dependencies
setup_frontend() {
    print_status "Setting up frontend..."
    
    cd frontend
    
    if [ ! -d "node_modules" ]; then
        print_status "Installing frontend dependencies..."
        npm install
    else
        print_status "Frontend dependencies already installed"
    fi
    
    cd ..
    print_success "Frontend setup completed"
}

# Function to test backend
test_backend() {
    print_status "Testing backend setup..."
    
    cd backend
    
    # Check if the main files exist
    if [ ! -f "server.js" ]; then
        print_error "Backend server.js not found"
        exit 1
    fi
    
    if [ ! -f "package.json" ]; then
        print_error "Backend package.json not found"
        exit 1
    fi
    
    print_success "Backend files are in place"
    cd ..
}

# Function to test frontend
test_frontend() {
    print_status "Testing frontend setup..."
    
    cd frontend
    
    # Check if the main files exist
    if [ ! -f "src/App.js" ]; then
        print_error "Frontend App.js not found"
        exit 1
    fi
    
    if [ ! -f "package.json" ]; then
        print_error "Frontend package.json not found"
        exit 1
    fi
    
    print_success "Frontend files are in place"
    cd ..
}

# Function to show development commands
show_dev_commands() {
    print_success "Local development environment is ready!"
    echo ""
    echo "=== Development Commands ==="
    echo ""
    echo "Backend (Terminal 1):"
    echo "  cd backend"
    echo "  npm run dev        # Start backend in development mode"
    echo "  npm start          # Start backend in production mode"
    echo ""
    echo "Frontend (Terminal 2):"
    echo "  cd frontend"
    echo "  npm start          # Start frontend development server"
    echo "  npm run build      # Build frontend for production"
    echo ""
    echo "Using Docker Compose (Alternative):"
    echo "  docker-compose up --build     # Build and start all services"
    echo "  docker-compose up -d          # Start in background"
    echo "  docker-compose logs -f        # View logs"
    echo "  docker-compose down           # Stop all services"
    echo ""
    echo "=== URLs ==="
    echo "Frontend: http://localhost:3000"
    echo "Backend:  http://localhost:3001"
    echo "API Health: http://localhost:3001/api/health"
    echo ""
    echo "=== Next Steps ==="
    echo "1. Edit .env file with your Snowflake credentials"
    echo "2. Run the database setup: ./scripts/deploy.sh database-only"
    echo "3. Start the backend: cd backend && npm run dev"
    echo "4. Start the frontend: cd frontend && npm start"
    echo "5. Open http://localhost:3000 in your browser"
}

# Main function
main() {
    echo "========================================="
    echo "Local Development Environment Setup"
    echo "========================================="
    echo ""
    
    check_node
    check_npm
    setup_env
    setup_backend
    setup_frontend
    test_backend
    test_frontend
    show_dev_commands
}

# Handle script arguments
case "${1:-setup}" in
    "setup")
        main
        ;;
    "backend")
        check_node
        check_npm
        setup_backend
        test_backend
        print_success "Backend setup completed"
        ;;
    "frontend")
        check_node
        check_npm
        setup_frontend
        test_frontend
        print_success "Frontend setup completed"
        ;;
    "clean")
        print_status "Cleaning up node_modules..."
        rm -rf backend/node_modules frontend/node_modules
        print_success "Cleanup completed"
        ;;
    "help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  setup      Full local development setup (default)"
        echo "  backend    Setup backend only"
        echo "  frontend   Setup frontend only"
        echo "  clean      Remove node_modules directories"
        echo "  help       Show this help"
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
