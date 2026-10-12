class UnlinkedUserOrMember {
  final String id;
  final String name;
  final String? email;
  final String? currentCellName;
  final bool isRegisteredUser;
  final String? userId;

  UnlinkedUserOrMember({
    required this.id,
    required this.name,
    this.email,
    this.currentCellName,
    required this.isRegisteredUser,
    this.userId,
  });
}