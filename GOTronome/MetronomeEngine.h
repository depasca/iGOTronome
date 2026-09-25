//
//  MetronomeEngine.h
//  GOTronome
//
//  Created by Paolo De Pascalis on 01.10.25.
//

#ifndef METRONOME_H
#define METRONOME_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define METRONOME_MAX_BEATS 16
#define METRONOME_MAX_STEPS_PER_BEAT 4
#define METRONOME_MAX_STEPS (METRONOME_MAX_BEATS * METRONOME_MAX_STEPS_PER_BEAT)

void metronome_start(
                     uint32_t beatsPerMinute,
                     uint32_t beatsPerMeasure,
                     uint32_t numSilentBars,
                     uint32_t numBars,
                     bool silenBarsEnabled,
                     bool countInEnabled
                     );
void metronome_stop(void);

// Set the per-beat level pattern: 2 = accent, 1 = normal, 0 = mute. Beats
// beyond `count` fall back to normal. Safe to call from the UI thread.
void metronome_set_accent_pattern(const int *pattern, int count);

// A groove is stepsPerBeat sub-steps per beat, each a bitmask of voices (see
// Voices.h), laid out beat-major for a whole measure. stepsPerBeat == 0 selects
// the Metronome style: one blip per beat chosen from the accent pattern. Safe
// to call from the UI thread; takes effect on the next beat.
void metronome_set_groove(int stepsPerBeat, const int *stepVoices, int count);

// Give voice number voiceIndex (bit position of its Voice flag) a recorded
// one-shot: mono float frames in -1..1 at `rate` Hz. Copies the frames. Must be
// called while stopped; returns false and does nothing otherwise.
bool metronome_load_sample(int voiceIndex, const float *frames, int length, int rate);

// Rebuild the output audio unit on the current route without disturbing the
// transport, so the click keeps its place across a device disconnect.
void metronome_restart_audio(void);

// Query current native state (safe to call from UI thread)
int     metronome_get_current_bar(void);
int     metronome_get_current_beat(void);
float   metronome_get_current_beat_phase(void);
bool    metronome_get_is_silent_bar(void);
bool    metronome_get_is_counting_in(void);

#ifdef __cplusplus
}
#endif

#endif // METRONOME_H
