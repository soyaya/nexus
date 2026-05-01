use axum::{extract::State, http::StatusCode, Json};
use serde_json::{json, Value};
use sqlx::PgPool;

/// GET /health — liveness probe
pub async fn health_check() -> (StatusCode, Json<Value>) {
    (
        StatusCode::OK,
        Json(json!({ "status": "ok", "service": "nexuscare-backend" })),
    )
}

/// GET /health/db — readiness probe (checks DB connectivity)
pub async fn db_health_check(State(pool): State<PgPool>) -> (StatusCode, Json<Value>) {
    match sqlx::query("SELECT 1").execute(&pool).await {
        Ok(_) => (
            StatusCode::OK,
            Json(json!({ "status": "ok", "database": "connected" })),
        ),
        Err(e) => (
            StatusCode::SERVICE_UNAVAILABLE,
            Json(json!({ "status": "error", "database": e.to_string() })),
        ),
    }
}
