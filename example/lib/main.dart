import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:face_recognition_sdk/face_recognition_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Recognition SDK Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SDKUserReference> _userReferences = [];

  Future<void> _showAddUserDialog() async {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add User Reference'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Enter user name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext);
                
                final picker = ImagePicker();
                final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                
                if (pickedFile != null) {
                  final imageFile = File(pickedFile.path);
                  final imageBytes = await imageFile.readAsBytes();
                  
                  setState(() {
                    _userReferences.add(SDKUserReference(
                      name: nameController.text.trim(),
                      imageBytes: imageBytes,
                    ));
                  });
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added ${nameController.text.trim()}')),
                    );
                  }
                }
              }
            },
            child: const Text('Upload Photo'),
          ),
        ],
      ),
    );
  }

  void _navigateToSDK({required bool isDemo}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupAttendanceSDK(
          isDemo: isDemo,
          userReferences: isDemo ? null : _userReferences,
          onComplete: (results) {
            Navigator.pop(context);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Recognized ${results.length} faces')),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition SDK'),
        elevation: 2,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.face,
                size: 100,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Face Recognition SDK Example',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'User References: ${_userReferences.length}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: () => _navigateToSDK(isDemo: true),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Demo Mode'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _userReferences.isEmpty
                    ? null
                    : () => _navigateToSDK(isDemo: false),
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Production Mode'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _userReferences.isEmpty
                    ? 'Add user references to enable production mode'
                    : 'Ready for face recognition',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
      ),
    );
  }
}
