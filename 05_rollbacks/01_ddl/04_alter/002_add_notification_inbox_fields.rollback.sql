-- Fails if an event already notified more than one recipient or a
-- DOCUMENT_READY notification exists; remove those rows before rolling back.
ALTER TABLE notifications.notification
    DROP CONSTRAINT ck_notification_subject_complete,
    DROP CONSTRAINT ck_notification_subject_type,
    DROP COLUMN subject_at,
    DROP COLUMN subject_id,
    DROP COLUMN subject_type,

    DROP CONSTRAINT ck_notification_type,
    ADD CONSTRAINT ck_notification_type CHECK (type IN (
        'PASSWORD_RECOVERY',
        'APPOINTMENT_CONFIRMED',
        'APPOINTMENT_CANCELLED',
        'APPOINTMENT_RESCHEDULED',
        'APPOINTMENT_REMINDER'
    )),

    DROP CONSTRAINT uq_notification_source_event_recipient,
    ADD CONSTRAINT uq_notification_source_event_id UNIQUE (source_event_id);
