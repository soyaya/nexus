-- Create custom enum types used across the schema

-- Hospital onboarding flow: 4 steps matching the UI labels
CREATE TYPE registration_step AS ENUM (
    'profile_setup',   -- Step 1: basic institutional credentials
    'credentials',     -- Step 2: legal document uploads
    'verification',    -- Step 3: NexusCare compliance review (24-48h)
    'access_granted'   -- Step 4: accreditation granted
);

-- CAC / regulatory verification status
CREATE TYPE verification_status AS ENUM (
    'pending',
    'verified',
    'rejected',
    'under_review'
);

-- Platform user roles
CREATE TYPE user_role AS ENUM (
    'hospital_admin',
    'staff',
    'super_admin'
);

-- Legal document types (Step 2 — Legal Verification)
CREATE TYPE document_type AS ENUM (
    'operational_license',            -- Ministry of Health registration (REQUIRED)
    'medical_certificate_of_standards', -- Clinical quality & safety certification
    'tax_compliance_certificate',     -- TCC — proof of current tax status
    'cac_certificate',                -- CAC certificate of incorporation
    'director_id',                    -- Director / trustee ID
    'other'
);

-- Issuing authority for a legal document
CREATE TYPE issuing_authority AS ENUM (
    'ministry_of_health_federal',
    'ministry_of_health_state',
    'nafdac_federal',
    'corporate_affairs_commission',
    'federal_inland_revenue_service',
    'other'
);

-- Submission state of an uploaded document
CREATE TYPE submission_status AS ENUM (
    'draft',        -- saved but not yet submitted
    'under_review', -- submitted, awaiting compliance check
    'approved',
    'rejected'
);

-- Notification delivery channel (Step 3: "SMS and email notification once your status changes")
CREATE TYPE notification_channel AS ENUM (
    'email',
    'sms',
    'in_app'
);

-- The onboarding event that triggered a notification
CREATE TYPE notification_event AS ENUM (
    'documents_submitted',      -- verification clock started
    'verification_approved',    -- compliance review passed
    'verification_rejected',    -- action required
    'access_granted',           -- onboarding complete
    'document_expiry_warning'   -- document expiring within 30 days
);

-- Delivery lifecycle of a single notification
CREATE TYPE notification_status AS ENUM (
    'pending',
    'sent',
    'failed',
    'read'
);

-- Hospital action permissions (Verification Pending screen)
-- Read-only actions are allowed; write/transactional actions are restricted.
CREATE TYPE hospital_action AS ENUM (
    -- Read-only (allowed while pending)
    'browse_app',
    'view_doctor_profiles',
    'explore_system_tools',
    -- Restricted until verified
    'create_shift',
    'approve_contract',
    'invite_staff',
    'initiate_payment',
    'export_data'
);

-- Resolved access level for a given action
CREATE TYPE access_level AS ENUM (
    'allowed',      -- fully permitted
    'restricted',   -- visible but blocked with a reason message
    'hidden'        -- not shown in the UI at all
);

-- Platform features unlocked on accreditation (Accreditation Granted screen)
-- Only the 4 feature cards shown on the screen are modelled.
CREATE TYPE platform_feature AS ENUM (
    'unlimited_shift_broadcasting',  -- reach entire vetted clinician network
    'direct_clinician_outreach',     -- invite specialists to departments
    'verified_payroll_integration',  -- automated billing & compensation
    'performance_analytics'          -- staffing efficiency & cost insights
);

-- Payment / billing enums (Add Payment Method screen — powered by Paystack)
CREATE TYPE card_type AS ENUM (
    'visa',
    'mastercard',
    'verve',
    'american_express',
    'unknown'
);

CREATE TYPE transaction_status AS ENUM (
    'pending',   -- charge initiated, awaiting Paystack confirmation
    'success',   -- Paystack confirmed charge succeeded
    'failed',    -- charge declined / failed
    'reversed'   -- charge reversed / refunded
);

CREATE TYPE billing_event_type AS ENUM (
    'shift_fee'   -- per-shift clinician fee ("You'll be billed for shifts")
);

-- Clinical Dashboard enums

-- Clinician specialty
CREATE TYPE clinical_specialty AS ENUM (
    'emergency_medicine',
    'pediatrics',
    'icu_specialist',
    'general_nursing',
    'pharmacy',
    'lab_technician',
    'surgery',
    'radiology',
    'anesthesiology',
    'cardiology',
    'obstetrics',
    'psychiatry',
    'other'
);

-- Workforce Pool availability status
CREATE TYPE clinician_availability AS ENUM (
    'available_now',  -- free, not on a shift
    'on_site',        -- currently working at this hospital
    'off_duty',       -- off duty, has a resume time
    'unavailable'     -- on leave / blocked
);

-- Shift lifecycle
CREATE TYPE shift_status AS ENUM (
    'open',        -- posted, awaiting assignment
    'upcoming',    -- assigned, not yet started
    'in_progress', -- currently running
    'completed',
    'cancelled',
    'no_show'
);

-- Shift priority badge (STAT / URGENT shown on dashboard)
CREATE TYPE shift_priority AS ENUM (
    'normal',
    'stat',    -- orange badge
    'urgent'   -- yellow/red badge
);

-- How a clinician's clock-in was verified
CREATE TYPE clockin_method AS ENUM (
    'gps',      -- GPS geofence verified
    'qr_code',  -- QR code scanned on-site
    'manual'    -- confirmed by hospital admin
);

-- Shift creation wizard enums (Step 1 of 4 — Basic Information)

-- Delivery mode radio toggle: In-person / Virtual
CREATE TYPE shift_type AS ENUM (
    'in_person',  -- on-site, GPS clock-in enforced
    'virtual'     -- remote / telemedicine
);

-- Broad role category dropdown in the wizard
CREATE TYPE role_category AS ENUM (
    'doctor',
    'nurse',
    'pharmacist',
    'lab_technician',
    'radiographer',
    'physiotherapist',
    'other'
);

-- Which step of the 5-step shift creation wizard the draft is on
CREATE TYPE shift_wizard_step AS ENUM (
    'basic_information',   -- Step 1: role, specialty, type, date, duration, urgency
    'compensation',        -- Step 2: pay type, hourly rate, bonuses, allowances
    'shift_description',   -- Step 3: job description, tasks, deliverables, equipment
    'requirements',        -- Step 4: qualifications, institutional verification
    'preview'              -- Step 5: shift card preview + Broadcast Shift action
);

-- Step 2 Shift Compensation enums
CREATE TYPE pay_type AS ENUM (
    'hourly_rate',  -- rate × hours, best for standard rotations
    'fixed_rate'    -- lump sum per shift
);

-- Step 3 Shift Description item categories
CREATE TYPE shift_item_category AS ENUM (
    'task',         -- clinical task the clinician must perform
    'deliverable',  -- expected output / document
    'equipment'     -- resource provided to the clinician
);
