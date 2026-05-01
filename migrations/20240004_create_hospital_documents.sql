-- Hospital legal documents (Step 2 — Legal Verification)
-- Each row is one document uploaded by a hospital.
-- Carries its own credential metadata (reg number, expiry, issuing authority)
-- and tracks the NexusCare compliance review lifecycle.

CREATE TABLE hospital_documents (
    id                  UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id         UUID              NOT NULL REFERENCES hospitals (id) ON DELETE CASCADE,
    document_type       document_type     NOT NULL,

    -- Uploaded file
    file_url            TEXT              NOT NULL,
    file_name           VARCHAR(255)      NOT NULL,
    file_mime_type      VARCHAR(100),                   -- e.g. 'application/pdf', 'image/png'
    file_size_bytes     BIGINT,                         -- enforced ≤ 10 MB at app layer

    -- Credential metadata entered by the hospital (e.g. "HOSP-4829-X")
    credential_number   VARCHAR(100),
    expiry_date         DATE,
    issuing_authority   issuing_authority,

    -- Submission lifecycle
    submission_status   submission_status NOT NULL DEFAULT 'draft',
    uploaded_at         TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ       NOT NULL DEFAULT NOW(),

    -- Compliance review (filled by NexusCare super_admin)
    reviewed_at         TIMESTAMPTZ,
    reviewed_by         UUID              REFERENCES users (id) ON DELETE SET NULL,
    review_notes        TEXT,

    -- A hospital may only have one active document per type
    CONSTRAINT uq_hospital_document_type UNIQUE (hospital_id, document_type)
);

CREATE INDEX idx_hosp_docs_hospital_id       ON hospital_documents (hospital_id);
CREATE INDEX idx_hosp_docs_document_type     ON hospital_documents (document_type);
CREATE INDEX idx_hosp_docs_submission_status ON hospital_documents (submission_status);
CREATE INDEX idx_hosp_docs_expiry_date       ON hospital_documents (expiry_date);

CREATE TRIGGER trg_hospital_documents_updated_at
    BEFORE UPDATE ON hospital_documents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
