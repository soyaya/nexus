-- Hospital location
-- Stores the GPS pin set via the "Set Hospital Location" map screen.
-- "Drag pin to exact hospital entrance"
--
-- Drives two platform features:
--   Clock-In Verification  — staff must be within clock_in_radius_meters (default 100m)
--   Shift Broadcasting     — shifts prioritised for workers within shift_broadcast_radius_km (default 5km)

CREATE TABLE hospital_locations (
    id                        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id               UUID        NOT NULL UNIQUE REFERENCES hospitals (id) ON DELETE CASCADE,

    -- GPS coordinates of the hospital entrance pin
    latitude                  DOUBLE PRECISION NOT NULL
                              CHECK (latitude  BETWEEN -90  AND  90),
    longitude                 DOUBLE PRECISION NOT NULL
                              CHECK (longitude BETWEEN -180 AND 180),

    -- Human-readable label from the map search box
    place_label               TEXT,

    -- Clock-In Verification geofence
    -- "Workers must be within 100m of this entrance to record their arrival."
    clock_in_radius_meters    INTEGER     NOT NULL DEFAULT 100
                              CHECK (clock_in_radius_meters BETWEEN 50 AND 5000),
    -- Auto-enabled when the location is confirmed
    gps_fencing_enabled       BOOLEAN     NOT NULL DEFAULT TRUE,

    -- Shift Broadcasting radius
    -- "New shifts are prioritised for workers within a 5km radius."
    shift_broadcast_radius_km DOUBLE PRECISION NOT NULL DEFAULT 5.0
                              CHECK (shift_broadcast_radius_km BETWEEN 1.0 AND 100.0),
    shift_distance_active     BOOLEAN     NOT NULL DEFAULT TRUE,

    -- Confirmation state
    location_confirmed        BOOLEAN     NOT NULL DEFAULT FALSE,
    confirmed_at              TIMESTAMPTZ,
    confirmed_by              UUID        REFERENCES users (id) ON DELETE SET NULL,

    created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_hospital_locations_hospital_id ON hospital_locations (hospital_id);

-- Spatial index using a functional index on (latitude, longitude) for proximity queries.
-- If PostGIS is available, replace with a GEOGRAPHY column and GIST index.
CREATE INDEX idx_hospital_locations_coords
    ON hospital_locations (latitude, longitude);

CREATE TRIGGER trg_hospital_locations_updated_at
    BEFORE UPDATE ON hospital_locations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
