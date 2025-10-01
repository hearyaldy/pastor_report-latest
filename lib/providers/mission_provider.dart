// lib/providers/mission_provider.dart
import 'package:flutter/material.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/models/mission_model.dart';
import 'package:pastor_report/services/department_service.dart';
import 'package:pastor_report/services/mission_service.dart';

class MissionProvider with ChangeNotifier {
  final MissionService _missionService = MissionService();
  final DepartmentService _departmentService = DepartmentService();

  bool _isLoading = false;
  String? _errorMessage;

  List<Mission> _missions = [];
  Mission? _selectedMission;
  List<Department> _departments = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Mission> get missions => _missions;
  Mission? get selectedMission => _selectedMission;
  List<Department> get departments => _departments;
  bool get isUsingMissionStructure =>
      _departmentService.isUsingMissionStructure();

  // Initialize provider and load data
  Future<void> initialize() async {
    await loadMissions();
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error message
  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Load all missions
  Future<void> loadMissions() async {
    _setLoading(true);
    try {
      _missions = await _missionService.getAllMissions();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load missions: $e');
    }
    _setLoading(false);
  }

  // Select a mission by id or name
  Future<void> selectMission({String? id, String? name}) async {
    _setLoading(true);
    try {
      if (id != null) {
        // Find mission by id in loaded missions first
        final missionIndex = _missions.indexWhere((m) => m.id == id);
        if (missionIndex >= 0) {
          _selectedMission = _missions[missionIndex];
        } else {
          // If not found, load from stream
          _selectedMission =
              await _missionService.getMissionWithDepartmentsStream(id).first;
        }
      } else if (name != null) {
        // Find mission by name
        final missionIndex = _missions.indexWhere((m) => m.name == name);
        if (missionIndex >= 0) {
          _selectedMission = _missions[missionIndex];
        } else {
          _selectedMission = await _missionService.getMissionByName(name);
        }
      }

      // Load departments for the selected mission
      if (_selectedMission != null) {
        await loadDepartments(missionName: _selectedMission!.name);
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to select mission: $e');
    }
    _setLoading(false);
  }

  // Load departments for a mission
  Future<void> loadDepartments({String? missionName}) async {
    _setLoading(true);
    try {
      if (missionName != null) {
        _departments =
            await _departmentService.getDepartments(mission: missionName);
      } else if (_selectedMission != null) {
        _departments = await _departmentService.getDepartments(
            mission: _selectedMission!.name);
      } else {
        _departments = await _departmentService.getDepartments();
      }
      notifyListeners();
    } catch (e) {
      _setError('Failed to load departments: $e');
    }
    _setLoading(false);
  }

  // Add a department to the selected mission
  Future<void> addDepartment(Department department) async {
    _setLoading(true);
    try {
      await _departmentService.addDepartment(department);
      await loadDepartments(missionName: department.mission);
    } catch (e) {
      _setError('Failed to add department: $e');
    }
    _setLoading(false);
  }

  // Update a department
  Future<void> updateDepartment(Department department) async {
    _setLoading(true);
    try {
      await _departmentService.updateDepartment(department);
      await loadDepartments(missionName: department.mission);
    } catch (e) {
      _setError('Failed to update department: $e');
    }
    _setLoading(false);
  }

  // Delete a department
  Future<void> deleteDepartment(String departmentId,
      {String? missionName}) async {
    _setLoading(true);
    try {
      await _departmentService.deleteDepartment(departmentId,
          missionName: missionName ?? _selectedMission?.name);
      await loadDepartments(missionName: missionName ?? _selectedMission?.name);
    } catch (e) {
      _setError('Failed to delete department: $e');
    }
    _setLoading(false);
  }

  // Add a new mission
  Future<void> addMission(Mission mission) async {
    _setLoading(true);
    try {
      final missionId = await _missionService.addMission(mission);
      await loadMissions();
      // Select the newly added mission
      await selectMission(id: missionId);
    } catch (e) {
      _setError('Failed to add mission: $e');
    }
    _setLoading(false);
  }

  // Update a mission
  Future<void> updateMission(Mission mission) async {
    _setLoading(true);
    try {
      await _missionService.updateMission(mission);
      await loadMissions();
      // Refresh the selected mission if it's the one being updated
      if (_selectedMission?.id == mission.id) {
        await selectMission(id: mission.id);
      }
    } catch (e) {
      _setError('Failed to update mission: $e');
    }
    _setLoading(false);
  }

  // Delete a mission
  Future<void> deleteMission(String missionId) async {
    _setLoading(true);
    try {
      await _missionService.deleteMission(missionId);
      // Clear selection if the deleted mission was selected
      if (_selectedMission?.id == missionId) {
        _selectedMission = null;
        _departments = [];
      }
      await loadMissions();
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete mission: $e');
    }
    _setLoading(false);
  }

  // Toggle between mission structure and legacy structure
  void toggleUsingMissionStructure(bool use) {
    _departmentService.setUseMissionStructure(use);
    loadDepartments(missionName: _selectedMission?.name);
    notifyListeners();
  }

  // Migrate data from legacy structure to mission structure
  Future<void> migrateToMissionStructure() async {
    _setLoading(true);
    try {
      await _departmentService.migrateToMissionStructure();
      _departmentService.setUseMissionStructure(true);
      await loadMissions();
      await loadDepartments();
    } catch (e) {
      _setError('Failed to migrate data: $e');
    }
    _setLoading(false);
  }

  // For admin/development use: seed or reseed data
  Future<void> reseedAllData() async {
    _setLoading(true);
    try {
      if (isUsingMissionStructure) {
        await _missionService.reseedAllMissionsWithDepartments();
      } else {
        await _departmentService.reseedAllDepartments();
      }
      await loadMissions();
      await loadDepartments();
    } catch (e) {
      _setError('Failed to reseed data: $e');
    }
    _setLoading(false);
  }
}
