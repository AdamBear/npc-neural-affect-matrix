use serde::{Deserialize, Serialize};

/// Standard API response wrapper
#[derive(Debug, Serialize, Deserialize)]
pub struct ApiResponse<T> {
    pub success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<T>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

impl<T> ApiResponse<T> {
    pub fn success(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
        }
    }

    pub fn error(message: String) -> Self {
        Self {
            success: false,
            data: None,
            error: Some(message),
        }
    }
}

/// Emotion response with valence and arousal
#[derive(Debug, Serialize, Deserialize)]
pub struct EmotionResponse {
    pub valence: f32,
    pub arousal: f32,
}

/// NPC session creation response
#[derive(Debug, Serialize, Deserialize)]
pub struct NpcSessionResponse {
    pub npc_id: String,
}

/// Request to create a new NPC session
#[derive(Debug, Serialize, Deserialize)]
pub struct CreateNpcRequest {
    pub config: serde_json::Value,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory: Option<serde_json::Value>,
}

/// Request to evaluate an interaction
#[derive(Debug, Serialize, Deserialize)]
pub struct EvaluateInteractionRequest {
    pub text: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub source_id: Option<String>,
}

/// Initialize request (empty body)
#[derive(Debug, Serialize, Deserialize)]
pub struct InitializeRequest {}

/// Generic message response
#[derive(Debug, Serialize, Deserialize)]
pub struct MessageResponse {
    pub message: String,
}

/// Health check response
#[derive(Debug, Serialize, Deserialize)]
pub struct HealthResponse {
    pub status: String,
    pub version: String,
}
