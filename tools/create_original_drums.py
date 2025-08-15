#!/usr/bin/env python3
"""
Create Original Drum Samples for TapCompose

This script creates basic kick, snare, and hihat samples for your drum sequencer.
"""

import os
import sys
import struct
import wave
import math
from pathlib import Path

def create_kick_sample(duration=1.5, sample_rate=44100, amplitude=0.8):
    """Create a kick drum sample with low-frequency punch."""
    frames = int(duration * sample_rate)
    samples = []
    
    for i in range(frames):
        t = i / sample_rate
        # Exponential decay for drum-like envelope
        envelope = math.exp(-t * 4.0)
        
        # Kick: Low frequency (60Hz) with harmonics and punch
        fundamental = math.sin(2 * math.pi * 60 * t)
        harmonic = math.sin(2 * math.pi * 120 * t) * 0.3
        sub_bass = math.sin(2 * math.pi * 30 * t) * 0.5
        
        # Add some click for punch (short burst at the beginning)
        click = 0
        if t < 0.01:  # First 10ms
            click = math.sin(2 * math.pi * 1000 * t) * (1 - t / 0.01) * 0.4
        
        sample = (fundamental + harmonic + sub_bass + click) * envelope
        
        # Convert to 16-bit
        sample = int(sample * amplitude * 32767)
        sample = max(-32768, min(32767, sample))
        samples.append(sample)
    
    return samples

def create_snare_sample(duration=0.8, sample_rate=44100, amplitude=0.7):
    """Create a snare drum sample with noise and tone."""
    frames = int(duration * sample_rate)
    samples = []
    
    for i in range(frames):
        t = i / sample_rate
        # Faster decay for snare
        envelope = math.exp(-t * 6.0)
        
        # Snare: Mix of noise and tonal components
        noise = (hash(str(i * 13)) % 2000 - 1000) / 1000.0  # Pseudo-random noise
        tone1 = math.sin(2 * math.pi * 200 * t)
        tone2 = math.sin(2 * math.pi * 400 * t) * 0.5
        
        # Add some bright attack
        attack = 0
        if t < 0.005:  # First 5ms
            attack = math.sin(2 * math.pi * 3000 * t) * (1 - t / 0.005) * 0.3
        
        sample = (noise * 0.7 + tone1 * 0.2 + tone2 * 0.1 + attack) * envelope
        
        # Convert to 16-bit
        sample = int(sample * amplitude * 32767)
        sample = max(-32768, min(32767, sample))
        samples.append(sample)
    
    return samples

def create_hihat_sample(duration=0.2, sample_rate=44100, amplitude=0.5):
    """Create a hi-hat sample with high-frequency noise."""
    frames = int(duration * sample_rate)
    samples = []
    
    for i in range(frames):
        t = i / sample_rate
        # Very fast decay for hi-hat
        envelope = math.exp(-t * 20.0)
        
        # Hi-hat: Mostly high-frequency noise with some metallic tones
        noise = (hash(str(i * 7)) % 2000 - 1000) / 1000.0
        metallic1 = math.sin(2 * math.pi * 8000 * t) * 0.3
        metallic2 = math.sin(2 * math.pi * 12000 * t) * 0.2
        
        sample = (noise * 0.8 + metallic1 + metallic2) * envelope
        
        # Convert to 16-bit
        sample = int(sample * amplitude * 32767)
        sample = max(-32768, min(32767, sample))
        samples.append(sample)
    
    return samples

def create_wav_file(filename, samples, sample_rate=44100):
    """Create a WAV file from sample data."""
    with wave.open(str(filename), 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)
        
        # Convert samples to bytes
        sample_bytes = b''.join(struct.pack('<h', sample) for sample in samples)
        wav_file.writeframes(sample_bytes)

def main():
    print("🥁 TapCompose Original Drums Creator")
    print("=" * 40)
    
    # Determine output directory
    script_dir = Path(__file__).parent
    output_dir = script_dir.parent / "assets" / "audio"
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"Creating drum samples in: {output_dir}")
    print()
    
    # Create the three essential drum sounds
    drums = {
        'kick': create_kick_sample,
        'snare': create_snare_sample, 
        'hihat': create_hihat_sample
    }
    
    success_count = 0
    
    for drum_name, create_func in drums.items():
        output_file = output_dir / f"{drum_name}.wav"
        
        try:
            print(f"Creating {drum_name}.wav...")
            samples = create_func()
            create_wav_file(output_file, samples)
            print(f"  ✓ Created: {output_file}")
            success_count += 1
        except Exception as e:
            print(f"  ✗ Failed to create {drum_name}: {e}")
    
    print()
    print(f"✅ Created {success_count}/3 drum samples")
    print(f"📁 Location: {output_dir}")
    
    if success_count == 3:
        print()
        print("🎵 Ready to use! Your drum samples are now available in:")
        print("   - assets/audio/kick.wav")
        print("   - assets/audio/snare.wav") 
        print("   - assets/audio/hihat.wav")
        print()
        print("🚀 Run your Flutter app to test the sequencer!")
    else:
        print("\n⚠️  Some samples failed to create. Check the errors above.")

if __name__ == "__main__":
    main()