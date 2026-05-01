-- Clinician profiles
-- Shown in the Workforce Pool panel on the Clinical Dashboard.
-- Each clinician links to a platform user account.

CREATE TABLE clinicians (
    id              UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID                  NOT NULL UNIQUE REFERENCES users (id) ON DELETE CASCADE,
    first_name      VARCHAR(100)          NOT NULL,
    last_name       VARCHAR(100)          NOT NULL,
    specialty       clinical_specialty    NOT NULL,
    -- Professional title shown on cards, e.g. "Emergency Doctor", "ICU Specialist"
    role_title      VARCHAR(150)          NOT NULL,
    -- Platform rating 0.0–5.0, e.g. 4.9
    rating          NUMERIC(3,1)          NOT NULL DEFAULT 0.0
                    CHECK (rating BETWEEN 0.0 AND 5.0),
    rating_count    INTEGER               NOT NULL DEFAULT 0,
    avatar_url      TEXT,
    availability    clinician_availability NOT NULL DEFAULT 'available_now',
    -- "Resumes 8 AM" — when the clinician will next be available
    available_from  TIMESTAMPTZ,
    is_verified     BOOLEAN               NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN               NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ           NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ           NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_clinicians_specialty     ON clinicians (specialty);
CREATE INDEX idx_clinicians_availability  ON clinicians (availability);
CREATE INDEX idx_clinicians_rating        ON clinicians (rating DESC);
CREATE INDEX idx_clinicians_is_active     ON clinicians (is_active);

CREATE TRIGGER trg_clinicians_updated_at
    BEFORE UPDATE ON clinicians
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ---------------------------------------------------------------------------
-- Clinician last-known location
-- Used to compute distance shown in Workforce Pool (e.g. "2.4km", "0.8km")
-- ---------------------------------------------------------------------------

CREATE TABLE clinician_locations (
    id               UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
    clinician_id     UUID             NOT NULL UNIQUE REFERENCES clinicians (id) ON DELETE CASCADE,
    latitude         DOUBLE PRECISION NOT NULL CHECK (latitude  BETWEEN -90  AND  90),
    longitude        DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    accuracy_meters  REAL,
    recorded_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_clinician_locations_coords ON clinician_locations (latitude, longitude);
