import 'dart:async';
import 'dart:io' show Platform;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// Database entity for tap events - equivalent to Room @Entity
class TapEventEntity {
  final int? id;
  final int projectId;
  final double time;
  final String label;
  final DateTime createdAt;

  TapEventEntity({
    this.id,
    required this.projectId,
    required this.time,
    required this.label,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'time': time,
      'label': label,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TapEventEntity.fromMap(Map<String, dynamic> map) {
    return TapEventEntity(
      id: map['id'] as int?,
      projectId: map['project_id'] as int,
      time: (map['time'] as num).toDouble(),
      label: map['label'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

/// Database entity for projects - equivalent to Room @Entity
class ProjectEntity {
  final int? id;
  final String name;
  final String patternJson; // Store grid pattern as JSON
  final double bpm;
  final int steps;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String? description;
  final bool isFavorite;

  ProjectEntity({
    this.id,
    required this.name,
    required this.patternJson,
    required this.bpm,
    required this.steps,
    required this.createdAt,
    required this.modifiedAt,
    this.description,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'pattern_json': patternJson,
      'bpm': bpm,
      'steps': steps,
      'created_at': createdAt.millisecondsSinceEpoch,
      'modified_at': modifiedAt.millisecondsSinceEpoch,
      'description': description,
      'is_favorite': isFavorite ? 1 : 0,
    };
  }

  factory ProjectEntity.fromMap(Map<String, dynamic> map) {
    return ProjectEntity(
      id: map['id'] as int?,
      name: map['name'] as String,
      patternJson: map['pattern_json'] as String,
      bpm: (map['bpm'] as num).toDouble(),
      steps: map['steps'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(map['modified_at'] as int),
      description: map['description'] as String?,
      isFavorite: (map['is_favorite'] as int) == 1,
    );
  }
}

/// Complete project data with tap events
class ProjectWithTapEvents {
  final ProjectEntity project;
  final List<TapEventEntity> tapEvents;

  ProjectWithTapEvents({
    required this.project,
    required this.tapEvents,
  });
}

/// Database service - equivalent to Room Database
class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;

  // Singleton pattern like Room
  DatabaseService._();
  
  static DatabaseService getInstance() {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  // Database version for migrations
  static const int _databaseVersion = 1;
  static const String _databaseName = 'tapcompose.db';

  // Table names
  static const String _projectsTable = 'projects';
  static const String _tapEventsTable = 'tap_events';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database - equivalent to Room database setup
  Future<Database> _initDatabase() async {
    // Initialize sqflite for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // For desktop platforms, initialize sqflite_ffi
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    
    print('📊 DB: Initializing database at: $path');

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
      onOpen: (db) => print('📊 DB: Database opened successfully'),
    );
  }

  /// Create database tables - equivalent to Room @Database entities
  Future<void> _createDatabase(Database db, int version) async {
    print('📊 DB: Creating database tables...');

    // Create projects table
    await db.execute('''
      CREATE TABLE $_projectsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        pattern_json TEXT NOT NULL,
        bpm REAL NOT NULL,
        steps INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        modified_at INTEGER NOT NULL,
        description TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create tap_events table with foreign key
    await db.execute('''
      CREATE TABLE $_tapEventsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        time REAL NOT NULL,
        label TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (project_id) REFERENCES $_projectsTable (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_projects_name ON $_projectsTable (name)');
    await db.execute('CREATE INDEX idx_projects_modified ON $_projectsTable (modified_at)');
    await db.execute('CREATE INDEX idx_tap_events_project ON $_tapEventsTable (project_id)');
    await db.execute('CREATE INDEX idx_tap_events_time ON $_tapEventsTable (time)');

    print('✅ DB: Database tables created successfully');
  }

  /// Handle database upgrades - equivalent to Room migrations
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    print('📊 DB: Upgrading database from $oldVersion to $newVersion');
    
    // Add migration logic here when needed
    // Example:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE $_projectsTable ADD COLUMN new_field TEXT');
    // }
  }

  // --- PROJECT DAO METHODS - equivalent to Room @Dao ---

  /// Insert a project - equivalent to Room @Insert
  Future<int> insertProject(ProjectEntity project) async {
    try {
      final db = await database;
      print('📊 DB: Inserting project: ${project.name}');
      
      final id = await db.insert(
        _projectsTable,
        project.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('✅ DB: Project inserted with ID: $id');
      return id;
    } catch (e) {
      print('❌ DB: Error inserting project: $e');
      rethrow;
    }
  }

  /// Update a project - equivalent to Room @Update
  Future<int> updateProject(ProjectEntity project) async {
    try {
      final db = await database;
      print('📊 DB: Updating project ID: ${project.id}');
      
      final rowsAffected = await db.update(
        _projectsTable,
        project.toMap(),
        where: 'id = ?',
        whereArgs: [project.id],
      );
      
      print('✅ DB: Updated $rowsAffected project(s)');
      return rowsAffected;
    } catch (e) {
      print('❌ DB: Error updating project: $e');
      rethrow;
    }
  }

  /// Delete a project - equivalent to Room @Delete
  Future<int> deleteProject(int projectId) async {
    try {
      final db = await database;
      print('📊 DB: Deleting project ID: $projectId');
      
      // Delete associated tap events first (cascade should handle this, but being explicit)
      await deleteTapEventsByProject(projectId);
      
      final rowsAffected = await db.delete(
        _projectsTable,
        where: 'id = ?',
        whereArgs: [projectId],
      );
      
      print('✅ DB: Deleted $rowsAffected project(s)');
      return rowsAffected;
    } catch (e) {
      print('❌ DB: Error deleting project: $e');
      rethrow;
    }
  }

  /// Get all projects - equivalent to Room @Query
  Future<List<ProjectEntity>> getAllProjects() async {
    try {
      final db = await database;
      print('📊 DB: Fetching all projects');
      
      final List<Map<String, dynamic>> maps = await db.query(
        _projectsTable,
        orderBy: 'modified_at DESC',
      );

      final projects = List.generate(maps.length, (i) => ProjectEntity.fromMap(maps[i]));
      print('✅ DB: Found ${projects.length} projects');
      
      return projects;
    } catch (e) {
      print('❌ DB: Error fetching projects: $e');
      rethrow;
    }
  }

  /// Get project by ID - equivalent to Room @Query
  Future<ProjectEntity?> getProjectById(int id) async {
    try {
      final db = await database;
      print('📊 DB: Fetching project ID: $id');
      
      final List<Map<String, dynamic>> maps = await db.query(
        _projectsTable,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        final project = ProjectEntity.fromMap(maps.first);
        print('✅ DB: Found project: ${project.name}');
        return project;
      }
      
      print('📊 DB: Project not found');
      return null;
    } catch (e) {
      print('❌ DB: Error fetching project: $e');
      rethrow;
    }
  }

  /// Get project by name - equivalent to Room @Query
  Future<ProjectEntity?> getProjectByName(String name) async {
    try {
      final db = await database;
      print('📊 DB: Fetching project by name: $name');
      
      final List<Map<String, dynamic>> maps = await db.query(
        _projectsTable,
        where: 'name = ?',
        whereArgs: [name],
      );

      if (maps.isNotEmpty) {
        final project = ProjectEntity.fromMap(maps.first);
        print('✅ DB: Found project: ${project.name}');
        return project;
      }
      
      print('📊 DB: Project not found');
      return null;
    } catch (e) {
      print('❌ DB: Error fetching project: $e');
      rethrow;
    }
  }

  /// Search projects - equivalent to Room @Query
  Future<List<ProjectEntity>> searchProjects(String query) async {
    try {
      final db = await database;
      print('📊 DB: Searching projects with query: $query');
      
      final List<Map<String, dynamic>> maps = await db.query(
        _projectsTable,
        where: 'name LIKE ? OR description LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'modified_at DESC',
      );

      final projects = List.generate(maps.length, (i) => ProjectEntity.fromMap(maps[i]));
      print('✅ DB: Found ${projects.length} projects matching query');
      
      return projects;
    } catch (e) {
      print('❌ DB: Error searching projects: $e');
      rethrow;
    }
  }

  /// Get favorite projects - equivalent to Room @Query
  Future<List<ProjectEntity>> getFavoriteProjects() async {
    try {
      final db = await database;
      print('📊 DB: Fetching favorite projects');
      
      final List<Map<String, dynamic>> maps = await db.query(
        _projectsTable,
        where: 'is_favorite = ?',
        whereArgs: [1],
        orderBy: 'modified_at DESC',
      );

      final projects = List.generate(maps.length, (i) => ProjectEntity.fromMap(maps[i]));
      print('✅ DB: Found ${projects.length} favorite projects');
      
      return projects;
    } catch (e) {
      print('❌ DB: Error fetching favorite projects: $e');
      rethrow;
    }
  }

  // --- TAP EVENT DAO METHODS - equivalent to Room @Dao ---

  /// Insert tap events for a project
  Future<List<int>> insertTapEvents(List<TapEventEntity> tapEvents) async {
    try {
      final db = await database;
      print('📊 DB: Inserting ${tapEvents.length} tap events');
      
      final ids = <int>[];
      await db.transaction((txn) async {
        for (final tapEvent in tapEvents) {
          final id = await txn.insert(_tapEventsTable, tapEvent.toMap());
          ids.add(id);
        }
      });
      
      print('✅ DB: Inserted ${ids.length} tap events');
      return ids;
    } catch (e) {
      print('❌ DB: Error inserting tap events: $e');
      rethrow;
    }
  }

  /// Get tap events for a project
  Future<List<TapEventEntity>> getTapEventsByProject(int projectId) async {
    try {
      final db = await database;
      print('📊 DB: Fetching tap events for project: $projectId');
      
      final List<Map<String, dynamic>> maps = await db.query(
        _tapEventsTable,
        where: 'project_id = ?',
        whereArgs: [projectId],
        orderBy: 'time ASC',
      );

      final tapEvents = List.generate(maps.length, (i) => TapEventEntity.fromMap(maps[i]));
      print('✅ DB: Found ${tapEvents.length} tap events');
      
      return tapEvents;
    } catch (e) {
      print('❌ DB: Error fetching tap events: $e');
      rethrow;
    }
  }

  /// Delete tap events for a project
  Future<int> deleteTapEventsByProject(int projectId) async {
    try {
      final db = await database;
      print('📊 DB: Deleting tap events for project: $projectId');
      
      final rowsAffected = await db.delete(
        _tapEventsTable,
        where: 'project_id = ?',
        whereArgs: [projectId],
      );
      
      print('✅ DB: Deleted $rowsAffected tap events');
      return rowsAffected;
    } catch (e) {
      print('❌ DB: Error deleting tap events: $e');
      rethrow;
    }
  }

  // --- HIGH-LEVEL OPERATIONS ---

  /// Get project with tap events - equivalent to Room relation queries
  Future<ProjectWithTapEvents?> getProjectWithTapEvents(int projectId) async {
    try {
      print('📊 DB: Fetching project with tap events: $projectId');
      
      final project = await getProjectById(projectId);
      if (project == null) return null;
      
      final tapEvents = await getTapEventsByProject(projectId);
      
      print('✅ DB: Found project with ${tapEvents.length} tap events');
      return ProjectWithTapEvents(project: project, tapEvents: tapEvents);
    } catch (e) {
      print('❌ DB: Error fetching project with tap events: $e');
      rethrow;
    }
  }

  /// Save complete project with tap events in transaction
  Future<int> saveProjectWithTapEvents(ProjectEntity project, List<TapEventEntity> tapEvents) async {
    try {
      final db = await database;
      print('📊 DB: Saving project with ${tapEvents.length} tap events');
      
      late int projectId;
      await db.transaction((txn) async {
        // Insert or update project
        if (project.id == null) {
          projectId = await txn.insert(_projectsTable, project.toMap());
          print('📊 DB: Created new project with ID: $projectId');
        } else {
          projectId = project.id!;
          await txn.update(
            _projectsTable,
            project.toMap(),
            where: 'id = ?',
            whereArgs: [projectId],
          );
          
          // Delete existing tap events
          await txn.delete(
            _tapEventsTable,
            where: 'project_id = ?',
            whereArgs: [projectId],
          );
        }
        
        // Insert tap events with correct project ID
        for (final tapEvent in tapEvents) {
          await txn.insert(
            _tapEventsTable,
            tapEvent.toMap()..['project_id'] = projectId,
          );
        }
      });
      
      print('✅ DB: Successfully saved project with tap events');
      return projectId;
    } catch (e) {
      print('❌ DB: Error saving project with tap events: $e');
      rethrow;
    }
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('📊 DB: Database closed');
    }
  }

  // --- UTILITY METHODS ---

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    try {
      final db = await database;
      
      final projectCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_projectsTable'),
      ) ?? 0;
      
      final tapEventCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_tapEventsTable'),
      ) ?? 0;
      
      return {
        'projects': projectCount,
        'tapEvents': tapEventCount,
      };
    } catch (e) {
      print('❌ DB: Error getting database stats: $e');
      return {'projects': 0, 'tapEvents': 0};
    }
  }

  /// Clear all data (for testing/reset)
  Future<void> clearAllData() async {
    try {
      final db = await database;
      print('📊 DB: Clearing all data...');
      
      await db.transaction((txn) async {
        await txn.delete(_tapEventsTable);
        await txn.delete(_projectsTable);
      });
      
      print('✅ DB: All data cleared');
    } catch (e) {
      print('❌ DB: Error clearing data: $e');
      rethrow;
    }
  }
}
