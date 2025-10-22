//
//  MetronomeEngine.c
//  GOTronome
//
//  Created by Paolo De Pascalis on 01.10.25.
//

#include "MetronomeEngine.h"

#include <AudioToolbox/AudioToolbox.h>
#include <math.h>
#include <stdbool.h>
#include <stdlib.h>

static AudioUnit gAudioUnit = NULL;
static bool gRunning = false;

// Configuration
static float gBeatsPerMinute = 120.0f;
static uint gBeatsPerBar = 4;
static uint gnumBars = 4;
static uint gNumSilentBars = 0;
static bool gSilentBarsEnabled = false;

// Playback state
static double gPhase = 0.0;
static uint gCurrentBeat = 0;
static uint gCurrentBar = 0;
static uint gSilentBarCounter = 0;
static uint64_t gSampleCounter = 0;
static bool gIsSilent = false;

// Sound parameters
static const float kSampleRate = 48000.0f;
static const float kClickDuration = 0.01f;
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

#pragma mark - Audio Setup

void metronome_start(uint32_t beatsPerMinute,
                     uint32_t beatsPerMeasure,
                     uint32_t numSilentBars,
                     uint32_t numBars,
                     bool silenBarsEnabled) {
    if (gRunning) return;

    gBeatsPerMinute = beatsPerMinute;
    gBeatsPerBar = beatsPerMeasure;
    gnumBars = numBars;
    gNumSilentBars = numSilentBars;
    gPhase = 0.0;
    gCurrentBeat = 0;
    gSampleCounter = 0;
    gSilentBarCounter = 0;
    gSilentBarsEnabled = silenBarsEnabled;
    gRunning = true;
    
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

void metronome_stop(void) {
    if (!gRunning) return;

    gRunning = false;
    AudioOutputUnitStop(gAudioUnit);
    AudioUnitUninitialize(gAudioUnit);
    AudioComponentInstanceDispose(gAudioUnit);
    gAudioUnit = NULL;

    gPhase = 0.0;
    gCurrentBeat = 0;
    gCurrentBar = 0;
    gIsSilent = false;
    gSilentBarCounter = 0;
    gSampleCounter = 0;
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
    double secondsPerBeat = 60.0 / gBeatsPerMinute;
    int samplesPerBeat = kSampleRate * secondsPerBeat;

    for (UInt32 i = 0; i < inNumberFrames; ++i) {
        int beatOffset = gSampleCounter % samplesPerBeat;
        float sample = 0.0f;
        // If we’ve reached the next beat
        if (beatOffset == 0) {
            gCurrentBeat += 1;
            if(gCurrentBeat > gBeatsPerBar){
                gCurrentBeat = 1;
                if(++gCurrentBar >= gnumBars)
                    gCurrentBar = 0;
            }
            if(gSilentBarsEnabled) {
                if (gIsSilent) {
                    gSilentBarCounter++;
                    if (gSilentBarCounter >= gNumSilentBars) {
                        gIsSilent = false;
                        gSilentBarCounter = 0;
                    }
                } else if (gNumSilentBars > 0) {
                    gIsSilent = true;
                }
            }
        }
        
        // Generate click at start of beat
        if (!gIsSilent && beatOffset < kSampleRate * kClickDuration) {
            double freq = (gCurrentBeat == 1) ? kAccentFreq : kNormalFreq;
            double vol  = (gCurrentBeat == 1) ? kAccentVol  : kNormalVol;
            float t = beatOffset / kSampleRate;
            float env = envelope(t, kClickDuration);
            sample = vol * env * sinf(2.0f * M_PI * freq * t);
        }
//        printf("%f\n", sample);
        out[i] = sample;

        // Advance sample counter
        gSampleCounter++;
        
        printf("bar, beat, is silent, silentbar: %d, %d, %d, %d\n", gCurrentBar, gCurrentBeat, gIsSilent, gSilentBarCounter);
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
