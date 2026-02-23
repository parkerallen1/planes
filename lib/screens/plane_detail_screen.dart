import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/plane.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../providers/theme_provider.dart';
import '../theme/app_themes.dart';

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
  bool _isLoadingTags = false;

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
        _plane.chatHistory,
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
    final isPokedex = ref.read(themeProvider).isPokedex;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPokedex ? 'DELETE ENTRY' : 'Delete Plane'),
        content: Text(
          isPokedex
              ? 'Permanently remove this aircraft from your Planedex?'
              : 'Are you sure you want to delete this plane?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isPokedex ? 'CANCEL' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isPokedex ? AppThemes.pokedexRed : Colors.red,
            ),
            child: Text(isPokedex ? 'DELETE' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final storageService = ref.read(storageServiceProvider);
      await storageService.deletePlane(_plane.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIdentifying = _plane.status == PlaneStatus.identifying;
    final isPokedex = ref.watch(themeProvider).isPokedex;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isIdentifying
              ? (isPokedex ? 'SCANNING...' : 'Identify Plane')
              : (isPokedex
                    ? _plane.identification.toUpperCase()
                    : _plane.identification),
        ),
        leading: isPokedex ? _buildPokedexBackButton(context) : null,
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
                  // Image with Pokedex overlay
                  _buildImageSection(isPokedex, isIdentifying),

                  if (isIdentifying) ...[
                    _buildIdentificationSection(isPokedex),
                  ] else ...[
                    _buildDetailSection(isPokedex),
                  ],

                  _buildDivider(isPokedex),

                  // Chat section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        if (isPokedex) ...[
                          _buildLedIndicator(AppThemes.pokedexGreen),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          isPokedex ? 'AIRCRAFT ANALYSIS' : 'Chat with Gemini',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(letterSpacing: isPokedex ? 2 : 0),
                        ),
                      ],
                    ),
                  ),
                  _buildChatHistory(isPokedex),
                ],
              ),
            ),
          ),
          _buildChatInput(isPokedex),
        ],
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

  Widget _buildImageSection(bool isPokedex, bool isIdentifying) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Stack(
        children: [
          Image.file(
            File(_plane.imagePath),
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
          if (isPokedex) ...[
            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.5, 1.0],
                    colors: [
                      Colors.transparent,
                      AppThemes.pokedexBlack.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),
            // Corner decorations
            Positioned(top: 16, left: 16, child: _buildCornerDecoration()),
            Positioned(
              top: 16,
              right: 16,
              child: _buildStatusIndicator(isIdentifying),
            ),
            // Bottom info bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildImageInfoBar(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCornerDecoration() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppThemes.pokedexCard.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppThemes.pokedexBlue.withOpacity(0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLedIndicator(AppThemes.pokedexBlue),
          const SizedBox(width: 8),
          Text(
            'VISUAL DATA',
            style: TextStyle(
              fontSize: 10,
              color: AppThemes.pokedexLightBlue,
              letterSpacing: 1,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(bool isIdentifying) {
    final color = isIdentifying
        ? AppThemes.pokedexYellow
        : AppThemes.pokedexGreen;
    final text = isIdentifying ? 'SCANNING' : 'CONFIRMED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isIdentifying)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.black87),
              ),
            )
          else
            Icon(Icons.check_circle, size: 14, color: Colors.black87),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: Colors.black87,
              letterSpacing: 1,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppThemes.pokedexCard.withOpacity(0.9),
        border: Border(
          top: BorderSide(color: AppThemes.pokedexBlue.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          _buildInfoItem(Icons.camera_alt, 'CAPTURED'),
          const Spacer(),
          _buildInfoItem(
            Icons.location_on,
            _plane.activity.isNotEmpty ? 'LOCATED' : 'UNKNOWN',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppThemes.pokedexBlue),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppThemes.pokedexLightBlue,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildLedIndicator(Color color) {
    return Container(
      width: 8,
      height: 8,
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

  Widget _buildDivider(bool isPokedex) {
    if (isPokedex) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        height: 2,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              AppThemes.pokedexBlue.withOpacity(0.5),
              Colors.transparent,
            ],
          ),
        ),
      );
    }
    return const Divider(height: 32);
  }

  Widget _buildIdentificationSection(bool isPokedex) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tips container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPokedex
                  ? AppThemes.pokedexCard
                  : Colors.yellow.withOpacity(0.1),
              border: Border.all(
                color: isPokedex ? AppThemes.pokedexYellow : Colors.yellow,
                width: isPokedex ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isPokedex) ...[
                      _buildLedIndicator(AppThemes.pokedexYellow),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      isPokedex
                          ? 'IDENTIFICATION NOTES'
                          : 'Identification Tips',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        letterSpacing: isPokedex ? 1 : 0,
                        color: isPokedex ? AppThemes.pokedexYellow : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _plane.identificationTips.isNotEmpty
                      ? _plane.identificationTips
                      : 'No tips available.',
                  style: TextStyle(color: isPokedex ? Colors.white70 : null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              if (isPokedex) ...[
                _buildLedIndicator(AppThemes.pokedexLightBlue),
                const SizedBox(width: 12),
              ],
              Text(
                isPokedex ? 'POSSIBLE MATCHES' : 'Gemini\'s Guesses',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  letterSpacing: isPokedex ? 2 : 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_plane.guesses.isEmpty)
            Text(
              isPokedex ? 'NO MATCHES FOUND' : 'No guesses available.',
              style: TextStyle(color: Colors.white54),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _plane.guesses.length,
              itemBuilder: (context, index) {
                final guess = _plane.guesses[index];
                return _buildGuessCard(guess, index, isPokedex);
              },
            ),
          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: () => _showManualEntryDialog(isPokedex),
              child: Text(
                isPokedex
                    ? 'MANUAL IDENTIFICATION'
                    : 'None of these? Enter manually',
                style: TextStyle(letterSpacing: isPokedex ? 1 : 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuessCard(PlaneGuess guess, int index, bool isPokedex) {
    final confidenceColor = guess.confidence > 0.8
        ? (isPokedex ? AppThemes.pokedexGreen : Colors.green)
        : (isPokedex ? AppThemes.pokedexYellow : Colors.orange);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isPokedex)
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppThemes.pokedexDarkGray,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppThemes.pokedexBlue.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      '#${(index + 1).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppThemes.pokedexBlue,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    isPokedex ? guess.name.toUpperCase() : guess.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      letterSpacing: isPokedex ? 0.5 : 0,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: isPokedex
                      ? BoxDecoration(
                          color: confidenceColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: confidenceColor),
                        )
                      : null,
                  child: Text(
                    '${(guess.confidence * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: confidenceColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: isPokedex ? 1 : 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              guess.description,
              style: TextStyle(color: isPokedex ? Colors.white70 : null),
            ),
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
                  label: Text(isPokedex ? 'IMAGES' : 'Search Images'),
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
                  child: Text(isPokedex ? 'CONFIRM' : 'Select This'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showManualEntryDialog(bool isPokedex) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPokedex ? 'MANUAL ID' : 'Enter Plane Name'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: isPokedex ? 'Aircraft designation' : 'Plane Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isPokedex ? 'CANCEL' : 'Cancel'),
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
            child: Text(isPokedex ? 'SAVE' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTagDialog(String tag, bool isPokedex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPokedex ? 'DELETE TAG' : 'Delete Tag'),
        content: Text('Are you sure you want to delete the tag "$tag"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isPokedex ? 'CANCEL' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _plane.tags.remove(tag);
              });
              _savePlane();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: isPokedex ? AppThemes.pokedexRed : Colors.red,
            ),
            child: Text(isPokedex ? 'DELETE' : 'Delete'),
          ),
        ],
      ),
    );
  }

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

  Widget _buildDetailSection(bool isPokedex) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          _buildDetailBlock(
            context,
            isPokedex ? 'DESCRIPTION' : 'Description',
            _plane.description,
            isPokedex,
            AppThemes.pokedexLightBlue,
          ),
          const SizedBox(height: 16),

          // Activity/Location
          _buildDetailBlock(
            context,
            isPokedex ? 'ACTIVITY LOG' : 'Activity',
            _plane.activity.isNotEmpty
                ? _plane.activity
                : 'No activity recorded',
            isPokedex,
            AppThemes.pokedexGreen,
          ),
          const SizedBox(height: 16),

          // Tags
          Row(
            children: [
              if (isPokedex) ...[
                _buildLedIndicator(AppThemes.pokedexYellow),
                const SizedBox(width: 10),
              ],
              Text(
                isPokedex ? 'TAGS' : 'Tags',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  letterSpacing: isPokedex ? 1 : 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._plane.tags.map(
                (t) => GestureDetector(
                  onLongPress: () => _showDeleteTagDialog(t, isPokedex),
                  child: _buildTagChip(t, isPokedex),
                ),
              ),
              _buildAddTagChip(isPokedex),
              _buildRerunTagsChip(isPokedex),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailBlock(
    BuildContext context,
    String title,
    String content,
    bool isPokedex,
    Color ledColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isPokedex) ...[
              _buildLedIndicator(ledColor),
              const SizedBox(width: 10),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                letterSpacing: isPokedex ? 1 : 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (isPokedex)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppThemes.pokedexCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ledColor.withOpacity(0.3)),
            ),
            child: Text(content, style: TextStyle(color: Colors.white70)),
          )
        else
          Text(content),
      ],
    );
  }

  Widget _buildTagChip(String tag, bool isPokedex) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isPokedex ? AppThemes.pokedexDarkGray : null,
        borderRadius: BorderRadius.circular(isPokedex ? 8 : 20),
        border: isPokedex
            ? Border.all(color: AppThemes.pokedexBlue.withOpacity(0.5))
            : null,
      ),
      child: isPokedex
          ? Text(
              tag.toUpperCase(),
              style: TextStyle(
                color: AppThemes.pokedexLightBlue,
                fontSize: 12,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w500,
              ),
            )
          : Chip(label: Text(tag)),
    );
  }

  Widget _buildAddTagChip(bool isPokedex) {
    return GestureDetector(
      onTap: () => _showAddTagDialog(isPokedex),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isPokedex ? AppThemes.pokedexDarkGray : Colors.grey[800],
          borderRadius: BorderRadius.circular(isPokedex ? 8 : 20),
          border: isPokedex
              ? Border.all(color: AppThemes.pokedexGreen.withOpacity(0.5))
              : null,
        ),
        child: Icon(
          Icons.add,
          size: 18,
          color: isPokedex ? AppThemes.pokedexGreen : Colors.white70,
        ),
      ),
    );
  }

  Widget _buildRerunTagsChip(bool isPokedex) {
    return GestureDetector(
      onTap: _isLoadingTags ? null : _rerunTags,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isPokedex ? AppThemes.pokedexDarkGray : Colors.grey[800],
          borderRadius: BorderRadius.circular(isPokedex ? 8 : 20),
          border: isPokedex
              ? Border.all(color: AppThemes.pokedexYellow.withOpacity(0.5))
              : null,
        ),
        child: _isLoadingTags
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                    isPokedex ? AppThemes.pokedexYellow : Colors.white70,
                  ),
                ),
              )
            : Icon(
                Icons.refresh,
                size: 18,
                color: isPokedex ? AppThemes.pokedexYellow : Colors.white70,
              ),
      ),
    );
  }

  Future<void> _rerunTags() async {
    setState(() {
      _isLoadingTags = true;
    });

    try {
      final geminiService = ref.read(geminiServiceProvider);
      final newTags = await geminiService.regenerateTags(_plane.imagePath);

      if (mounted) {
        setState(() {
          _plane.tags = newTags;
        });
        await _savePlane();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTags = false;
        });
      }
    }
  }

  void _showAddTagDialog(bool isPokedex) {
    // Separate current tags into "valid/managed" and "other/custom" (e.g. Manufacturer)
    final currentManagedTags = _plane.tags
        .where((t) => GeminiService.validTags.contains(t))
        .toSet();
    final otherTags = _plane.tags
        .where((t) => !GeminiService.validTags.contains(t))
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isPokedex ? 'MANAGE TAGS' : 'Manage Tags'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: GeminiService.validTags.length,
                  itemBuilder: (context, index) {
                    final tag = GeminiService.validTags[index];
                    final isSelected = currentManagedTags.contains(tag);
                    return CheckboxListTile(
                      title: Text(tag),
                      value: isSelected,
                      activeColor: isPokedex
                          ? AppThemes.pokedexGreen
                          : Theme.of(context).primaryColor,
                      checkColor: isPokedex ? Colors.black : Colors.white,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            currentManagedTags.add(tag);
                          } else {
                            currentManagedTags.remove(tag);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(isPokedex ? 'CANCEL' : 'Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    // Reassemble tags: Preserved others + new selection
                    final newTags = [...otherTags, ...currentManagedTags];
                    // Update parent state
                    this.setState(() {
                      _plane.tags = newTags;
                    });
                    _savePlane();
                    Navigator.pop(context);
                  },
                  child: Text(isPokedex ? 'SAVE' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildChatHistory(bool isPokedex) {
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
              color: msg.isUser
                  ? (isPokedex ? AppThemes.pokedexRed : Colors.blueAccent)
                  : (isPokedex ? AppThemes.pokedexCard : Colors.grey[800]),
              borderRadius: BorderRadius.circular(12),
              border: isPokedex && !msg.isUser
                  ? Border.all(color: AppThemes.pokedexBlue.withOpacity(0.5))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPokedex && !msg.isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLedIndicator(AppThemes.pokedexGreen),
                        const SizedBox(width: 6),
                        Text(
                          'ANALYSIS',
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
                Text(msg.text),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatInput(bool isPokedex) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: isPokedex
            ? BoxDecoration(
                color: AppThemes.pokedexCard,
                border: Border(
                  top: BorderSide(
                    color: AppThemes.pokedexBlue.withOpacity(0.5),
                  ),
                ),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatController,
                decoration: InputDecoration(
                  hintText: isPokedex
                      ? 'Query aircraft database...'
                      : 'Ask about this plane...',
                  border: const OutlineInputBorder(),
                ),
                enabled: !_isSending,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: isPokedex
                  ? BoxDecoration(
                      color: AppThemes.pokedexRed,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 2),
                    )
                  : null,
              child: IconButton(
                icon: _isSending
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            isPokedex ? Colors.white : null,
                          ),
                        ),
                      )
                    : Icon(Icons.send, color: isPokedex ? Colors.white : null),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
