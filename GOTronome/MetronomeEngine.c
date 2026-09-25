//
//  MetronomeEngine.c
//  GOTronome
//
//  Created by Paolo De Pascalis on 01.10.25.
//

#include "MetronomeEngine.h"
#include "StrikePool.h"

#include <AudioToolbox/AudioToolbox.h>
#include <math.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

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

// Groove: written from the UI thread, latched by the render thread at each beat.
// Steps per beat 0 = Metronome style (one blip per beat from the accent pattern).
static _Atomic int gGrooveStepsPerBeat = 0;
static _Atomic int gGrooveStepVoices[METRONOME_MAX_STEPS];
static int gActiveStepsPerBeat = 1;   // render thread only: sub-steps in the current beat
static int gNextStep = 0;             // render thread only: next sub-step to strike
static bool gMetronomeStyle = true;   // render thread only: latched at each beat
static StrikePool gStrikes;           // render thread only: every sounding strike
static SampleBank gSamples;           // filled while stopped, read by the render thread
static float *gSampleStorage[VOICES_NUM];

// Bass line: written from the UI thread, latched by the render thread at each beat.
static _Atomic int gBassStepsPerBeat = 0;   // 0 = no bass line
static _Atomic int gBassBars = 1;
static _Atomic int gBassNotes[METRONOME_MAX_BASS_STEPS];
static _Atomic int gBassRoot = 36;          // MIDI note of the root, C2 by default
static _Atomic bool gBassEnabled = false;
static bool gBassInitialized = false;
static int gActiveBassStepsPerBeat = 0;     // render thread only
static int gActiveBassBars = 1;             // render thread only
static int gNextBassStep = 0;               // render thread only
static uint gMeasureCounter = 0;            // render thread only: free-running, unlike gCurrentBar

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

// Sound parameters. The blip frequencies and volumes live in Voices.h.
static const float kSampleRate = 48000.0f;

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
    if (!gBassInitialized) {
        for (int i = 0; i < METRONOME_MAX_BASS_STEPS; ++i) {
            atomic_store_explicit(&gBassNotes[i], METRONOME_BASS_REST, memory_order_relaxed);
        }
        gBassInitialized = true;
    }
    strike_pool_reset(&gStrikes);
    gNextStep = 0;
    gActiveStepsPerBeat = 1;
    gMetronomeStyle = true;
    gNextBassStep = 0;
    gActiveBassStepsPerBeat = 0;
    gActiveBassBars = 1;
    gMeasureCounter = 0;
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

void metronome_set_groove(int stepsPerBeat, const int *stepVoices, int count) {
    int steps = stepsPerBeat < 0 ? 0 : stepsPerBeat;
    if (steps > METRONOME_MAX_STEPS_PER_BEAT) steps = METRONOME_MAX_STEPS_PER_BEAT;
    for (int i = 0; i < METRONOME_MAX_STEPS; ++i) {
        atomic_store_explicit(&gGrooveStepVoices[i], i < count ? stepVoices[i] : 0, memory_order_relaxed);
    }
    // Release after the steps so the render thread never pairs a new step count
    // with stale step voices.
    atomic_store_explicit(&gGrooveStepsPerBeat, steps, memory_order_release);
}

bool metronome_load_sample(int voiceIndex, const float *frames, int length, int rate, int baseMidiNote) {
    if (gRunning || voiceIndex < 0 || voiceIndex >= VOICES_NUM || length <= 0 || rate <= 0) return false;
    float *copy = malloc(sizeof(float) * (size_t)length);
    if (copy == NULL) return false;
    memcpy(copy, frames, sizeof(float) * (size_t)length);
    free(gSampleStorage[voiceIndex]);
    gSampleStorage[voiceIndex] = copy;
    gSamples.voices[voiceIndex] = (Sample){copy, length, (float)rate, baseMidiNote};
    return true;
}

void metronome_set_bass_line(int stepsPerBeat, int bars, const int *notes, int count) {
    int steps = stepsPerBeat < 0 ? 0 : stepsPerBeat;
    if (steps > METRONOME_MAX_STEPS_PER_BEAT) steps = METRONOME_MAX_STEPS_PER_BEAT;
    int measures = bars < 1 ? 1 : bars;
    if (measures > METRONOME_MAX_BASS_BARS) measures = METRONOME_MAX_BASS_BARS;
    for (int i = 0; i < METRONOME_MAX_BASS_STEPS; ++i) {
        atomic_store_explicit(&gBassNotes[i], i < count ? notes[i] : METRONOME_BASS_REST, memory_order_relaxed);
    }
    gBassInitialized = true;
    atomic_store_explicit(&gBassBars, measures, memory_order_relaxed);
    atomic_store_explicit(&gBassStepsPerBeat, steps, memory_order_release);
}

void metronome_set_bass_root(int midiNote) {
    atomic_store_explicit(&gBassRoot, midiNote, memory_order_relaxed);
}

void metronome_set_bass_enabled(bool enabled) {
    atomic_store_explicit(&gBassEnabled, enabled, memory_order_relaxed);
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


#pragma mark - Render Callback

// Per-beat level (2 = accent, 1 = normal, 0 = mute) as a voice mask.
static int blipForLevel(int level) {
    if (level == 2) return VOICE_BLIP_HI;
    if (level == 1) return VOICE_BLIP_LO;
    return 0;
}

// Sample offset of a sub-step inside a beat. Relative to the beat, so the
// fractional carry in gBeatPhase keeps the sub-steps drift-free as well.
static int stepStartSample(int step, double samplesPerBeat, int stepsPerBeat) {
    return (int)floor(step * samplesPerBeat / stepsPerBeat);
}

static int bassNoteForStep(int beat, int step) {
    if (beat < 1 || beat > METRONOME_MAX_BEATS || gActiveBassStepsPerBeat == 0) return METRONOME_BASS_REST;
    const int bar = (int)(gMeasureCounter % (uint)gActiveBassBars);
    const int index = ((bar * (int)gBeatsPerBar) + (beat - 1)) * gActiveBassStepsPerBeat + step;
    if (index < 0 || index >= METRONOME_MAX_BASS_STEPS) return METRONOME_BASS_REST;
    return atomic_load_explicit(&gBassNotes[index], memory_order_relaxed);
}

// Playback-rate multiplier that transposes the bass sound to midiNote. The
// synth placeholder sits at A1 (MIDI 33); a recorded note declares its own pitch.
static float bassRateFor(int midiNote) {
    const int bassIndex = voices_index(VOICE_BASS);
    const int base = gSamples.voices[bassIndex].length > 0 ? gSamples.voices[bassIndex].baseMidiNote : 33;
    return powf(2.0f, (float)(midiNote - base) / 12.0f);
}

static int voicesForStep(int beat, int step) {
    if (beat < 1 || beat > METRONOME_MAX_BEATS) return 0;
    if (gIsCountingIn) {
        // The count-in is a steady accent-on-1 click whatever the style.
        return blipForLevel(beat == 1 ? 2 : 1);
    }
    if (gMetronomeStyle) {
        return blipForLevel(atomic_load_explicit(&gAccentPattern[beat - 1], memory_order_relaxed));
    }
    return atomic_load_explicit(&gGrooveStepVoices[(beat - 1) * gActiveStepsPerBeat + step], memory_order_relaxed);
}

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
                    gMeasureCounter += 1;
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

            // Latch the groove for this beat so a live change from the UI
            // thread cannot move the step grid mid-beat.
            const int grooveSteps = atomic_load_explicit(&gGrooveStepsPerBeat, memory_order_acquire);
            gMetronomeStyle = gIsCountingIn || grooveSteps == 0;
            gActiveStepsPerBeat = gMetronomeStyle ? 1 : grooveSteps;
            gNextStep = 0;
            const bool bassOn = atomic_load_explicit(&gBassEnabled, memory_order_relaxed) && !gMetronomeStyle;
            gActiveBassStepsPerBeat = bassOn ? atomic_load_explicit(&gBassStepsPerBeat, memory_order_acquire) : 0;
            const int bars = atomic_load_explicit(&gBassBars, memory_order_relaxed);
            gActiveBassBars = bars < 1 ? 1 : bars;
            gNextBassStep = 0;
        }

        if (gNextStep < gActiveStepsPerBeat &&
            gSamplesSinceBeat >= stepStartSample(gNextStep, samplesPerBeat, gActiveStepsPerBeat)) {
            if (!gIsSilent) {
                strike_pool_strike(&gStrikes, voicesForStep((int)gCurrentBeat, gNextStep), 1.0f);
            }
            gNextStep++;
        }

        if (gNextBassStep < gActiveBassStepsPerBeat &&
            gSamplesSinceBeat >= stepStartSample(gNextBassStep, samplesPerBeat, gActiveBassStepsPerBeat)) {
            const int note = bassNoteForStep((int)gCurrentBeat, gNextBassStep);
            if (note != METRONOME_BASS_REST && !gIsSilent) {
                const int midi = atomic_load_explicit(&gBassRoot, memory_order_relaxed) + note;
                strike_pool_strike(&gStrikes, VOICE_BASS, bassRateFor(midi));
            }
            gNextBassStep++;
        }

        out[i] = strike_pool_render(&gStrikes, kSampleRate, &gSamples);

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
