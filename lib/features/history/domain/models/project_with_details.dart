import '../../../../core/database/app_database.dart';

/// Aggregated view combining a Project, its Source, and its Parts.
class ProjectWithDetails {
  final Project project;
  final Source source;
  final List<Part> parts;

  const ProjectWithDetails({
    required this.project,
    required this.source,
    required this.parts,
  });

  bool get isMultiPart =>
      project.outputLayout == 'multi_subfolder' || project.totalPartsCount > 1;

  int get splitCount =>
      parts.where((p) => p.stage == 'split' || p.stage == 'converted').length;

  int get convertedCount => parts.where((p) => p.stage == 'converted').length;

  int get totalDiskBytes =>
      parts.fold<int>(0, (sum, p) => sum + p.fileSizeBytes.toInt());

  bool get isCompleted =>
      parts.isNotEmpty && parts.every((p) => p.stage == 'converted');

  bool get hasFailures => parts.any((p) => p.status == 'failed');

  bool get hasMissing => parts.any((p) => p.isMissing);

  String get summaryBadgeText {
    if (isMultiPart) {
      return '${project.totalPartsCount} parts · $splitCount split · $convertedCount converted';
    }
    return convertedCount > 0 ? 'Converted' : 'Split';
  }
}
