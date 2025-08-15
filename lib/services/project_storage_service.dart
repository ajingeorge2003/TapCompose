import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Represents a single tap event with timing and instrument info
class TapEvent {
  final double time; // Time in seconds
  final String label; // Instrument label (kick, snare, hihat)

  TapEvent({
    required this.time,
    required this.label,
  });

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'label': label,
    };
  }

  factory TapEvent.fromJson(Map<String, dynamic> json) {
    return TapEvent(
      time: (json['time'] as num).toDouble(),
      label: json['label'] as String,
    );
  }
}

class ProjectData {
  final String name;
  final List<List<bool>> pattern;
  final double bpm;
  final int steps;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final List<TapEvent>? tapEvents; // Optional: original tap data from AI

  ProjectData({
    required this.name,
    required this.pattern,
    required this.bpm,
    required this.steps,
    required this.createdAt,
    required this.modifiedAt,
    this.tapEvents,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'pattern': pattern,
      'bpm': bpm,
      'steps': steps,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'modifiedAt': modifiedAt.millisecondsSinceEpoch,
      'tapEvents': tapEvents?.map((e) => e.toJson()).toList(),
    };
  }

  factory ProjectData.fromJson(Map<String, dynamic> json) {
    final tapEventsData = json['tapEvents'] as List<dynamic>?;
    return ProjectData(
      name: json['name'] ?? 'Untitled',
      pattern: (json['pattern'] as List<dynamic>)
          .map((row) => (row as List<dynamic>).cast<bool>())
          .toList(),
      bpm: (json['bpm'] as num).toDouble(),
      steps: json['steps'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(json['modifiedAt'] ?? 0),
      tapEvents: tapEventsData?.map((e) => TapEvent.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  ProjectData copyWith({
    String? name,
    List<List<bool>>? pattern,
    double? bpm,
    int? steps,
    DateTime? modifiedAt,
    List<TapEvent>? tapEvents,
  }) {
    return ProjectData(
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      bpm: bpm ?? this.bpm,
      steps: steps ?? this.steps,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? DateTime.now(),
      tapEvents: tapEvents ?? this.tapEvents,
    );
  }
}

class ProjectStorageService {
  static const String _projectsDir = 'tapcompose_projects';
  static const String _fileExtension = '.tcp'; // TapCompose Project
  
  // Instrument mapping
  static const Map<String, int> instrumentIndices = {
    'kick': 0,
    'snare': 1,
    'hihat': 2,
  };

  /// Convert tap events to grid pattern
  static List<List<bool>> tapEventsToGrid({
    required List<TapEvent> tapEvents,
    required double bpm,
    required int steps,
  }) {
    print('🎯 CONVERT: Converting tap events to grid pattern');
    print('🎯 CONVERT: Input - ${tapEvents.length} events, BPM: $bpm, Steps: $steps');
    
    // Initialize grid with all false
    final grid = List.generate(3, (index) => List.filled(steps, false));
    
    if (tapEvents.isEmpty) {
      print('🎯 CONVERT: No tap events to convert');
      return grid;
    }
    
    // Calculate time per step - simpler approach
    // For 8 steps at 120 BPM = 2 seconds total (4 beats at 0.5s per beat)
    // Each step = 0.25 seconds
    final beatsPerSecond = bpm / 60.0;
    final beatsInPattern = steps / 4.0; // Assuming 16th notes (4 steps per beat)
    final patternDuration = beatsInPattern / beatsPerSecond;
    final timePerStep = patternDuration / steps;
    
    print('🎯 CONVERT: Pattern duration: ${patternDuration}s');
    print('🎯 CONVERT: Time per step: ${timePerStep}s');
    
    for (final tapEvent in tapEvents) {
      final instrumentIndex = instrumentIndices[tapEvent.label];
      if (instrumentIndex == null) {
        print('🎯 CONVERT: Unknown instrument: ${tapEvent.label}');
        continue;
      }
      
      // Calculate which step this tap should trigger
      // Use modulo to wrap around for patterns longer than the loop
      final stepIndex = (tapEvent.time / timePerStep).round() % steps;
      
      print('🎯 CONVERT: ${tapEvent.label} at ${tapEvent.time}s -> step $stepIndex (timePerStep: $timePerStep)');
      grid[instrumentIndex][stepIndex] = true;
    }
    
    print('🎯 CONVERT: Final grid pattern:');
    for (int i = 0; i < grid.length; i++) {
      print('🎯 CONVERT: Instrument $i: ${grid[i]}');
    }
    
    return grid;
  }

  /// Create project from tap events (AI detection results)
  static ProjectData createProjectFromTapEvents({
    required String name,
    required List<TapEvent> tapEvents,
    double bpm = 120.0,
    int steps = 8,
  }) {
    print('🎯 CREATE: Creating project from tap events');
    print('🎯 CREATE: Name: $name, Events: ${tapEvents.length}');
    
    final pattern = tapEventsToGrid(
      tapEvents: tapEvents,
      bpm: bpm,
      steps: steps,
    );
    
    return ProjectData(
      name: name,
      pattern: pattern,
      bpm: bpm,
      steps: steps,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      tapEvents: tapEvents, // Keep original tap data
    );
  }

  /// Get the projects directory
  Future<Directory> _getProjectsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    print('📱 App documents directory: ${appDir.path}');
    
    final projectsDir = Directory('${appDir.path}/$_projectsDir');
    print('📁 Target projects directory: ${projectsDir.path}');
    
    if (!await projectsDir.exists()) {
      print('📁 Creating projects directory...');
      await projectsDir.create(recursive: true);
      print('✅ Projects directory created');
    } else {
      print('📁 Projects directory already exists');
    }
    
    return projectsDir;
  }

  /// Save a project to storage
  Future<bool> saveProject(ProjectData project) async {
    try {
      print('🔄 Starting save process for project: ${project.name}');
      print('📊 Project data - BPM: ${project.bpm}, Steps: ${project.steps}');
      print('🎵 Pattern data: ${project.pattern}');
      
      final projectsDir = await _getProjectsDirectory();
      print('📁 Projects directory: ${projectsDir.path}');
      
      final fileName = _sanitizeFileName(project.name);
      print('📝 Sanitized filename: $fileName');
      
      final file = File('${projectsDir.path}/$fileName$_fileExtension');
      print('💾 Full file path: ${file.path}');
      
      final jsonData = project.toJson();
      print('🗂️ JSON data: $jsonData');
      
      final jsonString = jsonEncode(jsonData);
      print('📄 JSON string length: ${jsonString.length}');
      
      await file.writeAsString(jsonString);
      
      // Verify the file was actually created and has content
      final exists = await file.exists();
      final fileSize = exists ? await file.length() : 0;
      print('✅ Project saved successfully!');
      print('📁 File exists: $exists, Size: $fileSize bytes');
      print('🌍 Full path: ${file.absolute.path}');
      
      return true;
    } catch (e) {
      print('❌ Error saving project: $e');
      print('🔍 Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Load a project from storage
  Future<ProjectData?> loadProject(String projectName) async {
    try {
      print('🔄 Starting load process for project: $projectName');
      
      final projectsDir = await _getProjectsDirectory();
      print('📁 Projects directory: ${projectsDir.path}');
      
      final fileName = _sanitizeFileName(projectName);
      print('📝 Sanitized filename: $fileName');
      
      final file = File('${projectsDir.path}/$fileName$_fileExtension');
      print('💾 Full file path: ${file.path}');
      
      final exists = await file.exists();
      print('📄 File exists: $exists');
      
      if (!exists) {
        print('❌ Project file not found: ${file.path}');
        return null;
      }
      
      final jsonString = await file.readAsString();
      print('📄 File content length: ${jsonString.length}');
      print('🗂️ File content: $jsonString');
      
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      print('📊 Parsed JSON data: $jsonData');
      
      final project = ProjectData.fromJson(jsonData);
      print('✅ Project loaded successfully: ${project.name}');
      print('📊 Loaded - BPM: ${project.bpm}, Steps: ${project.steps}');
      print('🎵 Loaded pattern: ${project.pattern}');
      
      return project;
    } catch (e) {
      print('❌ Error loading project: $e');
      print('🔍 Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Get list of all saved projects
  Future<List<String>> getProjectList() async {
    try {
      final projectsDir = await _getProjectsDirectory();
      final files = await projectsDir.list().toList();
      
      final projectNames = files
          .where((file) => file.path.endsWith(_fileExtension))
          .map((file) => _getFileNameWithoutExtension(file.path))
          .toList();
      
      projectNames.sort();
      return projectNames;
    } catch (e) {
      print('Error getting project list: $e');
      return [];
    }
  }

  /// Delete a project
  Future<bool> deleteProject(String projectName) async {
    try {
      final projectsDir = await _getProjectsDirectory();
      final fileName = _sanitizeFileName(projectName);
      final file = File('${projectsDir.path}/$fileName$_fileExtension');
      
      if (await file.exists()) {
        await file.delete();
        print('Project deleted: ${file.path}');
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting project: $e');
      return false;
    }
  }

  /// Check if a project exists
  Future<bool> projectExists(String projectName) async {
    try {
      final projectsDir = await _getProjectsDirectory();
      final fileName = _sanitizeFileName(projectName);
      final file = File('${projectsDir.path}/$fileName$_fileExtension');
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Sanitize filename to remove invalid characters
  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(' ', '_')
        .toLowerCase();
  }

  /// Get filename without extension from full path
  String _getFileNameWithoutExtension(String fullPath) {
    final fileName = fullPath.split('/').last.split('\\').last;
    return fileName.replaceAll(_fileExtension, '').replaceAll('_', ' ');
  }

  /// Create a sample project for demonstration using tap events
  ProjectData createSampleProject(String name) {
    print('🎯 SAMPLE: Creating sample project with tap events');
    
    // Create simple tap events for an 8-step pattern at 120 BPM
    // Each step = 0.25 seconds (quarter notes at 120 BPM)
    final sampleTapEvents = [
      TapEvent(time: 0.0, label: 'kick'),    // Step 1
      TapEvent(time: 0.25, label: 'hihat'),  // Step 2
      TapEvent(time: 0.5, label: 'snare'),   // Step 3
      TapEvent(time: 0.75, label: 'hihat'),  // Step 4
      TapEvent(time: 1.0, label: 'kick'),    // Step 5
      TapEvent(time: 1.25, label: 'hihat'),  // Step 6
      TapEvent(time: 1.5, label: 'snare'),   // Step 7
      TapEvent(time: 1.75, label: 'hihat'),  // Step 8
    ];

    print('🎯 SAMPLE: Created ${sampleTapEvents.length} tap events');
    for (final event in sampleTapEvents) {
      print('🎯 SAMPLE: ${event.time}s -> ${event.label}');
    }

    return ProjectStorageService.createProjectFromTapEvents(
      name: name,
      tapEvents: sampleTapEvents,
      bpm: 120.0,
      steps: 8,
    );
  }

  /// Create a sample project using the AI model detection data you provided
  ProjectData createAISampleProject(String name) {
    print('🤖 AI SAMPLE: Creating project from AI detection data');
    
    // Your example AI detection data
    final aiDetectionEvents = [
      TapEvent(time: 0.560, label: 'kick'),
      TapEvent(time: 1.147, label: 'snare'),
      TapEvent(time: 1.726, label: 'kick'),
      TapEvent(time: 2.020, label: 'kick'),
      TapEvent(time: 2.304, label: 'snare'),
      TapEvent(time: 2.901, label: 'kick'),
      TapEvent(time: 3.507, label: 'snare'),
      TapEvent(time: 4.085, label: 'kick'),
      TapEvent(time: 4.361, label: 'kick'),
      TapEvent(time: 4.664, label: 'snare'),
      TapEvent(time: 5.307, label: 'kick'),
      TapEvent(time: 5.913, label: 'snare'),
    ];

    print('🤖 AI SAMPLE: Created ${aiDetectionEvents.length} AI detection events');
    for (final event in aiDetectionEvents) {
      print('🤖 AI SAMPLE: ${event.time}s -> ${event.label}');
    }

    return ProjectStorageService.createProjectFromTapEvents(
      name: name,
      tapEvents: aiDetectionEvents,
      bpm: 120.0, // You can adjust this based on detected tempo
      steps: 16,   // More steps for complex patterns
    );
  }

  /// Get the full path where projects are stored (for debugging)
  Future<String> getStoragePath() async {
    final projectsDir = await _getProjectsDirectory();
    return projectsDir.path;
  }

  /// List all files in the projects directory (for debugging)
  Future<List<String>> getAllFilesInDirectory() async {
    try {
      final projectsDir = await _getProjectsDirectory();
      final files = await projectsDir.list().toList();
      
      return files.map((file) => file.path).toList();
    } catch (e) {
      print('Error listing files: $e');
      return [];
    }
  }
}
