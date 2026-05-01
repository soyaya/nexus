-- Hospital accreditation
-- Created when a hospital reaches Step 4 (Access Granted / Accreditation Granted).
-- "Lagos University Teaching Hospital is now a verified institution on the
--  NexusCare platform. Your clinical standards have been successfully validated."

CREATE TABLE hospital_accreditations (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id         UUID        NOT NULL UNIQUE REFERENCES hospitals (id) ON DELETE CASCADE,
    -- The super_admin who granted accreditation
    granted_by          UUID        NOT NULL REFERENCES users (id),
    granted_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- e.g. "NXC-2024-LUTH-001"
    certificate_number  VARCHAR(100) NOT NULL UNIQUE,
    -- URL to downloadable accreditation certificate PDF
    certificate_url     TEXT,
    -- NULL = no expiry; set for time-limited accreditations
    expires_at          TIMESTAMPTZ,
    is_active           BOOLEAN     NOT NULL DEFAULT TRUE,
    -- Populated if accreditation is later revoked
    revocation_reason   TEXT,
    revoked_at          TIMESTAMPTZ,
    revoked_by          UUID        REFERENCES users (id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_accreditations_hospital_id ON hospital_accreditations (hospital_id);
CREATE INDEX idx_accreditations_is_active   ON hospital_accreditations (is_active);
CREATE INDEX idx_accreditations_expires_at  ON hospital_accreditations (expires_at)
    WHERE expires_at IS NOT NULL;

CREATE TRIGGER trg_accreditations_updated_at
    BEFORE UPDATE ON hospital_accreditations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
