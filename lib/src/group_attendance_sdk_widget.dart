import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'face_recognition_view_model.dart';
import 'widgets/primary_button.dart';
import 'screens/user_selection_screen.dart';
import 'models.dart';

class GroupAttendanceSDK extends StatefulWidget {
  final List<SDKUserReference>? userReferences;
  final bool isDemo;
  final Function(List<RecognitionResult>)? onComplete;

  const GroupAttendanceSDK({
    Key? key,
    this.userReferences,
    this.isDemo = false,
    this.onComplete,
  }) : super(key: key);

  @override
  State<GroupAttendanceSDK> createState() => _GroupAttendanceSDKState();
}

class _GroupAttendanceSDKState extends State<GroupAttendanceSDK> {
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isDemo && widget.userReferences != null && widget.userReferences!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeUserReferences();
      });
    }
  }

  Future<void> _initializeUserReferences() async {
    setState(() {
      _isInitializing = true;
    });
    
    final viewModel = Provider.of<FaceRecognitionViewModel>(context, listen: false);
    
    viewModel.clearUserReferences();
    
    for (var userRef in widget.userReferences!) {
      File imageFile = await _convertBytesToFile(userRef.imageBytes, userRef.name);
      await viewModel.addUserReferenceFromFile(userRef.name, imageFile);
    }

    setState(() {
      _isInitializing = false;
    });
  }

  Future<File> _convertBytesToFile(Uint8List bytes, String name) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/user_${name}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes);
    return file;
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
    final watch = context.watch<FaceRecognitionViewModel>();
    final read = context.read<FaceRecognitionViewModel>();
    final int currentIndex = watch.currentImageIndex;
    final bool hasImage = watch.images.length > currentIndex && watch.images[currentIndex] != null;

    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true,
          title: Text(
            "Offline Attendance",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Loading user references...',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: Padding(
          padding: EdgeInsets.only(left: 18),
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: const Icon(Icons.arrow_back_ios),
          ),
        ),
        centerTitle: true,
        title: Text(
          "Offline Attendance",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                "Capture Attendance (Offline Mode)",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 10),
              GestureDetector(
                onTap: () => read.pickImageAndUpload(context),
                child: Container(
                  width: double.infinity,
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black12,
                  ),
                  child: hasImage
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      watch.images[currentIndex]!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                      : Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade300,
                        ),
                    child: Center(
                      child: Icon(Icons.camera_alt,size: 40,color: Colors.grey,),
                    ),
                      ),
                ),
              ),
              SizedBox(height: 20),
              if (watch.hasError.contains(true))
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Please capture the image before proceeding.",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              SizedBox(height: 10),
              Row(
                children: [
                  if (hasImage)
                    Expanded(
                      child: PrimaryButton(
                        onTap: () => read.removeImage(currentIndex),
                        height: 48,
                        borderRadius: 10,
                        color: const Color(0xFFE53935),
                        child: Text(
                          "Retake",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                      ),
                    ),
                  if (hasImage) SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      onTap: () async {
                        if (!hasImage) {
                          await read.pickImageAndUpload(context);
                          return;
                        }
                        final image = watch.images[currentIndex];
                        if (image != null) {
                          read.moveToNextImage();
                        }
                      },
                      height: 48,
                      borderRadius: 10,
                      color: hasImage
                          ? const Color(0xFF00B4D8)
                          : const Color(0xFF19CA74),
                      child: Text(
                        hasImage ? "Capture More" : "Capture",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              if (watch.images.any((img) => img != null)) ...[
                Text(
                  "Captured Images",
                  style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: watch.images.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final file = watch.images[index];
                    return GestureDetector(
                      onTap: () => read.setCurrentImageIndex(index),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: index == watch.currentImageIndex
                                ? Colors.blue
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child:file!=null? Image.file(file, fit: BoxFit.cover):Icon(Icons.camera_alt,size: 40,color: Colors.grey,),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 20),
                PrimaryButton(
                  onTap: () async {
                    if (watch.images.where((img) => img != null).isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please capture at least one image')),
                      );
                      return;
                    }

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );

                    await read.processAllCapturedImages(context);

                    Navigator.pop(context);

                    if (widget.isDemo) {
                      final demoResults = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserSelectionScreen(),
                        ),
                      );

                      if (demoResults != null && widget.onComplete != null) {
                        widget.onComplete!(demoResults);
                      }
                    } else {
                      if (read.userReferences.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No user references found. Please add users first.')),
                        );
                        return;
                      }

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );

                      await read.performFaceRecognition();

                      Navigator.pop(context);

                      final results = await _convertMatchResults(read.matchResults);

                      if (widget.onComplete != null) {
                        widget.onComplete!(results);
                      }
                    }
                  },
                  height: 48,
                  borderRadius: 10,
                  color: const Color(0xFF19CA74),
                  child: Text(
                    "Proceed",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}

