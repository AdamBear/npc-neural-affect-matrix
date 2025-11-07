use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;

/// Web error type for HTTP endpoints
#[derive(Debug)]
pub enum WebError {
    BadRequest(String),
    NotFound(String),
    InternalError(String),
}

impl IntoResponse for WebError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            WebError::BadRequest(msg) => (StatusCode::BAD_REQUEST, msg),
            WebError::NotFound(msg) => (StatusCode::NOT_FOUND, msg),
            WebError::InternalError(msg) => (StatusCode::INTERNAL_SERVER_ERROR, msg),
        };

        let body = Json(json!({
            "success": false,
            "error": message,
        }));

        (status, body).into_response()
    }
}

impl From<String> for WebError {
    fn from(msg: String) -> Self {
        WebError::InternalError(msg)
    }
}

impl From<&str> for WebError {
    fn from(msg: &str) -> Self {
        WebError::InternalError(msg.to_string())
    }
}
