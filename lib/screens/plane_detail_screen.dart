import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/plane.dart';
import '../models/scan_category.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../providers/category_provider.dart';
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

    // Snapshot the history before appending the new message: chat() expects
    // only past turns, and sends `text` itself as the new user turn.
    final history = List<ChatMessage>.from(_plane.chatHistory);
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
        history,
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
    final isRetro = ref.read(themeProvider).isRetro;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isRetro ? 'DELETE ENTRY' : 'Delete Plane'),
        content: Text(
          isRetro
              ? 'Permanently remove this aircraft from your Dexicon?'
              : 'Are you sure you want to delete this plane?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isRetro ? 'CANCEL' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isRetro ? AppThemes.retroRed : Colors.red,
            ),
            child: Text(isRetro ? 'DELETE' : 'Delete'),
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
    final isRetro = ref.watch(themeProvider).isRetro;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isIdentifying
              ? (isRetro ? 'SCANNING...' : 'Identify Plane')
              : (isRetro
                    ? _plane.identification.toUpperCase()
                    : _plane.identification),
        ),
        leading: isRetro ? _buildRetroBackButton(context) : null,
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
                  // Image with Retro overlay
                  _buildImageSection(isRetro, isIdentifying),

                  if (isIdentifying) ...[
                    _buildIdentificationSection(isRetro),
                  ] else ...[
                    _buildDetailSection(isRetro),
                  ],

                  _buildDivider(isRetro),

                  // Chat section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        if (isRetro) ...[
                          _buildLedIndicator(AppThemes.retroGreen),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          isRetro ? 'AIRCRAFT ANALYSIS' : 'Chat with Gemini',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(letterSpacing: isRetro ? 2 : 0),
                        ),
                      ],
                    ),
                  ),
                  _buildChatHistory(isRetro),
                ],
              ),
            ),
          ),
          _buildChatInput(isRetro),
        ],
      ),
    );
  }

  Widget _buildRetroBackButton(BuildContext context) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppThemes.retroDarkGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppThemes.retroBlue.withOpacity(0.5)),
        ),
        child: const Icon(Icons.arrow_back, size: 18),
      ),
      onPressed: () => Navigator.pop(context),
    );
  }

  Widget _buildImageSection(bool isRetro, bool isIdentifying) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    backgroundColor: Colors.black,
                    appBar: AppBar(
                      backgroundColor: Colors.black,
                      iconTheme: const IconThemeData(color: Colors.white),
                    ),
                    body: SafeArea(
                      child: Center(
                        child: InteractiveViewer(
                          panEnabled: true,
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Hero(
                            tag: 'plane_image_${_plane.id}',
                            child: _plane.imagePath.startsWith('assets/')
                                ? Image.asset(
                                    _plane.imagePath,
                                    fit: BoxFit.contain,
                                  )
                                : Image.file(
                                    File(_plane.imagePath),
                                    fit: BoxFit.contain,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            child: Hero(
              tag: 'plane_image_${_plane.id}',
              child: _plane.imagePath.startsWith('assets/')
                  ? Image.asset(
                      _plane.imagePath,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(_plane.imagePath),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
            ),
          ),
          if (isRetro) ...[
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
                      AppThemes.retroBlack.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),
            // Targeting Viewfinder brackets
            Positioned.fill(
              child: CustomPaint(
                painter: DetailViewfinderBracketsPainter(
                  color: isIdentifying
                      ? AppThemes.retroYellow.withOpacity(0.8)
                      : AppThemes.retroBlue.withOpacity(0.4),
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
        color: AppThemes.retroCard.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppThemes.retroBlue.withOpacity(0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLedIndicator(AppThemes.retroBlue),
          const SizedBox(width: 8),
          Text(
            'VISUAL DATA',
            style: TextStyle(
              fontSize: 10,
              color: AppThemes.retroLightBlue,
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
        ? AppThemes.retroYellow
        : AppThemes.retroGreen;
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
        color: AppThemes.retroCard.withOpacity(0.9),
        border: Border(
          top: BorderSide(color: AppThemes.retroBlue.withOpacity(0.5)),
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
        Icon(icon, size: 14, color: AppThemes.retroBlue),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppThemes.retroLightBlue,
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

  Widget _buildDivider(bool isRetro) {
    if (isRetro) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        height: 2,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              AppThemes.retroBlue.withOpacity(0.5),
              Colors.transparent,
            ],
          ),
        ),
      );
    }
    return const Divider(height: 32);
  }

  Widget _buildIdentificationSection(bool isRetro) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tips container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isRetro
                  ? const Color(0xFF0F140C)
                  : Colors.yellow.withOpacity(0.1),
              border: Border.all(
                color: isRetro ? AppThemes.retroYellow : Colors.yellow,
                width: isRetro ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(isRetro ? 6 : 8),
              boxShadow: isRetro
                  ? [
                      BoxShadow(
                        color: AppThemes.retroYellow.withOpacity(0.15),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isRetro) ...[
                      _buildLedIndicator(AppThemes.retroYellow),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      isRetro
                          ? 'IDENTIFICATION NOTES'
                          : 'Identification Tips',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        letterSpacing: isRetro ? 1 : 0,
                        color: isRetro ? AppThemes.retroYellow : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _plane.identificationTips.isNotEmpty
                      ? (isRetro ? _plane.identificationTips.toUpperCase() : _plane.identificationTips)
                      : 'No tips available.',
                  style: TextStyle(
                    color: isRetro ? AppThemes.retroYellow : null,
                    fontFamily: isRetro ? 'Courier' : null,
                    fontSize: isRetro ? 13 : null,
                    fontWeight: isRetro ? FontWeight.bold : null,
                    height: isRetro ? 1.4 : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              if (isRetro) ...[
                _buildLedIndicator(AppThemes.retroLightBlue),
                const SizedBox(width: 12),
              ],
              Text(
                isRetro ? 'POSSIBLE MATCHES' : 'Gemini\'s Guesses',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  letterSpacing: isRetro ? 2 : 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_plane.guesses.isEmpty)
            Text(
              isRetro ? 'NO MATCHES FOUND' : 'No guesses available.',
              style: TextStyle(color: Colors.white54),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _plane.guesses.length,
              itemBuilder: (context, index) {
                final guess = _plane.guesses[index];
                return _buildGuessCard(guess, index, isRetro);
              },
            ),
          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: () => _showManualEntryDialog(isRetro),
              child: Text(
                isRetro
                    ? 'MANUAL IDENTIFICATION'
                    : 'None of these? Enter manually',
                style: TextStyle(letterSpacing: isRetro ? 1 : 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuessCard(PlaneGuess guess, int index, bool isRetro) {
    final confidenceColor = guess.confidence > 0.8
        ? (isRetro ? AppThemes.retroGreen : Colors.green)
        : (isRetro ? AppThemes.retroYellow : Colors.orange);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isRetro)
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppThemes.retroDarkGray,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppThemes.retroBlue.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      '#${(index + 1).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppThemes.retroBlue,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    isRetro ? guess.name.toUpperCase() : guess.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      letterSpacing: isRetro ? 0.5 : 0,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: isRetro
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
                      letterSpacing: isRetro ? 1 : 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              guess.description,
              style: TextStyle(color: isRetro ? Colors.white70 : null),
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
                  label: Text(isRetro ? 'IMAGES' : 'Search Images'),
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
                  child: Text(isRetro ? 'CONFIRM' : 'Select This'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showManualEntryDialog(bool isRetro) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isRetro ? 'MANUAL ID' : 'Enter Plane Name'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: isRetro ? 'Aircraft designation' : 'Plane Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isRetro ? 'CANCEL' : 'Cancel'),
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
            child: Text(isRetro ? 'SAVE' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTagDialog(String tag, bool isRetro) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isRetro ? 'DELETE TAG' : 'Delete Tag'),
        content: Text('Are you sure you want to delete the tag "$tag"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isRetro ? 'CANCEL' : 'Cancel'),
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
              foregroundColor: isRetro ? AppThemes.retroRed : Colors.red,
            ),
            child: Text(isRetro ? 'DELETE' : 'Delete'),
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

  Widget _buildDetailSection(bool isRetro) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          _buildDetailBlock(
            context,
            isRetro ? 'DESCRIPTION' : 'Description',
            _plane.description,
            isRetro,
            AppThemes.retroLightBlue,
          ),
          const SizedBox(height: 16),

          // Activity/Location
          _buildDetailBlock(
            context,
            isRetro ? 'ACTIVITY LOG' : 'Activity',
            _plane.activity.isNotEmpty
                ? _plane.activity
                : 'No activity recorded',
            isRetro,
            AppThemes.retroGreen,
          ),
          const SizedBox(height: 16),

          // Tags
          Row(
            children: [
              if (isRetro) ...[
                _buildLedIndicator(AppThemes.retroYellow),
                const SizedBox(width: 10),
              ],
              Text(
                isRetro ? 'TAGS' : 'Tags',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  letterSpacing: isRetro ? 1 : 0,
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
                  onLongPress: () => _showDeleteTagDialog(t, isRetro),
                  child: _buildTagChip(t, isRetro),
                ),
              ),
              _buildAddTagChip(isRetro),
              _buildRerunTagsChip(isRetro),
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
    bool isRetro,
    Color ledColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isRetro) ...[
              _buildLedIndicator(ledColor),
              const SizedBox(width: 10),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                letterSpacing: isRetro ? 1 : 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (isRetro)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F140C),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ledColor.withOpacity(0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: ledColor.withOpacity(0.15),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              content.toUpperCase(),
              style: TextStyle(
                color: ledColor,
                fontFamily: 'Courier',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
          )
        else
          Text(content),
      ],
    );
  }

  Widget _buildTagChip(String tag, bool isRetro) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isRetro ? AppThemes.retroDarkGray : null,
        borderRadius: BorderRadius.circular(isRetro ? 8 : 20),
        border: isRetro
            ? Border.all(color: AppThemes.retroBlue.withOpacity(0.5))
            : null,
      ),
      child: isRetro
          ? Text(
              tag.toUpperCase(),
              style: TextStyle(
                color: AppThemes.retroLightBlue,
                fontSize: 12,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w500,
              ),
            )
          : Chip(label: Text(tag)),
    );
  }

  Widget _buildAddTagChip(bool isRetro) {
    return GestureDetector(
      onTap: () => _showAddTagDialog(isRetro),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isRetro ? AppThemes.retroDarkGray : Colors.grey[800],
          borderRadius: BorderRadius.circular(isRetro ? 8 : 20),
          border: isRetro
              ? Border.all(color: AppThemes.retroGreen.withOpacity(0.5))
              : null,
        ),
        child: Icon(
          Icons.add,
          size: 18,
          color: isRetro ? AppThemes.retroGreen : Colors.white70,
        ),
      ),
    );
  }

  Widget _buildRerunTagsChip(bool isRetro) {
    return GestureDetector(
      onTap: _isLoadingTags ? null : _rerunTags,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isRetro ? AppThemes.retroDarkGray : Colors.grey[800],
          borderRadius: BorderRadius.circular(isRetro ? 8 : 20),
          border: isRetro
              ? Border.all(color: AppThemes.retroYellow.withOpacity(0.5))
              : null,
        ),
        child: _isLoadingTags
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                    isRetro ? AppThemes.retroYellow : Colors.white70,
                  ),
                ),
              )
            : Icon(
                Icons.refresh,
                size: 18,
                color: isRetro ? AppThemes.retroYellow : Colors.white70,
              ),
      ),
    );
  }

  /// The category this plane was scanned under, if it still exists.
  ScanCategory? get _category {
    for (final c in ref.read(categoryProvider).categories) {
      if (c.id == _plane.categoryId) return c;
    }
    return null;
  }

  Future<void> _rerunTags() async {
    setState(() {
      _isLoadingTags = true;
    });

    try {
      final geminiService = ref.read(geminiServiceProvider);
      final category = _category;
      final newTags = await geminiService.regenerateTags(
        _plane.imagePath,
        category: category,
        onNewTags: category == null
            ? null
            : (tags) => ref
                  .read(categoryProvider.notifier)
                  .addTagsToCategory(category.id, tags),
      );

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

  void _showAddTagDialog(bool isRetro) {
    final managedTagList = _category?.validTags ?? GeminiService.validTags;

    // Separate current tags into "valid/managed" and "other/custom" (e.g. Manufacturer)
    final currentManagedTags = _plane.tags
        .where((t) => managedTagList.contains(t))
        .toSet();
    final otherTags = _plane.tags
        .where((t) => !managedTagList.contains(t))
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isRetro ? 'MANAGE TAGS' : 'Manage Tags'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: managedTagList.length,
                  itemBuilder: (context, index) {
                    final tag = managedTagList[index];
                    final isSelected = currentManagedTags.contains(tag);
                    return CheckboxListTile(
                      title: Text(tag),
                      value: isSelected,
                      activeColor: isRetro
                          ? AppThemes.retroGreen
                          : Theme.of(context).primaryColor,
                      checkColor: isRetro ? Colors.black : Colors.white,
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
                  child: Text(isRetro ? 'CANCEL' : 'Cancel'),
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
                  child: Text(isRetro ? 'SAVE' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildChatHistory(bool isRetro) {
    if (!isRetro) {
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

    // Retro CLI Terminal Mode
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF070B19), // Cyber terminal dark background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppThemes.retroBlue.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: _plane.chatHistory.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'DEXICON CORE v1.0.4\nWAITING FOR DIAGNOSTIC QUERY...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Courier',
                    color: Colors.white30,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _plane.chatHistory.map((msg) {
                final timestampStr = "${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}:${msg.timestamp.second.toString().padLeft(2, '0')}";
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.isUser
                            ? 'USER >'
                            : 'DEXICON_CORE [$timestampStr] >',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: msg.isUser
                              ? AppThemes.retroLightBlue
                              : AppThemes.retroGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          msg.text.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 13,
                            color: msg.isUser
                                ? Colors.white
                                : AppThemes.retroGreen.withOpacity(0.9),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildChatInput(bool isRetro) {
    if (!isRetro) {
      return SafeArea(
        top: false,
        child: Container(
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
              const SizedBox(width: 8),
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
        ),
      );
    }

    // Retro CLI prompt input
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppThemes.retroBlack,
          border: Border(
            top: BorderSide(
              color: AppThemes.retroBlue.withOpacity(0.4),
              width: 1.5,
            ),
          ),
        ),
        child: Row(
          children: [
            const Text(
              'QUERY > ',
              style: TextStyle(
                fontFamily: 'Courier',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppThemes.retroLightBlue,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _chatController,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 13,
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  hintText: 'RUN DIAGNOSTIC QUERY...',
                  hintStyle: TextStyle(
                    fontFamily: 'Courier',
                    color: Colors.white30,
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: Color(0xFF070B19),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                ),
                enabled: !_isSending,
                onSubmitted: (_) => _isSending ? null : _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: AppThemes.retroRed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30, width: 1.5),
              ),
              child: IconButton(
                iconSize: 18,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.keyboard_return, color: Colors.white),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailViewfinderBracketsPainter extends CustomPainter {
  final Color color;
  DetailViewfinderBracketsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    const length = 24.0;
    const margin = 20.0;

    // Top Left
    canvas.drawLine(
      const Offset(margin, margin),
      const Offset(margin + length, margin),
      paint,
    );
    canvas.drawLine(
      const Offset(margin, margin),
      const Offset(margin, margin + length),
      paint,
    );

    // Top Right
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin - length, margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin, margin + length),
      paint,
    );

    // Bottom Left
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin + length, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin, size.height - margin - length),
      paint,
    );

    // Bottom Right
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin - length, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin, size.height - margin - length),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
