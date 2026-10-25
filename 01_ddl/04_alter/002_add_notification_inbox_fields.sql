-- HU-17/HU-18 inbox. One appointment event notifies both the patient and the
-- professional, so idempotency is per source event AND recipient.
--
-- subject_type/subject_id point to what the notification is about, so the
-- portal can open it; subject_at is the appointment start shown in the text.
-- Names are not stored: the portal reads them from the owning services.
ALTER TABLE notifications.notification
    DROP CONSTRAINT uq_notification_source_event_id,
    ADD CONSTRAINT uq_notification_source_event_recipient
        UNIQUE (source_event_id, recipient_user_id),

    DROP CONSTRAINT ck_notification_type,
    ADD CONSTRAINT ck_notification_type CHECK (type IN (
        'PASSWORD_RECOVERY',
        'APPOINTMENT_CONFIRMED',
        'APPOINTMENT_CANCELLED',
        'APPOINTMENT_RESCHEDULED',
        'APPOINTMENT_REMINDER',
        'DOCUMENT_READY'
    )),

    ADD COLUMN subject_type varchar(20),
    ADD COLUMN subject_id   uuid,
    ADD COLUMN subject_at   timestamptz,

    ADD CONSTRAINT ck_notification_subject_type
        CHECK (subject_type IN ('APPOINTMENT', 'DOCUMENT')),
    ADD CONSTRAINT ck_notification_subject_complete
        CHECK ((subject_type IS NULL) = (subject_id IS NULL));
