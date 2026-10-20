-- =========================================================================
-- Schema tests for notifications.notification (HU-03).
--
-- Run by tests/run-db-tests.sh as notifications_app after the migrations.
-- Everything runs inside one transaction that is rolled back at the end,
-- so no test data persists. Each block raises an exception on failure and
-- psql stops (ON_ERROR_STOP).
-- =========================================================================

BEGIN;

-- 1. Structure ------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'notifications') THEN
        RAISE EXCEPTION 'schema notifications does not exist';
    END IF;

    IF to_regclass('notifications.notification') IS NULL THEN
        RAISE EXCEPTION 'table notifications.notification does not exist';
    END IF;
END $$;

-- Exact column set: guards against storing e-mail bodies, recipient e-mail
-- addresses or reset links (content rules of the notification data model).
DO $$
DECLARE
    expected text := 'attempt_count:integer:NO,'
                  || 'channel:character varying:NO,'
                  || 'correlation_id:character varying:YES,'
                  || 'created_at:timestamp with time zone:NO,'
                  || 'id:uuid:NO,'
                  || 'last_error:character varying:YES,'
                  || 'read_at:timestamp with time zone:YES,'
                  || 'recipient_user_id:uuid:NO,'
                  || 'sent_at:timestamp with time zone:YES,'
                  || 'source_event_id:uuid:NO,'
                  || 'status:character varying:NO,'
                  || 'type:character varying:NO,'
                  || 'updated_at:timestamp with time zone:NO';
    actual text;
BEGIN
    SELECT string_agg(column_name || ':' || data_type || ':' || is_nullable, ',' ORDER BY column_name)
      INTO actual
      FROM information_schema.columns
     WHERE table_schema = 'notifications'
       AND table_name = 'notification';

    IF actual IS DISTINCT FROM expected THEN
        RAISE EXCEPTION 'unexpected columns. expected [%] got [%]', expected, actual;
    END IF;
END $$;

-- X-Correlation-Id values of up to 128 characters are accepted by the
-- notifications-api filter and by the identity outbox that emits the events.
DO $$
DECLARE
    max_length integer;
BEGIN
    SELECT character_maximum_length
      INTO max_length
      FROM information_schema.columns
     WHERE table_schema = 'notifications'
       AND table_name = 'notification'
       AND column_name = 'correlation_id';

    IF max_length IS DISTINCT FROM 128 THEN
        RAISE EXCEPTION 'correlation_id must hold 128 characters, got %', max_length;
    END IF;
END $$;

-- 2. Defaults -------------------------------------------------------------

DO $$
DECLARE
    row_found notifications.notification%ROWTYPE;
BEGIN
    INSERT INTO notifications.notification (recipient_user_id, type, source_event_id)
    VALUES (gen_random_uuid(), 'PASSWORD_RECOVERY', gen_random_uuid())
    RETURNING * INTO row_found;

    IF row_found.id IS NULL THEN
        RAISE EXCEPTION 'id is not generated';
    END IF;
    IF row_found.channel <> 'EMAIL' THEN
        RAISE EXCEPTION 'channel default must be EMAIL, got %', row_found.channel;
    END IF;
    IF row_found.status <> 'PENDING' THEN
        RAISE EXCEPTION 'status default must be PENDING, got %', row_found.status;
    END IF;
    IF row_found.attempt_count <> 0 THEN
        RAISE EXCEPTION 'attempt_count default must be 0, got %', row_found.attempt_count;
    END IF;
    IF row_found.created_at IS NULL OR row_found.updated_at IS NULL THEN
        RAISE EXCEPTION 'created_at and updated_at must default to now()';
    END IF;
END $$;

-- 3. Accepted notification types ------------------------------------------

DO $$
DECLARE
    accepted text;
BEGIN
    FOREACH accepted IN ARRAY ARRAY[
        'PASSWORD_RECOVERY',
        'APPOINTMENT_CONFIRMED',
        'APPOINTMENT_CANCELLED',
        'APPOINTMENT_RESCHEDULED',
        'APPOINTMENT_REMINDER'
    ] LOOP
        INSERT INTO notifications.notification (recipient_user_id, type, source_event_id)
        VALUES (gen_random_uuid(), accepted, gen_random_uuid());
    END LOOP;
END $$;

-- 4. Check constraints reject invalid values ------------------------------

DO $$
BEGIN
    BEGIN
        INSERT INTO notifications.notification (recipient_user_id, type, source_event_id)
        VALUES (gen_random_uuid(), 'MEDICATION_REMINDER', gen_random_uuid());
        RAISE EXCEPTION 'unknown type was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO notifications.notification (recipient_user_id, type, source_event_id, status)
        VALUES (gen_random_uuid(), 'PASSWORD_RECOVERY', gen_random_uuid(), 'DELIVERED');
        RAISE EXCEPTION 'unknown status was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO notifications.notification (recipient_user_id, type, source_event_id, channel)
        VALUES (gen_random_uuid(), 'PASSWORD_RECOVERY', gen_random_uuid(), 'SMS');
        RAISE EXCEPTION 'unknown channel was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO notifications.notification (recipient_user_id, type, source_event_id, attempt_count)
        VALUES (gen_random_uuid(), 'PASSWORD_RECOVERY', gen_random_uuid(), -1);
        RAISE EXCEPTION 'negative attempt_count was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- A SENT notification must record when it was sent.
    BEGIN
        INSERT INTO notifications.notification (recipient_user_id, type, source_event_id, status)
        VALUES (gen_random_uuid(), 'PASSWORD_RECOVERY', gen_random_uuid(), 'SENT');
        RAISE EXCEPTION 'SENT without sent_at was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    INSERT INTO notifications.notification (recipient_user_id, type, source_event_id, status, sent_at)
    VALUES (gen_random_uuid(), 'PASSWORD_RECOVERY', gen_random_uuid(), 'SENT', now());
END $$;

-- 5. Idempotency: one notification per source event -----------------------

DO $$
DECLARE
    event_id uuid := gen_random_uuid();
BEGIN
    INSERT INTO notifications.notification (recipient_user_id, type, source_event_id)
    VALUES (gen_random_uuid(), 'PASSWORD_RECOVERY', event_id);

    BEGIN
        INSERT INTO notifications.notification (recipient_user_id, type, source_event_id)
        VALUES (gen_random_uuid(), 'PASSWORD_RECOVERY', event_id);
        RAISE EXCEPTION 'duplicate source_event_id was accepted';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
END $$;

-- 6. updated_at is refreshed on update ------------------------------------

DO $$
DECLARE
    notification_id uuid;
    refreshed timestamptz;
BEGIN
    INSERT INTO notifications.notification (recipient_user_id, type, source_event_id, updated_at)
    VALUES (gen_random_uuid(), 'PASSWORD_RECOVERY', gen_random_uuid(), '2000-01-01T00:00:00Z')
    RETURNING id INTO notification_id;

    UPDATE notifications.notification
       SET attempt_count = attempt_count + 1
     WHERE id = notification_id
    RETURNING updated_at INTO refreshed;

    IF refreshed <= '2000-01-01T00:00:00Z'::timestamptz THEN
        RAISE EXCEPTION 'updated_at was not refreshed on update';
    END IF;
END $$;

-- 7. Indexes --------------------------------------------------------------

DO $$
BEGIN
    IF to_regclass('notifications.idx_notification_recipient_created') IS NULL THEN
        RAISE EXCEPTION 'index idx_notification_recipient_created is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_indexes
         WHERE schemaname = 'notifications'
           AND indexname = 'idx_notification_pending_failed'
           AND indexdef LIKE '%WHERE%'
    ) THEN
        RAISE EXCEPTION 'partial index idx_notification_pending_failed is missing';
    END IF;
END $$;

-- 8. Least privilege ------------------------------------------------------

SET LOCAL ROLE notifications_reader;

DO $$
BEGIN
    PERFORM count(*) FROM notifications.notification;

    BEGIN
        INSERT INTO notifications.notification (recipient_user_id, type, source_event_id)
        VALUES (gen_random_uuid(), 'PASSWORD_RECOVERY', gen_random_uuid());
        RAISE EXCEPTION 'reader was allowed to INSERT';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END $$;

SET LOCAL ROLE notifications_writer;

DO $$
DECLARE
    notification_id uuid;
BEGIN
    INSERT INTO notifications.notification (recipient_user_id, type, source_event_id)
    VALUES (gen_random_uuid(), 'PASSWORD_RECOVERY', gen_random_uuid())
    RETURNING id INTO notification_id;

    UPDATE notifications.notification
       SET status = 'FAILED', last_error = 'smtp timeout', attempt_count = 1
     WHERE id = notification_id;

    BEGIN
        DELETE FROM notifications.notification WHERE id = notification_id;
        RAISE EXCEPTION 'writer was allowed to DELETE';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END $$;

RESET ROLE;

ROLLBACK;

\echo 'notification schema tests passed'
