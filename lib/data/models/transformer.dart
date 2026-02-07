class Transformer {
  final String id;
  final String status;
  final double latitude;
  final double longitude;
  final String capacity;
  final String address;
  final String lastMaintenance;
  final String phaseType;

  Transformer({
    required this.id,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.capacity,
    required this.address,
    required this.lastMaintenance,
    required this.phaseType,
  });
}