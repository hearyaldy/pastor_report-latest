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

  /// Create a new todo
  Future<String> createTodo({
    required String content,
    String? audioPath,
    int priority = 0,
  }) async {
    try {
      if (_userId == null) {
        throw Exception('User not authenticated');
      }

      final todoData = {
        'userId': _userId,
        'content': content,
        'audioPath': audioPath,
        'isCompleted': false,
        'priority': priority,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      debugPrint('📝 Creating new todo for user: $_userId');
      final docRef = await _firestore.collection(_todosCollection).add(todoData);
      debugPrint('✅ Todo created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating todo: $e');
      rethrow;
    }
  }

  /// Update an existing todo
  Future<void> updateTodo({
    required String todoId,
    String? content,
    String? audioPath,
    bool? isCompleted,
    int? priority,
    DateTime? completedAt,
  }) async {
    try {
      if (_userId == null) {
        throw Exception('User not authenticated');
      }

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (content != null) updateData['content'] = content;
      if (audioPath != null) updateData['audioPath'] = audioPath;
      if (isCompleted != null) updateData['isCompleted'] = isCompleted;
      if (priority != null) updateData['priority'] = priority;
      if (completedAt != null) {
        updateData['completedAt'] = completedAt.toIso8601String();
      }

      debugPrint('🔄 Updating todo: $todoId');
      await _firestore.collection(_todosCollection).doc(todoId).update(updateData);
      debugPrint('✅ Todo updated: $todoId');
    } catch (e) {
      debugPrint('❌ Error updating todo: $e');
      rethrow;
    }
  }

  /// Delete a todo
  Future<void> deleteTodo(String id) async {
    try {
      if (_userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('🗑️ Deleting todo: $id');
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

      final data = docSnap.data()!;
      final isCurrentlyCompleted = data['isCompleted'] as bool? ?? false;
      final newCompletedStatus = !isCurrentlyCompleted;

      final updateData = <String, dynamic>{
        'isCompleted': newCompletedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newCompletedStatus) {
        updateData['completedAt'] = DateTime.now().toIso8601String();
      } else {
        updateData['completedAt'] = null;
      }

      debugPrint('🔄 Toggling todo: $id to completed: $newCompletedStatus');
      await docRef.update(updateData);
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
