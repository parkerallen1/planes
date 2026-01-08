import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/plane.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';

class PlaneDetailScreen extends ConsumerStatefulWidget {
  final Plane plane;

  const PlaneDetailScreen({super.key, required this.plane});

  @override
  ConsumerState<PlaneDetailScreen> createState() => _PlaneDetailScreenState();
}

class _PlaneDetailScreenState extends ConsumerState<PlaneDetailScreen> {
  final TextEditingController _chatController = TextEditingController();
  late Plane _plane;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _plane = widget.plane;
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
      _plane.chatHistory.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
    });
    _chatController.clear();
    await _savePlane();

    try {
      final geminiService = ref.read(geminiServiceProvider);
      final response = await geminiService.chat(
        _plane.chatHistory, // Pass full history including the new user message
        text,
        _plane.imagePath,
        planeContext: _plane.identification,
      );

      setState(() {
        _plane.chatHistory.add(
          ChatMessage(text: response, isUser: false, timestamp: DateTime.now()),
        );
      });
      await _savePlane();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _savePlane() async {
    final storageService = ref.read(storageServiceProvider);
    await storageService.updatePlane(_plane);
  }

  Future<void> _deletePlane() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plane'),
        content: const Text('Are you sure you want to delete this plane?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final storageService = ref.read(storageServiceProvider);
      await storageService.deletePlane(_plane.id);
      if (mounted) {
        Navigator.pop(context); // Return to home
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIdentifying = _plane.status == PlaneStatus.identifying;

    return Scaffold(
      appBar: AppBar(
        title: Text(isIdentifying ? 'Identify Plane' : _plane.identification),
        actions: [
          if (!isIdentifying) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _plane.status = PlaneStatus.identifying;
                });
                _savePlane();
              },
            ),
            IconButton(icon: const Icon(Icons.delete), onPressed: _deletePlane),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.file(
                    File(_plane.imagePath),
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                  ),
                  if (isIdentifying) ...[
                    _buildIdentificationSection(),
                  ] else ...[
                    _buildDetailSection(),
                  ],
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Chat with Gemini',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _buildChatHistory(),
                ],
              ),
            ),
          ),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildIdentificationSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.yellow.withOpacity(0.1),
              border: Border.all(color: Colors.yellow),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Identification Tips',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _plane.identificationTips.isNotEmpty
                      ? _plane.identificationTips
                      : 'No tips available.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Gemini\'s Guesses',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (_plane.guesses.isEmpty)
            const Text('No guesses available.')
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _plane.guesses.length,
              itemBuilder: (context, index) {
                final guess = _plane.guesses[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                guess.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              '${(guess.confidence * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: guess.confidence > 0.8
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(guess.description),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                _launchURL(
                                  'https://www.google.com/search?tbm=isch&q=${Uri.encodeComponent(guess.name)}',
                                );
                              },
                              icon: const Icon(Icons.search),
                              label: const Text('Search Images'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _plane.identification = guess.name;
                                  _plane.description = guess.description;
                                  _plane.status = PlaneStatus.finalized;
                                });
                                _savePlane();
                              },
                              child: const Text('Select This'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () {
                // Allow manual entry or just finalize as "Unknown"
                _showManualEntryDialog();
              },
              child: const Text('None of these? Enter manually'),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Plane Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Plane Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _plane.identification = controller.text;
                  _plane.status = PlaneStatus.finalized;
                });
                _savePlane();
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTagDialog(String tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag'),
        content: Text('Are you sure you want to delete the tag "$tag"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _plane.tags.remove(tag);
              });
              _savePlane();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Helper to launch URL
  Future<void> _launchURL(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $urlString')));
      }
    }
  }

  Widget _buildDetailSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Description', style: Theme.of(context).textTheme.titleMedium),
          Text(_plane.description),
          const SizedBox(height: 16),
          Text('Activity', style: Theme.of(context).textTheme.titleMedium),
          Text(_plane.activity),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              ..._plane.tags.map(
                (t) => GestureDetector(
                  onLongPress: () {
                    _showDeleteTagDialog(t);
                  },
                  child: Chip(label: Text(t)),
                ),
              ),
              ActionChip(
                label: const Icon(Icons.add, size: 18),
                onPressed: () {
                  _showAddTagDialog();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddTagDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Tag Name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _plane.tags.add(controller.text.trim());
                });
                _savePlane();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatHistory() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _plane.chatHistory.length,
      itemBuilder: (context, index) {
        final msg = _plane.chatHistory[index];
        return Align(
          alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: msg.isUser ? Colors.blueAccent : Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(msg.text),
          ),
        );
      },
    );
  }

  Widget _buildChatInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: const InputDecoration(
                hintText: 'Ask about this plane...',
                border: OutlineInputBorder(),
              ),
              enabled: !_isSending,
            ),
          ),
          IconButton(
            icon: _isSending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: _isSending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}
