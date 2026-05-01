use axum::{
    routing::{get, patch, post},
    Router,
};
use sqlx::PgPool;
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};

use crate::handlers::{auth, health, hospitals};

pub fn create_router(pool: PgPool) -> Router {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    Router::new()
        // Health
        .route("/health", get(health::health_check))
        .route("/health/db", get(health::db_health_check))
        // Auth
        .route("/api/v1/auth/register", post(auth::register))
        .route("/api/v1/auth/login", post(auth::login))
        // Hospitals
        .route("/api/v1/hospitals", get(hospitals::list_hospitals))
        .route("/api/v1/hospitals", post(hospitals::create_hospital))
        .route("/api/v1/hospitals/:id", get(hospitals::get_hospital))
        .route("/api/v1/hospitals/:id", patch(hospitals::update_hospital))
        .route(
            "/api/v1/hospitals/:id/advance-step",
            patch(hospitals::advance_registration_step),
        )
        .layer(TraceLayer::new_for_http())
        .layer(cors)
        .with_state(pool)
}
