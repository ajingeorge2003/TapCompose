import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/instrument_data.dart';
import '../services/audio_service.dart';

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
  final int _steps = 16;
  
  late List<List<bool>> _gridState;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // --- ROBUST PLAYBACK ENGINE ---
  Timer? _playbackTimer;

  late TextEditingController _bpmController;
  final AudioService _audioService = AudioService();

  final List<InstrumentData> _instruments = [
    InstrumentData(name: "KICK", iconAsset: "assets/icons/kick_icon.png", color: const Color(0xFFFF5252), audioAsset: 'audio/kick.wav'),
    InstrumentData(name: "SNARE", iconAsset: "assets/icons/snare_icon.png", color: const Color(0xFF4CAF50), audioAsset: 'audio/snare.wav'),
    InstrumentData(name: "HI-HAT", iconAsset: "assets/icons/hihat_icon.png", color: const Color(0xFF2196F3), audioAsset: 'audio/hihat.wav'),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _gridState = List.generate(_instruments.length, (index) => List.filled(_steps, false));
    _bpmController = TextEditingController(text: _bpm.toString());
    _audioService.loadSounds(_instruments.map((i) => i.audioAsset).toList());

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  // --- PLAYBACK ENGINE LOGIC ---

  void _startPlayback() {
    if (_bpm <= 0) return;
    final int stepDuration = (60000 / _bpm).round();
    
    _playbackTimer = Timer.periodic(Duration(milliseconds: stepDuration), (timer) {
      if (!mounted) return;
      
      // Play sounds for the current step. This is a "fire-and-forget" call.
      for (int i = 0; i < _instruments.length; i++) {
        if (_gridState[i][_currentStep]) {
          _audioService.playSound(_instruments[i].audioAsset);
        }
      }

      // Advance the step for the next tick.
      setState(() {
        _currentStep = (_currentStep + 1) % _steps;
      });
    });
  }

  void _stopPlayback() {
    _playbackTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _currentStep = 0;
    });
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
        // If already playing, restart the timer with the new BPM
        if (_isPlaying) {
          _playbackTimer?.cancel();
          _startPlayback();
        }
      });
    }
  }
  
  void _resetGrid() {
    setState(() {
      _gridState = List.generate(_instruments.length, (index) => List.filled(_steps, false));
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _playbackTimer?.cancel();
    _pulseController.dispose();
    _bpmController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
    // **FIX**: This layout is now robust. The Column uses Expanded for the list,
    // preventing any overflow regardless of screen height.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildTransportControls(),
        const SizedBox(height: 16),
        Expanded(
          child: _buildInstrumentList()
        ),
        const SizedBox(height: 16),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildHeader() {
    return const Row(
      children: [
        Icon(Icons.graphic_eq, color: Color(0xFFBB86FC), size: 32),
        SizedBox(width: 8),
        Text("TAPCOMPOSE", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
          children: [
            SizedBox(
              height: 50,
              child: TextField(
                controller: _bpmController,
                onChanged: _onBpmChanged,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "BPM",
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _togglePlay,
                    icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow, color: Colors.black),
                    label: Text(_isPlaying ? "STOP" : "PLAY", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPlaying ? const Color(0xFFCF6679) : const Color(0xFF03DAC6),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.fiber_manual_record, color: Colors.red),
                  iconSize: 28,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.3),
                    side: BorderSide(color: Colors.red.withOpacity(0.6)),
                  ),
                ),
              ],
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
        child: ListView.builder(
          itemCount: _instruments.length,
          itemBuilder: (context, index) {
            final instrument = _instruments[index];
            final isSelected = _selectedInstrument == index;
            return Material(
              color: isSelected ? instrument.color.withOpacity(0.3) : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: isSelected ? instrument.color.withOpacity(0.6) : Colors.transparent),
              ),
              child: InkWell(
                onTap: () => setState(() => _selectedInstrument = index),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Image.asset(instrument.iconAsset, width: 32, height: 32, errorBuilder: (c, e, s) => const Icon(Icons.music_note)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          instrument.name,
                          style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                        ),
                      ),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: instrument.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(child: _actionButton(Icons.save, "SAVE", const Color(0xFF03DAC6), () => _showSaveDialog(context))),
        const SizedBox(width: 8),
        Expanded(child: _actionButton(Icons.folder_open, "LOAD", const Color(0xFFBB86FC), () => _showLoadDialog(context))),
        const SizedBox(width: 8),
        Expanded(child: _actionButton(Icons.clear, "RESET", const Color(0xFFCF6679), _resetGrid)),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildRightPanel() {
    final double cellWidth = 48.0;
    final double cellMargin = 4.0;
    final double indicatorWidth = 40.0;
    final double totalGridWidth = (_steps * (cellWidth + cellMargin)) + indicatorWidth;

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
            color: isCurrent ? const Color(0xFFBB86FC).withOpacity(0.3) : Colors.transparent,
            border: Border.all(color: isCurrent ? const Color(0xFFBB86FC) : Colors.white.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            "${index + 1}",
            style: TextStyle(
              color: isCurrent ? const Color(0xFFBB86FC) : Colors.white.withOpacity(0.6),
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
                      color: isCurrent ? instrument.color.withOpacity(0.8) : Colors.white.withOpacity(0.1),
                    ),
                  ),
                );

                if (isPulsing) {
                  cell = ScaleTransition(scale: _pulseAnimation, child: cell);
                }

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _gridState[rowIndex][colIndex] = !_gridState[rowIndex][colIndex];
                    });
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
    final bool isPlayingOnCurrentStep = _isPlaying && _gridState[instrumentIndex][_currentStep];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 40,
      height: 48,
      child: isPlayingOnCurrentStep
          ? Icon(Icons.volume_up, color: _instruments[instrumentIndex].color)
          : null,
    );
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

// Dialogs remain the same
void _showSaveDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: const Color(0xFF2D2D2D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: Color(0xFFBB86FC)),
        ),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "SAVE PATTERN",
                style: TextStyle(color: Color(0xFFBB86FC), fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Pattern name',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: const Color(0xFF3D3D3D),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFBB86FC))),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("CANCEL", style: TextStyle(color: Color(0xFFBB86FC))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBB86FC),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showLoadDialog(BuildContext context) {
    final samplePatterns = ["Drum Loop 1", "Beat 120BPM", "HipHop Pattern"];
  
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: const Color(0xFF2D2D2D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: Color(0xFF03DAC6)),
        ),
        child: Container(
          width: 300,
          height: 350,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "LOAD PATTERN",
                style: TextStyle(color: Color(0xFF03DAC6), fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                    itemCount: samplePatterns.length,
                    itemBuilder: (context, index) {
                        return Card(
                            color: const Color(0xFF3D3D3D),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                                leading: const Icon(Icons.library_music, color: Color(0xFF03DAC6)),
                                title: Text(samplePatterns[index], style: const TextStyle(color: Colors.white)),
                                trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF03DAC6), size: 16),
                                onTap: () {},
                            ),
                        );
                    },
                ),
              ),
               const SizedBox(height: 16),
               ElevatedButton(
                 onPressed: () => Navigator.of(context).pop(),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFF03DAC6),
                   foregroundColor: Colors.black
                 ),
                 child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold)),
               )
            ],
          ),
        ),
      );
    },
  );
}
