import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'face_recognition_view_model.dart';
import 'widgets/primary_button.dart';
import 'screens/user_selection_screen.dart';
import 'models.dart';
import 'native/native_bridge.dart';
import 'native/endpoint_encryption.dart';
import 'package:http/http.dart' as http;

class GroupAttendanceSDK extends StatefulWidget {
  final List<SDKUserReference>? userReferences;
  final bool isDemo;
  final Function(List<RecognitionResult>)? onComplete;
  final String licenseKey;

  const GroupAttendanceSDK({
    Key? key,
    this.userReferences,
    this.isDemo = false,
    this.onComplete,
    required this.licenseKey,
  }) : super(key: key);

  @override
  State<GroupAttendanceSDK> createState() => _GroupAttendanceSDKState();
}

class _GroupAttendanceSDKState extends State<GroupAttendanceSDK> with WidgetsBindingObserver {
  static const _licenseValidKey = 'ga_sdk_license_valid';
  static const _licenseKeyCacheKey = 'ga_sdk_license_value';
  static const _licenseAppIdKey = 'ga_sdk_license_app_id';
  static const _licenseValidatedAtKey = 'ga_sdk_license_validated_at';
  static const _licenseEndpoint = 'https://classes-api.indoai.co/api/employee/validatekey';
  static const _integrityChallenge = 'ga_sdk_integrity_v1';
  static const _integrityExpectedSignature = 'KEkoetaYxpjbSD1UydnUDn0648ohgzpJcqDAMnv/IJc=';

  bool _isInitializing = false;
  bool _isCheckingLicense = true;
  bool _isLicenseValid = false;
  bool _licenseRequestInFlight = false;
  bool _hasInitializedReferences = false;
  bool _integrityVerified = false;
  bool isTampered = false;
  String? _licenseError;

  late FaceRecognitionViewModel viewModel;
  PackageInfo? _packageInfo;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    viewModel = FaceRecognitionViewModel();
    _verifyLicense();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    viewModel.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _attemptBackgroundValidation();
    }
  }

  Future<void> _verifyLicense() async {
    setState(() {
      _isCheckingLicense = true;
    });

    final integrityOk = await _ensureIntegrity();
    
    if (!integrityOk) {
      if (mounted) {
        setState(() {
          _isCheckingLicense = false;
        });
      }
      return;
    }

    await _loadPackageInfo();
    await _loadCachedLicenseState();

    if (_isLicenseValid) {
      _onLicenseValidated();
      _attemptBackgroundValidation();
    } else {
      final hasInternet = await _hasInternetConnection();
      
      if (hasInternet) {
        await _validateLicenseOnline(showDialogOnFail: true, skipInternetCheck: true);
      } else {
        if (mounted) {
          setState(() {
            _licenseError = 'License validation requires an active internet connection.';
          });
          _showLicenseDialog('License validation requires an active internet connection.');
        }
      }
    }

    if (mounted) {
      setState(() {
        _isCheckingLicense = false;
      });
    }
  }

  Future<void> _loadPackageInfo() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
  }

  Future<void> _loadCachedLicenseState() async {
    final prefs = await _getPrefs();
    final cachedValid = prefs.getBool(_licenseValidKey) ?? false;
    final cachedKey = prefs.getString(_licenseKeyCacheKey);
    final cachedAppId = prefs.getString(_licenseAppIdKey);
    final currentAppId = _currentAppId();

    if (cachedValid &&
        cachedKey == widget.licenseKey &&
        cachedAppId != null &&
        cachedAppId.isNotEmpty &&
        cachedAppId == currentAppId) {
      _isLicenseValid = true;
      _licenseError = null;
      _onLicenseValidated();
    }
  }

  Future<void> _attemptBackgroundValidation() async {
    if (_licenseRequestInFlight) {
      return;
    }
    final hasInternet = await _hasInternetConnection();
    if (!hasInternet) {
      return;
    }
    await _validateLicenseOnline(showDialogOnFail: !_isLicenseValid, skipInternetCheck: true);
  }

  Future<void> _validateLicenseOnline({required bool showDialogOnFail, bool skipInternetCheck = false}) async {
    if (_licenseRequestInFlight) {
      return;
    }

    final integrityOk = await _ensureIntegrity();
    if (!integrityOk) {
      return;
    }

    _licenseRequestInFlight = true;
    try {
      if (!skipInternetCheck) {
        final hasInternet = await _hasInternetConnection();
        if (!hasInternet) {
          if (!_isLicenseValid && showDialogOnFail && mounted) {
            _showLicenseDialog('License key not validated. Check internet connection.');
          }
          return;
        }
      }

      final appId = _currentAppId();
      if (appId.isEmpty) {
        if (showDialogOnFail && mounted) {
          _showLicenseDialog('Unable to read application identifier.');
        }
        return;
      }
      
      final encryptedEndpoint = EndpointEncryption.encrypt(_licenseEndpoint);
      final isValid = await NativeSecurityBridge.validateLicense(
        licenseKey: widget.licenseKey,
        appId: appId,
        endpoint: encryptedEndpoint,
      );
      
      if (!isValid) {
        final integrityCheck = await NativeSecurityBridge.fetchIntegritySignature(_integrityChallenge);
        
        if (integrityCheck == 'TAMPERED' || integrityCheck != _integrityExpectedSignature) {
          isTampered = true;
          if (mounted) {
            setState(() {
              _isLicenseValid = false;
              _licenseError = 'License validation failed. SDK integrity compromised.';
            });
          }
        }
      }

      if (isValid) {
        await _cacheLicenseState(appId);
        if (mounted) {
          setState(() {
            _isLicenseValid = true;
            _licenseError = null;
          });
        }
        _onLicenseValidated();
      } else {
        _handleLicenseFailure(showDialogOnFail);
      }
    } catch (_) {
      _handleLicenseFailure(showDialogOnFail);
    } finally {
      _licenseRequestInFlight = false;
    }
  }

  Future<void> _cacheLicenseState(String appId) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_licenseValidKey, true);
    await prefs.setString(_licenseKeyCacheKey, widget.licenseKey);
    await prefs.setString(_licenseAppIdKey, appId);
    await prefs.setInt(_licenseValidatedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  void _handleLicenseFailure(bool showDialogOnFail) {
    if (mounted) {
      setState(() {
        _isLicenseValid = false;
        _licenseError = 'License validation failed. Contact support.';
      });
    }
    if (showDialogOnFail && mounted) {
      _showLicenseDialog('License key not validated. Check internet connection.');
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  String _currentAppId() {
    return _packageInfo?.packageName ?? '';
  }

  Future<bool> _ensureIntegrity() async {
    if (isTampered) {
      return false;
    }

    if (_integrityVerified) {
      return true;
    }

    try {
      final signature = await NativeSecurityBridge.fetchIntegritySignature(_integrityChallenge);
      
      if (signature == 'TAMPERED' || signature == null) {
        isTampered = true;
        if (mounted) {
          setState(() {
            _licenseError = 'SDK integrity check failed.';
            _isLicenseValid = false;
          });
        }
        return false;
      }

      final matches = signature == _integrityExpectedSignature;
      
      if (!matches && mounted) {
        isTampered = true;
        setState(() {
          _licenseError = 'SDK integrity check failed.';
          _isLicenseValid = false;
        });
      } else if (matches) {
        _integrityVerified = true;
      }
      return matches;
    } catch (_) {
      if (mounted) {
        setState(() {
          _licenseError = 'SDK integrity verification unavailable.';
          _isLicenseValid = false;
        });
      }
      return false;
    }
  }

  void _showLicenseDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('License Validation'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _validateLicenseOnline(showDialogOnFail: true);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _onLicenseValidated() {
    if (_hasInitializedReferences) {
      return;
    }
    if (!widget.isDemo && widget.userReferences != null && widget.userReferences!.isNotEmpty) {
      _hasInitializedReferences = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeUserReferences();
      });
    }
  }

  Future<void> _initializeUserReferences() async {
    setState(() {
      _isInitializing = true;
    });
    
    viewModel.clearUserReferences();
    
    for (var userRef in widget.userReferences!) {
      File imageFile = await _convertBytesToFile(userRef.imageBytes, userRef.name);
      await viewModel.addUserReferenceFromFile(userRef.name, imageFile);
      setState(() {});
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
      ));
    }
    
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final int currentIndex = viewModel.currentImageIndex;
    final bool hasImage = viewModel.images.length > currentIndex && viewModel.images[currentIndex] != null;

    if (_isCheckingLicense) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true,
          title: const Text(
            "Group Attendance",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isLicenseValid) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true,
          title: const Text(
            "Group Attendance",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 56, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  _licenseError ?? 'License key not validated. Check internet connection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  onTap: () => _validateLicenseOnline(showDialogOnFail: true),
                  height: 48,
                  borderRadius: 10,
                  color: const Color(0xFF19CA74),
                  child: const Text(
                    "Retry Validation",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true,
          title: Text(
            "Group Attendance",
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
          "Group Attendance",
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
                "Capture Attendance",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  await viewModel.pickImageAndUpload(context);
                  setState(() {});
                },
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
                      viewModel.images[currentIndex]!,
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
              if (viewModel.hasError.contains(true))
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
                        onTap: () {
                          viewModel.removeImage(currentIndex);
                          setState(() {});
                        },
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
                          await viewModel.pickImageAndUpload(context);
                          setState(() {});
                          return;
                        }
                        final image = viewModel.images[currentIndex];
                        if (image != null) {
                          viewModel.moveToNextImage();
                          setState(() {});
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
              if (viewModel.images.any((img) => img != null)) ...[
                Text(
                  "Captured Images",
                  style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: viewModel.images.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final file = viewModel.images[index];
                    return GestureDetector(
                      onTap: () {
                        viewModel.setCurrentImageIndex(index);
                        setState(() {});
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: index == viewModel.currentImageIndex
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
                    if (isTampered || !_isLicenseValid) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('SDK license validation failed.')),
                      );
                      return;
                    }

                    if (viewModel.images.where((img) => img != null).isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please capture at least one image')),
                      );
                      return;
                    }

                    final integrityOk = await _ensureIntegrity();
                    if (!integrityOk || isTampered) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('SDK integrity check failed.')),
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

                    await viewModel.processAllCapturedImages(context);

                    Navigator.pop(context);

                    if (widget.isDemo) {
                      final demoResults = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserSelectionScreen(
                            parentViewModel: viewModel,
                          ),
                        ),
                      );

                      if (demoResults != null && widget.onComplete != null) {
                        widget.onComplete!(demoResults);
                      }
                    } else {
                        if (viewModel.userReferences.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No user references found. Please add users first.')),
                        );
                        return;
                      }

                      if (!_isLicenseValid) {
                        await _validateLicenseOnline(showDialogOnFail: false, skipInternetCheck: false);
                        if (!_isLicenseValid) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('License validation required. Please check your internet connection.')),
                          );
                          return;
                        }
                      }

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );

                      final integrityCheck = await _ensureIntegrity();
                      if (!integrityCheck || isTampered) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('SDK integrity check failed during recognition.')),
                        );
                        return;
                      }

                      await viewModel.performFaceRecognition();

                      Navigator.pop(context);

                      final results = await _convertMatchResults(viewModel.matchResults);

                      if (widget.onComplete != null && !isTampered) {
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

