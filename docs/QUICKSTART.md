# 🚀 Quick Start Guide

Get the NPC Neural Affect Matrix Web API running in under 5 minutes.

## Prerequisites

- Rust 1.70+ ([Install Rust](https://rustup.rs/))
- curl (for testing)
- jq (optional, for pretty JSON output)

## 1️⃣ Start the Server

```bash
# Clone the repository (if you haven't already)
git clone https://github.com/mavdol/npc-neural-affect-matrix.git
cd npc-neural-affect-matrix

# Run the web server
cargo run --release
```

The server will start on `http://localhost:3000`

**Alternative methods:**
```bash
# Using the helper script
./run-web-server.sh prod

# Using Docker
docker-compose up
```

## 2️⃣ Test the API

Open a new terminal and run:

```bash
# Test health endpoint
curl http://localhost:3000/health

# Initialize the neural model
curl -X POST http://localhost:3000/api/v1/initialize \
  -H "Content-Type: application/json" \
  -d '{}'

# Create an NPC
curl -X POST http://localhost:3000/api/v1/npcs \
  -H "Content-Type: application/json" \
  -d '{
    "config": {
      "identity": {
        "name": "Guard",
        "background": "Village guard"
      },
      "personality": {
        "valence": 0.0,
        "arousal": 0.0
      },
      "memory": {
        "decay_rate": 0.1
      }
    }
  }'
```

**Or run the complete test suite:**
```bash
./examples/web_api_test.sh
```

## 3️⃣ Integration

### JavaScript/Node.js
```javascript
const response = await fetch('http://localhost:3000/api/v1/initialize', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({})
});
```

### Python
```python
import requests

response = requests.post('http://localhost:3000/api/v1/initialize', json={})
print(response.json())
```

### Unity C#
```csharp
using UnityEngine.Networking;

UnityWebRequest request = UnityWebRequest.Post(
    "http://localhost:3000/api/v1/initialize",
    "{}"
);
yield return request.SendWebRequest();
```

## 📖 Full Documentation

- **Complete API Reference**: [WEB_API.md](./WEB_API.md)
- **FFI/Native Library**: [README.md](./README.md)
- **Examples**: [examples/](./examples/)

## 🐛 Troubleshooting

**Port already in use?**
```bash
PORT=8080 cargo run --release
```

**Model download issues?**
The ONNX model should be included in the repository. If missing:
```bash
# The model files should be in ./model/ directory
ls -la model/
```

**Compilation errors?**
```bash
# Update Rust toolchain
rustup update

# Clean and rebuild
cargo clean
cargo build --release
```

## 🎯 Next Steps

1. Read the [full API documentation](./WEB_API.md)
2. Try the [complete test script](./examples/web_api_test.sh)
3. Integrate with your game engine
4. Explore different NPC personalities
5. Experiment with memory decay rates

## 💡 Key Concepts

- **Valence**: Pleasantness (-1 to +1)
- **Arousal**: Energy level (-1 to +1)
- **Memory**: Past interactions shape current emotions
- **Decay**: Old memories gradually fade

## 🆘 Support

- [GitHub Issues](https://github.com/mavdol/npc-neural-affect-matrix/issues)
- [Discussions](https://github.com/mavdol/npc-neural-affect-matrix/discussions)
