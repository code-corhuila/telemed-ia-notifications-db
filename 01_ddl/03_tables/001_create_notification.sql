-- -------------------------------------------------------------------------
-- notification: delivery record for one domain event (HU-03, HU-17, HU-18).
--
-- Content rules: the e-mail body, the recipient address and the password
-- reset link are NOT stored. They arrive in the event payload and are used
-- only while sending. recipient_user_id is an external reference to
-- identity-and-access (no FK across schemas).
--
-- source_event_id is the eventId of the consumed event; its uniqueness
-- makes at-least-once delivery idempotent.
-- -------------------------------------------------------------------------

CREATE TABLE notifications.notification (
    id                uuid         NOT NULL DEFAULT gen_random_uuid(),
    recipient_user_id uuid         NOT NULL,
    type              varchar(40)  NOT NULL,
    channel           varchar(20)  NOT NULL DEFAULT 'EMAIL',
    status            varchar(20)  NOT NULL DEFAULT 'PENDING',
    attempt_count     integer      NOT NULL DEFAULT 0,
    last_error        varchar(500),
    source_event_id   uuid         NOT NULL,
    correlation_id    varchar(100),
    sent_at           timestamptz,
    read_at           timestamptz,
    created_at        timestamptz  NOT NULL DEFAULT now(),
    updated_at        timestamptz  NOT NULL DEFAULT now(),

    CONSTRAINT pk_notification PRIMARY KEY (id),
    CONSTRAINT uq_notification_source_event_id UNIQUE (source_event_id),
    CONSTRAINT ck_notification_type CHECK (type IN (
        'PASSWORD_RECOVERY',
        'APPOINTMENT_CONFIRMED',
        'APPOINTMENT_CANCELLED',
        'APPOINTMENT_RESCHEDULED',
        'APPOINTMENT_REMINDER'
    )),
    CONSTRAINT ck_notification_channel CHECK (channel IN ('EMAIL')),
    CONSTRAINT ck_notification_status CHECK (status IN ('PENDING', 'SENT', 'FAILED')),
    CONSTRAINT ck_notification_attempt_count CHECK (attempt_count >= 0),
    CONSTRAINT ck_notification_sent_at CHECK (status <> 'SENT' OR sent_at IS NOT NULL)
);
