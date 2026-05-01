-- Hospital access policies
-- Defines what a hospital can do at each verification_status.
-- Enforces the "Read-Only Mode" / "Action Restricted" rules shown on the
-- Verification Pending screen:
--   • Read-Only:  browse app, view doctor profiles, explore system tools → ALLOWED
--   • Restricted: create shifts, approve contracts → RESTRICTED (with reason)

CREATE TABLE access_policies (
    id                   UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
    -- The verification_status this rule applies to (stored as text to avoid
    -- a circular FK; validated at the app layer against the enum)
    verification_status  VARCHAR(50)       NOT NULL,
    action               hospital_action   NOT NULL,
    access_level         access_level      NOT NULL,
    -- Message shown in the UI when access_level = 'restricted'
    restriction_reason   TEXT,
    created_at           TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ       NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_policy_status_action UNIQUE (verification_status, action)
);

CREATE INDEX idx_access_policies_status ON access_policies (verification_status);

CREATE TRIGGER trg_access_policies_updated_at
    BEFORE UPDATE ON access_policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ---------------------------------------------------------------------------
-- Seed default policies
-- These match exactly what the Verification Pending screen communicates.
-- ---------------------------------------------------------------------------

-- While pending: read-only actions are allowed
INSERT INTO access_policies (verification_status, action, access_level, restriction_reason) VALUES
    ('pending', 'browse_app',           'allowed',    NULL),
    ('pending', 'view_doctor_profiles', 'allowed',    NULL),
    ('pending', 'explore_system_tools', 'allowed',    NULL),
    ('pending', 'create_shift',         'restricted', 'Creation of new shifts is disabled until your institution is verified.'),
    ('pending', 'approve_contract',     'restricted', 'Contract approvals are disabled until your institution is verified.'),
    ('pending', 'invite_staff',         'restricted', 'Staff invitations are disabled until your institution is verified.'),
    ('pending', 'initiate_payment',     'restricted', 'Payments are disabled until your institution is verified.'),
    ('pending', 'export_data',          'restricted', 'Data export is disabled until your institution is verified.');

-- While under_review: same as pending
INSERT INTO access_policies (verification_status, action, access_level, restriction_reason) VALUES
    ('under_review', 'browse_app',           'allowed',    NULL),
    ('under_review', 'view_doctor_profiles', 'allowed',    NULL),
    ('under_review', 'explore_system_tools', 'allowed',    NULL),
    ('under_review', 'create_shift',         'restricted', 'Creation of new shifts is disabled until your institution is verified.'),
    ('under_review', 'approve_contract',     'restricted', 'Contract approvals are disabled until your institution is verified.'),
    ('under_review', 'invite_staff',         'restricted', 'Staff invitations are disabled until your institution is verified.'),
    ('under_review', 'initiate_payment',     'restricted', 'Payments are disabled until your institution is verified.'),
    ('under_review', 'export_data',          'restricted', 'Data export is disabled until your institution is verified.');

-- Once verified: all actions allowed
INSERT INTO access_policies (verification_status, action, access_level, restriction_reason) VALUES
    ('verified', 'browse_app',           'allowed', NULL),
    ('verified', 'view_doctor_profiles', 'allowed', NULL),
    ('verified', 'explore_system_tools', 'allowed', NULL),
    ('verified', 'create_shift',         'allowed', NULL),
    ('verified', 'approve_contract',     'allowed', NULL),
    ('verified', 'invite_staff',         'allowed', NULL),
    ('verified', 'initiate_payment',     'allowed', NULL),
    ('verified', 'export_data',          'allowed', NULL);

-- If rejected: read-only allowed, write actions hidden (not just restricted)
INSERT INTO access_policies (verification_status, action, access_level, restriction_reason) VALUES
    ('rejected', 'browse_app',           'allowed',    NULL),
    ('rejected', 'view_doctor_profiles', 'allowed',    NULL),
    ('rejected', 'explore_system_tools', 'allowed',    NULL),
    ('rejected', 'create_shift',         'hidden',     NULL),
    ('rejected', 'approve_contract',     'hidden',     NULL),
    ('rejected', 'invite_staff',         'hidden',     NULL),
    ('rejected', 'initiate_payment',     'hidden',     NULL),
    ('rejected', 'export_data',          'hidden',     NULL);
