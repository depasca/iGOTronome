//
//  StrikePool.h
//  GOTronome
//
//  Fixed pool of sounding strikes. Each strike is (voice, samples since struck,
//  state), so the same voice can ring several times over, e.g. a ride cymbal's
//  tail carrying through the next hit. No allocation; the render thread owns it.
//

#ifndef GOTRONOME_STRIKEPOOL_H
#define GOTRONOME_STRIKEPOOL_H

#include "Samples.h"
#include <stddef.h>
#include "Voices.h"

#define STRIKE_POOL_MAX 32
#define STRIKE_RELEASE_SECONDS 0.008f  // fade when a monophonic voice is re-struck

typedef struct {
    int voice;                         // voice index 0..VOICES_NUM-1
    int age;                           // samples since struck, -1 = free slot
    int releaseAge;                    // age at which the fade-out began, -1 = not releasing
    float rate;                        // pitch multiplier for pitched voices
    float state[VOICES_STRIKE_STATE];  // voice-owned memory, e.g. filter history
} Strike;

typedef struct {
    Strike slots[STRIKE_POOL_MAX];
} StrikePool;

static inline void strike_pool_reset(StrikePool *pool) {
    for (int i = 0; i < STRIKE_POOL_MAX; ++i) pool->slots[i].age = -1;
}

// Start every voice in mask at pitch rate; when the pool is full the oldest
// strike is replaced. A monophonic voice fades out its previous strike first.
static inline void strike_pool_strike(StrikePool *pool, int mask, float rate) {
    for (int v = 0; v < VOICES_NUM; ++v) {
        if (!(mask & (1 << v))) continue;
        if (voices_is_monophonic(v)) {
            for (int i = 0; i < STRIKE_POOL_MAX; ++i) {
                Strike *s = &pool->slots[i];
                if (s->age >= 0 && s->voice == v && s->releaseAge < 0) s->releaseAge = s->age;
            }
        }
        Strike *target = NULL;
        for (int i = 0; i < STRIKE_POOL_MAX; ++i) {
            Strike *s = &pool->slots[i];
            if (s->age < 0) { target = s; break; }
            if (target == NULL || s->age > target->age) target = s;
        }
        target->voice = v;
        target->age = 0;
        target->releaseAge = -1;
        target->rate = rate;
        for (int k = 0; k < VOICES_STRIKE_STATE; ++k) target->state[k] = 0.0f;
    }
}

// One output sample: the soft-limited sum of every sounding strike, then advance
// them. A voice with a recorded sample in bank plays that instead of its synth.
static inline float strike_pool_render(StrikePool *pool, double sampleRate, const SampleBank *bank) {
    float out = 0.0f;
    const int releaseSamples = (int)(STRIKE_RELEASE_SECONDS * sampleRate);
    for (int i = 0; i < STRIKE_POOL_MAX; ++i) {
        Strike *s = &pool->slots[i];
        if (s->age < 0) continue;
        const int sampled = samples_has(bank, s->voice);
        float value = sampled ? samples_play(&bank->voices[s->voice], s->age, sampleRate, s->rate)
                              : voices_render(s->voice, s->age, sampleRate, s->state, s->rate);
        int duration = sampled ? samples_duration_samples(&bank->voices[s->voice], sampleRate, s->rate)
                               : voices_duration_samples(s->voice, sampleRate);
        if (s->releaseAge >= 0) {
            value *= 1.0f - (float)(s->age - s->releaseAge) / releaseSamples;
            const int releaseEnd = s->releaseAge + releaseSamples;
            if (releaseEnd < duration) duration = releaseEnd;
        }
        out += value;
        if (++s->age >= duration) s->age = -1;
    }
    return voices_soft_limit(out);
}

#endif // GOTRONOME_STRIKEPOOL_H
