-- Shifts
-- Core operational table. Shown in:
--   "Today's Active Shifts"  — IN-PROGRESS / UPCOMING cards
--   "Open Shifts Needing Staff" — STAT / URGENT open shift cards

CREATE TABLE shifts (
    id                          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id                 UUID            NOT NULL REFERENCES hospitals (id) ON DELETE CASCADE,

    -- Step 1: Basic Information
    role_category               role_category   NOT NULL,
    role_title                  VARCHAR(255)    NOT NULL,
    specialty                   VARCHAR(150),
    department                  VARCHAR(255),

    -- In-person (GPS enforced) or virtual
    shift_type                  shift_type      NOT NULL DEFAULT 'in_person',

    status                      shift_status    NOT NULL DEFAULT 'open',
    priority                    shift_priority  NOT NULL DEFAULT 'normal',
    -- Bonus percentage for STAT urgency (e.g. 20 for +20% rate)
    urgency_bonus_pct           SMALLINT        DEFAULT 0
                                CHECK (urgency_bonus_pct BETWEEN 0 AND 100),

    -- Scheduled window
    scheduled_start             TIMESTAMPTZ     NOT NULL,
    -- Explicit duration in hours as entered in the wizard (e.g. 8.0)
    duration_hours              REAL            NOT NULL CHECK (duration_hours > 0),
    -- Derived: scheduled_start + duration_hours (stored for query convenience)
    scheduled_end               TIMESTAMPTZ     NOT NULL,
    CHECK (scheduled_end > scheduled_start),

    -- Actual times set on clock-in / clock-out
    actual_start                TIMESTAMPTZ,
    actual_end                  TIMESTAMPTZ,

    -- Assigned clinician (NULL while open)
    assigned_clinician_id       UUID            REFERENCES clinicians (id) ON DELETE SET NULL,

    -- Compensation (Step 2)
    pay_type                    pay_type        NOT NULL DEFAULT 'hourly_rate',
    rate_kobo_per_hour          BIGINT          CHECK (rate_kobo_per_hour > 0),
    fixed_rate_kobo             BIGINT          CHECK (fixed_rate_kobo > 0),
    -- STAT bonus fixed amount in kobo (e.g. 500000 = ₦5,000)
    stat_bonus_kobo             BIGINT          DEFAULT 0 CHECK (stat_bonus_kobo >= 0),
    -- Effective hourly rate after urgency bonus (computed, stored for billing)
    effective_rate_kobo_per_hour BIGINT         CHECK (effective_rate_kobo_per_hour > 0),
    -- Grand total: base + stat_bonus + allowances (computed, stored for billing)
    grand_total_kobo            BIGINT          CHECK (grand_total_kobo >= 0),

    -- Human-readable label, e.g. "Night Shift: General Ward A"
    shift_label                 VARCHAR(150),

    notes                       TEXT,
    -- Step 3: Shift Description
    -- Free-text job description (required in Step 3)
    job_description             TEXT,
    -- AI-generated draft quality score 0–100 (e.g. 85/100)
    draft_quality_score         SMALLINT        CHECK (draft_quality_score BETWEEN 0 AND 100),
    -- Step 4: Requirements
    -- Institutional verification consent confirmed before broadcasting
    broadcast_consent_confirmed BOOLEAN         NOT NULL DEFAULT FALSE,
    -- Number of matched clinicians at publish time ("48 matched clinicians immediately")
    matched_clinicians_at_publish INTEGER,
    -- Step 5: Preview / Broadcast
    -- When the hospital clicked "Broadcast Shift"
    broadcast_at                TIMESTAMPTZ,
    -- When billing was triggered (only after a clinician is successfully booked)
    -- "Charges will only apply once a clinician is successfully booked."
    billing_triggered_at        TIMESTAMPTZ,
    created_by                  UUID            NOT NULL REFERENCES users (id),
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_shifts_hospital_id          ON shifts (hospital_id);
CREATE INDEX idx_shifts_status               ON shifts (status);
CREATE INDEX idx_shifts_priority             ON shifts (priority);
CREATE INDEX idx_shifts_scheduled_start      ON shifts (scheduled_start);
CREATE INDEX idx_shifts_assigned_clinician   ON shifts (assigned_clinician_id)
    WHERE assigned_clinician_id IS NOT NULL;

CREATE TRIGGER trg_shifts_updated_at
    BEFORE UPDATE ON shifts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ---------------------------------------------------------------------------
-- Shift interest
-- Clinicians express interest in open shifts.
-- "3 Interested", "1 Interested", "Waitlisting active"
-- ---------------------------------------------------------------------------

CREATE TABLE shift_interests (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    shift_id       UUID        NOT NULL REFERENCES shifts (id) ON DELETE CASCADE,
    clinician_id   UUID        NOT NULL REFERENCES clinicians (id) ON DELETE CASCADE,
    -- Algorithmic top match flag (shown as "Top match: Adebayo K.")
    is_top_match   BOOLEAN     NOT NULL DEFAULT FALSE,
    -- On the waitlist when shift is already assigned
    is_waitlisted  BOOLEAN     NOT NULL DEFAULT FALSE,
    expressed_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_shift_interest UNIQUE (shift_id, clinician_id)
);

CREATE INDEX idx_shift_interests_shift_id     ON shift_interests (shift_id);
CREATE INDEX idx_shift_interests_clinician_id ON shift_interests (clinician_id);

-- ---------------------------------------------------------------------------
-- Shift attendance (clock-in / clock-out)
-- GPS geofence verified within hospital's clock_in_radius_meters (default 100m)
-- ---------------------------------------------------------------------------

CREATE TABLE shift_attendance (
    id                       UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    shift_id                 UUID            NOT NULL UNIQUE REFERENCES shifts (id) ON DELETE CASCADE,
    clinician_id             UUID            NOT NULL REFERENCES clinicians (id) ON DELETE CASCADE,

    clockin_at               TIMESTAMPTZ,
    clockin_method           clockin_method,
    clockin_latitude         DOUBLE PRECISION,
    clockin_longitude        DOUBLE PRECISION,
    -- Distance from hospital entrance at clock-in (metres)
    clockin_distance_meters  REAL,

    clockout_at              TIMESTAMPTZ,
    clockout_method          clockin_method,
    clockout_latitude        DOUBLE PRECISION,
    clockout_longitude       DOUBLE PRECISION,

    -- Total worked duration in minutes (computed on clock-out)
    worked_minutes           INTEGER         CHECK (worked_minutes >= 0),

    created_at               TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_attendance_shift_id     ON shift_attendance (shift_id);
CREATE INDEX idx_attendance_clinician_id ON shift_attendance (clinician_id);

CREATE TRIGGER trg_shift_attendance_updated_at
    BEFORE UPDATE ON shift_attendance
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ---------------------------------------------------------------------------
-- Dashboard KPI snapshots
-- Pre-computed metrics for the top KPI cards on the Clinical Dashboard.
--   Shift Fill Rate: 84% (goal: 92%, -8% from target)
--   Total Disbursements: ₦12.4M (+4.2% from last week)
--   Average Fill Time: 14.2 hrs (-2h improvement)
-- ---------------------------------------------------------------------------

CREATE TABLE dashboard_kpi_snapshots (
    id                        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id               UUID        NOT NULL REFERENCES hospitals (id) ON DELETE CASCADE,

    shift_fill_rate_pct       REAL        NOT NULL CHECK (shift_fill_rate_pct BETWEEN 0 AND 100),
    fill_rate_goal_pct        REAL        NOT NULL DEFAULT 92.0,
    fill_rate_delta_pct       REAL        NOT NULL DEFAULT 0.0,

    total_disbursements_kobo  BIGINT      NOT NULL DEFAULT 0,
    disbursements_delta_pct   REAL        NOT NULL DEFAULT 0.0,

    avg_fill_time_hours       REAL        NOT NULL DEFAULT 0.0,
    fill_time_delta_hours     REAL        NOT NULL DEFAULT 0.0,

    computed_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Only keep the latest snapshot per hospital for fast dashboard queries
CREATE INDEX idx_kpi_snapshots_hospital_computed
    ON dashboard_kpi_snapshots (hospital_id, computed_at DESC);

-- ---------------------------------------------------------------------------
-- Staffing insights
-- AI/analytics-generated cards shown in the dashboard right panel.
-- "Nurse availability is 15% higher than average on Fridays..."
-- ---------------------------------------------------------------------------

CREATE TABLE staffing_insights (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id   UUID        NOT NULL REFERENCES hospitals (id) ON DELETE CASCADE,
    insight_text  TEXT        NOT NULL,
    -- CTA label, e.g. "Explore Trends"
    cta_label     VARCHAR(100),
    is_active     BOOLEAN     NOT NULL DEFAULT TRUE,
    generated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at    TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_staffing_insights_hospital_active
    ON staffing_insights (hospital_id, is_active, generated_at DESC);

-- ---------------------------------------------------------------------------
-- Shift creation wizard drafts
-- Persists partial state across the 4-step wizard so the user can navigate
-- back and forward without losing data.
-- Promoted to a full shift record when Step 4 (Review & Publish) is submitted.
-- ---------------------------------------------------------------------------

CREATE TABLE shift_wizard_drafts (
    id                          UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id                 UUID              NOT NULL REFERENCES hospitals (id) ON DELETE CASCADE,
    created_by                  UUID              NOT NULL REFERENCES users (id),
    current_step                shift_wizard_step NOT NULL DEFAULT 'basic_information',

    -- Step 1: Basic Information
    role_category               role_category,
    role_title                  VARCHAR(255),
    specialty                   VARCHAR(150),
    shift_type                  shift_type,
    scheduled_start             TIMESTAMPTZ,
    duration_hours              REAL              CHECK (duration_hours > 0),
    priority                    shift_priority,
    urgency_bonus_pct           SMALLINT          CHECK (urgency_bonus_pct BETWEEN 0 AND 100),

    -- Step 2: Compensation
    pay_type                    pay_type,
    rate_kobo_per_hour          BIGINT            CHECK (rate_kobo_per_hour > 0),
    fixed_rate_kobo             BIGINT            CHECK (fixed_rate_kobo > 0),
    stat_bonus_kobo             BIGINT            DEFAULT 0 CHECK (stat_bonus_kobo >= 0),
    grand_total_kobo            BIGINT            CHECK (grand_total_kobo >= 0),

    -- Step 3: Shift Description
    department                  VARCHAR(255),
    job_description             TEXT,
    -- AI-generated quality score updated as the user types (0–100)
    draft_quality_score         SMALLINT          CHECK (draft_quality_score BETWEEN 0 AND 100),
    notes                       TEXT,

    -- Step 4: Requirements
    broadcast_consent_confirmed BOOLEAN           NOT NULL DEFAULT FALSE,
    matched_clinicians_at_publish INTEGER,

    -- Human-readable label shown in "Current Progress" card, e.g. "Night Shift: General Ward A"
    shift_label                 VARCHAR(150),

    matched_professionals_count INTEGER           DEFAULT 0,

    created_at                  TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_shift_drafts_hospital_id ON shift_wizard_drafts (hospital_id);
CREATE INDEX idx_shift_drafts_created_by  ON shift_wizard_drafts (created_by);

CREATE TRIGGER trg_shift_drafts_updated_at
    BEFORE UPDATE ON shift_wizard_drafts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ---------------------------------------------------------------------------
-- Shift allowances
-- Additional allowances added via "+ Add Additional Allowance" in Step 2.
-- Each row is one allowance line item on a shift or wizard draft.
-- ---------------------------------------------------------------------------

CREATE TABLE shift_allowances (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    -- One of shift_id or draft_id must be set
    shift_id     UUID        REFERENCES shifts (id) ON DELETE CASCADE,
    draft_id     UUID        REFERENCES shift_wizard_drafts (id) ON DELETE CASCADE,
    -- Label entered by the admin, e.g. "Transport Allowance", "Night Differential"
    label        VARCHAR(100) NOT NULL,
    -- Amount in kobo
    amount_kobo  BIGINT      NOT NULL CHECK (amount_kobo > 0),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_allowance_parent CHECK (
        (shift_id IS NOT NULL AND draft_id IS NULL) OR
        (shift_id IS NULL AND draft_id IS NOT NULL)
    )
);

CREATE INDEX idx_allowances_shift_id ON shift_allowances (shift_id) WHERE shift_id IS NOT NULL;
CREATE INDEX idx_allowances_draft_id ON shift_allowances (draft_id) WHERE draft_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Shift description items (Step 3 — Shift Description)
-- Three categories shown on the screen:
--   Tasks       — clinical responsibilities (e.g. "See 20-25 emergency patients")
--   Deliverables — expected outputs (e.g. "Documents — PDF Files")
--   Equipment   — resources provided (e.g. "Workstation with EMR access")
-- Each item links to either a published shift or a wizard draft.
-- ---------------------------------------------------------------------------

CREATE TABLE shift_description_items (
    id           UUID                 PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Exactly one of shift_id or draft_id must be set (enforced by CHECK below)
    shift_id     UUID                 REFERENCES shifts (id) ON DELETE CASCADE,
    draft_id     UUID                 REFERENCES shift_wizard_drafts (id) ON DELETE CASCADE,
    category     shift_item_category  NOT NULL,
    label        VARCHAR(255)         NOT NULL,
    -- Sub-label / description, e.g. "Full privileges for the duration of shift"
    description  TEXT,
    -- Display order within the category (0-indexed)
    sort_order   SMALLINT             NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ          NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_description_item_parent CHECK (
        (shift_id IS NOT NULL AND draft_id IS NULL) OR
        (shift_id IS NULL AND draft_id IS NOT NULL)
    )
);

CREATE INDEX idx_desc_items_shift_id    ON shift_description_items (shift_id, category)
    WHERE shift_id IS NOT NULL;
CREATE INDEX idx_desc_items_draft_id    ON shift_description_items (draft_id, category)
    WHERE draft_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Shift requirements / qualifications (Step 4 — Requirements)
-- Free-text qualification tags added via the pill input.
-- e.g. "2+ years emergency experience", "ACLS certified", "Valid medical license"
-- Linked to either a published shift or a wizard draft.
-- ---------------------------------------------------------------------------

CREATE TABLE shift_requirements (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Exactly one of shift_id or draft_id must be set
    shift_id      UUID        REFERENCES shifts (id) ON DELETE CASCADE,
    draft_id      UUID        REFERENCES shift_wizard_drafts (id) ON DELETE CASCADE,
    -- Free-text qualification tag
    qualification VARCHAR(200) NOT NULL,
    sort_order    SMALLINT    NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_requirement_parent CHECK (
        (shift_id IS NOT NULL AND draft_id IS NULL) OR
        (shift_id IS NULL AND draft_id IS NOT NULL)
    )
);

CREATE INDEX idx_requirements_shift_id ON shift_requirements (shift_id) WHERE shift_id IS NOT NULL;
CREATE INDEX idx_requirements_draft_id ON shift_requirements (draft_id) WHERE draft_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Shift bookmarks
-- Clinicians bookmark shifts from the preview card (🔖 icon, Step 5).
-- ---------------------------------------------------------------------------

CREATE TABLE shift_bookmarks (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    shift_id       UUID        NOT NULL REFERENCES shifts (id) ON DELETE CASCADE,
    clinician_id   UUID        NOT NULL REFERENCES clinicians (id) ON DELETE CASCADE,
    bookmarked_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_shift_bookmark UNIQUE (shift_id, clinician_id)
);

CREATE INDEX idx_bookmarks_clinician_id ON shift_bookmarks (clinician_id);
CREATE INDEX idx_bookmarks_shift_id     ON shift_bookmarks (shift_id);

-- ---------------------------------------------------------------------------
-- Shift broadcast records
-- Audit log created when a hospital clicks "Broadcast Shift" (Step 5).
-- "By clicking broadcast, this position will be immediately published to
--  the clinician marketplace. Charges will only apply once a clinician
--  is successfully booked."
-- ---------------------------------------------------------------------------

CREATE TABLE shift_broadcast_records (
    id                        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    shift_id                  UUID        NOT NULL UNIQUE REFERENCES shifts (id) ON DELETE CASCADE,
    broadcast_by              UUID        NOT NULL REFERENCES users (id),
    broadcast_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Number of eligible clinicians the shift was sent to (e.g. 45 shown as "+45")
    eligible_clinicians_count INTEGER     NOT NULL DEFAULT 0,
    -- Radius used to filter nearby clinicians (from hospital_locations)
    broadcast_radius_km       DOUBLE PRECISION NOT NULL DEFAULT 5.0,
    -- Location label shown on the shift card, e.g. "Idi-Araba, Lagos"
    location_label            VARCHAR(255),
    created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_broadcast_records_shift_id ON shift_broadcast_records (shift_id);
