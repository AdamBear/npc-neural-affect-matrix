#!/bin/bash

# NPC Neural Affect Matrix - Web Server Launcher
# This script simplifies running the web server in different modes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PORT=${PORT:-3000}
MODE=${1:-dev}

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  🧠 NPC Neural Affect Matrix - Web Server${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

case "$MODE" in
  dev|development)
    echo -e "${GREEN}Starting in DEVELOPMENT mode...${NC}"
    echo -e "${YELLOW}Port: ${PORT}${NC}"
    echo ""
    RUST_LOG=npc_neural_affect_matrix=debug,tower_http=debug PORT=$PORT cargo run
    ;;

  prod|production)
    echo -e "${GREEN}Starting in PRODUCTION mode (optimized build)...${NC}"
    echo -e "${YELLOW}Port: ${PORT}${NC}"
    echo ""
    RUST_LOG=npc_neural_affect_matrix=info,tower_http=info PORT=$PORT cargo run --release
    ;;

  build)
    echo -e "${GREEN}Building optimized binary...${NC}"
    cargo build --release
    echo ""
    echo -e "${GREEN}✅ Build complete!${NC}"
    echo -e "Binary location: ${BLUE}./target/release/npc-neural-affect-matrix${NC}"
    ;;

  docker)
    echo -e "${GREEN}Starting with Docker Compose...${NC}"
    docker-compose up --build
    ;;

  test)
    echo -e "${GREEN}Running tests...${NC}"
    cargo test
    ;;

  check)
    echo -e "${GREEN}Checking compilation...${NC}"
    cargo check
    echo -e "${GREEN}✅ Check passed!${NC}"
    ;;

  *)
    echo -e "${RED}Unknown mode: $MODE${NC}"
    echo ""
    echo "Usage: $0 [mode]"
    echo ""
    echo "Available modes:"
    echo "  dev          - Development mode (default, hot reload)"
    echo "  prod         - Production mode (optimized)"
    echo "  build        - Build optimized binary"
    echo "  docker       - Run with Docker Compose"
    echo "  test         - Run tests"
    echo "  check        - Check compilation"
    echo ""
    echo "Example:"
    echo "  $0 dev              # Start in development mode"
    echo "  PORT=8080 $0 prod  # Production on port 8080"
    exit 1
    ;;
esac
