import 'models/project_record.dart';

/// Abstract repository for persisting and querying split project history.
abstract class HistoryRepository {
  Future<List<ProjectRecord>> getProjects();
  Future<void> saveProject(ProjectRecord project);
  Future<void> deleteProject(String id);
  Future<void> deleteProjects(List<String> ids);
  Future<void> clearHistory();
}
