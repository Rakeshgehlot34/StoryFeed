import '../../../core/database/app_database.dart';
import 'models/project_with_details.dart';

abstract class ProjectRepository {
  Stream<List<ProjectWithDetails>> watchAllProjects();
  Future<List<ProjectWithDetails>> getAllProjects();
  Future<ProjectWithDetails?> getProject(String id);
  Future<void> saveProject(ProjectsCompanion project);
  Future<void> updateProjectTimestamp(String id);
  Future<void> deleteProject(String id, {bool deleteFiles = false});
  Future<void> clearAllProjects();
}
