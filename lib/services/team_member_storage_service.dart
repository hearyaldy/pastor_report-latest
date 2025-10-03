import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pastor_report/models/team_member_model.dart';

class TeamMemberStorageService {
  static TeamMemberStorageService? _instance;
  static TeamMemberStorageService get instance {
    _instance ??= TeamMemberStorageService._();
    return _instance!;
  }

  TeamMemberStorageService._();

  static const String _storageKey = 'team_members';
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('✅ TeamMemberStorageService initialized');
  }

  /// Get all team members
  Future<List<TeamMember>> getAllTeamMembers() async {
    try {
      final String? jsonString = _prefs?.getString(_storageKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      final members = jsonList
          .map((json) => TeamMember.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort by name
      members.sort((a, b) => a.name.compareTo(b.name));

      return members;
    } catch (e) {
      debugPrint('❌ Error loading team members: $e');
      return [];
    }
  }

  /// Get team members for specific user
  Future<List<TeamMember>> getUserTeamMembers(String userId) async {
    final allMembers = await getAllTeamMembers();
    return allMembers.where((member) => member.userId == userId).toList();
  }

  /// Save a team member
  Future<bool> saveTeamMember(TeamMember member) async {
    try {
      final members = await getAllTeamMembers();

      // Check if member exists (update) or new (add)
      final index = members.indexWhere((m) => m.id == member.id);
      if (index != -1) {
        members[index] = member.copyWith(updatedAt: DateTime.now());
      } else {
        members.add(member);
      }

      final jsonString = jsonEncode(members.map((m) => m.toJson()).toList());
      await _prefs?.setString(_storageKey, jsonString);

      debugPrint('✅ Team member saved: ${member.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving team member: $e');
      return false;
    }
  }

  /// Delete a team member
  Future<bool> deleteTeamMember(String memberId) async {
    try {
      final members = await getAllTeamMembers();
      members.removeWhere((m) => m.id == memberId);

      final jsonString = jsonEncode(members.map((m) => m.toJson()).toList());
      await _prefs?.setString(_storageKey, jsonString);

      debugPrint('🗑️ Team member deleted: $memberId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting team member: $e');
      return false;
    }
  }

  /// Get team member by ID
  Future<TeamMember?> getTeamMemberById(String memberId) async {
    final members = await getAllTeamMembers();
    try {
      return members.firstWhere((m) => m.id == memberId);
    } catch (e) {
      return null;
    }
  }
}
