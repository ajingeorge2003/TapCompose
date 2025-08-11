import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/instrument_data.dart';
import '../services/audio_service.dart';
import '../services/project_storage_service.dart';
import '../services/project_repository.dart';

class AdvancedMidiArrangerScreen extends StatefulWidget {
  const AdvancedMidiArrangerScreen({super.key});

  @override
  State<AdvancedMidiArrangerScreen> createState() =>
      _AdvancedMidiArrangerScreenState();
}

class _AdvancedMidiArrangerScreenState extends State<AdvancedMidiArrangerScreen>
    with TickerProviderStateMixin {
  // --- STATE MANAGEMENT ---
  double _bpm = 120.0;
  bool _isPlaying = false;
  int _currentStep = 0;
  int _selectedInstrument = -1;

  int _steps = 16;
  final List<int> _stepOptions = [8, 12, 16];

  late List<List<bool>> _gridState;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _playbackTimer;

  late TextEditingController _bpmController;
  final AudioService _audioService = AudioService();
  final ProjectStorageService _storageService = ProjectStorageService();
  final ProjectRepository _repository = ProjectRepository.getInstance();

  // **NEW**: Loading state for sound initialization
  bool _isLoading = true;
  bool _hasInitializedGrid = false; // Flag to prevent grid reset after load
  String? _currentProjectName; // Track current project for auto-save
  bool _isMetronomeEnabled = false; // Metronome state
  Timer? _metronomeTimer; // Separate timer for metronome

  final List<InstrumentData> _instruments = [
    InstrumentData(
      name: "KICK",
      iconAsset: "assets/icons/kick_icon.png",
      color: const Color(0xFFFF5252),
      audioAsset: 'assets/audio/kick.wav',
    ),
    InstrumentData(
      name: "SNARE",
      iconAsset: "assets/icons/snare_icon.png",
      color: const Color(0xFF4CAF50),
      audioAsset: 'assets/audio/snare.wav',
    ),
    InstrumentData(
      name: "HI-HAT",
      iconAsset: "assets/icons/hihat_icon.png",
      color: const Color(0xFF2196F3),
      audioAsset: 'assets/audio/hihat.wav',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only initialize grid if it hasn't been loaded from a project
    if (_hasInitializedGrid) return;

    final initialPattern =
        ModalRoute.of(context)?.settings.arguments as List<List<bool>>?;

    if (initialPattern != null &&
        initialPattern.length == _instruments.length) {
      _gridState = initialPattern;
      if (initialPattern.isNotEmpty) {
        _steps = initialPattern[0].length;
      }
    } else {
      _gridState = List.generate(
        _instruments.length,
        (index) => List.filled(_steps, false),
      );
    }
    
    _hasInitializedGrid = true;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Set orientation first
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _bpmController = TextEditingController(text: _bpm.toString());

    // Initialize the audio service and load sounds
    await _audioService.initialize();
    
    // Re-enable sound preloading with better error handling
    print('DEBUG: Starting sound preloading...');
    
    // Now that memory corruption is fixed, load all sounds systematically
    print('DEBUG: Loading all sounds with memory corruption protection...');
    try {
      for (int i = 0; i < _instruments.length; i++) {
        final instrument = _instruments[i];
        print('DEBUG: Loading sound $i: ${instrument.audioAsset}');
        await _audioService.loadSound(instrument.audioAsset);
        print('DEBUG: Successfully loaded: ${instrument.audioAsset}');
        
        // Small delay between loads for stability
        await Future.delayed(Duration(milliseconds: 100));
      }
      print('DEBUG: All sounds loaded successfully!');
    } catch (e) {
      print('❌ ERROR: Failed to load sounds: $e');
    }

    // Initialize database and perform migration if needed
    await _initializeDatabase();
    
    print('DEBUG: Sound loading completed. App ready for playback.');
    
    // TODO: Later we'll add back the full sound loading
    // for (int i = 0; i < _instruments.length; i++) {

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Sounds are loaded, update UI
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Initialize database and perform migration from file storage
  Future<void> _initializeDatabase() async {
    try {
      print('📊 DB INIT: Initializing database system');
      
      // Perform one-time migration from file storage if needed
      final stats = await _repository.getDatabaseStats();
      if (stats['projects'] == 0) {
        print('📊 DB INIT: Database is empty, checking for file-based projects to migrate');
        await _repository.migrateFromFileStorage();
        
        // If still empty, create sample projects
        final updatedStats = await _repository.getDatabaseStats();
        if (updatedStats['projects'] == 0) {
          print('📊 DB INIT: Creating sample projects');
          await _repository.createSampleProjects();
        }
      }
      
      final finalStats = await _repository.getDatabaseStats();
      print('📊 DB INIT: Database ready - ${finalStats['projects']} projects, ${finalStats['tapEvents']} tap events');
    } catch (e) {
      print('❌ DB INIT: Database initialization error: $e');
    }
  }

  // --- PLAYBACK ENGINE LOGIC ---

  void _startPlayback() {
    if (_bpm <= 0) return;

    // Calculate step duration in microseconds for higher precision
    final int stepDurationMs = (60000 / _bpm / 4)
        .round(); // Divide by 4 for 16th notes

    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(Duration(milliseconds: stepDurationMs), (
      timer,
    ) {
      if (!mounted) return;

      // Collect sounds to play in this step
      final List<String> soundsToPlay = [];
      for (int i = 0; i < _instruments.length; i++) {
        if (_gridState[i][_currentStep]) {
          soundsToPlay.add(_instruments[i].audioAsset);
        }
      }

      // Play all sounds simultaneously for tight timing
      if (soundsToPlay.isNotEmpty) {
        _audioService.playMultiple(soundsToPlay);
      }

      setState(() {
        _currentStep = (_currentStep + 1) % _steps;
      });
    });
  }

  void _stopPlayback() {
    _playbackTimer?.cancel();
    _metronomeTimer?.cancel();
    // Stop any remaining audio for immediate response
    _audioService.stopAllSounds();
    setState(() {
      _isPlaying = false;
      _currentStep = 0;
    });
  }

  void _toggleMetronome() {
    setState(() {
      _isMetronomeEnabled = !_isMetronomeEnabled;
    });

    if (_isMetronomeEnabled) {
      _startMetronome();
    } else {
      _stopMetronome();
    }

    print('🎵 METRONOME: ${_isMetronomeEnabled ? "Enabled" : "Disabled"}');
  }

  void _startMetronome() {
    if (!_isMetronomeEnabled) return;
    
    _metronomeTimer?.cancel();
    final interval = Duration(milliseconds: (15000 / _bpm).round()); // Quarter note intervals
    
    _metronomeTimer = Timer.periodic(interval, (timer) {
      // Play a click sound for metronome
      // Using hi-hat as metronome click (you could add a dedicated click sound)
      _audioService.playSound(_instruments[2].audioAsset); // Hi-hat as click
    });
    
    print('🎵 METRONOME: Started at ${_bpm} BPM');
  }

  void _stopMetronome() {
    _metronomeTimer?.cancel();
    print('🎵 METRONOME: Stopped');
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _startPlayback();
      } else {
        _stopPlayback();
      }
    });
  }

  void _onBpmChanged(String value) {
    final newBpm = double.tryParse(value);
    if (newBpm != null && newBpm > 0) {
      setState(() {
        _bpm = newBpm;
        if (_isPlaying) {
          _startPlayback();
        }
      });
    }
  }

  void _changeSteps(int? newStepCount) {
    if (newStepCount == null || _steps == newStepCount) return;
    
    setState(() {
      if (_isPlaying) _stopPlayback();
      
      // Preserve existing data when changing step count
      final oldGrid = _gridState;
      final oldSteps = _steps;
      
      _steps = newStepCount;
      _currentStep = 0;
      
      // Create new grid preserving existing data
      _gridState = List.generate(_instruments.length, (instrumentIndex) {
        final newRow = List.filled(_steps, false);
        
        // Copy over existing data up to the minimum of old/new step count
        if (instrumentIndex < oldGrid.length) {
          final oldRow = oldGrid[instrumentIndex];
          final copyCount = math.min(oldRow.length, _steps);
          for (int i = 0; i < copyCount; i++) {
            newRow[i] = oldRow[i];
          }
        }
        
        return newRow;
      });
      
      _hasInitializedGrid = true;
      
      print('🔄 STEPS: Changed from $oldSteps to $_steps steps, preserved existing data');
    });
  }

  void _resetGrid() {
    // Show confirmation dialog before resetting
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text(
          "Reset Grid",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Are you sure you want to clear all steps? This action cannot be undone.",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Color(0xFFBB86FC)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performGridReset();
            },
            child: const Text(
              "Reset",
              style: TextStyle(color: Color(0xFFFF5722)),
            ),
          ),
        ],
      ),
    );
  }

  void _performGridReset() {
    setState(() {
      if (_isPlaying) _stopPlayback();
      _gridState = List.generate(
        _instruments.length,
        (index) => List.filled(_steps, false),
      );
      _hasInitializedGrid = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Grid reset successfully"),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _playbackTimer?.cancel();
    _metronomeTimer?.cancel();
    _pulseController.dispose();
    _bpmController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // **NEW**: Show a loading indicator while sounds are being prepared.
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFBB86FC)),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF121212), Color(0xFF1E1E1E), Color(0xFF252525)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              if (_isPlaying) _buildGlowEffect(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _buildLeftPanel()),
                    const SizedBox(width: 16),
                    Expanded(flex: 7, child: _buildRightPanel()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildLeftPanel() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildTransportControls(),
          const SizedBox(height: 16),
          SizedBox(height: 180, child: _buildInstrumentList()),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Row(
      children: [
        Icon(Icons.graphic_eq, color: Color(0xFFBB86FC), size: 32),
        SizedBox(width: 8),
        Text(
          "TAPCOMPOSE",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTransportControls() {
    return Card(
      color: Colors.white.withOpacity(0.1),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 48,
              child: TextField(
                controller: _bpmController,
                onChanged: _onBpmChanged,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: "BPM",
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _togglePlay,
                    icon: Icon(
                      _isPlaying ? Icons.stop : Icons.play_arrow,
                      color: Colors.black,
                      size: 20,
                    ),
                    label: Text(
                      _isPlaying ? "STOP" : "PLAY",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPlaying
                          ? const Color(0xFFCF6679)
                          : const Color(0xFF03DAC6),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _toggleMetronome,
                  icon: Icon(
                    _isMetronomeEnabled 
                        ? Icons.volume_up 
                        : Icons.volume_off,
                    color: _isMetronomeEnabled 
                        ? const Color(0xFF03DAC6) 
                        : Colors.grey,
                  ),
                  iconSize: 28,
                  tooltip: _isMetronomeEnabled ? "Disable Metronome" : "Enable Metronome",
                  style: IconButton.styleFrom(
                    backgroundColor: _isMetronomeEnabled 
                        ? const Color(0xFF03DAC6).withOpacity(0.1)
                        : Colors.transparent,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _resetGrid,
                  icon: const Icon(
                    Icons.clear,
                    color: Colors.orange,
                  ),
                  iconSize: 28,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.orange.withOpacity(0.3),
                    side: BorderSide(color: Colors.orange.withOpacity(0.6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _steps,
              items: _stepOptions.map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text('$value Steps'),
                );
              }).toList(),
              onChanged: _changeSteps,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
              ),
              dropdownColor: const Color(0xFF2D2D2D),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstrumentList() {
    return Card(
      color: Colors.white.withOpacity(0.1),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Audio engine info
            Container(
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: const Color(0xFF03DAC6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.speed, color: Color(0xFF03DAC6), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    "Low-Latency Audio Engine",
                    style: TextStyle(
                      color: const Color(0xFF03DAC6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _instruments.length,
                itemBuilder: (context, index) {
                  final instrument = _instruments[index];
                  final isSelected = _selectedInstrument == index;
                  return Material(
                    color: isSelected
                        ? instrument.color.withOpacity(0.3)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(
                        color: isSelected
                            ? instrument.color.withOpacity(0.6)
                            : Colors.transparent,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedInstrument = index);
                        // Play sound preview when selecting instrument
                        _audioService.playSound(instrument.audioAsset);
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Row(
                          children: [
                            Image.asset(
                              instrument.iconAsset,
                              width: 28,
                              height: 28,
                              errorBuilder: (c, e, s) =>
                                  const Icon(Icons.music_note),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                instrument.name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: instrument.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    final double cellWidth = 48.0;
    final double cellMargin = 4.0;
    final double indicatorWidth = 40.0;
    final double totalGridWidth =
        (_steps * (cellWidth + cellMargin)) + indicatorWidth;

    return Card(
      color: Colors.white.withOpacity(0.1),
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalGridWidth,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: indicatorWidth),
                  child: _buildStepIndicators(),
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildGrid()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicators() {
    return Row(
      children: List.generate(_steps, (index) {
        final isCurrent = index == _currentStep && _isPlaying;
        return Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isCurrent
                ? const Color(0xFFBB86FC).withOpacity(0.3)
                : Colors.transparent,
            border: Border.all(
              color: isCurrent
                  ? const Color(0xFFBB86FC)
                  : Colors.white.withOpacity(0.1),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            "${index + 1}",
            style: TextStyle(
              color: isCurrent
                  ? const Color(0xFFBB86FC)
                  : Colors.white.withOpacity(0.6),
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGrid() {
    return ListView.builder(
      itemCount: _instruments.length,
      itemBuilder: (context, rowIndex) {
        final instrument = _instruments[rowIndex];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              _buildInstrumentIndicator(rowIndex),
              ...List.generate(_steps, (colIndex) {
                final isActive = _gridState[rowIndex][colIndex];
                final isCurrent = colIndex == _currentStep && _isPlaying;
                final isPulsing = isActive && isCurrent;

                Widget cell = Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? instrument.color
                        : isCurrent
                        ? instrument.color.withOpacity(0.2)
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isCurrent
                          ? instrument.color.withOpacity(0.8)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                );

                if (isPulsing) {
                  cell = ScaleTransition(scale: _pulseAnimation, child: cell);
                }

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _gridState[rowIndex][colIndex] =
                          !_gridState[rowIndex][colIndex];
                    });

                    print('🎵 STEP: Toggled step [$rowIndex][$colIndex] to ${_gridState[rowIndex][colIndex]}');

                    // Provide immediate audio feedback when toggling a step
                    if (_gridState[rowIndex][colIndex]) {
                      _audioService.playSound(instrument.audioAsset);
                    }
                  },
                  child: cell,
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstrumentIndicator(int instrumentIndex) {
    final bool isPlayingOnCurrentStep =
        _isPlaying && _gridState[instrumentIndex][_currentStep];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 40,
      height: 48,
      child: isPlayingOnCurrentStep
          ? Icon(Icons.volume_up, color: _instruments[instrumentIndex].color)
          : null,
    );
  }

  Widget _buildActionButtons() {
    return Card(
      color: Colors.white.withOpacity(0.1),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "PROJECT",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showSaveDialog(),
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text("SAVE"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showLoadDialog(),
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text("LOAD"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _createNewProject(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text("NEW PROJECT"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _createSampleProject(),
              icon: const Icon(Icons.audiotrack, size: 16),
              label: const Text("CREATE SAMPLE"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _createAISampleProject(),
              icon: const Icon(Icons.smart_toy, size: 16),
              label: const Text("AI SAMPLE"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showStorageInfo(),
              icon: const Icon(Icons.folder, size: 16),
              label: const Text("STORAGE INFO"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showDatabaseInfo(),
              icon: const Icon(Icons.storage, size: 16),
              label: const Text("DATABASE INFO"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF795548),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PROJECT MANAGEMENT ---

  void _showSaveDialog() {
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text(
          "Save Project",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Project Name",
                labelStyle: TextStyle(color: Color(0xFFBB86FC)),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFBB86FC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFBB86FC)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(); // Close dialog first
                await _saveProject(name);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showLoadDialog() async {
    // Use repository instead of file service for database storage
    final projectNames = await _repository.getProjectList();
    
    if (!mounted) return;
    
    if (projectNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No saved projects found"),
          backgroundColor: Color(0xFFFF5722),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text(
          "Load Project",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: projectNames.length,
            itemBuilder: (context, index) {
              final projectName = projectNames[index];
              return Card(
                color: Colors.white.withOpacity(0.1),
                child: ListTile(
                  title: Text(
                    projectName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  leading: const Icon(
                    Icons.music_note,
                    color: Color(0xFFBB86FC),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDeleteProject(projectName),
                  ),
                  onTap: () async {
                    await _loadProject(projectName);
                    if (mounted) Navigator.of(context).pop();
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProject(String projectName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text(
          "Delete Project",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "Are you sure you want to delete '$projectName'?",
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Use repository for database storage
              await _repository.deleteProject(projectName);
              if (mounted) {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Close load dialog too
                _showLoadDialog(); // Refresh the list
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _createSampleProject() async {
    print('🎯 UI: Creating sample project...');
    
    // Check if there's existing data
    bool hasData = _gridState.any((row) => row.any((step) => step));
    
    if (hasData) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text(
            "Create Sample Project",
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "This will replace your current pattern with a sample beat. Continue?",
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Color(0xFFBB86FC)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                "Continue",
                style: TextStyle(color: Color(0xFF4CAF50)),
              ),
            ),
          ],
        ),
      );
      
      if (shouldContinue != true) return;
    }
    
    try {
      final sampleProject = _storageService.createSampleProject('Sample-${DateTime.now().millisecondsSinceEpoch}');
      final success = await _storageService.saveProject(sampleProject);
      
      if (success) {
        // Load the created sample into the current UI
        setState(() {
          if (_isPlaying) _stopPlayback();
          _bpm = sampleProject.bpm;
          _steps = sampleProject.steps;
          _gridState = sampleProject.pattern.map((row) => List<bool>.from(row)).toList();
          _bpmController.text = _bpm.toString();
          _hasInitializedGrid = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sample project created and loaded!'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create sample project'),
            backgroundColor: Color(0xFFFF5722),
          ),
        );
      }
    } catch (e) {
      print('🎯 UI: Error creating sample project: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating sample project: $e'),
            backgroundColor: const Color(0xFFFF5722),
          ),
        );
      }
    }
  }

  void _createAISampleProject() async {
    print('🤖 UI: Creating AI sample project...');
    
    // Check if there's existing data
    bool hasData = _gridState.any((row) => row.any((step) => step));
    
    if (hasData) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text(
            "Create AI Sample Project",
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "This will replace your current pattern with an AI-generated beat pattern. Continue?",
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Color(0xFFBB86FC)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                "Continue",
                style: TextStyle(color: Color(0xFF00BCD4)),
              ),
            ),
          ],
        ),
      );
      
      if (shouldContinue != true) return;
    }
    
    try {
      final aiSampleProject = _storageService.createAISampleProject('AI-Sample-${DateTime.now().millisecondsSinceEpoch}');
      final success = await _storageService.saveProject(aiSampleProject);
      
      if (success) {
        // Load the created AI sample into the current UI
        setState(() {
          if (_isPlaying) _stopPlayback();
          _bpm = aiSampleProject.bpm;
          _steps = aiSampleProject.steps;
          _gridState = List.generate(_instruments.length, (i) => List.filled(_steps, false));
          
          // Copy pattern data safely
          for (int i = 0; i < math.min(_instruments.length, aiSampleProject.pattern.length); i++) {
            final sourceRow = aiSampleProject.pattern[i];
            final targetLength = math.min(_steps, sourceRow.length);
            for (int j = 0; j < targetLength; j++) {
              _gridState[i][j] = sourceRow[j];
            }
          }
          
          _bpmController.text = _bpm.toString();
          _hasInitializedGrid = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI sample project created and loaded!'),
              backgroundColor: Color(0xFF00BCD4),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create AI sample project'),
            backgroundColor: Color(0xFFFF5722),
          ),
        );
      }
    } catch (e) {
      print('🤖 UI: Error creating AI sample project: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating AI sample project: $e'),
            backgroundColor: const Color(0xFFFF5722),
          ),
        );
      }
    }
  }

  Future<void> _saveProject(String name) async {
    print('DEBUG: _saveProject called with name: $name');
    print('DEBUG: Grid state before save: $_gridState');
    print('DEBUG: BPM: $_bpm, Steps: $_steps');
    
    try {
      final project = ProjectData(
        name: name,
        pattern: _gridState.map((row) => List<bool>.from(row)).toList(),
        bpm: _bpm,
        steps: _steps,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );

      print('DEBUG: Project data created: ${project.pattern}');
      
      // Use repository for database storage
      final success = await _repository.saveProject(project);
      
      print('DEBUG: Save result: $success');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
              ? "Project '$name' saved successfully!" 
              : "Failed to save project"),
            backgroundColor: success 
              ? const Color(0xFF4CAF50) 
              : const Color(0xFFFF5722),
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving project: $e"),
            backgroundColor: const Color(0xFFFF5722),
          ),
        );
      }
    }
  }

  Future<void> _loadProject(String name) async {
    print('DEBUG: _loadProject called with name: $name');
    try {
      // Use repository for database storage
      final project = await _repository.loadProject(name);
      
      if (project == null) {
        print('DEBUG: Project is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to load project"),
              backgroundColor: Color(0xFFFF5722),
            ),
          );
        }
        return;
      }

      print('DEBUG: Project loaded: ${project.name}');
      print('DEBUG: Project pattern: ${project.pattern}');
      print('DEBUG: Project BPM: ${project.bpm}, Steps: ${project.steps}');
      print('DEBUG: Current instruments count: ${_instruments.length}');
      print('DEBUG: Current grid state before load: $_gridState');

      // Stop playback if currently playing
      if (_isPlaying) {
        _stopPlayback();
      }

      setState(() {
        // Stop playback before loading
        if (_isPlaying) _stopPlayback();
        
        // Always update BPM and steps from loaded project
        _bpm = project.bpm;
        _steps = project.steps;
        _bpmController.text = _bpm.toString();
        
        // Handle pattern loading more robustly
        if (project.pattern.length == _instruments.length) {
          print('DEBUG: Pattern has correct number of instruments');
          
          // Create a new grid with the correct dimensions
          _gridState = List.generate(_instruments.length, (i) => List.filled(_steps, false));
          
          // Copy over the pattern data, handling different step counts
          for (int i = 0; i < _instruments.length; i++) {
            final sourcePattern = project.pattern[i];
            final minSteps = math.min(sourcePattern.length, _steps);
            
            for (int j = 0; j < minSteps; j++) {
              _gridState[i][j] = sourcePattern[j];
            }
            
            print('DEBUG: Loaded ${minSteps} steps for instrument $i: ${_gridState[i]}');
          }
        } else {
          print('DEBUG: Pattern has ${project.pattern.length} instruments, expected ${_instruments.length}');
          print('DEBUG: Creating empty grid with project settings');
          
          // Create empty grid if instrument count doesn't match
          _gridState = List.generate(
            _instruments.length,
            (index) => List.filled(_steps, false),
          );
        }
        
        _currentStep = 0;
        _hasInitializedGrid = true; // Ensure we don't get overridden
        
        print('DEBUG: Final grid state after load: $_gridState');
        print('DEBUG: Final BPM: $_bpm, Steps: $_steps');
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Project '${project.name}' loaded successfully!"),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading project: $e"),
            backgroundColor: const Color(0xFFFF5722),
          ),
        );
      }
    }
  }

  void _createNewProject() {
    // Show confirmation dialog if there's existing data
    bool hasData = _gridState.any((row) => row.any((step) => step));
    
    if (hasData) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text(
            "Create New Project",
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "You have existing pattern data. Creating a new project will clear all current steps. Continue?",
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Color(0xFFBB86FC)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performNewProject();
              },
              child: const Text(
                "Continue",
                style: TextStyle(color: Color(0xFFFF9800)),
              ),
            ),
          ],
        ),
      );
    } else {
      _performNewProject();
    }
  }

  void _performNewProject() {
    if (_isPlaying) {
      _stopPlayback();
    }

    setState(() {
      _steps = 16; // Reset to default first
      _gridState = List.generate(
        _instruments.length,
        (index) => List.filled(_steps, false),
      );
      _bpm = 120.0;
      _currentStep = 0;
      _bpmController.text = _bpm.toString();
      _hasInitializedGrid = true; // Mark as initialized to prevent override
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("New project created"),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  void _showStorageInfo() async {
    try {
      final storagePath = await _storageService.getStoragePath();
      final allFiles = await _storageService.getAllFilesInDirectory();
      
      print('📁 Storage path: $storagePath');
      print('📄 All files: $allFiles');
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text(
            "Storage Information",
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Storage Location:",
                  style: TextStyle(color: Color(0xFFBB86FC), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  storagePath,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Files in Directory:",
                  style: TextStyle(color: Color(0xFFBB86FC), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...allFiles.map((file) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: SelectableText(
                    file,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                )),
                if (allFiles.isEmpty)
                  const Text(
                    "No project files found",
                    style: TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Close",
                style: TextStyle(color: Color(0xFFBB86FC)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error showing storage info: $e');
    }
  }

  /// Show database statistics and information
  void _showDatabaseInfo() async {
    try {
      final stats = await _repository.getDatabaseStats();
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text(
            "Database Information",
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "📊 Database Statistics:",
                style: TextStyle(
                  color: Color(0xFFBB86FC),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildStatRow("Projects Stored:", "${stats['projects']}"),
              _buildStatRow("Tap Events:", "${stats['tapEvents']}"),
              const SizedBox(height: 16),
              const Text(
                "💾 Storage Type:",
                style: TextStyle(
                  color: Color(0xFFBB86FC),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "SQLite Database (Room-like)",
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                "✨ Features:",
                style: TextStyle(
                  color: Color(0xFFBB86FC),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "• Relational data storage\n"
                "• Foreign key constraints\n"
                "• Transaction support\n"
                "• Index optimization\n"
                "• Migration support\n"
                "• Crash-safe storage",
                style: TextStyle(color: Colors.white, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => _clearDatabase(),
              child: const Text(
                "Clear All Data",
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Close",
                style: TextStyle(color: Color(0xFFBB86FC)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error showing database info: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading database info: $e"),
            backgroundColor: const Color(0xFFFF5722),
          ),
        );
      }
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _clearDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text(
          "Clear All Database Data",
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          "This will permanently delete all projects and tap events from the database. This action cannot be undone.",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              "Clear All Data",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.clearAllData();
        
        if (mounted) {
          Navigator.of(context).pop(); // Close database info dialog
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("All database data cleared successfully"),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error clearing database: $e"),
              backgroundColor: const Color(0xFFFF5722),
            ),
          );
        }
      }
    }
  }

  Widget _buildGlowEffect() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 0.8,
          colors: [
            const Color(0xFFBB86FC).withOpacity(0.15),
            const Color(0xFFBB86FC).withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}
