//
//  Samples.h
//  GOTronome
//
//  Optional recorded one-shots. A voice with a sample plays it instead of its
//  synthesized version. The bank only points at storage the engine owns; it is
//  filled while stopped and never written from the render thread.
//

#ifndef GOTRONOME_SAMPLES_H
#define GOTRONOME_SAMPLES_H

#include "Voices.h"

typedef struct {
    const float *data;  // mono, full scale +-1
    int length;         // frames; 0 = no sample, use the synth voice
    float rate;         // frames per second the sample was recorded at
    int baseMidiNote;   // pitch of the recording for pitched voices, 0 = unpitched
} Sample;

typedef struct {
    Sample voices[VOICES_NUM];
} SampleBank;

static inline int samples_has(const SampleBank *bank, int voiceIndex) {
    return bank->voices[voiceIndex].length > 0;
}

// pitch multiplies the playback rate: 2^(semitones/12) transposes the note.
static inline int samples_duration_samples(const Sample *s, double sampleRate, float pitch) {
    return (int)(s->length * sampleRate / (s->rate * pitch));
}

// Linear-interpolated playback of s, resampled from its own rate to sampleRate.
static inline float samples_play(const Sample *s, int age, double sampleRate, float pitch) {
    const double pos = age * (s->rate * pitch / sampleRate);
    const int i = (int)pos;
    if (i + 1 >= s->length) return i < s->length ? s->data[i] : 0.0f;
    const float frac = (float)(pos - i);
    return s->data[i] + frac * (s->data[i + 1] - s->data[i]);
}

#endif // GOTRONOME_SAMPLES_H
