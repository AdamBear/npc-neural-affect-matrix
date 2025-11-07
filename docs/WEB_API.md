# 🌐 Web API Documentation

This document describes the RESTful HTTP API for the Neural Affect Matrix NPC system.

## 🚀 Getting Started

### Running the Server

```bash
# Development mode
cargo run

# Production mode (optimized)
cargo run --release

# Custom port
PORT=8080 cargo run
```

The server will start on `http://0.0.0.0:3000` by default.

### Environment Variables

- `PORT`: Server port (default: `3000`)
- `RUST_LOG`: Logging level (default: `npc_neural_affect_matrix=info,tower_http=info`)

---

## 📋 API Endpoints

### Base URL

```
http://localhost:3000/api/v1
```

All API responses follow this format:

```json
{
  "success": true,
  "data": { ... },
  "error": null
}
```

On error:

```json
{
  "success": false,
  "data": null,
  "error": "Error message here"
}
```

---

## 🏥 Health Check

### `GET /health`

Check if the server is running.

**Response:**
```json
{
  "success": true,
  "data": {
    "status": "healthy",
    "version": "0.1.0"
  }
}
```

**Example:**
```bash
curl http://localhost:3000/health
```

---

## 🧠 Initialize Model

### `POST /api/v1/initialize`

Initialize the neural emotion prediction model. **Must be called once before creating any NPC sessions.**

**Request Body:** Empty or `{}`

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "Model initialized successfully"
  }
}
```

**Example:**
```bash
curl -X POST http://localhost:3000/api/v1/initialize \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

## 👤 NPC Management

### `POST /api/v1/npcs`

Create a new NPC session with configuration and optional memory.

**Request Body:**
```json
{
  "config": {
    "identity": {
      "name": "Village Guard",
      "background": "A loyal guard protecting the village for 15 years"
    },
    "personality": {
      "valence": 0.2,
      "arousal": -0.1
    },
    "memory": {
      "decay_rate": 0.1
    }
  },
  "memory": [
    {
      "id": "mem_001",
      "source_id": "player",
      "text": "Thank you for helping us",
      "valence": 0.85,
      "arousal": 0.45,
      "past_time": 1440
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "npc_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

**Example:**
```bash
curl -X POST http://localhost:3000/api/v1/npcs \
  -H "Content-Type: application/json" \
  -d '{
    "config": {
      "identity": {
        "name": "Shopkeeper",
        "background": "Friendly merchant who loves trading"
      },
      "personality": {
        "valence": 0.5,
        "arousal": 0.0
      },
      "memory": {
        "decay_rate": 0.1
      }
    }
  }'
```

### `DELETE /api/v1/npcs/:npc_id`

Remove an NPC session and all associated data.

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "NPC session 'npc_id' removed successfully"
  }
}
```

**Example:**
```bash
curl -X DELETE http://localhost:3000/api/v1/npcs/550e8400-e29b-41d4-a716-446655440000
```

---

## 💬 Interaction & Emotion

### `POST /api/v1/npcs/:npc_id/evaluate`

Evaluate an interaction with the NPC. This analyzes the emotional impact of text and updates the NPC's memory.

**Request Body:**
```json
{
  "text": "You saved my life, thank you!",
  "source_id": "player"
}
```

- `text` (required): The text to evaluate (dialogue, action description, etc.)
- `source_id` (optional): Identifier for who/what caused this interaction

**Response:**
```json
{
  "success": true,
  "data": {
    "valence": 0.85,
    "arousal": 0.45
  }
}
```

**Example:**
```bash
curl -X POST http://localhost:3000/api/v1/npcs/550e8400-e29b-41d4-a716-446655440000/evaluate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "I bought some potions from your shop",
    "source_id": "player"
  }'
```

### `GET /api/v1/npcs/:npc_id/emotion`

Get the NPC's current overall emotional state (weighted average of all memories).

**Response:**
```json
{
  "success": true,
  "data": {
    "valence": 0.35,
    "arousal": -0.15
  }
}
```

**Example:**
```bash
curl http://localhost:3000/api/v1/npcs/550e8400-e29b-41d4-a716-446655440000/emotion
```

### `GET /api/v1/npcs/:npc_id/emotion/:source_id`

Get the NPC's emotional state toward a specific source/character.

**Response:**
```json
{
  "success": true,
  "data": {
    "valence": 0.75,
    "arousal": 0.20
  }
}
```

**Example:**
```bash
curl http://localhost:3000/api/v1/npcs/550e8400-e29b-41d4-a716-446655440000/emotion/player
```

---

## 💾 Memory Management

### `GET /api/v1/npcs/:npc_id/memory`

Get all memory records for an NPC.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "mem_001",
      "source_id": "player",
      "text": "Thank you for helping us",
      "valence": 0.85,
      "arousal": 0.45,
      "past_time": 1440
    }
  ]
}
```

**Example:**
```bash
curl http://localhost:3000/api/v1/npcs/550e8400-e29b-41d4-a716-446655440000/memory
```

### `DELETE /api/v1/npcs/:npc_id/memory`

Clear all memory for an NPC (resets emotional state to base personality).

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "Memory cleared for NPC 'npc_id'"
  }
}
```

**Example:**
```bash
curl -X DELETE http://localhost:3000/api/v1/npcs/550e8400-e29b-41d4-a716-446655440000/memory
```

---

## 📊 Emotion Values

All emotion responses use **Russell's Circumplex Model**:

### Valence (X-axis)
- `-1.0` to `+1.0`
- Negative = Unpleasant emotions (sad, angry, afraid)
- Positive = Pleasant emotions (happy, excited, calm)

### Arousal (Y-axis)
- `-1.0` to `+1.0`
- Negative = Low energy (calm, tired, bored)
- Positive = High energy (alert, excited, tense)

### Example Emotions:
| Valence | Arousal | Emotion        |
|---------|---------|----------------|
| +0.8    | +0.6    | Excited/Happy  |
| +0.7    | -0.5    | Calm/Content   |
| -0.7    | +0.6    | Angry/Afraid   |
| -0.6    | -0.5    | Sad/Depressed  |

---

## 🔥 Complete Workflow Example

```bash
# 1. Initialize the model
curl -X POST http://localhost:3000/api/v1/initialize \
  -H "Content-Type: application/json" \
  -d '{}'

# 2. Create an NPC
NPC_ID=$(curl -X POST http://localhost:3000/api/v1/npcs \
  -H "Content-Type: application/json" \
  -d '{
    "config": {
      "identity": {
        "name": "Innkeeper",
        "background": "Runs the local tavern, friendly but cautious with strangers"
      },
      "personality": {
        "valence": 0.1,
        "arousal": -0.2
      },
      "memory": {
        "decay_rate": 0.1
      }
    }
  }' | jq -r '.data.npc_id')

echo "Created NPC: $NPC_ID"

# 3. Evaluate an interaction (positive)
curl -X POST "http://localhost:3000/api/v1/npcs/$NPC_ID/evaluate" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "I paid for everyones drinks tonight!",
    "source_id": "player"
  }'

# 4. Evaluate another interaction (negative)
curl -X POST "http://localhost:3000/api/v1/npcs/$NPC_ID/evaluate" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "You overcharged me!",
    "source_id": "player"
  }'

# 5. Check overall emotion
curl "http://localhost:3000/api/v1/npcs/$NPC_ID/emotion"

# 6. Check emotion towards player
curl "http://localhost:3000/api/v1/npcs/$NPC_ID/emotion/player"

# 7. View all memories
curl "http://localhost:3000/api/v1/npcs/$NPC_ID/memory"

# 8. Clear memory
curl -X DELETE "http://localhost:3000/api/v1/npcs/$NPC_ID/memory"

# 9. Remove NPC
curl -X DELETE "http://localhost:3000/api/v1/npcs/$NPC_ID"
```

---

## ⚠️ Error Handling

### HTTP Status Codes

- `200 OK`: Successful request
- `201 Created`: NPC session created
- `400 Bad Request`: Invalid request body or parameters
- `404 Not Found`: NPC not found
- `500 Internal Server Error`: Server error

### Error Response Example:

```json
{
  "success": false,
  "error": "NPC session 'invalid-id' not found"
}
```

---

## 🔧 CORS Configuration

The API has CORS enabled for all origins. This allows web applications from any domain to access the API.

---

## 📝 Notes

1. **Model Initialization**: Always call `/api/v1/initialize` before creating NPCs
2. **Memory Persistence**: Memory is stored in-memory and will be lost on server restart. Export memory via `GET /memory` to save NPC state
3. **Thread Safety**: The API is thread-safe and can handle multiple concurrent requests
4. **Text Length**: Text inputs support up to 512 characters for optimal emotion prediction
5. **Language**: The model is optimized for English text

---

## 🎮 Integration Examples

### Unity (C#)

```csharp
using UnityEngine;
using System.Collections;
using UnityEngine.Networking;

public class NPCEmotionAPI : MonoBehaviour
{
    private string baseUrl = "http://localhost:3000/api/v1";
    private string npcId;

    IEnumerator Start()
    {
        // Initialize model
        yield return InitializeModel();

        // Create NPC
        yield return CreateNPC();

        // Evaluate interaction
        yield return EvaluateInteraction("Hello there!");
    }

    IEnumerator InitializeModel()
    {
        using (UnityWebRequest request = UnityWebRequest.Post($"{baseUrl}/initialize", "{}"))
        {
            yield return request.SendWebRequest();
            Debug.Log("Model initialized");
        }
    }

    IEnumerator CreateNPC()
    {
        string json = @"{
            ""config"": {
                ""identity"": {
                    ""name"": ""Guard"",
                    ""background"": ""Village guard""
                },
                ""personality"": {
                    ""valence"": 0.0,
                    ""arousal"": 0.0
                },
                ""memory"": {
                    ""decay_rate"": 0.1
                }
            }
        }";

        using (UnityWebRequest request = UnityWebRequest.Post($"{baseUrl}/npcs", json, "application/json"))
        {
            yield return request.SendWebRequest();
            // Parse npcId from response
            Debug.Log("NPC created");
        }
    }

    IEnumerator EvaluateInteraction(string text)
    {
        string json = $@"{{""text"": ""{text}"", ""source_id"": ""player""}}";

        using (UnityWebRequest request = UnityWebRequest.Post($"{baseUrl}/npcs/{npcId}/evaluate", json, "application/json"))
        {
            yield return request.SendWebRequest();
            // Parse emotion from response
            Debug.Log("Emotion evaluated");
        }
    }
}
```

### JavaScript/TypeScript

```typescript
class NPCEmotionClient {
  private baseUrl = 'http://localhost:3000/api/v1';

  async initialize(): Promise<void> {
    await fetch(`${this.baseUrl}/initialize`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    });
  }

  async createNPC(config: any): Promise<string> {
    const response = await fetch(`${this.baseUrl}/npcs`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ config })
    });
    const data = await response.json();
    return data.data.npc_id;
  }

  async evaluateInteraction(npcId: string, text: string, sourceId?: string) {
    const response = await fetch(`${this.baseUrl}/npcs/${npcId}/evaluate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text, source_id: sourceId })
    });
    const data = await response.json();
    return data.data; // { valence, arousal }
  }

  async getCurrentEmotion(npcId: string) {
    const response = await fetch(`${this.baseUrl}/npcs/${npcId}/emotion`);
    const data = await response.json();
    return data.data; // { valence, arousal }
  }
}
```

### Python

```python
import requests

class NPCEmotionClient:
    def __init__(self, base_url="http://localhost:3000/api/v1"):
        self.base_url = base_url

    def initialize(self):
        response = requests.post(f"{self.base_url}/initialize", json={})
        return response.json()

    def create_npc(self, config):
        response = requests.post(
            f"{self.base_url}/npcs",
            json={"config": config}
        )
        return response.json()["data"]["npc_id"]

    def evaluate_interaction(self, npc_id, text, source_id=None):
        payload = {"text": text}
        if source_id:
            payload["source_id"] = source_id

        response = requests.post(
            f"{self.base_url}/npcs/{npc_id}/evaluate",
            json=payload
        )
        return response.json()["data"]

    def get_current_emotion(self, npc_id):
        response = requests.get(f"{self.base_url}/npcs/{npc_id}/emotion")
        return response.json()["data"]

# Usage
client = NPCEmotionClient()
client.initialize()

npc_id = client.create_npc({
    "identity": {"name": "Guard", "background": "Protects the city"},
    "personality": {"valence": 0.0, "arousal": 0.0},
    "memory": {"decay_rate": 0.1}
})

emotion = client.evaluate_interaction(npc_id, "Hello friend!", "player")
print(f"Valence: {emotion['valence']}, Arousal: {emotion['arousal']}")
```

---

## 🐳 Docker Deployment

```dockerfile
FROM rust:1.70 as builder
WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/npc-neural-affect-matrix /usr/local/bin/
EXPOSE 3000
CMD ["npc-neural-affect-matrix"]
```

```bash
docker build -t npc-emotion-api .
docker run -p 3000:3000 npc-emotion-api
```

---

## 📞 Support

For issues and questions:
- GitHub Issues: [https://github.com/mavdol/npc-neural-affect-matrix/issues](https://github.com/mavdol/npc-neural-affect-matrix/issues)
- Discussions: [https://github.com/mavdol/npc-neural-affect-matrix/discussions](https://github.com/mavdol/npc-neural-affect-matrix/discussions)
