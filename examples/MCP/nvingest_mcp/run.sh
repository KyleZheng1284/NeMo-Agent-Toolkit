#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# NV-Ingest MCP RAG Example - Quick Run Script
# =============================================================================
#
# This script provides easy commands to run the NAT MCP example in Docker.
#
# Quick Start (Recommended):
#   ./run.sh up              # Build and start container (runs in background)
#   ./run.sh exec            # Exec into running container
#   # Now run NAT commands inside...
#   ./run.sh down            # Stop container
#
# Alternative (one-off runs):
#   ./run.sh shell           # Run temporary container with shell
#   ./run.sh direct <query>  # Run single query
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check for NVIDIA_API_KEY
if [ -z "$NVIDIA_API_KEY" ]; then
    echo "Warning: NVIDIA_API_KEY is not set. LLM calls may fail."
    echo "Set it with: export NVIDIA_API_KEY=<your_key>"
fi

case "$1" in
    # =========================================================================
    # Long-running container management (RECOMMENDED)
    # =========================================================================
    up)
        echo "Building and starting container in background..."
        docker compose up -d --build
        echo ""
        echo "Container is running! Use these commands:"
        echo "  ./run.sh exec    # Get a shell inside the container"
        echo "  ./run.sh down    # Stop the container"
        echo "  ./run.sh logs    # View container logs"
        ;;
    
    down)
        echo "Stopping container..."
        docker compose down
        echo "Container stopped."
        ;;
    
    exec)
        echo "Connecting to running container..."
        echo "Run NAT commands like:"
        echo "  nat run --config_file /app/nvingest_mcp/configs/nvingest_agent_direct.yml --input 'Your query'"
        echo ""
        docker compose exec nat bash
        ;;
    
    logs)
        docker compose logs -f
        ;;
    
    status)
        echo "Container status:"
        docker compose ps
        echo ""
        echo "Container logs (last 20 lines):"
        docker compose logs --tail=20
        ;;

    # =========================================================================
    # One-off container commands
    # =========================================================================
    build)
        echo "Building Docker image..."
        docker compose build
        echo "Build complete!"
        ;;
    
    shell)
        echo "Starting temporary interactive shell..."
        docker compose run --rm nat bash
        ;;
    
    direct)
        shift
        if [ -z "$1" ]; then
            echo "Usage: ./run.sh direct <query>"
            echo "Example: ./run.sh direct 'Ingest the file /app/nv-ingest-lib-mode/multimodal_test.pdf into the vector database'"
            exit 1
        fi
        echo "Running direct workflow..."
        docker compose run --rm nat nat run \
            --config_file /app/nvingest_mcp/configs/nvingest_agent_direct.yml \
            --input "$*"
        ;;
    
    server)
        echo "Starting MCP server on port 9901..."
        echo "Press Ctrl+C to stop"
        docker compose run --rm nat nat mcp serve \
            --config_file /app/nvingest_mcp/configs/nvingest_mcp_server.yml \
            --host 0.0.0.0
        ;;
    
    client)
        shift
        if [ -z "$1" ]; then
            echo "Usage: ./run.sh client <query>"
            echo "Note: MCP server must be running first (./run.sh server)"
            exit 1
        fi
        echo "Running MCP client workflow..."
        docker compose run --rm nat nat run \
            --config_file /app/nvingest_mcp/configs/nvingest_mcp_client.yml \
            --input "$*"
        ;;
    
    list-tools)
        echo "Listing MCP server tools..."
        docker compose run --rm nat nat mcp client tool list \
            --url http://localhost:9901/mcp
        ;;
    
    ping)
        echo "Pinging MCP server..."
        docker compose run --rm nat nat mcp client ping \
            --url http://localhost:9901/mcp
        ;;

    # =========================================================================
    # Testing/debugging commands
    # =========================================================================
    test-milvus)
        echo "Testing Milvus connection from container..."
        docker compose run --rm nat python -c "
from pymilvus import connections
try:
    connections.connect(uri='http://localhost:19530')
    print('✓ Milvus connection successful!')
except Exception as e:
    print(f'✗ Milvus connection failed: {e}')
"
        ;;
    
    test-embedding)
        echo "Testing embedding service connection from container..."
        docker compose run --rm nat python -c "
import requests
try:
    r = requests.get('http://localhost:8012/v1/models', timeout=5)
    print(f'✓ Embedding service reachable! Status: {r.status_code}')
except Exception as e:
    print(f'✗ Embedding service connection failed: {e}')
"
        ;;
    
    test-nvingest)
        echo "Testing NV-Ingest connection from container..."
        docker compose run --rm nat python -c "
import requests
try:
    r = requests.get('http://localhost:7670/health', timeout=5)
    print(f'✓ NV-Ingest reachable! Status: {r.status_code}')
except Exception as e:
    print(f'✗ NV-Ingest connection failed: {e}')
"
        ;;
    
    test-all)
        echo "Testing all service connections..."
        echo ""
        $0 test-milvus
        echo ""
        $0 test-embedding
        echo ""
        $0 test-nvingest
        ;;
    
    help|*)
        echo "NV-Ingest MCP RAG Example - Docker Runner"
        echo ""
        echo "=== RECOMMENDED WORKFLOW (Long-running container) ==="
        echo ""
        echo "  ./run.sh up       Build & start container in background"
        echo "  ./run.sh exec     Get shell inside running container"
        echo "  ./run.sh down     Stop the container"
        echo "  ./run.sh logs     View container logs"
        echo "  ./run.sh status   Show container status"
        echo ""
        echo "=== ONE-OFF COMMANDS ==="
        echo ""
        echo "  ./run.sh build           Build Docker image only"
        echo "  ./run.sh shell           Start temporary shell container"
        echo "  ./run.sh direct <query>  Run single query"
        echo "  ./run.sh server          Start MCP server (port 9901)"
        echo "  ./run.sh client <query>  Run MCP client workflow"
        echo ""
        echo "=== TESTING ==="
        echo ""
        echo "  ./run.sh test-all        Test all service connections"
        echo "  ./run.sh test-milvus     Test Milvus connection"
        echo "  ./run.sh test-embedding  Test embedding service"
        echo "  ./run.sh test-nvingest   Test NV-Ingest connection"
        echo ""
        echo "=== EXAMPLES ==="
        echo ""
        echo "  # Start container and work interactively"
        echo "  ./run.sh up"
        echo "  ./run.sh exec"
        echo "  nat run --config_file /app/nvingest_mcp/configs/nvingest_agent_direct.yml \\"
        echo "      --input 'Ingest /app/nv-ingest-lib-mode/multimodal_test.pdf'"
        echo ""
        echo "  # One-off query"
        echo "  ./run.sh direct 'What is machine learning?'"
        echo ""
        echo "Prerequisites:"
        echo "  - Docker and Docker Compose installed"
        echo "  - NVIDIA_API_KEY environment variable set"
        echo "  - NV-Ingest services running (docker ps | grep nv-ingest)"
        ;;
esac
