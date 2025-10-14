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
                     uint32_t numBars);
void metronome_stop(void);

// Query current native state (safe to call from UI thread)
uint32_t metronome_getCurrentBeatIndex(void);
uint32_t metronome_getCurrentBarIndex(void);
float    metronome_getBeatPhase(void);        // 0.0 .. <1.0
double   metronome_getCurrentTimeSeconds(void);
bool     metronome_is_running(void);

#ifdef __cplusplus
}
#endif

#endif // METRONOME_H
