//
//  MetronomeEngine.c
//  GOTronome
//
//  Created by Paolo De Pascalis on 01.10.25.
//

#include "MetronomeEngine.h"

#include <AudioToolbox/AudioToolbox.h>
#include <math.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdlib.h>

static AudioUnit gAudioUnit = NULL;
static bool gRunning = false;

// Configuration
static float gBeatsPerMinute = 120.0f;
static uint gBeatsPerBar = 4;
static uint gNumBars = 4;
static uint gNumSilentBars = 0;
static bool gSilentBarsEnabled = false;
static bool gCountInEnabled = true;

// Per-beat level: 2 = accent, 1 = normal, 0 = mute. Written from the UI thread,
// read from the audio thread. Defaults to accent-on-1 until Swift pushes one.
static _Atomic int gAccentPattern[METRONOME_MAX_BEATS];
static bool gAccentInitialized = false;

static void ensureAccentDefault(void) {
    if (gAccentInitialized) return;
    for (int i = 0; i < METRONOME_MAX_BEATS; ++i) {
        atomic_store_explicit(&gAccentPattern[i], i == 0 ? 2 : 1,
                              memory_order_relaxed);
    }
    gAccentInitialized = true;
}

// Count-in state
static bool gIsCountingIn = false;
static uint gCountInBeats = 4;
static uint gCountInBeat = 0;

// Playback state
static double gPhase = 0.0;
static uint gCurrentBeat = 0;
static uint gCurrentBar = 0;
static uint gSilentBarCounter = 0;
static uint64_t gSampleCounter = 0;
static bool gIsSilent = false;
static double gBeatPhase = 0.0;     // samples until the next beat (fractional)
static int gSamplesSinceBeat = 0;   // samples since the last beat, for the click

// Sound parameters
static const float kSampleRate = 48000.0f;
static const float kClickDuration = 0.01f * kSampleRate;
static const float kNormalFreq = 880.0f;
static const float kAccentFreq = 1760.0f;
static const float  kAccentVol = 0.5f;
static const float  kNormalVol = 0.30f;

// Forward declaration
static OSStatus RenderCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData);
static void setupAudioUnit(void);
static void teardownAudioUnit(void);

#pragma mark - Audio Setup

void metronome_start(uint32_t beatsPerMinute,
                     uint32_t beatsPerMeasure,
                     uint32_t numSilentBars,
                     uint32_t numBars,
                     bool silenBarsEnabled,
                     bool countInEnabled) {
    if (gRunning) return;
    printf("starting with beatsPerMinute=%d, beatsPerMeasure=%d, numSilentBars=%d, numBars=%d, silenBarsEnabled=%d\n", beatsPerMinute, beatsPerMeasure, numSilentBars, numBars, silenBarsEnabled);
    gBeatsPerMinute = beatsPerMinute;
    gBeatsPerBar = beatsPerMeasure;
    gNumBars = numBars;
    gNumSilentBars = numSilentBars;
    gPhase = 0.0;
    gCurrentBeat = 0;
    gCurrentBar = 0;
    gSampleCounter = 0;
    gSilentBarCounter = 0;
    gIsSilent = false;
    gBeatPhase = 0.0;
    gSamplesSinceBeat = 0;
    gSilentBarsEnabled = silenBarsEnabled;

    // Arm a one-bar count-in lead-in before the song proper.
    gCountInEnabled = countInEnabled;
    gIsCountingIn = countInEnabled;
    gCountInBeats = beatsPerMeasure;
    gCountInBeat = 0;

    ensureAccentDefault();
    gRunning = true;

    setupAudioUnit();
}

static void setupAudioUnit(void) {
    // Set up audio component
    AudioComponentDescription desc = {0};
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;

    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    AudioComponentInstanceNew(comp, &gAudioUnit);

    AURenderCallbackStruct callback = {0};
    callback.inputProc = RenderCallback;
    AudioUnitSetProperty(gAudioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         0,
                         &callback,
                         sizeof(callback));

    // Set format
    AudioStreamBasicDescription format = {0};
    format.mSampleRate = kSampleRate;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    format.mChannelsPerFrame = 1;
    format.mFramesPerPacket = 1;
    format.mBytesPerFrame = sizeof(float);
    format.mBytesPerPacket = sizeof(float);
    format.mBitsPerChannel = 32;
    AudioUnitSetProperty(gAudioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         0,
                         &format,
                         sizeof(format));

    AudioUnitInitialize(gAudioUnit);
    AudioOutputUnitStart(gAudioUnit);
}

static void teardownAudioUnit(void) {
    if (gAudioUnit == NULL) return;
    AudioOutputUnitStop(gAudioUnit);
    AudioUnitUninitialize(gAudioUnit);
    AudioComponentInstanceDispose(gAudioUnit);
    gAudioUnit = NULL;
}

void metronome_restart_audio(void) {
    // A route change (e.g. Bluetooth/headphones connect or disconnect) can
    // silence the unit. Rebuild it on the new route but leave the transport
    // counters untouched so the click continues in place.
    if (!gRunning) return;
    teardownAudioUnit();
    setupAudioUnit();
}

void metronome_set_accent_pattern(const int *pattern, int count) {
    for (int i = 0; i < METRONOME_MAX_BEATS; ++i) {
        int level = (i < count) ? pattern[i] : 1;
        atomic_store_explicit(&gAccentPattern[i], level, memory_order_relaxed);
    }
    gAccentInitialized = true;
}

void metronome_stop(void) {
    if (!gRunning) return;

    gRunning = false;
    teardownAudioUnit();

    gPhase = 0.0;
    gCurrentBeat = 0;
    gCurrentBar = 0;
    gIsSilent = false;
    gSilentBarCounter = 0;
    gSampleCounter = 0;
    gBeatPhase = 0.0;
    gSamplesSinceBeat = 0;
    gIsCountingIn = false;
    gCountInBeat = 0;
}


float envelope(float t, float duration) {
    float attack = 0.002f;
    float release = 0.008f;
    if (t < attack) return t / attack;
    else if (t > duration - release) return (duration - t) / release;
    else return 1.0f;
}

#pragma mark - Render Callback

static OSStatus RenderCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData)
{
    float *out = (float *)ioData->mBuffers[0].mData;
    double samplesPerBeat = kSampleRate * (60.0 / gBeatsPerMinute);

    for (UInt32 i = 0; i < inNumberFrames; ++i) {
        float sample = 0.0f;

        // Fire a beat when a full (fractional) beat period has elapsed. The
        // remainder carries into gBeatPhase, so the tempo never drifts.
        if (gBeatPhase <= 0.0) {
            gBeatPhase += samplesPerBeat;
            gSamplesSinceBeat = 0;
            if (gIsCountingIn) {
                if (gCountInBeat >= gCountInBeats) {
                    // Lead-in complete: begin the song on this beat as a fresh
                    // downbeat so bar/silent logic starts aligned.
                    gIsCountingIn = false;
                    gCurrentBeat = 1;
                    gCurrentBar = 0;
                    gIsSilent = false;
                    gSilentBarCounter = 0;
                } else {
                    // Count 1..N without advancing the song.
                    gCountInBeat += 1;
                    gCurrentBeat = gCountInBeat;
                }
            } else {
                gCurrentBeat += 1;
                if (gCurrentBeat > gBeatsPerBar) {
                    gCurrentBeat = 1;
                    if (++gCurrentBar >= gNumBars)
                        gCurrentBar = 0;
                    if (gSilentBarsEnabled) {
                        if (gIsSilent) {
                            if (++gSilentBarCounter >= gNumSilentBars) {
                                gIsSilent = false;
                                gSilentBarCounter = 0;
                            }
                        } else if (gNumSilentBars > 0) {
                            gIsSilent = true;
                        }
                    }
                }
            }
        }

        // Generate the click at the start of the beat.
        if (!gIsSilent && gSamplesSinceBeat < (int)kClickDuration) {
            // Per-beat level: 2 = accent, 1 = normal, 0 = mute. The count-in
            // keeps a steady accent-on-1 and ignores the pattern.
            int level;
            if (gIsCountingIn) {
                level = (gCurrentBeat == 1) ? 2 : 1;
            } else if (gCurrentBeat >= 1 && gCurrentBeat <= METRONOME_MAX_BEATS) {
                level = atomic_load_explicit(&gAccentPattern[gCurrentBeat - 1],
                                             memory_order_relaxed);
            } else {
                level = 1;
            }
            if (level != 0) {
                double freq = (level == 2) ? kAccentFreq : kNormalFreq;
                double vol  = (level == 2) ? kAccentVol  : kNormalVol;
                float t = gSamplesSinceBeat / kSampleRate;
                float env = envelope(t, kClickDuration / kSampleRate);
                sample = vol * env * sinf(2.0f * M_PI * freq * t);
            }
        }
        out[i] = sample;

        // Expose progress through the current beat (0 at the click, ->1 before
        // the next) so the visual pulse can shrink smoothly.
        gPhase = (float)(gSamplesSinceBeat / samplesPerBeat);
        gBeatPhase -= 1.0;
        gSamplesSinceBeat++;
    }

    return noErr;
}

#pragma mark - Optional Accessors (for Swift polling)

int metronome_get_current_bar(void) {
    return gCurrentBar;
}

int metronome_get_current_beat(void) {
    return gCurrentBeat - 1;
}

float metronome_get_current_beat_phase(void){
    return gPhase;
}

bool metronome_get_is_silent_bar(void){
    return gIsSilent;
}

bool metronome_get_is_counting_in(void){
    return gIsCountingIn;
}
