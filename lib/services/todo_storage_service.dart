import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pastor_report/models/todo_model.dart';

class TodoStorageService {
  static const String _todosKey = 'todos';
  static final TodoStorageService instance = TodoStorageService._();

  TodoStorageService._();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<List<Todo>> getTodos() async {
    if (_prefs == null) await initialize();

    final todosJson = _prefs!.getString(_todosKey);
    if (todosJson == null) return [];

    final List<dynamic> decoded = json.decode(todosJson);
    return decoded.map((json) => Todo.fromJson(json)).toList();
  }

  Future<void> saveTodo(Todo todo) async {
    final todos = await getTodos();

    // Check if todo already exists
    final index = todos.indexWhere((t) => t.id == todo.id);
    if (index != -1) {
      todos[index] = todo;
    } else {
      todos.add(todo);
    }

    await _saveTodos(todos);
  }

  Future<void> deleteTodo(String id) async {
    final todos = await getTodos();
    todos.removeWhere((todo) => todo.id == id);
    await _saveTodos(todos);
  }

  Future<void> toggleTodoComplete(String id) async {
    final todos = await getTodos();
    final index = todos.indexWhere((todo) => todo.id == id);

    if (index != -1) {
      final todo = todos[index];
      todos[index] = todo.copyWith(
        isCompleted: !todo.isCompleted,
        completedAt: !todo.isCompleted ? DateTime.now() : null,
      );
      await _saveTodos(todos);
    }
  }

  Future<void> _saveTodos(List<Todo> todos) async {
    if (_prefs == null) await initialize();

    final encoded = json.encode(todos.map((t) => t.toJson()).toList());
    await _prefs!.setString(_todosKey, encoded);
  }

  // Get incomplete todos
  Future<List<Todo>> getIncompleteTodos() async {
    final todos = await getTodos();
    return todos.where((todo) => !todo.isCompleted).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority)); // High priority first
  }

  // Get completed todos
  Future<List<Todo>> getCompletedTodos() async {
    final todos = await getTodos();
    return todos.where((todo) => todo.isCompleted).toList()
      ..sort((a, b) => (b.completedAt ?? b.createdAt)
          .compareTo(a.completedAt ?? a.createdAt)); // Recent first
  }
}
