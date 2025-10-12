import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:pastor_report/models/todo_model.dart';

/// Cloud storage service for todos using Firebase Firestore
class TodoStorageService {
  static const String _todosCollection = 'todos';
  static final TodoStorageService instance = TodoStorageService._();

  TodoStorageService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user's ID
  String? get _userId => _auth.currentUser?.uid;

  Future<void> initialize() async {
    debugPrint('✅ TodoStorageService initialized with Firestore');
  }

  /// Get all todos
  Future<List<Todo>> getTodos() async {
    try {
      if (_userId == null) {
        debugPrint('⚠️ No user logged in');
        return [];
      }

      final snapshot = await _firestore
          .collection(_todosCollection)
          .where('userId', isEqualTo: _userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Todo.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading todos: $e');
      return [];
    }
  }

  /// Get todos stream for real-time updates
  Stream<List<Todo>> getTodosStream() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_todosCollection)
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Todo.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Save or update a todo
  Future<void> saveTodo(Todo todo) async {
    try {
      if (_userId == null) {
        throw Exception('User not authenticated');
      }

      final todoData = todo.toJson();
      todoData['userId'] = _userId;
      todoData['updatedAt'] = FieldValue.serverTimestamp();

      if (todo.id.isEmpty) {
        // New todo
        todoData['createdAt'] = FieldValue.serverTimestamp();
        await _firestore.collection(_todosCollection).add(todoData);
        debugPrint('✅ Todo added');
      } else {
        // Update existing todo
        await _firestore
            .collection(_todosCollection)
            .doc(todo.id)
            .update(todoData);
        debugPrint('✅ Todo updated: ${todo.id}');
      }
    } catch (e) {
      debugPrint('❌ Error saving todo: $e');
      rethrow;
    }
  }

  /// Delete a todo
  Future<void> deleteTodo(String id) async {
    try {
      if (_userId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection(_todosCollection).doc(id).delete();
      debugPrint('✅ Todo deleted: $id');
    } catch (e) {
      debugPrint('❌ Error deleting todo: $e');
      rethrow;
    }
  }

  /// Toggle todo completion status
  Future<void> toggleTodoComplete(String id) async {
    try {
      if (_userId == null) {
        throw Exception('User not authenticated');
      }

      final docRef = _firestore.collection(_todosCollection).doc(id);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        throw Exception('Todo not found');
      }

      final todo = Todo.fromJson({...docSnap.data()!, 'id': docSnap.id});
      final updatedTodo = todo.copyWith(
        isCompleted: !todo.isCompleted,
        completedAt: !todo.isCompleted ? DateTime.now() : null,
      );

      await docRef.update({
        'isCompleted': updatedTodo.isCompleted,
        'completedAt': updatedTodo.completedAt?.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Todo toggled: $id');
    } catch (e) {
      debugPrint('❌ Error toggling todo: $e');
      rethrow;
    }
  }

  /// Get incomplete todos
  Future<List<Todo>> getIncompleteTodos() async {
    try {
      if (_userId == null) {
        debugPrint('⚠️ No user logged in');
        return [];
      }

      final snapshot = await _firestore
          .collection(_todosCollection)
          .where('userId', isEqualTo: _userId)
          .where('isCompleted', isEqualTo: false)
          .orderBy('priority', descending: true) // High priority first
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => Todo.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading incomplete todos: $e');
      return [];
    }
  }

  /// Get completed todos
  Future<List<Todo>> getCompletedTodos() async {
    try {
      if (_userId == null) {
        debugPrint('⚠️ No user logged in');
        return [];
      }

      final snapshot = await _firestore
          .collection(_todosCollection)
          .where('userId', isEqualTo: _userId)
          .where('isCompleted', isEqualTo: true)
          .orderBy('completedAt', descending: true) // Recent first
          .get();

      return snapshot.docs
          .map((doc) => Todo.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading completed todos: $e');
      return [];
    }
  }
}
