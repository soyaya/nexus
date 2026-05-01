-- Registration audit log
-- Immutable record of every step transition during hospital onboarding.

CREATE TABLE registration_audit_log (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id   UUID        NOT NULL REFERENCES hospitals (id) ON DELETE CASCADE,
    previous_step VARCHAR(50),
    new_step      VARCHAR(50) NOT NULL,
    -- NULL when the system triggers the transition automatically
    changed_by    UUID        REFERENCES users (id) ON DELETE SET NULL,
    notes         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_reg_audit_hospital_id ON registration_audit_log (hospital_id);
CREATE INDEX idx_reg_audit_created_at  ON registration_audit_log (created_at DESC);
