/*
 * Purpose: The C ABI the app's Dart adapter calls; see lasr_whisper.c.
 * Inputs: None.
 * Returns: Declarations only.
 * Side effects: None.
 * Notes: Plain types only, so no Dart code depends on a whisper.cpp struct
 * layout. Return codes: 0 success, 1 cancelled, anything else a failure.
 */

#ifndef LASR_WHISPER_H
#define LASR_WHISPER_H

#include <stdint.h>

#if defined(_WIN32)
#define LASR_API __declspec(dllexport)
#else
#define LASR_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

struct lasr_context;

/* Load ggml's backends from this library's own directory; returns how many
 * backend registries there are afterwards. Safe to call more than once. */
LASR_API int lasr_load_backends(void);

/* Print whisper.cpp and ggml log lines to stderr (off by default). */
LASR_API void lasr_set_logging(int enabled);

/* Bytes this process could still use, or -1 when unknown. */
LASR_API int64_t lasr_available_memory(void);

LASR_API const char * lasr_version(void);
LASR_API const char * lasr_system_info(void);

/* The compute devices ggml found: name, description, and type
 * (0 CPU, 1 GPU, 2 integrated GPU, 3 accelerator). */
LASR_API int lasr_device_count(void);
LASR_API const char * lasr_device_name(int index);
LASR_API const char * lasr_device_description(int index);
LASR_API int lasr_device_type(int index);

/* Load a model; NULL on failure. */
LASR_API struct lasr_context * lasr_load(const char * model_path, int use_gpu, int flash_attn);
LASR_API void lasr_free(struct lasr_context * handle);

/* Transcribe 16 kHz mono float samples. abort_flag is polled; progress
 * receives 0-100. Both point at memory the caller owns and may be NULL. */
LASR_API int lasr_transcribe(
        struct lasr_context * handle,
        const float * samples,
        int n_samples,
        const char * language,
        const char * prompt,
        int n_threads,
        volatile int32_t * abort_flag,
        volatile int32_t * progress);

LASR_API int lasr_n_segments(struct lasr_context * handle);
/* Segment times in centiseconds, as whisper.cpp reports them. */
LASR_API int64_t lasr_segment_t0(struct lasr_context * handle, int index);
LASR_API int64_t lasr_segment_t1(struct lasr_context * handle, int index);
LASR_API const char * lasr_segment_text(struct lasr_context * handle, int index);
LASR_API const char * lasr_detected_language(struct lasr_context * handle);

#ifdef __cplusplus
}
#endif

#endif
