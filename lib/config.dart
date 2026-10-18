// App-wide switches.

/// When true, the app itself evaluates thresholds and writes alerts while it
/// is open (the original behaviour). Set this to false once the Cloud
/// Functions in /functions are deployed: the server then raises alerts
/// (even when no app is open) and sends push notifications, and leaving this
/// on would create duplicate alerts.
const bool kClientSideAlerts = true;

/// A device counts as online if its heartbeat is newer than this. Generous
/// enough that a slow upload cycle on the ESP32 does not flip the status to
/// "offline" and back again.
const int kDeviceStaleMs = 30000;
