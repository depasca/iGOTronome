//
//  MetronomeEngine.c
//  GOTronome
//
//  Created by Paolo De Pascalis on 01.10.25.
//

#include "MetronomeEngine.h"

#include <AudioToolbox/AudioToolbox.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include <stdatomic.h>

// ----------------------- Engine state -----------------------
static AudioComponentInstance gAudioUnit = NULL;
static atomic_bool gIsPlaying = ATOMIC_VAR_INIT(false);
static atomic_bool gIsSilent = ATOMIC_VAR_INIT(false);
static uint32_t gBeatsPerMinute = 120;
static uint32_t gBeatsPerBar = 4;
static uint32_t gNumBars = 0;
static uint32_t gNumSilentBars = 0;
static uint32_t gSilentMeasureCounter = 0;
static atomic_uint_fast32_t gCurrentBar = ATOMIC_VAR_INIT(0);
static atomic_uint_fast32_t gCurrentBeat = ATOMIC_VAR_INIT(0);
static atomic_uint_fast64_t gFrameCounter = ATOMIC_VAR_INIT(0);

static double gSampleRate = 48000.0;
static double gSamplesPerBeat = 0.0;

// synthesis params
static const double kAccentFreq = 1760.0;
static const double kNormalFreq = 880.0;
static const float  kAccentVol = 0.5f;
static const float  kNormalVol = 0.30f;
static const double kTickDurationSeconds = 0.010; // 10ms

// oscillator phase (per channel if needed); keep simple single-phase since mono -> stereo copy
static double gPhase = 0.0;

// ----------------------- Helpers -----------------------
static void updateSamplesPerBeat(void) {
    if (gBeatsPerMinute <= 0) gBeatsPerMinute = 120;
    gSamplesPerBeat = (gSampleRate * 60.0) / (double)gBeatsPerMinute;
}

// clamp helper
static inline double clamp01(double v) {
    if (v < 0.0) return 0.0;
    if (v > 1.0) return 1.0;
    return v;
}

// ----------------------- Audio Render Callback -----------------------
static OSStatus RenderCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData) {

    (void) inRefCon;
    (void) inTimeStamp;
    (void) inBusNumber;

    // If not playing: output silence
    if (!atomic_load(&gIsPlaying)) {
        for (UInt32 i = 0; i < ioData->mNumberBuffers; ++i) {
            memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
        }
        return noErr;
    }

    const int tickLenSamples = (int)floor(kTickDurationSeconds * gSampleRate);
    const double sr = gSampleRate;

    // Determine interleave vs non-interleaved
    bool interleaved = (ioData->mNumberBuffers == 1);
    float *outL = NULL;
    float *outR = NULL;
    float *outInterleaved = NULL;
    if (!interleaved) {
        if (ioData->mNumberBuffers >= 1) outL = (float*)ioData->mBuffers[0].mData;
        if (ioData->mNumberBuffers >= 2) outR = (float*)ioData->mBuffers[1].mData;
    } else {
        outInterleaved = (float*)ioData->mBuffers[0].mData;
    }

    for (UInt32 frame = 0; frame < inNumberFrames; ++frame) {
        uint64_t frameIndex = atomic_fetch_add(&gFrameCounter, (uint_fast64_t)1);

        // compute position in beat
        double posInBeat = 0.0;
        if (gSamplesPerBeat > 0.0) {
            posInBeat = fmod((double)frameIndex, gSamplesPerBeat);
        }
        bool isTick = (posInBeat < tickLenSamples);

        // compute beat index (the beat that is sounding at this sample)
        gCurrentBar = 0;
        gCurrentBeat = 0;
        if (gSamplesPerBeat > 0.0) {
            uint64_t totalBeats = (uint64_t)floor((double)frameIndex / gSamplesPerBeat);
            gCurrentBeat = (uint32_t)(totalBeats % (uint64_t)gBeatsPerBar);
            if(gCurrentBeat == 1){
                gCurrentBar += 1;
                if(gCurrentBar > gNumBars){
                    gCurrentBar = 1;
                }
            }
        }

        float sample = 0.0f;
        if (isTick) {
            double freq = (gCurrentBeat == 0) ? kAccentFreq : kNormalFreq;
            double vol  = (gCurrentBeat == 0) ? kAccentVol  : kNormalVol;

            double phaseInc = (2.0 * M_PI * freq) / sr;
            double s = sin(gPhase);
            // quick linear attack/release envelope
            int offsetInTick = (int)posInBeat;
            double env = 1.0;
            int attackSamples = (int)(0.002 * sr); // 2ms
            int releaseSamples = (int)(0.008 * sr); // 8ms
            if (offsetInTick < attackSamples) {
                env = (double)offsetInTick / (double)attackSamples;
            } else if (offsetInTick > (tickLenSamples - releaseSamples)) {
                double rem = (double)(tickLenSamples - offsetInTick);
                env = rem / (double)releaseSamples;
                if (env < 0.0) env = 0.0;
            }
            sample = (float)(vol * env * s);

            gPhase += phaseInc;
            if (gPhase > 2.0 * M_PI) gPhase -= 2.0 * M_PI;
        } else {
            sample = 0.0f;
        }

        if (!interleaved) {
            if (outL) outL[frame] = sample;
            if (outR) outR[frame] = sample;
        } else {
            // interleaved stereo buffer: L,R,L,R...
            if (outInterleaved) {
                outInterleaved[2*frame]     = sample;
                outInterleaved[2*frame + 1] = sample;
            }
        }
    }

    return noErr;
}

// ----------------------- Audio Unit Setup & Tear Down -----------------------
static bool setupAudioUnit(void) {
    if (gAudioUnit != NULL) return true;

    AudioComponentDescription desc = {0};
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;

    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    if (!comp) return false;

    OSStatus status = AudioComponentInstanceNew(comp, &gAudioUnit);
    if (status != noErr) {
        gAudioUnit = NULL;
        return false;
    }

    // Enable IO for playback on bus 0 (output)
    UInt32 enableIO = 1;
    status = AudioUnitSetProperty(gAudioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  0,
                                  &enableIO,
                                  sizeof(enableIO));
    if (status != noErr) {
        AudioComponentInstanceDispose(gAudioUnit);
        gAudioUnit = NULL;
        return false;
    }

    // Configure stream format: 32-bit float, non-interleaved stereo (preferred)
    AudioStreamBasicDescription streamFormat;
    memset(&streamFormat, 0, sizeof(streamFormat));
    streamFormat.mSampleRate = 48000.0;
    streamFormat.mFormatID = kAudioFormatLinearPCM;
    streamFormat.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    streamFormat.mBytesPerPacket = sizeof(float);
    streamFormat.mFramesPerPacket = 1;
    streamFormat.mBytesPerFrame = sizeof(float);
    streamFormat.mChannelsPerFrame = 2;
    streamFormat.mBitsPerChannel = 8 * sizeof(float);

    status = AudioUnitSetProperty(gAudioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &streamFormat,
                                  sizeof(streamFormat));
    if (status != noErr) {
        // fallback: try interleaved float stereo
        streamFormat.mFormatFlags = kAudioFormatFlagsNativeFloatPacked;
        streamFormat.mBytesPerPacket = sizeof(float) * 2;
        streamFormat.mBytesPerFrame = sizeof(float) * 2;
        streamFormat.mChannelsPerFrame = 2;
        status = AudioUnitSetProperty(gAudioUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      0,
                                      &streamFormat,
                                      sizeof(streamFormat));
        if (status != noErr) {
            AudioComponentInstanceDispose(gAudioUnit);
            gAudioUnit = NULL;
            return false;
        }
    }

    // get actual sample rate
    UInt32 size = sizeof(streamFormat);
    status = AudioUnitGetProperty(gAudioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &streamFormat,
                                  &size);
    if (status == noErr) {
        gSampleRate = streamFormat.mSampleRate;
    } else {
        gSampleRate = 48000.0;
    }

    updateSamplesPerBeat();

    // set render callback
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = RenderCallback;
    callbackStruct.inputProcRefCon = NULL;

    status = AudioUnitSetProperty(gAudioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global,
                                  0,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    if (status != noErr) {
        AudioComponentInstanceDispose(gAudioUnit);
        gAudioUnit = NULL;
        return false;
    }

    // initialize audio unit
    status = AudioUnitInitialize(gAudioUnit);
    if (status != noErr) {
        AudioComponentInstanceDispose(gAudioUnit);
        gAudioUnit = NULL;
        return false;
    }

    return true;
}

static void teardownAudioUnit(void) {
    if (gAudioUnit) {
        AudioOutputUnitStop(gAudioUnit);
        AudioUnitUninitialize(gAudioUnit);
        AudioComponentInstanceDispose(gAudioUnit);
        gAudioUnit = NULL;
    }
}

// ----------------------- Public C API -----------------------
void metronome_start(
                     uint32_t beatsPerMinute,
                     uint32_t beatsPerMeasure,
                     uint32_t numSilentBars,
                     uint32_t numBars
                     ) {
    gBeatsPerMinute = beatsPerMinute;
    gBeatsPerBar = beatsPerMeasure;
    gNumBars = numBars;
    gNumSilentBars = numSilentBars;
    
    
    updateSamplesPerBeat();

    // Setup audio unit
    if (!setupAudioUnit()) return;

    // reset state
    atomic_store(&gFrameCounter, (uint_fast64_t)0);
    gPhase = 0.0;

    atomic_store(&gIsPlaying, true);
    AudioOutputUnitStart(gAudioUnit);
}

void metronome_stop(void) {
    atomic_store(&gIsPlaying, false);
    teardownAudioUnit();
}

uint32_t metronome_getCurrentBeatIndex(void) {
    return gCurrentBeat;
}

uint32_t metronome_getCurrentBarIndex(void) {
    return gCurrentBar;
}

float metronome_getBeatPhase(void) {
    double samplesPerBeatLocal = gSamplesPerBeat;
    if (samplesPerBeatLocal <= 0.0) return 0.0f;
    uint64_t frameIndex = atomic_load(&gFrameCounter);
    double posInBeat = fmod((double)frameIndex, samplesPerBeatLocal);
    return (float)(posInBeat / samplesPerBeatLocal);
}

double metronome_getCurrentTimeSeconds(void) {
    uint64_t frameIndex = atomic_load(&gFrameCounter);
    return (double)frameIndex / gSampleRate;
}

bool metronome_is_running(void) {
    return atomic_load(&gIsPlaying);
}
