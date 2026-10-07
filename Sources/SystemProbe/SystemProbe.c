#include "SystemProbe.h"
#include <IOKit/IOKitLib.h>
#include <libproc.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/sysctl.h>

TMSystemSample tm_read_system(void) {
    TMSystemSample sample = {0};
    size_t size = sizeof(sample.total_bytes);
    bool total_ok = sysctlbyname("hw.memsize", &sample.total_bytes, &size, NULL, 0) == 0;
    mach_port_t host = mach_host_self();
    vm_statistics64_data_t vm = {0};
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    vm_size_t page_size = 0;
    if (total_ok && host_page_size(host, &page_size) == KERN_SUCCESS &&
        host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vm, &count) == KERN_SUCCESS) {
        uint64_t internal = vm.internal_page_count;
        uint64_t purgeable = vm.purgeable_count;
        sample.app_bytes = (internal > purgeable ? internal - purgeable : 0) * page_size;
        sample.wired_bytes = (uint64_t)vm.wire_count * page_size;
        sample.compressed_bytes = (uint64_t)vm.compressor_page_count * page_size;
        sample.cached_bytes = ((uint64_t)vm.external_page_count + purgeable) * page_size;
        sample.used_bytes = sample.app_bytes + sample.wired_bytes + sample.compressed_bytes;
        if (sample.used_bytes > sample.total_bytes) sample.used_bytes = sample.total_bytes;
        sample.memory_valid = true;
    }
    struct xsw_usage swap = {0};
    size = sizeof(swap);
    if (sysctlbyname("vm.swapusage", &swap, &size, NULL, 0) == 0) {
        sample.swap_used_bytes = swap.xsu_used;
        sample.swap_total_bytes = swap.xsu_total;
        sample.swap_valid = true;
    }
    size = sizeof(sample.pressure_level);
    if (sysctlbyname("kern.memorystatus_vm_pressure_level", &sample.pressure_level, &size, NULL, 0) != 0)
        sample.pressure_level = 0;
    host_cpu_load_info_data_t cpu = {0};
    count = HOST_CPU_LOAD_INFO_COUNT;
    if (host_statistics(host, HOST_CPU_LOAD_INFO, (host_info_t)&cpu, &count) == KERN_SUCCESS) {
        sample.cpu_user = cpu.cpu_ticks[CPU_STATE_USER];
        sample.cpu_system = cpu.cpu_ticks[CPU_STATE_SYSTEM];
        sample.cpu_idle = cpu.cpu_ticks[CPU_STATE_IDLE];
        sample.cpu_nice = cpu.cpu_ticks[CPU_STATE_NICE];
        sample.cpu_valid = true;
    }
    mach_port_deallocate(mach_task_self(), host);
    return sample;
}

TMProcessSample *tm_read_processes(size_t *count, size_t *skipped) {
    *count = 0;
    *skipped = 0;
    int estimate = proc_listallpids(NULL, 0);
    if (estimate <= 0 || estimate > 100000) return NULL;
    int capacity = estimate + 256;
    pid_t *pids = calloc((size_t)capacity, sizeof(pid_t));
    if (!pids) return NULL;
    int actual = proc_listallpids(pids, capacity * (int)sizeof(pid_t));
    if (actual <= 0) { free(pids); return NULL; }
    if (actual > capacity) actual = capacity;
    TMProcessSample *samples = calloc((size_t)actual, sizeof(TMProcessSample));
    if (!samples) { free(pids); return NULL; }
    for (int i = 0; i < actual; i++) {
        if (pids[i] <= 0) continue;
        struct rusage_info_v4 usage = {0};
        uint64_t energy = 0;
        bool has_energy = false;
#ifdef RUSAGE_INFO_V6
        struct rusage_info_v6 newest = {0};
        if (proc_pid_rusage(pids[i], RUSAGE_INFO_V6, (rusage_info_t *)&newest) == 0) {
            memcpy(&usage, &newest, sizeof(usage));
            energy = newest.ri_energy_nj;
            has_energy = energy > 0;
        } else
#endif
        if (proc_pid_rusage(pids[i], RUSAGE_INFO_V4, (rusage_info_t *)&usage) != 0) {
            (*skipped)++;
            continue;
        }
        TMProcessSample *row = &samples[(*count)++];
        row->pid = pids[i];
        row->start_time = usage.ri_proc_start_abstime;
        row->cpu_nanoseconds = usage.ri_user_time + usage.ri_system_time;
        row->footprint_bytes = usage.ri_phys_footprint;
        row->energy_nanojoules = energy;
        row->energy_available = has_energy;
        if (proc_name(pids[i], row->name, sizeof(row->name)) <= 0)
            snprintf(row->name, sizeof(row->name), "Process %d", pids[i]);
        row->name[sizeof(row->name) - 1] = '\0';
    }
    free(pids);
    return samples;
}

void tm_free_processes(TMProcessSample *samples) { free(samples); }

double tm_continuous_seconds(void) {
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    return (double)mach_continuous_time() * timebase.numer / timebase.denom / 1e9;
}

/* AppleSMC's read-only wire layout is not a public macOS API. */
typedef struct {
    uint32_t key;
    struct { uint8_t major, minor, build, reserved; uint16_t release; } version;
    struct { uint16_t version, length; uint32_t cpu, gpu, memory; } limits;
    struct { uint32_t size, type; uint8_t attributes; } info;
    uint8_t result, status, command;
    uint32_t argument;
    uint8_t bytes[32];
} TMSMCPacket;

_Static_assert(sizeof(TMSMCPacket) == 80, "Unexpected AppleSMC packet layout");

static uint32_t tm_fourcc(const char *key) {
    return ((uint32_t)(uint8_t)key[0] << 24) | ((uint32_t)(uint8_t)key[1] << 16) |
           ((uint32_t)(uint8_t)key[2] << 8) | (uint8_t)key[3];
}

static bool tm_smc_number(io_connect_t connection, const char *key, double *number) {
    TMSMCPacket input = {0}, output = {0};
    input.key = tm_fourcc(key);
    input.command = 9;
    size_t output_size = sizeof(output);
    if (IOConnectCallStructMethod(connection, 2, &input, sizeof(input), &output, &output_size) != KERN_SUCCESS ||
        output_size != sizeof(output) || output.result != 0 || output.info.size == 0 || output.info.size > 32)
        return false;
    uint32_t type = output.info.type;
    uint32_t data_size = output.info.size;
    input.info.size = data_size;
    input.command = 5;
    memset(&output, 0, sizeof(output));
    output_size = sizeof(output);
    if (IOConnectCallStructMethod(connection, 2, &input, sizeof(input), &output, &output_size) != KERN_SUCCESS ||
        output_size != sizeof(output) || output.result != 0) return false;
    if (type == tm_fourcc("ui8 ") && data_size == 1) *number = output.bytes[0];
    else if (type == tm_fourcc("ui16") && data_size == 2)
        *number = ((uint16_t)output.bytes[0] << 8) | output.bytes[1];
    else if (type == tm_fourcc("ui32") && data_size == 4)
        *number = ((uint32_t)output.bytes[0] << 24) | ((uint32_t)output.bytes[1] << 16) |
                  ((uint32_t)output.bytes[2] << 8) | output.bytes[3];
    else if (type == tm_fourcc("fpe2") && data_size == 2)
        *number = (((uint16_t)output.bytes[0] << 8) | output.bytes[1]) / 4.0;
    else if (type == tm_fourcc("flt ") && data_size == 4) {
        float value;
        memcpy(&value, output.bytes, sizeof(value));
        *number = value;
    } else return false;
    return isfinite(*number) && *number >= 0;
}

TMFanSnapshot tm_read_fans(void) {
    TMFanSnapshot snapshot = {0};
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return snapshot;
    io_connect_t connection = 0;
    kern_return_t status = IOServiceOpen(service, mach_task_self(), 0, &connection);
    IOObjectRelease(service);
    if (status != KERN_SUCCESS) return snapshot;
    double count = 0;
    if (tm_smc_number(connection, "FNum", &count) && count <= 10 && floor(count) == count) {
        snapshot.available = true;
        snapshot.count = (int)count;
        for (int i = 0; i < snapshot.count; i++) {
            char key[5];
            snprintf(key, sizeof(key), "F%dAc", i);
            snapshot.fans[i].index = i;
            snapshot.fans[i].available = tm_smc_number(connection, key, &snapshot.fans[i].rpm);
            if (snapshot.fans[i].rpm > 30000) snapshot.fans[i].available = false;
        }
    }
    IOServiceClose(connection);
    return snapshot;
}
