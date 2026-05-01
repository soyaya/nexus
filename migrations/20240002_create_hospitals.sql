-- Hospitals table
-- Stores institutional credentials submitted during Step 1 (Setup) of registration.

CREATE TABLE hospitals (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    name                VARCHAR(255)    NOT NULL,
    -- CAC registration number, e.g. "RC-1234567"
    registration_number VARCHAR(50)     NOT NULL UNIQUE,
    email               VARCHAR(255)    NOT NULL UNIQUE,
    address             TEXT            NOT NULL,
    phone_number        VARCHAR(20)     NOT NULL,
    verification_status verification_status NOT NULL DEFAULT 'pending',
    registration_step   registration_step   NOT NULL DEFAULT 'profile_setup',
    -- Timestamp when documents were submitted for compliance review (Step 3).
    -- Used to track the 24-48 business hour verification window shown on the status page.
    legal_submitted_at  TIMESTAMPTZ,
    -- Overall setup progress percentage (0–100) shown in the bottom progress bar.
    -- Incremented as the hospital completes each setup section (location, etc.)
    setup_progress_percent SMALLINT    NOT NULL DEFAULT 0
                           CHECK (setup_progress_percent BETWEEN 0 AND 100),
    logo_url            TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- Indexes for common lookups
CREATE INDEX idx_hospitals_email               ON hospitals (email);
CREATE INDEX idx_hospitals_registration_number ON hospitals (registration_number);
CREATE INDEX idx_hospitals_verification_status ON hospitals (verification_status);
CREATE INDEX idx_hospitals_registration_step   ON hospitals (registration_step);

-- Automatically keep updated_at current
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_hospitals_updated_at
    BEFORE UPDATE ON hospitals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
