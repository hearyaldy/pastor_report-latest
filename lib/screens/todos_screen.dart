import 'package:flutter/material.dart';
import 'package:pastor_report/models/todo_model.dart';
import 'package:pastor_report/services/todo_storage_service.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:uuid/uuid.dart';

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Todo> _incompleteTodos = [];
  List<Todo> _completedTodos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    setState(() => _isLoading = true);

    final incomplete = await TodoStorageService.instance.getIncompleteTodos();
    final completed = await TodoStorageService.instance.getCompletedTodos();

    setState(() {
      _incompleteTodos = incomplete;
      _completedTodos = completed;
      _isLoading = false;
    });
  }

  Future<void> _showAddTodoDialog({Todo? editTodo}) async {
    final contentController = TextEditingController(text: editTodo?.content ?? '');
    int selectedPriority = editTodo?.priority ?? 0;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(editTodo == null ? 'Add Todo' : 'Edit Todo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'What needs to be done?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Priority:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _PriorityChip(
                    label: 'Low',
                    color: Colors.green,
                    isSelected: selectedPriority == 0,
                    onTap: () => setState(() => selectedPriority = 0),
                  ),
                  const SizedBox(width: 8),
                  _PriorityChip(
                    label: 'Medium',
                    color: Colors.orange,
                    isSelected: selectedPriority == 1,
                    onTap: () => setState(() => selectedPriority = 1),
                  ),
                  const SizedBox(width: 8),
                  _PriorityChip(
                    label: 'High',
                    color: Colors.red,
                    isSelected: selectedPriority == 2,
                    onTap: () => setState(() => selectedPriority = 2),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (contentController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter todo content')),
                  );
                  return;
                }

                final todo = Todo(
                  id: editTodo?.id ?? const Uuid().v4(),
                  content: contentController.text.trim(),
                  priority: selectedPriority,
                  createdAt: editTodo?.createdAt ?? DateTime.now(),
                  isCompleted: editTodo?.isCompleted ?? false,
                );

                await TodoStorageService.instance.saveTodo(todo);
                if (context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              child: Text(editTodo == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadTodos();
    }
  }

  Future<void> _toggleTodo(String id) async {
    await TodoStorageService.instance.toggleTodoComplete(id);
    _loadTodos();
  }

  Future<void> _deleteTodo(String id) async {
    await TodoStorageService.instance.deleteTodo(id);
    _loadTodos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Todos'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Active (${_incompleteTodos.length})'),
            Tab(text: 'Completed (${_completedTodos.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTodoList(_incompleteTodos, isCompleted: false),
                _buildTodoList(_completedTodos, isCompleted: true),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTodoDialog(),
        backgroundColor: AppColors.primaryLight,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTodoList(List<Todo> todos, {required bool isCompleted}) {
    if (todos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCompleted ? Icons.check_circle_outline : Icons.playlist_add_check,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isCompleted ? 'No completed todos' : 'No active todos',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        return _TodoCard(
          todo: todo,
          onToggle: () => _toggleTodo(todo.id),
          onEdit: () => _showAddTodoDialog(editTodo: todo),
          onDelete: () => _deleteTodo(todo.id),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _TodoCard extends StatelessWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TodoCard({
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  Color _getPriorityColor() {
    switch (todo.priority) {
      case 2:
        return Colors.red;
      case 1:
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Checkbox(
          value: todo.isCompleted,
          onChanged: (_) => onToggle(),
          activeColor: AppColors.primaryLight,
        ),
        title: Text(
          todo.content,
          style: TextStyle(
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
            color: todo.isCompleted ? Colors.grey : null,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getPriorityColor().withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                todo.priorityText,
                style: TextStyle(
                  fontSize: 11,
                  color: _getPriorityColor(),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDate(todo.createdAt),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!todo.isCompleted)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: onEdit,
                color: Colors.blue,
              ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Todo'),
                    content: const Text('Are you sure you want to delete this todo?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  onDelete();
                }
              },
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
