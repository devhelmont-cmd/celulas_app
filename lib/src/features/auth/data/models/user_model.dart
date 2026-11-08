// lib/src/features/auth/data/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    super.name,
    super.photoUrl,
    super.roles,
    super.primaryCellId,
    super.phone,
    super.birthDate,
    super.gender,
    super.maritalStatus,
    super.profession,
    super.address,
    super.conversionDate,
    super.isWaterBaptized,
    super.waterBaptismDate,
    super.isHolySpiritBaptized,
    super.originChurch,
    super.ministry,
    super.completedCourses,
    super.customRoles,
  });

  factory UserModel.fromFirebaseUser(firebase.User user, {String? primaryCellId}) {
    return UserModel(
      id: user.uid,
      email: user.email ?? '',
      name: user.displayName,
      photoUrl: user.photoURL,
      roles: const [UserRole.member],
      primaryCellId: primaryCellId,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      name: map['name'],
      photoUrl: map['photoUrl'],
      roles: (map['roles'] as List<dynamic>?)
          ?.map(
            (e) => UserRole.values.firstWhere(
              (role) => role.name == e,
          orElse: () => UserRole.member,
        ),
      )
          .toList() ??
          [UserRole.member],
      primaryCellId: map['primaryCellId'],
      phone: map['phone'],
      birthDate: (map['birthDate'] as Timestamp?)?.toDate(),
      gender: map['gender'],
      maritalStatus: map['maritalStatus'],
      profession: map['profession'],
      address: map['address'],
      conversionDate: (map['conversionDate'] as Timestamp?)?.toDate(),
      isWaterBaptized: map['isWaterBaptized'],
      waterBaptismDate: (map['waterBaptismDate'] as Timestamp?)?.toDate(),
      isHolySpiritBaptized: map['isHolySpiritBaptized'],
      originChurch: map['originChurch'],
      ministry: map['ministry'],
      completedCourses: map['completedCourses'],
      customRoles: map['customRoles'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'roles': roles.map((r) => r.name).toList(),
      'primaryCellId': primaryCellId,
      'phone': phone,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'gender': gender,
      'maritalStatus': maritalStatus,
      'profession': profession,
      'address': address,
      'conversionDate':
      conversionDate != null ? Timestamp.fromDate(conversionDate!) : null,
      'isWaterBaptized': isWaterBaptized,
      'waterBaptismDate': waterBaptismDate != null
          ? Timestamp.fromDate(waterBaptismDate!)
          : null,
      'isHolySpiritBaptized': isHolySpiritBaptized,
      'originChurch': originChurch,
      'ministry': ministry,
      'completedCourses': completedCourses,
      'customRoles': customRoles,
    };
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      email: entity.email,
      name: entity.name,
      photoUrl: entity.photoUrl,
      roles: entity.roles,
      primaryCellId: entity.primaryCellId,
      phone: entity.phone,
      birthDate: entity.birthDate,
      gender: entity.gender,
      maritalStatus: entity.maritalStatus,
      profession: entity.profession,
      address: entity.address,
      conversionDate: entity.conversionDate,
      isWaterBaptized: entity.isWaterBaptized,
      waterBaptismDate: entity.waterBaptismDate,
      isHolySpiritBaptized: entity.isHolySpiritBaptized,
      originChurch: entity.originChurch,
      ministry: entity.ministry,
      completedCourses: entity.completedCourses,
      customRoles: entity.customRoles,
    );
  }
}