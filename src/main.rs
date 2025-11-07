use npc_neural_affect_matrix::web::create_router;
use npc_neural_affect_matrix::MemoryStore;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "npc_neural_affect_matrix=info,tower_http=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Load NPC memories from disk
    match MemoryStore::load_all_from_disk() {
        Ok(count) if count > 0 => {
            tracing::info!("✅ Loaded {} NPC memory files from disk", count);
        }
        Ok(_) => {
            tracing::info!("📂 No existing NPC memory files found (fresh start)");
        }
        Err(e) => {
            tracing::warn!("⚠️  Failed to load NPC memories: {}", e);
        }
    }

    // Build our application router
    let app = create_router();

    // Get port from environment variable or use default
    let port = std::env::var("PORT").unwrap_or_else(|_| "3000".to_string());
    let addr = format!("0.0.0.0:{}", port);

    tracing::info!("Starting NPC Neural Affect Matrix Web Server on {}", addr);
    tracing::info!("Health check endpoint: http://{}/health", addr);
    tracing::info!("API base URL: http://{}/api/v1", addr);

    // Create TCP listener
    let listener = tokio::net::TcpListener::bind(&addr).await?;

    // Start the server
    axum::serve(listener, app).await?;

    Ok(())
}
