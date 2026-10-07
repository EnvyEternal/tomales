#ifndef TOMALES_SYSTEM_PROBE_H
#define TOMALES_SYSTEM_PROBE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
    bool memory_valid;
    bool swap_valid;
    bool cpu_valid;
    uint64_t total_bytes;
    uint64_t used_bytes;
    uint64_t app_bytes;
    uint64_t wired_bytes;
    uint64_t compressed_bytes;
    uint64_t cached_bytes;
    uint64_t swap_used_bytes;
    uint64_t swap_total_bytes;
    uint64_t cpu_user;
    uint64_t cpu_system;
    uint64_t cpu_idle;
    uint64_t cpu_nice;
    int pressure_level;
} TMSystemSample;

typedef struct {
    int32_t pid;
    uint64_t start_time;
    uint64_t cpu_nanoseconds;
    uint64_t footprint_bytes;
    uint64_t energy_nanojoules;
    bool energy_available;
    char name[256];
} TMProcessSample;

typedef struct {
    int index;
    bool available;
    double rpm;
} TMFanSample;

typedef struct {
    bool available;
    int count;
    TMFanSample fans[10];
} TMFanSnapshot;

TMSystemSample tm_read_system(void);
TMProcessSample *tm_read_processes(size_t *count, size_t *skipped);
void tm_free_processes(TMProcessSample *samples);
TMFanSnapshot tm_read_fans(void);
double tm_continuous_seconds(void);

#endif
