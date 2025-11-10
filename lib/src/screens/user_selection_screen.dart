import 'package:flutter/material.dart';
import '../face_recognition_view_model.dart';
import '../models.dart';
import 'result_screen.dart';

class UserSelectionScreen extends StatefulWidget {
  final FaceRecognitionViewModel parentViewModel;
  
  const UserSelectionScreen({
    Key? key,
    required this.parentViewModel,
  }) : super(key: key);

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  final TextEditingController _nameController = TextEditingController();
  late FaceRecognitionViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = widget.parentViewModel;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add User'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Enter Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _nameController.clear();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext);
                await viewModel.addUserReference(_nameController.text.trim(), context);
                setState(() {});
                _nameController.clear();
              }
            },
            child: const Text('Upload Photo'),
          ),
        ],
      ),
    );
  }

  Future<List<RecognitionResult>> _convertMatchResults(List<FaceMatchResult> matchResults) async {
    List<RecognitionResult> results = [];
    
    for (var result in matchResults) {
      results.add(RecognitionResult(
        isMatched: result.isMatched,
        name: result.matchedUserName ?? 'Unknown',
        croppedImagePath: result.croppedFace.path,
        similarity: result.similarity,
      ));
    }
    
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Users to Recognize'),
        elevation: 2,
      ),
      body: viewModel.userReferences.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add_alt_1,
                    size: 100,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No users added yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap + button to add users',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: viewModel.userReferences.length,
            itemBuilder: (context, index) {
              final user = viewModel.userReferences[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundImage: FileImage(user.photo),
                  ),
                  title: Text(
                    user.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    user.faceTemplate != null ? 'Template extracted' : 'No template',
                    style: TextStyle(
                      color: user.faceTemplate != null ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        viewModel.removeUserReference(index);
                        setState(() {});
                      },
                    ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddUserDialog(context),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: viewModel.userReferences.isEmpty
          ? const SizedBox.shrink()
          : Container(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                await viewModel.performFaceRecognition();

                Navigator.pop(context);

                final results = await _convertMatchResults(viewModel.matchResults);

                final shouldReturn = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultScreen(results: results),
                  ),
                );

                if (shouldReturn == true) {
                  Navigator.pop(context, results);
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Submit & Recognize',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
    );
  }
}

