#!/bin/bash

# Simple test script for the NPC Neural Affect Matrix Web API
# This demonstrates the complete workflow

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
NC='\033[0m'

# Test 1: Health Check
echo -e "${BLUE}📋 Test 1: Health Check${NC}"
curl -s "$BASE_URL/health" | jq '.'
echo ""

# Test 2: Initialize Model
echo -e "${BLUE}🧠 Test 2: Initialize Neural Model${NC}"
curl -s -X POST "$API_URL/initialize" \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.'
echo ""

# Test 3: Create NPC
echo -e "${BLUE}👤 Test 3: Create NPC (Friendly Shopkeeper)${NC}"
NPC_RESPONSE=$(curl -s -X POST "$API_URL/npcs" \
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

echo "$NPC_RESPONSE" | jq '.'
NPC_ID=$(echo "$NPC_RESPONSE" | jq -r '.data.npc_id')
echo -e "${GREEN}Created NPC with ID: $NPC_ID${NC}"
echo ""

# Test 4: Positive Interaction
echo -e "${BLUE}💬 Test 4: Positive Interaction${NC}"
echo "Player: 'Thank you for all your help over the years!'"
curl -s -X POST "$API_URL/npcs/$NPC_ID/evaluate" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Thank you for all your help over the years!",
    "source_id": "player"
  }' | jq '.'
echo ""

# Test 5: Another Positive Interaction
echo -e "${BLUE}💬 Test 5: Another Positive Interaction${NC}"
echo "Player: 'Your prices are always fair!'"
curl -s -X POST "$API_URL/npcs/$NPC_ID/evaluate" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Your prices are always fair!",
    "source_id": "player"
  }' | jq '.'
echo ""

# Test 6: Negative Interaction
echo -e "${BLUE}💬 Test 6: Negative Interaction${NC}"
echo "Thief: 'Give me all your gold or else!'"
curl -s -X POST "$API_URL/npcs/$NPC_ID/evaluate" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Give me all your gold or else!",
    "source_id": "thief"
  }' | jq '.'
echo ""

# Test 7: Get Overall Emotion
echo -e "${BLUE}😊 Test 7: Get Overall Current Emotion${NC}"
curl -s "$API_URL/npcs/$NPC_ID/emotion" | jq '.'
echo ""

# Test 8: Get Emotion Towards Player
echo -e "${BLUE}❤️  Test 8: Get Emotion Towards Player${NC}"
curl -s "$API_URL/npcs/$NPC_ID/emotion/player" | jq '.'
echo ""

# Test 9: Get Emotion Towards Thief
echo -e "${BLUE}😠 Test 9: Get Emotion Towards Thief${NC}"
curl -s "$API_URL/npcs/$NPC_ID/emotion/thief" | jq '.'
echo ""

# Test 10: Get All Memory
echo -e "${BLUE}💾 Test 10: Get All Memory Records${NC}"
curl -s "$API_URL/npcs/$NPC_ID/memory" | jq '.'
echo ""

# Test 11: Clear Memory
echo -e "${YELLOW}🗑️  Test 11: Clear Memory${NC}"
curl -s -X DELETE "$API_URL/npcs/$NPC_ID/memory" | jq '.'
echo ""

# Test 12: Verify Memory Cleared
echo -e "${BLUE}✅ Test 12: Verify Memory is Empty${NC}"
curl -s "$API_URL/npcs/$NPC_ID/memory" | jq '.'
echo ""

# Test 13: Remove NPC
echo -e "${YELLOW}❌ Test 13: Remove NPC Session${NC}"
curl -s -X DELETE "$API_URL/npcs/$NPC_ID" | jq '.'
echo ""

echo -e "${GREEN}✅ All tests completed successfully!${NC}"
