import 'dart:convert';
import 'database_service.dart';
import 'project_storage_service.dart';

/// Repository that bridges between file-based storage and database storage
/// This allows easy migration and provides a unified interface
class ProjectRepository {
  static ProjectRepository? _instance;
  
  final DatabaseService _databaseService = DatabaseService.getInstance();
  final ProjectStorageService _fileService = ProjectStorageService();
  
  ProjectRepository._();
  
  static ProjectRepository getInstance() {
    _instance ??= ProjectRepository._();
    return _instance!;
  }

  // --- CONVERSION METHODS ---

  /// Convert ProjectData to ProjectEntity for database storage
  ProjectEntity _projectDataToEntity(ProjectData projectData, {int? id}) {
    return ProjectEntity(
      id: id,
      name: projectData.name,
      patternJson: jsonEncode(projectData.pattern),
      bpm: projectData.bpm,
      steps: projectData.steps,
      createdAt: projectData.createdAt,
      modifiedAt: projectData.modifiedAt,
      description: null, // Can be added later
      isFavorite: false, // Can be added later
    );
  }

  /// Convert ProjectEntity to ProjectData for compatibility
  ProjectData _entityToProjectData(ProjectEntity entity, List<TapEvent>? tapEvents) {
    final pattern = (jsonDecode(entity.patternJson) as List<dynamic>)
        .map((row) => (row as List<dynamic>).cast<bool>())
        .toList();

    return ProjectData(
      name: entity.name,
      pattern: pattern,
      bpm: entity.bpm,
      steps: entity.steps,
      createdAt: entity.createdAt,
      modifiedAt: entity.modifiedAt,
      tapEvents: tapEvents,
    );
  }

  /// Convert TapEvent to TapEventEntity
  TapEventEntity _tapEventToEntity(TapEvent tapEvent, int projectId) {
    return TapEventEntity(
      projectId: projectId,
      time: tapEvent.time,
      label: tapEvent.label,
      createdAt: DateTime.now(),
    );
  }

  /// Convert TapEventEntity to TapEvent
  TapEvent _entityToTapEvent(TapEventEntity entity) {
    return TapEvent(
      time: entity.time,
      label: entity.label,
    );
  }

  // --- MAIN REPOSITORY METHODS ---

  /// Save project using database (new method)
  Future<bool> saveProject(ProjectData project) async {
    try {
      print('📂 REPO: Saving project to database: ${project.name}');
      
      // Check if project already exists
      final existingProject = await _databaseService.getProjectByName(project.name);
      
      ProjectEntity projectEntity;
      if (existingProject != null) {
        // Update existing project
        projectEntity = _projectDataToEntity(project, id: existingProject.id);
      } else {
        // Create new project
        projectEntity = _projectDataToEntity(project);
      }

      // Convert tap events if they exist
      List<TapEventEntity> tapEventEntities = [];
      if (project.tapEvents != null) {
        // We need project ID first, so we'll handle this in the saveProjectWithTapEvents method
      }

      int projectId;
      if (project.tapEvents != null && project.tapEvents!.isNotEmpty) {
        // Save with tap events
        tapEventEntities = project.tapEvents!
            .map((tapEvent) => _tapEventToEntity(tapEvent, 0)) // Temporary ID
            .toList();
        projectId = await _databaseService.saveProjectWithTapEvents(projectEntity, tapEventEntities);
      } else {
        // Save project only
        if (existingProject != null) {
          await _databaseService.updateProject(projectEntity);
          projectId = existingProject.id!;
        } else {
          projectId = await _databaseService.insertProject(projectEntity);
        }
      }

      print('✅ REPO: Project saved successfully with ID: $projectId');
      return true;
    } catch (e) {
      print('❌ REPO: Error saving project: $e');
      return false;
    }
  }

  /// Load project using database (new method)
  Future<ProjectData?> loadProject(String projectName) async {
    try {
      print('📂 REPO: Loading project from database: $projectName');
      
      final projectEntity = await _databaseService.getProjectByName(projectName);
      if (projectEntity == null) {
        print('📂 REPO: Project not found in database');
        return null;
      }

      // Load associated tap events
      final tapEventEntities = await _databaseService.getTapEventsByProject(projectEntity.id!);
      final tapEvents = tapEventEntities
          .map((entity) => _entityToTapEvent(entity))
          .toList();

      final projectData = _entityToProjectData(projectEntity, tapEvents.isEmpty ? null : tapEvents);
      
      print('✅ REPO: Project loaded successfully with ${tapEvents.length} tap events');
      return projectData;
    } catch (e) {
      print('❌ REPO: Error loading project: $e');
      return null;
    }
  }

  /// Get list of all projects
  Future<List<String>> getProjectList() async {
    try {
      print('📂 REPO: Fetching project list from database');
      
      final projects = await _databaseService.getAllProjects();
      final projectNames = projects.map((project) => project.name).toList();
      
      print('✅ REPO: Found ${projectNames.length} projects');
      return projectNames;
    } catch (e) {
      print('❌ REPO: Error fetching project list: $e');
      return [];
    }
  }

  /// Delete project
  Future<bool> deleteProject(String projectName) async {
    try {
      print('📂 REPO: Deleting project from database: $projectName');
      
      final projectEntity = await _databaseService.getProjectByName(projectName);
      if (projectEntity == null) {
        print('📂 REPO: Project not found');
        return false;
      }

      final rowsDeleted = await _databaseService.deleteProject(projectEntity.id!);
      final success = rowsDeleted > 0;
      
      print(success ? '✅ REPO: Project deleted successfully' : '❌ REPO: Failed to delete project');
      return success;
    } catch (e) {
      print('❌ REPO: Error deleting project: $e');
      return false;
    }
  }

  /// Check if project exists
  Future<bool> projectExists(String projectName) async {
    try {
      final project = await _databaseService.getProjectByName(projectName);
      return project != null;
    } catch (e) {
      print('❌ REPO: Error checking project existence: $e');
      return false;
    }
  }

  /// Get project details with additional metadata
  Future<ProjectData?> getProjectDetails(String projectName) async {
    try {
      final projectEntity = await _databaseService.getProjectByName(projectName);
      if (projectEntity == null) return null;

      final tapEventEntities = await _databaseService.getTapEventsByProject(projectEntity.id!);
      final tapEvents = tapEventEntities
          .map((entity) => _entityToTapEvent(entity))
          .toList();

      return _entityToProjectData(projectEntity, tapEvents.isEmpty ? null : tapEvents);
    } catch (e) {
      print('❌ REPO: Error getting project details: $e');
      return null;
    }
  }

  /// Search projects by name or description
  Future<List<String>> searchProjects(String query) async {
    try {
      print('📂 REPO: Searching projects with query: $query');
      
      final projects = await _databaseService.searchProjects(query);
      final projectNames = projects.map((project) => project.name).toList();
      
      print('✅ REPO: Found ${projectNames.length} projects matching query');
      return projectNames;
    } catch (e) {
      print('❌ REPO: Error searching projects: $e');
      return [];
    }
  }

  /// Get favorite projects
  Future<List<String>> getFavoriteProjects() async {
    try {
      print('📂 REPO: Fetching favorite projects');
      
      final projects = await _databaseService.getFavoriteProjects();
      final projectNames = projects.map((project) => project.name).toList();
      
      print('✅ REPO: Found ${projectNames.length} favorite projects');
      return projectNames;
    } catch (e) {
      print('❌ REPO: Error fetching favorite projects: $e');
      return [];
    }
  }

  /// Mark project as favorite
  Future<bool> toggleProjectFavorite(String projectName) async {
    try {
      print('📂 REPO: Toggling favorite status for: $projectName');
      
      final projectEntity = await _databaseService.getProjectByName(projectName);
      if (projectEntity == null) {
        print('📂 REPO: Project not found');
        return false;
      }

      final updatedProject = ProjectEntity(
        id: projectEntity.id,
        name: projectEntity.name,
        patternJson: projectEntity.patternJson,
        bpm: projectEntity.bpm,
        steps: projectEntity.steps,
        createdAt: projectEntity.createdAt,
        modifiedAt: DateTime.now(),
        description: projectEntity.description,
        isFavorite: !projectEntity.isFavorite,
      );

      final rowsUpdated = await _databaseService.updateProject(updatedProject);
      final success = rowsUpdated > 0;
      
      print(success ? '✅ REPO: Favorite status toggled successfully' : '❌ REPO: Failed to toggle favorite');
      return success;
    } catch (e) {
      print('❌ REPO: Error toggling favorite: $e');
      return false;
    }
  }

  // --- MIGRATION METHODS ---

  /// Migrate from file-based storage to database (one-time operation)
  Future<bool> migrateFromFileStorage() async {
    try {
      print('🔄 REPO: Starting migration from file storage to database');
      
      // Get all projects from file storage
      final fileProjectNames = await _fileService.getProjectList();
      print('📂 REPO: Found ${fileProjectNames.length} projects in file storage');

      if (fileProjectNames.isEmpty) {
        print('📂 REPO: No projects to migrate');
        return true;
      }

      int migratedCount = 0;
      for (final projectName in fileProjectNames) {
        try {
          // Check if already exists in database
          final existsInDb = await projectExists(projectName);
          if (existsInDb) {
            print('📂 REPO: Project $projectName already exists in database, skipping');
            continue;
          }

          // Load from file storage
          final projectData = await _fileService.loadProject(projectName);
          if (projectData == null) {
            print('❌ REPO: Failed to load project $projectName from file storage');
            continue;
          }

          // Save to database
          final success = await saveProject(projectData);
          if (success) {
            migratedCount++;
            print('✅ REPO: Migrated project: $projectName');
          } else {
            print('❌ REPO: Failed to migrate project: $projectName');
          }
        } catch (e) {
          print('❌ REPO: Error migrating project $projectName: $e');
        }
      }

      print('✅ REPO: Migration completed. Migrated $migratedCount/${fileProjectNames.length} projects');
      return true;
    } catch (e) {
      print('❌ REPO: Migration failed: $e');
      return false;
    }
  }

  /// Create sample projects in database
  Future<bool> createSampleProjects() async {
    try {
      print('📂 REPO: Creating sample projects');
      
      // Create basic sample project
      final sampleProject = _fileService.createSampleProject('Sample Beat');
      await saveProject(sampleProject);

      // Create AI sample project  
      final aiSampleProject = _fileService.createAISampleProject('AI Detection Sample');
      await saveProject(aiSampleProject);

      print('✅ REPO: Sample projects created successfully');
      return true;
    } catch (e) {
      print('❌ REPO: Error creating sample projects: $e');
      return false;
    }
  }

  // --- UTILITY METHODS ---

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    return await _databaseService.getDatabaseStats();
  }

  /// Clear all data (for testing/reset)
  Future<bool> clearAllData() async {
    try {
      await _databaseService.clearAllData();
      print('✅ REPO: All data cleared');
      return true;
    } catch (e) {
      print('❌ REPO: Error clearing data: $e');
      return false;
    }
  }

  /// Close repository connections
  Future<void> close() async {
    await _databaseService.close();
  }
}
