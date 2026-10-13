# Booking reminder consumer

The API owns server-side reminders24hours and1hour before the scheduled booking start. Eligible bookings are confirmed/rescheduled and not canceled, completed or checked in. The agreed scheduler contract uses a10-minute late window, schedule-revision/stage deduplication, dispatch-time revalidation and bookingAlerts preferences. Missed stages for short-notice confirmation/rescheduling and due points before rollout are skipped. Backend implementation and deployment are separate acceptance gates.

Visible push event types are customer_booking_reminder_24h and customer_booking_reminder_1h. Existing route/url is /account/bookings/<booking-id>; notificationId is stable per booking/schedule revision/stage. Copy includes booking reference, vendor and scheduled local date/time. Inbox schema stays unchanged; inbox rows still mark read when tapped.

Mobile distinguishes notification receipt from an explicit tap. Foreground receipt refreshes existing ticket/inbox state without opening another screen. Background/cold-start taps and Android local foreground-banner taps open the booking after authenticated account detail fetch. Only relative account-booking routes with safe opaque IDs are accepted; URLs, query/fragment components and encoded separators are rejected. Push data cannot set its own opened flag.

Duplicate taps do not stack routes. Pending fetches time out after20seconds and expose a Bookings-list fallback. Account replacement clears the pending signal, invalidates late fetches and closes a booking route opened by the old account's notification. Detail navigation always uses the fetched booking snapshot, never trusted notification content.

Delivery acceptance requires the backend scheduler/outbox migration and worker rollout, real due notifications, preference/reschedule/cancellation verification, then actual tap/inbox checks on Zero32 and Zero32 Domain. A build/install or a mocked push test does not prove server delivery.
