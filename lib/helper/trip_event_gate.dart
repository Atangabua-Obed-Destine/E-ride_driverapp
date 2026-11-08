/// A trip event reaches the app twice: over the websocket and as a push. Both are
/// kept, because either can be late or lost on a mobile network, but only the first
/// to arrive acts. Handling both opened the request screen twice, or went to the
/// dashboard or the review screen twice.
class TripEventGate {
  static const String request = 'request';
  static const String cancelled = 'cancelled';
  static const String taken = 'taken';
  static const String paid = 'paid';

  static const Duration _window = Duration(seconds: 60);
  static final Map<String, DateTime> _seen = {};

  /// True the first time this event is seen for this trip.
  static bool firstTime(String? tripId, String event) {
    if (tripId == null || tripId.isEmpty) return true;
    final DateTime now = DateTime.now();
    _seen.removeWhere((_, at) => now.difference(at) > _window);
    final String key = '$tripId/$event';
    if (_seen.containsKey(key)) return false;
    _seen[key] = now;
    return true;
  }

  /// False when the websocket already delivered the event in this push.
  static bool shouldHandlePush(Map<String, dynamic> data) {
    final String? event = _eventOfPush(data['action']?.toString());
    return event == null || firstTime(data['ride_request_id']?.toString(), event);
  }

  static String? _eventOfPush(String? action) {
    switch (action) {
      case 'new_ride_request':
      case 'new_parcel_request':
        return request;
      case 'customer_canceled_trip':
        return cancelled;
      case 'another_driver_assigned':
        return taken;
      case 'payment_successful':
        return paid;
      default:
        return null;
    }
  }
}
