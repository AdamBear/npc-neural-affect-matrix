#!/bin/bash

# Simple test script for the NPC Neural Affect Matrix Web API
# No external dependencies required (no jq needed)

set -e

BASE_URL=${BASE_URL:-http://localhost:3000}
API_URL="$BASE_URL/api/v1"

echo "🧪 Testing NPC Neural Affect Matrix Web API"
echo "Base URL: $BASE_URL"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Test counter
PASSED=0
FAILED=0

# Helper function to check HTTP status
check_response() {
    local name="$1"
    local response="$2"

    if echo "$response" | grep -q '"success":true'; then
        echo -e "${GREEN}✅ PASSED${NC}: $name"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}❌ FAILED${NC}: $name"
        echo "Response: $response"
        FAILED=$((FAILED + 1))
    fi
    echo ""
}

# Test 1: Health Check
echo -e "${BLUE}📋 Test 1: Health Check${NC}"
RESPONSE=$(curl -s "$BASE_URL/health")
echo "$RESPONSE"
check_response "Health Check" "$RESPONSE"

# Test 2: Initialize Model (Optional - model auto-initializes on first use)
echo -e "${BLUE}🧠 Test 2: Initialize Neural Model (Optional)${NC}"
RESPONSE=$(curl -s -X POST "$API_URL/initialize" \
  -H "Content-Type: application/json" \
  -d '{}')
echo "$RESPONSE"

# Check if initialization succeeded or if model was already initialized
if echo "$RESPONSE" | grep -q '"success":true'; then
    echo -e "${GREEN}✅ PASSED${NC}: Initialize Model"
    PASSED=$((PASSED + 1))
elif echo "$RESPONSE" | grep -q "already initialized"; then
    echo -e "${GREEN}✅ PASSED${NC}: Initialize Model (already initialized)"
    PASSED=$((PASSED + 1))
else
    echo -e "${YELLOW}⚠️  SKIPPED${NC}: Initialize Model (will auto-initialize on first use)"
    echo "Note: Model initialization is optional and happens automatically on first NPC creation"
fi
echo ""

# Test 3: Create NPC
echo -e "${BLUE}👤 Test 3: Create NPC (Friendly Shopkeeper)${NC}"
RESPONSE=$(curl -s -X POST "$API_URL/npcs" \
  -H "Content-Type: application/json" \
  -d '{
    "config": {
      "identity": {
        "name": "Marcus the Shopkeeper",
        "background": "A friendly merchant who has run the general store for 20 years. Known for fair prices and good advice."
      },
      "personality": {
        "valence": 0.3,
        "arousal": -0.1
      },
      "memory": {
        "decay_rate": 0.1
      }
    }
  }')
echo "$RESPONSE"

# Extract NPC ID (simple grep/sed approach without jq)
NPC_ID=$(echo "$RESPONSE" | grep -o '"npc_id":"[^"]*"' | sed 's/"npc_id":"\([^"]*\)"/\1/')
echo -e "${GREEN}Created NPC with ID: $NPC_ID${NC}"
check_response "Create NPC" "$RESPONSE"

if [ -z "$NPC_ID" ]; then
    echo -e "${RED}Failed to extract NPC ID. Aborting remaining tests.${NC}"
    exit 1
fi

# Test 4: Positive Interaction
echo -e "${BLUE}💬 Test 4: Positive Interaction${NC}"
echo "Player: 'Thank you for all your help over the years!'"
RESPONSE=$(curl -s -X POST "$API_URL/npcs/$NPC_ID/evaluate" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Thank you for all your help over the years!",
    "source_id": "player"
  }')
echo "$RESPONSE"
check_response "Positive Interaction" "$RESPONSE"

# Test 5: Another Positive Interaction
echo -e "${BLUE}💬 Test 5: Another Positive Interaction${NC}"
echo "Player: 'Your prices are always fair!'"
RESPONSE=$(curl -s -X POST "$API_URL/npcs/$NPC_ID/evaluate" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Your prices are always fair!",
    "source_id": "player"
  }')
echo "$RESPONSE"
check_response "Another Positive Interaction" "$RESPONSE"

# Test 6: Negative Interaction
echo -e "${BLUE}💬 Test 6: Negative Interaction${NC}"
echo "Thief: 'Give me all your gold or else!'"
RESPONSE=$(curl -s -X POST "$API_URL/npcs/$NPC_ID/evaluate" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Give me all your gold or else!",
    "source_id": "thief"
  }')
echo "$RESPONSE"
check_response "Negative Interaction" "$RESPONSE"

# Test 7: Get Overall Emotion
echo -e "${BLUE}😊 Test 7: Get Overall Current Emotion${NC}"
RESPONSE=$(curl -s "$API_URL/npcs/$NPC_ID/emotion")
echo "$RESPONSE"
check_response "Get Overall Emotion" "$RESPONSE"

# Test 8: Get Emotion Towards Player
echo -e "${BLUE}❤️  Test 8: Get Emotion Towards Player${NC}"
RESPONSE=$(curl -s "$API_URL/npcs/$NPC_ID/emotion/player")
echo "$RESPONSE"
check_response "Get Emotion Towards Player" "$RESPONSE"

# Test 9: Get Emotion Towards Thief
echo -e "${BLUE}😠 Test 9: Get Emotion Towards Thief${NC}"
RESPONSE=$(curl -s "$API_URL/npcs/$NPC_ID/emotion/thief")
echo "$RESPONSE"
check_response "Get Emotion Towards Thief" "$RESPONSE"

# Test 10: Get All Memory
echo -e "${BLUE}💾 Test 10: Get All Memory Records${NC}"
RESPONSE=$(curl -s "$API_URL/npcs/$NPC_ID/memory")
echo "$RESPONSE"
check_response "Get All Memory" "$RESPONSE"

# Test 11: Clear Memory
echo -e "${YELLOW}🗑️  Test 11: Clear Memory${NC}"
RESPONSE=$(curl -s -X DELETE "$API_URL/npcs/$NPC_ID/memory")
echo "$RESPONSE"
check_response "Clear Memory" "$RESPONSE"

# Test 12: Verify Memory Cleared
echo -e "${BLUE}✅ Test 12: Verify Memory is Empty${NC}"
RESPONSE=$(curl -s "$API_URL/npcs/$NPC_ID/memory")
echo "$RESPONSE"
check_response "Verify Memory Cleared" "$RESPONSE"

# Test 13: Remove NPC
echo -e "${YELLOW}❌ Test 13: Remove NPC Session${NC}"
RESPONSE=$(curl -s -X DELETE "$API_URL/npcs/$NPC_ID")
echo "$RESPONSE"
check_response "Remove NPC" "$RESPONSE"

# Summary
echo ""
echo "═══════════════════════════════════════"
echo -e "${BLUE}📊 Test Summary${NC}"
echo "═══════════════════════════════════════"
echo -e "${GREEN}✅ Passed: $PASSED${NC}"
echo -e "${RED}❌ Failed: $FAILED${NC}"
echo "═══════════════════════════════════════"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some tests failed. Please check the output above.${NC}"
    exit 1
fi
