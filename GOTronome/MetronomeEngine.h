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
