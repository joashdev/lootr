import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/database/app_database.dart';
import '../../domain/entities/household.dart';
import '../../domain/entities/household_member.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/value_objects/field_types.dart';
import 'database_provider.dart';
import 'repo_providers.dart';

class HouseholdSummary {
  const HouseholdSummary({
    required this.household,
    required this.memberCount,
    required this.currentUserRole,
  });

  final Household household;
  final int memberCount;
  final String? currentUserRole;
}

class HouseholdMemberView {
  const HouseholdMemberView({
    required this.member,
    required this.displayName,
    required this.roleLabel,
    required this.isCurrentUser,
    required this.isCreator,
  });

  final HouseholdMember member;
  final String displayName;
  final String roleLabel;
  final bool isCurrentUser;
  final bool isCreator;
}

class HouseholdDetailView {
  const HouseholdDetailView({
    required this.household,
    required this.members,
    required this.currentUserId,
  });

  final Household household;
  final List<HouseholdMemberView> members;
  final String? currentUserId;
}

final householdsProvider = StreamProvider<List<HouseholdSummary>>((ref) {
  final householdRepo = ref.watch(householdRepoProvider);
  final userRepo = ref.watch(userRepoProvider);
  final db = ref.watch(databaseProvider);

  final householdsStream = householdRepo.watchAll().map(
    (rows) => rows.map((row) => row.toEntity()).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
  );
  final membersStream = (db.select(
    db.householdMembers,
  )..where((row) => row.deletedAt.isNull())).watch();
  final currentUserIdStream = userRepo.watchCurrentUser().map(
    (user) => user?.id,
  );

  return Rx.combineLatest3(
    householdsStream,
    membersStream,
    currentUserIdStream,
    (
      List<Household> households,
      List<HouseholdMemberData> members,
      String? currentUserId,
    ) {
      return households.map((household) {
        final householdMembers = members
            .where((member) => member.householdId == household.id)
            .toList();
        String? currentUserRole;
        if (currentUserId != null) {
          for (final member in householdMembers) {
            if (member.userId == currentUserId) {
              currentUserRole = member.role;
              break;
            }
          }
        }

        return HouseholdSummary(
          household: household,
          memberCount: householdMembers.length,
          currentUserRole: currentUserRole,
        );
      }).toList();
    },
  );
});

final householdDetailProvider =
    StreamProvider.family<HouseholdDetailView?, String>((ref, householdId) {
      final householdRepo = ref.watch(householdRepoProvider);
      final userRepo = ref.watch(userRepoProvider);
      final db = ref.watch(databaseProvider);

      final householdStream = householdRepo
          .watchById(householdId)
          .map((row) => row?.toEntity());
      final membersStream = householdRepo
          .watchMembers(householdId)
          .map(
            (rows) =>
                rows.map((row) => row.toEntity()).toList()..sort((left, right) {
                  final roleCompare = _roleWeight(
                    left.role,
                  ).compareTo(_roleWeight(right.role));
                  if (roleCompare != 0) return roleCompare;
                  return left.createdAt.compareTo(right.createdAt);
                }),
          );
      final usersStream = (db.select(
        db.users,
      )..where((row) => row.deletedAt.isNull())).watch();
      final currentUserIdStream = userRepo.watchCurrentUser().map(
        (user) => user?.id,
      );

      return Rx.combineLatest4(
        householdStream,
        membersStream,
        usersStream,
        currentUserIdStream,
        (
          Household? household,
          List<HouseholdMember> members,
          List<UserData> users,
          String? currentUserId,
        ) {
          if (household == null) return null;

          final userMap = {for (final user in users) user.id: user};
          final memberViews = members.map((member) {
            final user = userMap[member.userId];
            return HouseholdMemberView(
              member: member,
              displayName: _displayNameForUser(
                user,
                member.userId,
                isCurrentUser: member.userId == currentUserId,
              ),
              roleLabel: _roleLabel(member.role),
              isCurrentUser: member.userId == currentUserId,
              isCreator: member.userId == household.createdByUserId,
            );
          }).toList();

          return HouseholdDetailView(
            household: household,
            members: memberViews,
            currentUserId: currentUserId,
          );
        },
      );
    });

String _displayNameForUser(
  UserData? user,
  String userId, {
  required bool isCurrentUser,
}) {
  final displayName = user?.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) {
    return isCurrentUser ? '$displayName (You)' : displayName;
  }

  final email = user?.email?.trim();
  if (email != null && email.isNotEmpty) {
    return isCurrentUser ? '$email (You)' : email;
  }

  final shortId = userId.length <= 8 ? userId : '${userId.substring(0, 8)}...';
  return isCurrentUser ? 'You' : shortId;
}

String roleLabel(String role) => _roleLabel(role);

String _roleLabel(String role) {
  switch (role) {
    case HouseholdRole.owner:
      return 'Owner';
    case HouseholdRole.viewer:
      return 'Viewer';
    case HouseholdRole.member:
    default:
      return 'Member';
  }
}

int _roleWeight(String role) {
  switch (role) {
    case HouseholdRole.owner:
      return 0;
    case HouseholdRole.member:
      return 1;
    case HouseholdRole.viewer:
    default:
      return 2;
  }
}
