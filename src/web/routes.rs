use axum::{
    extract::{Json, Path},
    http::StatusCode,
    response::IntoResponse,
    routing::{delete, get, post},
    Router,
};
use tower_http::cors::{Any, CorsLayer};

use crate::api::services::evaluator_service::{
    create_npc_session as create_session, evaluate_interaction_with_cached_model,
    initialize_shared_model, remove_npc_session as remove_session, with_npc_evaluator,
};
use crate::api::services::memory_service::{clear_memory, get_all_memory};
use crate::config::NpcConfig;
use crate::modules::memory::{MemoryEmotionEvaluator, MemoryStore};
use crate::web::error::WebError;
use crate::web::types::*;

/// Health check endpoint
async fn health_check() -> impl IntoResponse {
    Json(ApiResponse::success(HealthResponse {
        status: "healthy".to_string(),
        version: env!("CARGO_PKG_VERSION").to_string(),
    }))
}

/// Initialize the neural emotion prediction model
async fn initialize() -> Result<impl IntoResponse, WebError> {
    match initialize_shared_model() {
        Ok(()) => Ok(Json(ApiResponse::success(MessageResponse {
            message: "Model initialized successfully".to_string(),
        }))),
        Err(api_result_ptr) => {
            // Extract error message from the ApiResult pointer
            let error_msg = unsafe {
                let result_ref = &*api_result_ptr;
                if !result_ref.error.is_null() {
                    std::ffi::CStr::from_ptr(result_ref.error)
                        .to_string_lossy()
                        .into_owned()
                } else {
                    "Unknown error during model initialization".to_string()
                }
            };

            // Clean up the ApiResult
            unsafe {
                let _ = Box::from_raw(api_result_ptr);
            }

            Err(WebError::InternalError(error_msg))
        }
    }
}

/// Create a new NPC session
async fn create_npc(Json(payload): Json<CreateNpcRequest>) -> Result<impl IntoResponse, WebError> {
    let npc_id = uuid::Uuid::new_v4().to_string();

    let config: NpcConfig = serde_json::from_value(payload.config)
        .map_err(|e| WebError::BadRequest(format!("Invalid config format: {}", e)))?;

    if let Some(memory) = payload.memory {
        let memory_records: Vec<crate::modules::memory::MemoryRecord> = serde_json::from_value(memory)
            .map_err(|e| WebError::BadRequest(format!("Invalid memory format: {}", e)))?;

        MemoryStore::import(&npc_id, memory_records)
            .map_err(|e| WebError::InternalError(format!("Failed to import memory: {}", e)))?;
    }

    let evaluator = MemoryEmotionEvaluator::new_with_id(config, None, npc_id.clone())
        .map_err(|e| WebError::InternalError(format!("Failed to create evaluator: {:?}", e)))?;

    create_session(npc_id.clone(), evaluator)
        .map_err(|_| WebError::InternalError("Failed to create session".to_string()))?;

    Ok((
        StatusCode::CREATED,
        Json(ApiResponse::success(NpcSessionResponse { npc_id })),
    ))
}

/// Get list of all NPCs
async fn list_npcs() -> Result<impl IntoResponse, WebError> {
    use crate::api::services::evaluator_service::get_npc_sessions;

    let sessions = get_npc_sessions()
        .map_err(|_| WebError::InternalError("Failed to get NPC sessions".to_string()))?;

    let npc_list: Vec<serde_json::Value> = sessions
        .iter()
        .map(|(npc_id, evaluator)| {
            serde_json::json!({
                "npc_id": npc_id,
                "name": evaluator.config.identity.name,
                "background": evaluator.config.identity.background,
                "personality": {
                    "valence": evaluator.config.personality.valence,
                    "arousal": evaluator.config.personality.arousal
                }
            })
        })
        .collect();

    Ok(Json(ApiResponse::success(npc_list)))
}

/// Remove an NPC session
async fn remove_npc(Path(npc_id): Path<String>) -> Result<impl IntoResponse, WebError> {
    MemoryStore::remove_npc(&npc_id)
        .map_err(|e| WebError::InternalError(format!("Failed to remove NPC memory: {}", e)))?;

    remove_session(&npc_id).map_err(|_| WebError::NotFound(format!("NPC session '{}' not found", npc_id)))?;

    Ok(Json(ApiResponse::success(MessageResponse {
        message: format!("NPC session '{}' removed successfully", npc_id),
    })))
}

/// Evaluate an interaction for an NPC
async fn evaluate_interaction(
    Path(npc_id): Path<String>,
    Json(payload): Json<EvaluateInteractionRequest>,
) -> Result<impl IntoResponse, WebError> {
    let result = with_npc_evaluator(&npc_id, |evaluator| {
        let emotion = evaluate_interaction_with_cached_model(evaluator, &payload.text, payload.source_id.as_deref())?;

        Ok(serde_json::to_string(&EmotionResponse {
            valence: emotion.valence,
            arousal: emotion.arousal,
        })
        .unwrap())
    });

    let result_ref = unsafe { &*result };
    if result_ref.success == 0 {
        let error_msg = if !result_ref.error.is_null() {
            unsafe {
                std::ffi::CStr::from_ptr(result_ref.error)
                    .to_string_lossy()
                    .into_owned()
            }
        } else {
            "Unknown error".to_string()
        };

        unsafe {
            if !result_ref.data.is_null() {
                let _ = std::ffi::CString::from_raw(result_ref.data);
            }
            if !result_ref.error.is_null() {
                let _ = std::ffi::CString::from_raw(result_ref.error);
            }
            let _ = Box::from_raw(result);
        }

        return Err(WebError::InternalError(error_msg));
    }

    let data_str = if !result_ref.data.is_null() {
        unsafe {
            std::ffi::CStr::from_ptr(result_ref.data)
                .to_string_lossy()
                .into_owned()
        }
    } else {
        "{}".to_string()
    };

    let emotion: EmotionResponse = serde_json::from_str(&data_str)
        .map_err(|e| WebError::InternalError(format!("Failed to parse response: {}", e)))?;

    unsafe {
        if !result_ref.data.is_null() {
            let _ = std::ffi::CString::from_raw(result_ref.data);
        }
        if !result_ref.error.is_null() {
            let _ = std::ffi::CString::from_raw(result_ref.error);
        }
        let _ = Box::from_raw(result);
    }

    Ok(Json(ApiResponse::success(emotion)))
}

/// Get current emotion for an NPC
async fn get_current_emotion(Path(npc_id): Path<String>) -> Result<impl IntoResponse, WebError> {
    let result = with_npc_evaluator(&npc_id, |evaluator| {
        let emotion = evaluator
            .calculate_current_emotion()
            .map_err(|e| format!("Failed to calculate emotion: {:?}", e))?;

        Ok(serde_json::to_string(&EmotionResponse {
            valence: emotion.valence,
            arousal: emotion.arousal,
        })
        .unwrap())
    });

    let result_ref = unsafe { &*result };
    if result_ref.success == 0 {
        let error_msg = if !result_ref.error.is_null() {
            unsafe {
                std::ffi::CStr::from_ptr(result_ref.error)
                    .to_string_lossy()
                    .into_owned()
            }
        } else {
            "Unknown error".to_string()
        };

        unsafe {
            if !result_ref.data.is_null() {
                let _ = std::ffi::CString::from_raw(result_ref.data);
            }
            if !result_ref.error.is_null() {
                let _ = std::ffi::CString::from_raw(result_ref.error);
            }
            let _ = Box::from_raw(result);
        }

        return Err(WebError::InternalError(error_msg));
    }

    let data_str = if !result_ref.data.is_null() {
        unsafe {
            std::ffi::CStr::from_ptr(result_ref.data)
                .to_string_lossy()
                .into_owned()
        }
    } else {
        "{}".to_string()
    };

    let emotion: EmotionResponse = serde_json::from_str(&data_str)
        .map_err(|e| WebError::InternalError(format!("Failed to parse response: {}", e)))?;

    unsafe {
        if !result_ref.data.is_null() {
            let _ = std::ffi::CString::from_raw(result_ref.data);
        }
        if !result_ref.error.is_null() {
            let _ = std::ffi::CString::from_raw(result_ref.error);
        }
        let _ = Box::from_raw(result);
    }

    Ok(Json(ApiResponse::success(emotion)))
}

/// Get current emotion towards a specific source
async fn get_emotion_by_source(Path((npc_id, source_id)): Path<(String, String)>) -> Result<impl IntoResponse, WebError> {
    let result = with_npc_evaluator(&npc_id, |evaluator| {
        let emotion = evaluator
            .calculate_current_emotion_towards_source(&source_id)
            .map_err(|e| format!("Failed to calculate emotion: {:?}", e))?;

        Ok(serde_json::to_string(&EmotionResponse {
            valence: emotion.valence,
            arousal: emotion.arousal,
        })
        .unwrap())
    });

    let result_ref = unsafe { &*result };
    if result_ref.success == 0 {
        let error_msg = if !result_ref.error.is_null() {
            unsafe {
                std::ffi::CStr::from_ptr(result_ref.error)
                    .to_string_lossy()
                    .into_owned()
            }
        } else {
            "Unknown error".to_string()
        };

        unsafe {
            if !result_ref.data.is_null() {
                let _ = std::ffi::CString::from_raw(result_ref.data);
            }
            if !result_ref.error.is_null() {
                let _ = std::ffi::CString::from_raw(result_ref.error);
            }
            let _ = Box::from_raw(result);
        }

        return Err(WebError::InternalError(error_msg));
    }

    let data_str = if !result_ref.data.is_null() {
        unsafe {
            std::ffi::CStr::from_ptr(result_ref.data)
                .to_string_lossy()
                .into_owned()
        }
    } else {
        "{}".to_string()
    };

    let emotion: EmotionResponse = serde_json::from_str(&data_str)
        .map_err(|e| WebError::InternalError(format!("Failed to parse response: {}", e)))?;

    unsafe {
        if !result_ref.data.is_null() {
            let _ = std::ffi::CString::from_raw(result_ref.data);
        }
        if !result_ref.error.is_null() {
            let _ = std::ffi::CString::from_raw(result_ref.error);
        }
        let _ = Box::from_raw(result);
    }

    Ok(Json(ApiResponse::success(emotion)))
}

/// Get NPC memory
async fn get_memory(Path(npc_id): Path<String>) -> Result<impl IntoResponse, WebError> {
    let json_str =
        get_all_memory(&npc_id).map_err(|_| WebError::NotFound(format!("NPC '{}' not found", npc_id)))?;

    let memory: serde_json::Value = serde_json::from_str(&json_str)
        .map_err(|e| WebError::InternalError(format!("Failed to parse memory: {}", e)))?;

    Ok(Json(ApiResponse::success(memory)))
}

/// Clear NPC memory
async fn clear_memory_handler(Path(npc_id): Path<String>) -> Result<impl IntoResponse, WebError> {
    let message = clear_memory(&npc_id).map_err(|_| WebError::NotFound(format!("NPC '{}' not found", npc_id)))?;

    Ok(Json(ApiResponse::success(MessageResponse { message })))
}

/// Create the application router with all routes
pub fn create_router() -> Router {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    Router::new()
        .route("/health", get(health_check))
        .route("/api/v1/initialize", post(initialize))
        .route("/api/v1/npcs", get(list_npcs))
        .route("/api/v1/npcs", post(create_npc))
        .route("/api/v1/npcs/:npc_id", delete(remove_npc))
        .route("/api/v1/npcs/:npc_id/evaluate", post(evaluate_interaction))
        .route("/api/v1/npcs/:npc_id/emotion", get(get_current_emotion))
        .route(
            "/api/v1/npcs/:npc_id/emotion/:source_id",
            get(get_emotion_by_source),
        )
        .route("/api/v1/npcs/:npc_id/memory", get(get_memory))
        .route("/api/v1/npcs/:npc_id/memory", delete(clear_memory_handler))
        .layer(cors)
}
