class CellEntity {
  final String id;
  final String name;
  final String? leaderId; // Agora é opcional (?)
  final String? coLeaderId;
  final String? hostId;
  final String address;
  final String neighborhood;
  final String meetingDay;
  final String meetingTime;
  final String category;
  final bool isActive;
  final DateTime createdAt;

  const CellEntity({
    required this.id,
    required this.name,
    this.leaderId, // Removido o 'required'
    this.coLeaderId,
    this.hostId,
    required this.address,
    required this.neighborhood,
    required this.meetingDay,
    required this.meetingTime,
    required this.category,
    this.isActive = true,
    required this.createdAt,
  });
}