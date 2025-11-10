import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models.dart';
import 'result_screen.dart';

class UserSelectionScreen extends StatefulWidget {
  final List<File> croppedFaces;

  const UserSelectionScreen({
    Key? key,
    required this.croppedFaces,
  }) : super(key: key);

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  Map<int, String> faceNames = {};

  Future<void> _assignName(int index) async {
    final TextEditingController controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Assign Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index < widget.croppedFaces.length)
              Image.file(
                widget.croppedFaces[index],
                height: 150,
                width: 150,
                fit: BoxFit.cover,
              ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Enter Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  faceNames[index] = controller.text.trim();
                });
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  void _proceedToResults() {
    final results = <RecognitionResult>[];

    for (int i = 0; i < widget.croppedFaces.length; i++) {
      final name = faceNames[i] ?? 'Unknown';
      results.add(RecognitionResult(
        isMatched: faceNames.containsKey(i),
        name: name,
        croppedImagePath: widget.croppedFaces[i].path,
        similarity: null,
      ));
    }

    Navigator.pop(context, results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Names to Faces'),
        elevation: 2,
      ),
      body: widget.croppedFaces.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.face, size: 100, color: Colors.grey[400]),
                  const SizedBox(height: 20),
                  Text(
                    'No faces detected',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: widget.croppedFaces.length,
              itemBuilder: (context, index) {
                final hasName = faceNames.containsKey(index);
                return GestureDetector(
                  onTap: () => _assignName(index),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: hasName ? Colors.green : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.file(
                              widget.croppedFaces[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: hasName ? Colors.green.shade50 : Colors.grey.shade100,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(12),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                faceNames[index] ?? 'Tap to assign name',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: hasName ? Colors.green.shade900 : Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (hasName)
                                const SizedBox(height: 4),
                              if (hasName)
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: widget.croppedFaces.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Assigned: ${faceNames.length} / ${widget.croppedFaces.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: faceNames.isEmpty ? null : _proceedToResults,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Proceed',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
