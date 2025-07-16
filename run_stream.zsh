#!/bin/zsh

# Stream Server Manager
# Manages both producer (FastAPI) and consumer (HTTP server) with graceful shutdown

set -e

# Configuration
PRODUCER_PORT=8000
CONSUMER_PORT=8080
PRODUCER_PID_FILE=".producer.pid"
CONSUMER_PID_FILE=".consumer.pid"
LOG_DIR="logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create logs directory
mkdir -p "$LOG_DIR"

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

# Function to check if port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to kill processes on specific port
kill_port() {
    local port=$1
    local pids=$(lsof -Pi :$port -sTCP:LISTEN -t 2>/dev/null)
    
    if [ -n "$pids" ]; then
        print_warning "Killing processes on port $port: $pids"
        echo $pids | xargs kill -9 2>/dev/null || true
        sleep 1
        
        # Verify port is free
        if check_port $port; then
            print_error "Failed to free port $port"
            return 1
        else
            print_success "Port $port is now free"
            return 0
        fi
    else
        print_status "Port $port is already free"
        return 0
    fi
}

# Function to cleanup all processes and ports
cleanup() {
    print_status "Starting cleanup process..."
    
    # Kill producer
    if [ -f "$PRODUCER_PID_FILE" ]; then
        local producer_pid=$(cat "$PRODUCER_PID_FILE")
        if kill -0 "$producer_pid" 2>/dev/null; then
            print_status "Stopping producer (PID: $producer_pid)"
            kill -TERM "$producer_pid" 2>/dev/null || true
            sleep 2
            kill -9 "$producer_pid" 2>/dev/null || true
        fi
        rm -f "$PRODUCER_PID_FILE"
    fi
    
    # Kill consumer
    if [ -f "$CONSUMER_PID_FILE" ]; then
        local consumer_pid=$(cat "$CONSUMER_PID_FILE")
        if kill -0 "$consumer_pid" 2>/dev/null; then
            print_status "Stopping consumer (PID: $consumer_pid)"
            kill -TERM "$consumer_pid" 2>/dev/null || true
            sleep 2
            kill -9 "$consumer_pid" 2>/dev/null || true
        fi
        rm -f "$CONSUMER_PID_FILE"
    fi
    
    # Clean up ports
    kill_port $PRODUCER_PORT
    kill_port $CONSUMER_PORT
    
    print_success "Cleanup completed"
}

# Function to start producer
start_producer() {
    print_status "Starting producer on port $PRODUCER_PORT..."
    
    if check_port $PRODUCER_PORT; then
        print_warning "Port $PRODUCER_PORT is already in use"
        kill_port $PRODUCER_PORT
    fi
    
    # Start producer in background
    nohup uv run uvicorn main:app --host 127.0.0.1 --port $PRODUCER_PORT --reload > "$LOG_DIR/producer.log" 2>&1 &
    local producer_pid=$!
    echo $producer_pid > "$PRODUCER_PID_FILE"
    
    # Wait for producer to start
    local attempts=0
    while [ $attempts -lt 10 ]; do
        if check_port $PRODUCER_PORT; then
            print_success "Producer started (PID: $producer_pid) on http://127.0.0.1:$PRODUCER_PORT"
            return 0
        fi
        sleep 1
        attempts=$((attempts + 1))
    done
    
    print_error "Failed to start producer"
    return 1
}

# Function to start consumer
start_consumer() {
    print_status "Starting consumer on port $CONSUMER_PORT..."
    
    if check_port $CONSUMER_PORT; then
        print_warning "Port $CONSUMER_PORT is already in use"
        kill_port $CONSUMER_PORT
    fi
    
    # Start simple HTTP server for consumer
    (cd consumer && python3 -m http.server $CONSUMER_PORT) > "$LOG_DIR/consumer.log" 2>&1 &
    local consumer_pid=$!
    echo $consumer_pid > "$CONSUMER_PID_FILE"
    
    # Wait for consumer to start
    local attempts=0
    while [ $attempts -lt 10 ]; do
        if check_port $CONSUMER_PORT; then
            print_success "Consumer started (PID: $consumer_pid) on http://127.0.0.1:$CONSUMER_PORT"
            return 0
        fi
        sleep 1
        attempts=$((attempts + 1))
    done
    
    print_error "Failed to start consumer"
    return 1
}

# Function to show status
show_status() {
    print_status "Service Status:"
    
    # Producer status
    if [ -f "$PRODUCER_PID_FILE" ]; then
        local producer_pid=$(cat "$PRODUCER_PID_FILE")
        if kill -0 "$producer_pid" 2>/dev/null; then
            print_success "Producer: Running (PID: $producer_pid) on http://127.0.0.1:$PRODUCER_PORT"
            echo "  Endpoints:"
            echo "    - Health: http://127.0.0.1:$PRODUCER_PORT/"
            echo "    - Stream: http://127.0.0.1:$PRODUCER_PORT/stream_message"
        else
            print_error "Producer: Stopped (stale PID file)"
            rm -f "$PRODUCER_PID_FILE"
        fi
    else
        print_error "Producer: Stopped"
    fi
    
    # Consumer status
    if [ -f "$CONSUMER_PID_FILE" ]; then
        local consumer_pid=$(cat "$CONSUMER_PID_FILE")
        if kill -0 "$consumer_pid" 2>/dev/null; then
            print_success "Consumer: Running (PID: $consumer_pid) on http://127.0.0.1:$CONSUMER_PORT"
        else
            print_error "Consumer: Stopped (stale PID file)"
            rm -f "$CONSUMER_PID_FILE"
        fi
    else
        print_error "Consumer: Stopped"
    fi
}

# Function to show help
show_help() {
    echo "Stream Server Manager"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     Start both producer and consumer services"
    echo "  stop      Stop all services and cleanup ports"
    echo "  restart   Restart all services"
    echo "  status    Show status of all services"
    echo "  cleanup   Force cleanup all ports and processes"
    echo "  logs      Show recent logs"
    echo "  help      Show this help message"
    echo ""
    echo "Services:"
    echo "  Producer: FastAPI server on port $PRODUCER_PORT"
    echo "  Consumer: HTTP server on port $CONSUMER_PORT"
}

# Function to show logs
show_logs() {
    print_status "Recent logs:"
    echo ""
    
    if [ -f "$LOG_DIR/producer.log" ]; then
        echo -e "${BLUE}Producer logs:${NC}"
        tail -20 "$LOG_DIR/producer.log"
        echo ""
    fi
    
    if [ -f "$LOG_DIR/consumer.log" ]; then
        echo -e "${BLUE}Consumer logs:${NC}"
        tail -20 "$LOG_DIR/consumer.log"
    fi
}

# Trap signals for graceful shutdown
trap cleanup EXIT INT TERM

# Main script logic
case "${1:-start}" in
    "start")
        print_status "Starting stream services..."
        start_producer && start_consumer
        if [ $? -eq 0 ]; then
            echo ""
            print_success "All services started successfully!"
            echo ""
            print_status "Access your services:"
            echo "  Producer API: http://127.0.0.1:$PRODUCER_PORT"
            echo "  Consumer UI:  http://127.0.0.1:$CONSUMER_PORT"
            echo ""
            print_status "Use './run_stream.zsh stop' to shutdown"
            echo ""
            print_status "Press Ctrl+C to stop services..."
            
            # Keep script running
            while true; do
                sleep 1
            done
        else
            print_error "Failed to start services"
            cleanup
            exit 1
        fi
        ;;
    "stop"|"shutdown")
        cleanup
        ;;
    "restart")
        cleanup
        sleep 2
        start_producer && start_consumer
        ;;
    "status")
        show_status
        ;;
    "cleanup")
        cleanup
        ;;
    "logs")
        show_logs
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac