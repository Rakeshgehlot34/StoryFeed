/// Types of media processing tasks supported by the studio engine.
enum JobType {
  shortsSplit,
  customSplit,
  editExport,
  convert,
  audioStudio,
  screenshot,
  merge,
}

extension JobTypeExtension on JobType {
  String get displayName => switch (this) {
        JobType.shortsSplit => 'Shorts Split',
        JobType.customSplit => 'Custom Split',
        JobType.editExport => 'Studio Edit',
        JobType.convert => 'Format Convert',
        JobType.audioStudio => 'Audio Studio',
        JobType.screenshot => 'Screenshot Capture',
        JobType.merge => 'Video Merge',
      };

  String get iconAsset => switch (this) {
        JobType.shortsSplit => 'split',
        JobType.customSplit => 'custom_split',
        JobType.editExport => 'edit',
        JobType.convert => 'convert',
        JobType.audioStudio => 'audio',
        JobType.screenshot => 'screenshot',
        JobType.merge => 'merge',
      };
}

/// Execution status of a job in the queue.
enum JobStatus { queued, running, completed, failed, cancelled }

extension JobStatusExtension on JobStatus {
  bool get isActive => this == JobStatus.queued || this == JobStatus.running;
  bool get isTerminal =>
      this == JobStatus.completed ||
      this == JobStatus.failed ||
      this == JobStatus.cancelled;
}

/// Serializable representation of any processing job in the unified studio queue.
class JobRecord {
  final String id;
  final JobType type;
  final String title;
  final String inputPath;
  final String outputDirectory;
  final JobStatus status;
  final double overallProgress;
  final String currentStepMessage;
  final int currentPart;
  final int totalParts;
  final List<String> outputPaths;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic> payload;

  const JobRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.inputPath,
    required this.outputDirectory,
    this.status = JobStatus.queued,
    this.overallProgress = 0.0,
    this.currentStepMessage = 'Waiting in queue...',
    this.currentPart = 0,
    this.totalParts = 1,
    this.outputPaths = const [],
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
    this.payload = const {},
  });

  double get progress => overallProgress;
  String get subtitle => currentStepMessage;

  JobRecord copyWith({
    JobStatus? status,
    double? overallProgress,
    String? currentStepMessage,
    int? currentPart,
    int? totalParts,
    List<String>? outputPaths,
    String? errorMessage,
    bool clearErrorMessage = false,
    DateTime? completedAt,
    Map<String, dynamic>? payload,
  }) {
    return JobRecord(
      id: id,
      type: type,
      title: title,
      inputPath: inputPath,
      outputDirectory: outputDirectory,
      status: status ?? this.status,
      overallProgress: overallProgress ?? this.overallProgress,
      currentStepMessage: currentStepMessage ?? this.currentStepMessage,
      currentPart: currentPart ?? this.currentPart,
      totalParts: totalParts ?? this.totalParts,
      outputPaths: outputPaths ?? this.outputPaths,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      payload: payload ?? this.payload,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'inputPath': inputPath,
        'outputDirectory': outputDirectory,
        'status': status.name,
        'overallProgress': overallProgress,
        'currentStepMessage': currentStepMessage,
        'currentPart': currentPart,
        'totalParts': totalParts,
        'outputPaths': outputPaths,
        'errorMessage': errorMessage,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'payload': payload,
      };

  factory JobRecord.fromJson(Map<String, dynamic> json) {
    return JobRecord(
      id: json['id'] as String,
      type: JobType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => JobType.shortsSplit,
      ),
      title: json['title'] as String,
      inputPath: json['inputPath'] as String,
      outputDirectory: json['outputDirectory'] as String,
      status: JobStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => JobStatus.queued,
      ),
      overallProgress: (json['overallProgress'] as num?)?.toDouble() ?? 0.0,
      currentStepMessage: json['currentStepMessage'] as String? ?? '',
      currentPart: json['currentPart'] as int? ?? 0,
      totalParts: json['totalParts'] as int? ?? 1,
      outputPaths:
          (json['outputPaths'] as List<dynamic>?)?.cast<String>() ?? [],
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    );
  }
}
