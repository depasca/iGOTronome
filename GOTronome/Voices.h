//
//  Voices.h
//  GOTronome
//
//  Synthesized percussion voices, shared in spirit with the Android app's
//  Voices.h: every voice is a function of the samples since it was struck plus
//  a small explicitly passed state block for voices that need filter memory.
//  Plain C99 with no Apple dependency, so it also builds on the host for
//  listening and parity checks.
//

#ifndef GOTRONOME_VOICES_H
#define GOTRONOME_VOICES_H

#include <math.h>
#include <stdint.h>

enum Voice {
    VOICE_BLIP_HI = 1 << 0,
    VOICE_BLIP_LO = 1 << 1,
    VOICE_KICK = 1 << 2,
    VOICE_SNARE = 1 << 3,
    VOICE_HAT_CLOSED = 1 << 4,
    VOICE_HAT_PEDAL = 1 << 5,
    VOICE_RIDE = 1 << 6,
    VOICE_CROSS_STICK = 1 << 7,
    VOICE_BASS = 1 << 8,
};

#define VOICES_NUM 9
#define VOICES_STRIKE_STATE 200  // floats of per-strike memory available to a voice

static const float kVoicesPi = 3.14159265358979f;
static const float kBlipSeconds = 0.01f;

// Bit position of a single Voice flag, e.g. voices_index(VOICE_RIDE) == 6.
static inline int voices_index(int voiceBit) {
    int index = 0;
    while (index < VOICES_NUM - 1 && !(voiceBit & (1 << index))) ++index;
    return index;
}

// The click envelope the iOS app has always used: 2 ms attack, 8 ms release.
static inline float voices_blip_envelope(float t, float duration) {
    const float attack = 0.002f;
    const float release = 0.008f;
    if (t < attack) return t / attack;
    else if (t > duration - release) return (duration - t) / release;
    else return 1.0f;
}

static inline float voices_decay(float t, float tau) { return expf(-t / tau); }

// Deterministic white noise: a hash of (sample index, voice) in [-1, 1].
static inline float voices_noise(int age, int voice) {
    uint32_t h = (uint32_t)age * 0x9E3779B1u ^ (uint32_t)voice * 0x85EBCA77u;
    h ^= h >> 15; h *= 0x2C1B3C6Du; h ^= h >> 12; h *= 0x297A2D39u; h ^= h >> 15;
    return (float)h / 2147483648.0f - 1.0f;
}

// First difference of the noise: a cheap first-order high-pass for bright, tinny sounds.
static inline float voices_bright_noise(int age, int voice) {
    return 0.5f * (voices_noise(age, voice) - voices_noise(age - 1, voice));
}

static inline float voices_blip(int age, double sampleRate, float freq, float volume) {
    const float duration = (float)((int)(sampleRate * kBlipSeconds) / sampleRate);
    const float t = (float)(age / sampleRate);
    return volume * voices_blip_envelope(t, duration) * sinf(2.0f * kVoicesPi * freq * t);
}

// Sine whose pitch falls from fStart to fEnd with time constant tau; the phase
// is the closed-form integral of that frequency curve.
static inline float voices_swept_sine(float t, float fStart, float fEnd, float tau) {
    const float phase = 2.0f * kVoicesPi * (fEnd * t + (fStart - fEnd) * tau * (1.0f - expf(-t / tau)));
    return sinf(phase);
}

static inline float voices_kick(float t) {
    return 0.7f * voices_decay(t, 0.09f) * voices_swept_sine(t, 160.0f, 48.0f, 0.03f);
}

static inline float voices_snare(float t, int age) {
    const float body = 0.4f * voices_decay(t, 0.04f) * sinf(2.0f * kVoicesPi * 185.0f * t);
    const float wires = 0.3f * voices_decay(t, 0.06f) * voices_noise(age, VOICE_SNARE);
    return body + wires;
}

static inline float voices_hat_closed(float t, int age) {
    return 0.5f * voices_decay(t, 0.015f) * voices_bright_noise(age, VOICE_HAT_CLOSED);
}

// Foot "chick": darker and rounder than the stick hat, with enough body to mark 2 and 4.
static inline float voices_hat_pedal(float t, int age) {
    const float dark = 0.6f * voices_noise(age, VOICE_HAT_PEDAL) + 0.4f * voices_bright_noise(age, VOICE_HAT_PEDAL);
    return 0.5f * voices_decay(t, 0.025f) * dark;
}

// Modal resonator on st = {c1, c2, y1, y2, gain}: a two-pole filter that, hit
// with an impulse, rings as a decaying sine at freq with amplitude time constant tau.
static inline void voices_tune_mode(float *st, float freq, float tau, float amplitude, double sampleRate) {
    const float sr = (float)sampleRate;
    const float r = expf(-1.0f / (tau * sr));
    const float theta = 2.0f * kVoicesPi * freq / sr;
    st[0] = 2.0f * r * cosf(theta);
    st[1] = -r * r;
    st[2] = 0.0f;
    st[3] = 0.0f;
    st[4] = amplitude * sinf(theta);
}

static inline float voices_ring_mode(float *st, float x) {
    const float y = x + st[0] * st[2] + st[1] * st[3];
    st[3] = st[2];
    st[2] = y;
    return st[4] * y;
}

// Synthesized ride, used only when no recorded ride sample is loaded: forty
// narrow inharmonic modes excited by a short noise burst.
#define VOICES_RIDE_MODES 40
#define VOICES_RIDE_MODE_FLOATS 5

static inline void voices_tune_ride(float *state, double sampleRate) {
    for (int k = 0; k < VOICES_RIDE_MODES; ++k) {
        const float pos = (float)k / (VOICES_RIDE_MODES - 1);
        const float grid = 700.0f * powf(10000.0f / 700.0f, pos);
        const float freq = grid * (1.0f + 0.10f * voices_noise(k, VOICE_RIDE));
        const float tau = 1.4f * powf(700.0f / freq, 0.6f);
        const float logRatio = logf(freq / 3500.0f);
        const float weight = expf(-logRatio * logRatio / (2.0f * 0.7f * 0.7f)) + 0.25f;
        const float amplitude = weight * (1.0f + 0.3f * voices_noise(k + 100, VOICE_RIDE));
        voices_tune_mode(state + VOICES_RIDE_MODE_FLOATS * k, freq, tau, amplitude, sampleRate);
    }
}

static inline float voices_ride(float t, int age, double sampleRate, float *state) {
    if (age == 0) voices_tune_ride(state, sampleRate);
    const float burst = voices_decay(t, 0.004f);
    const float trickle = 0.006f * voices_decay(t, 0.5f);
    const float excite = voices_noise(age, VOICE_RIDE) * (burst + trickle);
    float out = 0.0f;
    for (int k = 0; k < VOICES_RIDE_MODES; ++k) out += voices_ring_mode(state + VOICES_RIDE_MODE_FLOATS * k, excite);
    const float stick = 0.15f * voices_decay(t, 0.003f) * voices_bright_noise(age, VOICE_RIDE);
    return 0.008f * out + stick;
}

// Pitched voices play one note at a time: a new strike fades the previous one out.
static inline int voices_is_monophonic(int voiceIndex) { return (1 << voiceIndex) == VOICE_BASS; }

// Placeholder plucked bass at A1 when no recorded note is loaded; rate is the
// pitch multiplier, 2^(semitones/12). Harmonics decay faster the higher they are.
static const float kBassBaseHz = 55.0f;

static inline float voices_bass(float t, int age, float rate) {
    const float f = kBassBaseHz * rate;
    const float amps[6] = {1.0f, 0.5f, 0.33f, 0.2f, 0.12f, 0.08f};
    float body = 0.0f;
    for (int n = 1; n <= 6; ++n) body += amps[n - 1] * voices_decay(t, 0.9f / n) * sinf(2.0f * kVoicesPi * f * n * t);
    const float attack = 1.0f - voices_decay(t, 0.003f);
    const float thump = 0.15f * voices_decay(t, 0.01f) * voices_noise(age, VOICE_BASS);
    return 0.22f * body * attack + thump;
}

static inline float voices_cross_stick(float t, int age) {
    const float wood = 0.35f * voices_decay(t, 0.012f) *
                       (sinf(2.0f * kVoicesPi * 1250.0f * t) + 0.5f * sinf(2.0f * kVoicesPi * 2600.0f * t));
    const float click = 0.15f * voices_decay(t, 0.004f) * voices_noise(age, VOICE_CROSS_STICK);
    return wood + click;
}

static inline float voices_duration_seconds(int voiceBit) {
    switch (voiceBit) {
        case VOICE_BLIP_HI:
        case VOICE_BLIP_LO: return kBlipSeconds;
        case VOICE_KICK: return 0.30f;
        case VOICE_SNARE: return 0.25f;
        case VOICE_HAT_CLOSED: return 0.07f;
        case VOICE_HAT_PEDAL: return 0.12f;
        case VOICE_RIDE: return 2.00f;
        case VOICE_CROSS_STICK: return 0.06f;
        case VOICE_BASS: return 1.5f;
        default: return 0.0f;
    }
}

static inline int voices_duration_samples(int voiceIndex, double sampleRate) {
    return (int)(sampleRate * voices_duration_seconds(1 << voiceIndex));
}

// Sample `age` of voice number voiceIndex (0..VOICES_NUM-1). `state` is the
// strike's VOICES_STRIKE_STATE floats, zeroed when it was struck; `rate` the
// pitch multiplier for pitched voices.
static inline float voices_render(int voiceIndex, int age, double sampleRate, float *state, float rate) {
    const float t = (float)(age / sampleRate);
    switch (1 << voiceIndex) {
        case VOICE_BLIP_HI: return voices_blip(age, sampleRate, 1760.0f, 0.5f);
        case VOICE_BLIP_LO: return voices_blip(age, sampleRate, 880.0f, 0.3f);
        case VOICE_KICK: return voices_kick(t);
        case VOICE_SNARE: return voices_snare(t, age);
        case VOICE_HAT_CLOSED: return voices_hat_closed(t, age);
        case VOICE_HAT_PEDAL: return voices_hat_pedal(t, age);
        case VOICE_RIDE: return voices_ride(t, age, sampleRate, state);
        case VOICE_CROSS_STICK: return voices_cross_stick(t, age);
        case VOICE_BASS: return voices_bass(t, age, rate);
        default: return 0.0f;
    }
}

// Transparent below the knee, then a smooth tanh shoulder that never reaches
// full scale. The metronome blips peak at 0.5 and pass through untouched.
static inline float voices_soft_limit(float x) {
    const float knee = 0.8f;
    const float mag = fabsf(x);
    if (mag <= knee) return x;
    const float shaped = knee + (1.0f - knee) * tanhf((mag - knee) / (1.0f - knee));
    return x < 0 ? -shaped : shaped;
}

#endif // GOTRONOME_VOICES_H
