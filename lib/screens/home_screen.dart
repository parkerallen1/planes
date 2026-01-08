import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import '../models/plane.dart';

import 'plane_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? selectedTag;

  @override
  Widget build(BuildContext context) {
    final storageService = ref.watch(storageServiceProvider);
    // In a real app, we'd use a StreamProvider or ValueListenableBuilder for live updates.
    // For now, we'll just rebuild when we return from other screens.
    final allPlanes = storageService.getAllPlanes();
    final allTags = storageService.getAllTags();

    final filteredPlanes = selectedTag == null
        ? allPlanes
        : allPlanes.where((p) => p.tags.contains(selectedTag)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My Planes')),
      body: Column(
        children: [
          // Tag Filter
          if (allTags.isNotEmpty)
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: selectedTag == null,
                    onSelected: (selected) {
                      setState(() {
                        selectedTag = null;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ...allTags.map(
                    (tag) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tag),
                        selected: selectedTag == tag,
                        onSelected: (selected) {
                          setState(() {
                            selectedTag = selected ? tag : null;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Plane List
          Expanded(
            child: filteredPlanes.isEmpty
                ? const Center(child: Text('No planes found. Add one!'))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.75, // Adjust as needed
                        ),
                    itemCount: filteredPlanes.length,
                    itemBuilder: (context, index) {
                      final plane = filteredPlanes[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        shape: plane.status == PlaneStatus.identifying
                            ? RoundedRectangleBorder(
                                side: const BorderSide(
                                  color: Colors.yellow,
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              )
                            : null,
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PlaneDetailScreen(plane: plane),
                              ),
                            );
                            setState(() {}); // Refresh on return
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Image.file(
                                  File(plane.imagePath),
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(
                                        child: Icon(Icons.broken_image),
                                      ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plane.status == PlaneStatus.identifying
                                          ? 'Identifying...'
                                          : plane.identification,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    if (plane.status !=
                                            PlaneStatus.identifying &&
                                        plane.tags.isNotEmpty)
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: plane.tags
                                            .map(
                                              (tag) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  tag,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/add');
          setState(() {}); // Refresh on return
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
