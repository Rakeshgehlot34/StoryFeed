import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/constants/app_strings.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/services/app_messenger.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../output/domain/models/exported_clip.dart';
import '../../../output/presentation/controllers/output_controller.dart';
import '../../domain/models/project_record.dart';
import '../controllers/history_controller.dart';
import '../widgets/history_project_card.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final Set<String> _selectedIds = <String>{};
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _openProjectResults(ProjectRecord project) {
    final clips = project.outputFilePaths.asMap().entries.map((e) {
      return ExportedClip(
        path: e.value,
        fileName: e.value.split('/').last,
        partIndex: e.key + 1,
        totalParts: project.outputFilePaths.length,
        duration: Duration.zero,
        sizeInBytes: 0,
        createdAt: project.createdAt,
      );
    }).toList();

    ref.read(exportedClipsProvider.notifier).setClips(clips);
    context.push(AppRoutes.results);
  }

  void _deleteWithUndo(String id) {
    ref.read(historyControllerProvider.notifier).deleteProject(id);
    AppMessenger.show(
      context,
      message: AppStrings.historyDeletedSnackbar,
      actionLabel: AppStrings.actionUndo,
      onAction: () {
        ref.read(historyControllerProvider.notifier).undoDelete();
      },
    );
  }

  Map<String, List<ProjectRecord>> _groupByDate(List<ProjectRecord> projects) {
    final Map<String, List<ProjectRecord>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    for (final p in projects) {
      final pDate = DateTime(
        p.createdAt.year,
        p.createdAt.month,
        p.createdAt.day,
      );
      final String groupName;
      if (pDate.isAtSameMomentAs(today)) {
        groupName = 'Today';
      } else if (pDate.isAtSameMomentAs(yesterday)) {
        groupName = 'Yesterday';
      } else if (pDate.isAfter(weekAgo)) {
        groupName = 'Earlier This Week';
      } else {
        groupName = 'Older';
      }
      groups.putIfAbsent(groupName, () => []).add(p);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyControllerProvider);
    final isSelectionMode = _selectedIds.isNotEmpty;

    return Scaffold(
      appBar: _buildAppBar(isSelectionMode),
      body: RefreshIndicator(
        onRefresh: () => ref.read(historyControllerProvider.notifier).refresh(),
        child: historyAsync.when(
          loading: () => _buildLoadingList(),
          error: (err, _) => ErrorState(
            message: err.toString(),
            onRetry: () =>
                ref.read(historyControllerProvider.notifier).search(''),
          ),
          data: (projects) {
            if (projects.isEmpty) {
              return const EmptyState(
                icon: Icons.history_toggle_off_rounded,
                title: 'No Project History',
                message: AppStrings.historyEmpty,
              );
            }
            return _buildGroupedProjectsList(projects, isSelectionMode);
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isSelectionMode) {
    final controller = ref.read(historyControllerProvider.notifier);
    final currentSort = controller.sortOrder;

    if (isSelectionMode) {
      return AppBar(
        title: Text('${_selectedIds.length} Selected'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => setState(() => _selectedIds.clear()),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Delete Selected',
            onPressed: () async {
              await controller.deleteMultiple(_selectedIds.toList());
              setState(() => _selectedIds.clear());
            },
          ),
        ],
      );
    }

    return AppBar(
      title: _isSearchOpen
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: AppStrings.historySearchHint,
                border: InputBorder.none,
                filled: false,
              ),
              onChanged: (val) {
                controller.search(val);
              },
            )
          : const Text(AppStrings.historyTitle),
      actions: [
        IconButton(
          icon: Icon(_isSearchOpen ? Icons.close : Icons.search_rounded),
          tooltip: 'Search Projects',
          onPressed: () {
            setState(() {
              _isSearchOpen = !_isSearchOpen;
              if (!_isSearchOpen) {
                _searchController.clear();
                controller.search('');
              }
            });
          },
        ),
        PopupMenuButton<HistorySortOrder>(
          icon: const Icon(Icons.sort_rounded),
          tooltip: 'Sort History',
          initialValue: currentSort,
          onSelected: (order) => controller.setSortOrder(order),
          itemBuilder: (ctx) => HistorySortOrder.values.map((order) {
            return PopupMenuItem(
              value: order,
              child: Row(
                children: [
                  if (order == currentSort)
                    Icon(
                      Icons.check,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(order.label),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGroupedProjectsList(
    List<ProjectRecord> projects,
    bool isSelectionMode,
  ) {
    final grouped = _groupByDate(projects);
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      itemCount: grouped.keys.length,
      itemBuilder: (context, groupIndex) {
        final groupTitle = grouped.keys.elementAt(groupIndex);
        final groupProjects = grouped[groupTitle]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppTokens.spaceSm,
                horizontal: AppTokens.spaceXs,
              ),
              child: Text(
                groupTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            ...groupProjects.map((p) {
              final isSelected = _selectedIds.contains(p.id);
              return Dismissible(
                key: Key(p.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppTokens.spaceLg),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: AppTokens.borderRadiusLg,
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => _deleteWithUndo(p.id),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
                  child: HistoryProjectCard(
                    project: p,
                    isSelected: isSelected,
                    isSelectionMode: isSelectionMode,
                    onTap: () {
                      if (isSelectionMode) {
                        _toggleSelect(p.id);
                      } else {
                        _openProjectResults(p);
                      }
                    },
                    onLongPress: () => _toggleSelect(p.id),
                    onDelete: () => _deleteWithUndo(p.id),
                  ),
                ),
              );
            }),
            const SizedBox(height: AppTokens.spaceSm),
          ],
        );
      },
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
        child: LoadingSkeleton.tile(),
      ),
    );
  }
}
