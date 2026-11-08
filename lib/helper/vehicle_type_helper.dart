/// Vehicle category types from the backend. Besides car and motor_bike,
/// E-Ride Move adds goods vehicles (tricycle, pickup, dyna, truck); a trip on
/// one of them is a move, with the price agreed with the customer in person.
class VehicleTypeHelper {
  static const List<String> moveTypes = ['tricycle', 'pickup', 'dyna', 'truck'];

  static bool isMove(String? type) => moveTypes.contains(type);
}
