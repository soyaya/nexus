-- Billing: payment methods and transaction history
-- "Add Payment Method — You'll be billed for shifts"
-- "Secure payment powered by Paystack"
--
-- SECURITY NOTE: Raw card numbers and CVVs are NEVER stored.
-- The Paystack SDK tokenizes card details on the frontend and returns an
-- authorization_code. Only that token + masked display metadata is persisted.

-- ---------------------------------------------------------------------------
-- Payment methods
-- ---------------------------------------------------------------------------

CREATE TABLE hospital_payment_methods (
    id                           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id                  UUID         NOT NULL REFERENCES hospitals (id) ON DELETE CASCADE,

    -- Paystack token — the only sensitive reference stored
    paystack_authorization_code  TEXT         NOT NULL,
    paystack_customer_code       VARCHAR(100),

    -- Display-only card metadata (safe to store, returned by Paystack)
    cardholder_name              VARCHAR(255) NOT NULL,
    card_last_four               CHAR(4)      NOT NULL,
    card_type                    card_type    NOT NULL DEFAULT 'unknown',
    card_expiry                  VARCHAR(5)   NOT NULL,   -- MM/YY
    bank_name                    VARCHAR(100),

    is_default                   BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active                    BOOLEAN      NOT NULL DEFAULT TRUE,

    added_by                     UUID         NOT NULL REFERENCES users (id),
    created_at                   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at                   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payment_methods_hospital_id ON hospital_payment_methods (hospital_id);
CREATE INDEX idx_payment_methods_is_default  ON hospital_payment_methods (hospital_id, is_default)
    WHERE is_default = TRUE;

-- Ensure only one default payment method per hospital
CREATE UNIQUE INDEX uq_hospital_default_payment
    ON hospital_payment_methods (hospital_id)
    WHERE is_default = TRUE AND is_active = TRUE;

CREATE TRIGGER trg_payment_methods_updated_at
    BEFORE UPDATE ON hospital_payment_methods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ---------------------------------------------------------------------------
-- Billing transactions
-- ---------------------------------------------------------------------------

CREATE TABLE billing_transactions (
    id                      UUID                 PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id             UUID                 NOT NULL REFERENCES hospitals (id) ON DELETE CASCADE,
    payment_method_id       UUID                 REFERENCES hospital_payment_methods (id) ON DELETE SET NULL,

    event_type              billing_event_type   NOT NULL,
    -- Amount in smallest currency unit (kobo for NGN: 500000 = ₦5,000.00)
    amount_kobo             BIGINT               NOT NULL CHECK (amount_kobo != 0),
    currency                CHAR(3)              NOT NULL DEFAULT 'NGN',

    status                  transaction_status   NOT NULL DEFAULT 'pending',

    -- Paystack references
    paystack_reference      VARCHAR(100)         UNIQUE,
    paystack_transaction_id VARCHAR(100),

    -- What was billed
    -- NULL for non-shift charges (subscription fees, adjustments)
    shift_id                UUID,
    description             TEXT,

    initiated_at            TIMESTAMPTZ          NOT NULL DEFAULT NOW(),
    completed_at            TIMESTAMPTZ,
    created_at              TIMESTAMPTZ          NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ          NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_billing_hospital_id    ON billing_transactions (hospital_id);
CREATE INDEX idx_billing_status         ON billing_transactions (status);
CREATE INDEX idx_billing_event_type     ON billing_transactions (event_type);
CREATE INDEX idx_billing_shift_id       ON billing_transactions (shift_id) WHERE shift_id IS NOT NULL;
CREATE INDEX idx_billing_initiated_at   ON billing_transactions (initiated_at DESC);
CREATE INDEX idx_billing_paystack_ref   ON billing_transactions (paystack_reference)
    WHERE paystack_reference IS NOT NULL;

CREATE TRIGGER trg_billing_transactions_updated_at
    BEFORE UPDATE ON billing_transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
