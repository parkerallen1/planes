import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_service.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../providers/theme_provider.dart';
import '../theme/app_themes.dart';
import 'plane_detail_screen.dart';

import 'package:exif/exif.dart';

class AddPlaneScreen extends ConsumerStatefulWidget {
  const AddPlaneScreen({super.key});

  @override
  ConsumerState<AddPlaneScreen> createState() => _AddPlaneScreenState();
}

class _AddPlaneScreenState extends ConsumerState<AddPlaneScreen>
    with SingleTickerProviderStateMixin {
  File? _image;
  bool _isAnalyzing = false;
  String? _statusMessage;
  final TextEditingController _locationController = TextEditingController();
  double? _exifLat;
  double? _exifLong;

  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _scanAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() {
        _image = file;
        _statusMessage = null;
        _locationController.clear();
        _exifLat = null;
        _exifLong = null;
      });

      _extractLocation(file);
    }
  }

  Future<void> _extractLocation(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final tags = await readExifFromBytes(bytes);

      if (tags.containsKey('GPS GPSLatitude') &&
          tags.containsKey('GPS GPSLongitude')) {
        final latTags = tags['GPS GPSLatitude']?.values.toList();
        final longTags = tags['GPS GPSLongitude']?.values.toList();
        final latRef = tags['GPS GPSLatitudeRef']?.printable;
        final longRef = tags['GPS GPSLongitudeRef']?.printable;

        if (latTags != null && longTags != null) {
          double toDouble(List<dynamic> tags) {
            double degrees = (tags[0] as Ratio).toDouble();
            double minutes = (tags[1] as Ratio).toDouble();
            double seconds = (tags[2] as Ratio).toDouble();
            return degrees + (minutes / 60.0) + (seconds / 3600.0);
          }

          double lat = toDouble(latTags);
          double long = toDouble(longTags);

          if (latRef == 'S') lat = -lat;
          if (longRef == 'W') long = -long;

          setState(() {
            _exifLat = lat;
            _exifLong = long;
            _locationController.text = '$lat, $long';
          });
        }
      }
    } catch (e) {
      print('Error reading EXIF: $e');
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    final isPokedex = ref.read(themeProvider).isPokedex;

    setState(() {
      _isAnalyzing = true;
      _statusMessage = isPokedex
          ? 'ACQUIRING LOCATION...'
          : 'Getting location...';
    });

    _scanAnimationController.repeat(reverse: true);

    try {
      double? lat = _exifLat;
      double? long = _exifLong;
      String? manualLocation = _locationController.text.isNotEmpty
          ? _locationController.text
          : null;

      if (lat == null && manualLocation == null) {
        final locationService = ref.read(locationServiceProvider);
        final position = await locationService.getCurrentLocation();
        lat = position?.latitude;
        long = position?.longitude;
      }

      setState(() {
        _statusMessage = isPokedex
            ? 'ANALYZING VISUAL DATA...'
            : 'Analyzing with Gemini...';
      });

      final geminiService = ref.read(geminiServiceProvider);
      final plane = await geminiService.identifyPlane(
        _image!.path,
        lat,
        long,
        manualLocation,
      );

      setState(() {
        _statusMessage = isPokedex ? 'STORING ENTRY...' : 'Saving...';
      });

      final storageService = ref.read(storageServiceProvider);
      await storageService.savePlane(plane);

      _scanAnimationController.stop();

      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaneDetailScreen(plane: plane),
          ),
        );
      }
    } catch (e) {
      _scanAnimationController.stop();
      setState(() {
        _statusMessage = isPokedex ? 'ERROR: $e' : 'Error: $e';
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPokedex = ref.watch(themeProvider).isPokedex;

    return Scaffold(
      appBar: AppBar(
        title: Text(isPokedex ? 'SCAN AIRCRAFT' : 'Add Plane'),
        leading: isPokedex ? _buildPokedexBackButton(context) : null,
      ),
      body: Center(
        child: _isAnalyzing
            ? _buildAnalyzingState(isPokedex)
            : _buildCaptureState(isPokedex),
      ),
    );
  }

  Widget _buildPokedexBackButton(BuildContext context) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppThemes.pokedexDarkGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppThemes.pokedexBlue.withOpacity(0.5)),
        ),
        child: const Icon(Icons.arrow_back, size: 18),
      ),
      onPressed: () => Navigator.pop(context),
    );
  }

  Widget _buildAnalyzingState(bool isPokedex) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isPokedex) ...[
          // Pokedex scanning animation
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppThemes.pokedexBlue.withOpacity(0.5),
                    width: 3,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _scanAnimation,
                builder: (context, child) {
                  return Container(
                    width: 180 * (_scanAnimation.value * 0.3 + 0.7),
                    height: 180 * (_scanAnimation.value * 0.3 + 0.7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppThemes.pokedexRed.withOpacity(
                          _scanAnimation.value,
                        ),
                        width: 4,
                      ),
                    ),
                  );
                },
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.radar,
                    size: 60,
                    color: AppThemes.pokedexLightBlue,
                  ),
                  const SizedBox(height: 8),
                  _buildLedIndicator(AppThemes.pokedexYellow, size: 12),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            _statusMessage ?? 'PROCESSING...',
            style: TextStyle(
              fontSize: 16,
              color: AppThemes.pokedexLightBlue,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: AppThemes.pokedexDarkGray,
              valueColor: AlwaysStoppedAnimation(AppThemes.pokedexBlue),
            ),
          ),
        ] else ...[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_statusMessage ?? 'Processing...'),
        ],
      ],
    );
  }

  Widget _buildCaptureState(bool isPokedex) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_image != null) ...[
            // Image preview
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(isPokedex ? 8 : 16),
                  child: Image.file(_image!, height: 300, fit: BoxFit.cover),
                ),
                if (isPokedex) ...[
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppThemes.pokedexBlue,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppThemes.pokedexCard.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppThemes.pokedexGreen),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildLedIndicator(AppThemes.pokedexGreen),
                          const SizedBox(width: 8),
                          Text(
                            'IMAGE LOADED',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppThemes.pokedexGreen,
                              letterSpacing: 1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Location input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: isPokedex
                      ? 'LOCATION DATA'
                      : 'Location (Optional)',
                  hintText: isPokedex
                      ? 'Airport code or coordinates'
                      : 'e.g. JFK Airport, London',
                  prefixIcon: Icon(
                    Icons.pin_drop,
                    color: isPokedex ? AppThemes.pokedexBlue : null,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Analyze button
            _buildAnalyzeButton(isPokedex),
            const SizedBox(height: 24),
          ] else
            _buildEmptyState(isPokedex),

          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: isPokedex
                    ? BoxDecoration(
                        color: _statusMessage!.contains('Error')
                            ? AppThemes.pokedexRed.withOpacity(0.2)
                            : AppThemes.pokedexCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _statusMessage!.contains('Error')
                              ? AppThemes.pokedexRed
                              : AppThemes.pokedexBlue.withOpacity(0.5),
                        ),
                      )
                    : null,
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _statusMessage!.contains('Error')
                        ? (isPokedex ? AppThemes.pokedexRed : Colors.red)
                        : (isPokedex ? AppThemes.pokedexLightBlue : null),
                    letterSpacing: isPokedex ? 0.5 : 0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Capture buttons
          _buildCaptureButtons(isPokedex),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isPokedex) {
    return Column(
      children: [
        Container(
          width: 150,
          height: 150,
          decoration: isPokedex
              ? BoxDecoration(
                  color: AppThemes.pokedexCard,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppThemes.pokedexBlue.withOpacity(0.5),
                    width: 3,
                  ),
                )
              : null,
          child: Icon(
            isPokedex ? Icons.radar : Icons.airplanemode_active,
            size: 80,
            color: isPokedex
                ? AppThemes.pokedexBlue.withOpacity(0.7)
                : Colors.grey,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          isPokedex ? 'READY TO SCAN' : 'Capture an Aircraft',
          style: TextStyle(
            fontSize: isPokedex ? 18 : 16,
            color: isPokedex ? AppThemes.pokedexLightBlue : Colors.white70,
            letterSpacing: isPokedex ? 3 : 0,
            fontWeight: isPokedex ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (isPokedex) ...[
          const SizedBox(height: 8),
          Text(
            'Use camera or select from gallery',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white54,
              letterSpacing: 1,
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAnalyzeButton(bool isPokedex) {
    return ElevatedButton.icon(
      onPressed: _analyzeImage,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPokedex ? AppThemes.pokedexRed : null,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isPokedex ? 8 : 25),
          side: isPokedex
              ? const BorderSide(color: Colors.white24, width: 2)
              : BorderSide.none,
        ),
      ),
      icon: Icon(isPokedex ? Icons.radar : Icons.auto_awesome),
      label: Text(
        isPokedex ? 'BEGIN SCAN' : 'Identify Plane',
        style: TextStyle(
          letterSpacing: isPokedex ? 2 : 0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCaptureButtons(bool isPokedex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCaptureButton(
          isPokedex: isPokedex,
          icon: Icons.camera_alt,
          label: isPokedex ? 'CAMERA' : 'Camera',
          onTap: () => _pickImage(ImageSource.camera),
          isPrimary: true,
        ),
        const SizedBox(width: 16),
        _buildCaptureButton(
          isPokedex: isPokedex,
          icon: Icons.photo_library,
          label: isPokedex ? 'GALLERY' : 'Gallery',
          onTap: () => _pickImage(ImageSource.gallery),
          isPrimary: false,
        ),
      ],
    );
  }

  Widget _buildCaptureButton({
    required bool isPokedex,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    if (isPokedex) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: isPrimary ? AppThemes.pokedexDarkRed : AppThemes.pokedexCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary
                  ? AppThemes.pokedexRed
                  : AppThemes.pokedexBlue.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: AppThemes.pokedexRed.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.white : AppThemes.pokedexLightBlue,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : AppThemes.pokedexLightBlue,
                  fontSize: 12,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Widget _buildLedIndicator(Color color, {double size = 8}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.8),
            blurRadius: 6,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}
