-- Onboarding notifications
-- Tracks every SMS / email / in-app notification sent when a hospital's
-- verification status changes. Shown on Step 3 (Verification Pending):
-- "You will receive an SMS and email notification once your status changes."

CREATE TABLE onboarding_notifications (
    id                  UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id         UUID                  NOT NULL REFERENCES hospitals (id) ON DELETE CASCADE,
    -- The hospital admin user who receives this notification (NULL = broadcast)
    recipient_user_id   UUID                  REFERENCES users (id) ON DELETE SET NULL,
    channel             notification_channel  NOT NULL,
    event               notification_event    NOT NULL,
    subject             VARCHAR(255),
    body                TEXT                  NOT NULL,
    status              notification_status   NOT NULL DEFAULT 'pending',
    sent_at             TIMESTAMPTZ,
    read_at             TIMESTAMPTZ,
    created_at          TIMESTAMPTZ           NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_hospital_id ON onboarding_notifications (hospital_id);
CREATE INDEX idx_notifications_status      ON onboarding_notifications (status);
CREATE INDEX idx_notifications_event       ON onboarding_notifications (event);
CREATE INDEX idx_notifications_created_at  ON onboarding_notifications (created_at DESC);

-- ---------------------------------------------------------------------------
-- Notification preferences per hospital
-- Lets the hospital admin control which channels are active.
-- ---------------------------------------------------------------------------

CREATE TABLE hospital_notification_preferences (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id      UUID        NOT NULL UNIQUE REFERENCES hospitals (id) ON DELETE CASCADE,
    email_enabled    BOOLEAN     NOT NULL DEFAULT TRUE,
    sms_enabled      BOOLEAN     NOT NULL DEFAULT TRUE,
    in_app_enabled   BOOLEAN     NOT NULL DEFAULT TRUE,
    -- SMS number may differ from the main hospital phone number
    sms_phone_number VARCHAR(20),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_notif_prefs_updated_at
    BEFORE UPDATE ON hospital_notification_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
