-- A user's notifications, newest first (HU-17 listing).
CREATE INDEX idx_notification_recipient_created
  ON notifications.notification (recipient_user_id, created_at DESC);

-- Deliveries still to send or to retry.
CREATE INDEX idx_notification_pending_failed
  ON notifications.notification (status, created_at)
  WHERE status IN ('PENDING', 'FAILED');
