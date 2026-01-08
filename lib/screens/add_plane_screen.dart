import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_service.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import 'plane_detail_screen.dart';

import 'package:exif/exif.dart';

class AddPlaneScreen extends ConsumerStatefulWidget {
  const AddPlaneScreen({super.key});

  @override
  ConsumerState<AddPlaneScreen> createState() => _AddPlaneScreenState();
}

class _AddPlaneScreenState extends ConsumerState<AddPlaneScreen> {
  File? _image;
  bool _isAnalyzing = false;
  String? _statusMessage;
  final TextEditingController _locationController = TextEditingController();
  double? _exifLat;
  double? _exifLong;

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
          // Convert rational coordinates to double
          // This is a simplified conversion, assuming standard EXIF format
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
            _locationController.text = '$lat, $long'; // Pre-fill for visibility
          });
        }
      }
    } catch (e) {
      print('Error reading EXIF: $e');
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Getting location...';
    });

    try {
      // Use EXIF or manual entry if available, otherwise fallback to current location
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
        _statusMessage = 'Analyzing with Gemini...';
      });

      final geminiService = ref.read(geminiServiceProvider);
      final plane = await geminiService.identifyPlane(
        _image!.path,
        lat,
        long,
        manualLocation,
      );

      setState(() {
        _statusMessage = 'Saving...';
      });

      final storageService = ref.read(storageServiceProvider);
      await storageService.savePlane(plane);

      if (mounted) {
        Navigator.pop(context); // Close AddPlaneScreen
        // Navigate to Detail Screen immediately to show identification results
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaneDetailScreen(plane: plane),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Plane')),
      body: Center(
        child: _isAnalyzing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage ?? 'Processing...'),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_image != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          _image!,
                          height: 300,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: TextField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location (Optional)',
                            hintText: 'e.g. JFK Airport, London',
                            prefixIcon: Icon(Icons.pin_drop),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      ElevatedButton.icon(
                        onPressed: _analyzeImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Identify Plane'),
                      ),
                      const SizedBox(height: 24),
                    ] else
                      const Icon(
                        Icons.airplanemode_active,
                        size: 100,
                        color: Colors.grey,
                      ),

                    if (_statusMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: _statusMessage!.startsWith('Error')
                                ? Colors.red
                                : null,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
