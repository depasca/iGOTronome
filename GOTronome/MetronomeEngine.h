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

void metronome_start(
                     uint32_t beatsPerMinute,
                     uint32_t beatsPerMeasure,
                     uint32_t numSilentBars,
                     uint32_t numBars,
                     bool silenBarsEnabled
                     );
void metronome_stop(void);

// Query current native state (safe to call from UI thread)
int     metronome_get_current_bar(void);
int     metronome_get_current_beat(void);
float   metronome_get_current_beat_phase(void);

#ifdef __cplusplus
}
#endif

#endif // METRONOME_H
