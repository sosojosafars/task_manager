import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minhas Tarefas',
      theme: ThemeData(primarySwatch: Colors.green, brightness: Brightness.light),
      home: TaskScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TaskScreen extends StatefulWidget {
  @override
  _TaskScreenState createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final _textController = TextEditingController();
  final _itemsCollection = FirebaseFirestore.instance.collection('tarefas');

  int _selectedPriority = 2;

  // Adicionar Tarefa
  void _addItem() async {
    if (_textController.text.isEmpty) return;
    await _itemsCollection.add({
      'title': _textController.text,
      'isDone': false,
      'priority': _selectedPriority,
      'timestamp': Timestamp.now(),
    });
    _textController.clear();
    setState(() {
      _selectedPriority = 2; 
    });
  }

  void _toggleDone(String docId, bool isDone) async {
    await _itemsCollection.doc(docId).update({'isDone': isDone});
  }

  void _deleteItem(String docId) async {
    await _itemsCollection.doc(docId).delete();
  }

  void _editItem(String docId, String currentTitle) async {
    final controller = TextEditingController(text: currentTitle);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Editar Tarefa"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: "Novo título"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await _itemsCollection.doc(docId).update({'title': controller.text.trim()});
              }
              Navigator.pop(context);
            },
            child: Text("Salvar"),
          )
        ],
      ),
    );
  }

  Icon _priorityIcon(int priority) {
    switch (priority) {
      case 3:
        return Icon(Icons.flag, color: Colors.red);
      case 2:
        return Icon(Icons.flag, color: Colors.amber);
      case 1:
      default:
        return Icon(Icons.flag, color: Colors.green);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Minhas Tarefas')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    labelText: 'Adicionar tarefa...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              SizedBox(width: 10),
              DropdownButton<int>(
                value: _selectedPriority,
                items: const [
                  DropdownMenuItem(value: 1, child: Text("Baixa")),
                  DropdownMenuItem(value: 2, child: Text("Média")),
                  DropdownMenuItem(value: 3, child: Text("Alta")),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedPriority = value!;
                  });
                },
              ),
              SizedBox(width: 10),
              IconButton.filled(
                icon: Icon(Icons.add),
                onPressed: _addItem,
                style: IconButton.styleFrom(padding: EdgeInsets.all(16)),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _itemsCollection
                .orderBy('priority', descending: true)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('Nenhuma tarefa adicionada!'));
              }
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final title = data['title'] ?? '';
                  final isDone = data['isDone'] ?? false;
                  final priority = data['priority'] ?? 2;

                  return ListTile(
                    leading: _priorityIcon(priority),
                    title: GestureDetector(
                      onTap: () => _editItem(doc.id, title),
                      child: Text(
                        title,
                        style: TextStyle(
                          decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: isDone,
                          onChanged: (value) => _toggleDone(doc.id, value ?? false),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteItem(doc.id),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
