/*
 * Purpose: A small, stable C ABI over whisper.cpp for the app's FFI adapter.
 * Inputs: A model path, PCM samples, and a few plain options per call.
 * Returns: A context handle, segment counts, times and text.
 * Side effects: Loads models, runs inference, and loads ggml's backend
 * libraries from the directory this library itself was loaded from.
 * Notes: whisper.cpp's own API passes a large parameter struct by value,
 * and its layout changes between releases; mirroring it in Dart would turn
 * every upstream update into a silent memory-corruption risk. This shim
 * takes only ints, floats and strings, so the Dart side never depends on a
 * struct layout. Cancellation and progress go through two ints in memory
 * the caller owns, which another Dart isolate can write and read while a
 * transcription is running. See doc/en-us/features/local-models.md.
 */

#include "lasr_whisper.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ggml-backend.h"
#include "whisper.h"

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#else
#include <dlfcn.h>
#endif

#if defined(__APPLE__)
#include <TargetConditionals.h>
#include <mach/mach.h>
#if TARGET_OS_IPHONE
#include <os/proc.h>
#endif
#elif defined(__linux__)
#include <stdio.h>
#endif

struct lasr_context {
    struct whisper_context * ctx;
};

/*
 * Purpose: Find the directory this library was loaded from.
 * Inputs: buf and its size.
 * Returns: 1 when found, 0 otherwise.
 * Side effects: None.
 * Notes: Flutter puts every native library of an app in one directory,
 * but that directory is not the executable's on Android, and not in a
 * `flutter test` run; ggml looks beside the executable by default, so the
 * CPU backends are loaded from here instead.
 */
static int lasr_self_dir(char * buf, size_t size) {
#if defined(_WIN32)
    HMODULE module = NULL;
    if (!GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                                GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                            (LPCSTR) &lasr_self_dir, &module)) {
        return 0;
    }
    DWORD n = GetModuleFileNameA(module, buf, (DWORD) size);
    if (n == 0 || n >= size) return 0;
#else
    Dl_info info;
    if (!dladdr((void *) &lasr_self_dir, &info) || info.dli_fname == NULL) return 0;
    if (strlen(info.dli_fname) >= size) return 0;
    strcpy(buf, info.dli_fname);
#endif
    char * slash = strrchr(buf, '/');
#if defined(_WIN32)
    char * backslash = strrchr(buf, '\\');
    if (backslash && (!slash || backslash > slash)) slash = backslash;
#endif
    if (!slash) return 0;
    *slash = '\0';
    return 1;
}

static int lasr_backends_loaded = 0;
static int lasr_logging = 0;

/*
 * Purpose: Drop whisper.cpp and ggml log lines unless logging was asked for.
 * Inputs: The level, the text, and unused user data.
 * Returns: None.
 * Side effects: Writes to stderr when logging is on.
 * Notes: Both libraries print every load and every run; in an app that is
 * noise on the console of a user who never sees it.
 */
static void lasr_log(enum ggml_log_level level, const char * text, void * user_data) {
    (void) level;
    (void) user_data;
    if (lasr_logging) fputs(text, stderr);
}

LASR_API void lasr_set_logging(int enabled) {
    lasr_logging = enabled;
    whisper_log_set(lasr_log, NULL);
    ggml_log_set(lasr_log, NULL);
}

LASR_API int lasr_load_backends(void) {
    if (lasr_backends_loaded) return (int) ggml_backend_reg_count();
    lasr_backends_loaded = 1;
    whisper_log_set(lasr_log, NULL);
    ggml_log_set(lasr_log, NULL);
    char dir[4096];
    if (lasr_self_dir(dir, sizeof dir)) {
        ggml_backend_load_all_from_path(dir);
    }
    if (ggml_backend_reg_count() == 0) {
        ggml_backend_load_all();
    }
    return (int) ggml_backend_reg_count();
}

/*
 * Purpose: Report how much memory this process could still use.
 * Inputs: None.
 * Returns: Bytes, or -1 when the platform gives no figure.
 * Side effects: Reads OS counters.
 * Notes: The memory guard compares a model's documented need against
 * this before loading, so a model that cannot fit fails with the numbers
 * rather than the system killing the app. Windows: the available physical
 * memory; Linux and Android: MemAvailable; iOS: what the OS will still grant
 * this process; macOS: free plus inactive pages.
 */
LASR_API int64_t lasr_available_memory(void) {
#if defined(_WIN32)
    MEMORYSTATUSEX status;
    status.dwLength = sizeof status;
    if (!GlobalMemoryStatusEx(&status)) return -1;
    return (int64_t) status.ullAvailPhys;
#elif defined(__APPLE__)
#if TARGET_OS_IPHONE
    if (__builtin_available(iOS 13.0, *)) {
        return (int64_t) os_proc_available_memory();
    }
    return -1;
#else
    vm_statistics64_data_t stats;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    if (host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t) &stats, &count) != KERN_SUCCESS) {
        return -1;
    }
    vm_size_t page = 0;
    host_page_size(mach_host_self(), &page);
    return (int64_t) (stats.free_count + stats.inactive_count) * (int64_t) page;
#endif
#elif defined(__linux__)
    FILE * file = fopen("/proc/meminfo", "r");
    if (file == NULL) return -1;
    char line[256];
    long long kb = -1;
    while (fgets(line, sizeof line, file) != NULL) {
        if (sscanf(line, "MemAvailable: %lld kB", &kb) == 1) break;
    }
    fclose(file);
    return kb < 0 ? -1 : (int64_t) kb * 1024;
#else
    return -1;
#endif
}

LASR_API const char * lasr_version(void) {
    return whisper_version();
}

LASR_API const char * lasr_system_info(void) {
    lasr_load_backends();
    return whisper_print_system_info();
}

LASR_API int lasr_device_count(void) {
    lasr_load_backends();
    return (int) ggml_backend_dev_count();
}

LASR_API const char * lasr_device_name(int index) {
    if (index < 0 || (size_t) index >= ggml_backend_dev_count()) return "";
    return ggml_backend_dev_name(ggml_backend_dev_get((size_t) index));
}

LASR_API const char * lasr_device_description(int index) {
    if (index < 0 || (size_t) index >= ggml_backend_dev_count()) return "";
    return ggml_backend_dev_description(ggml_backend_dev_get((size_t) index));
}

LASR_API int lasr_device_type(int index) {
    if (index < 0 || (size_t) index >= ggml_backend_dev_count()) return -1;
    return (int) ggml_backend_dev_type(ggml_backend_dev_get((size_t) index));
}

LASR_API struct lasr_context * lasr_load(const char * model_path, int use_gpu, int flash_attn) {
    lasr_load_backends();
    struct whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = use_gpu != 0;
    cparams.flash_attn = flash_attn != 0;
    struct whisper_context * ctx = whisper_init_from_file_with_params(model_path, cparams);
    if (ctx == NULL) return NULL;
    struct lasr_context * handle = (struct lasr_context *) calloc(1, sizeof *handle);
    if (handle == NULL) {
        whisper_free(ctx);
        return NULL;
    }
    handle->ctx = ctx;
    return handle;
}

LASR_API void lasr_free(struct lasr_context * handle) {
    if (handle == NULL) return;
    whisper_free(handle->ctx);
    free(handle);
}

struct lasr_callbacks {
    volatile int32_t * abort_flag;
    volatile int32_t * progress;
};

static bool lasr_abort(void * user_data) {
    struct lasr_callbacks * cb = (struct lasr_callbacks *) user_data;
    return cb->abort_flag != NULL && *cb->abort_flag != 0;
}

static void lasr_progress(struct whisper_context * ctx, struct whisper_state * state, int progress, void * user_data) {
    (void) ctx;
    (void) state;
    struct lasr_callbacks * cb = (struct lasr_callbacks *) user_data;
    if (cb->progress != NULL) *cb->progress = progress;
}

LASR_API int lasr_transcribe(
        struct lasr_context * handle,
        const float * samples,
        int n_samples,
        const char * language,
        const char * prompt,
        int n_threads,
        volatile int32_t * abort_flag,
        volatile int32_t * progress) {
    if (handle == NULL || samples == NULL || n_samples <= 0) return -1;
    struct lasr_callbacks cb = { abort_flag, progress };

    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.n_threads = n_threads > 0 ? n_threads : 4;
    params.print_progress = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    params.print_special = false;
    params.translate = false;
    params.no_context = true;
    params.language = (language != NULL && language[0] != '\0') ? language : "auto";
    params.detect_language = false;
    params.initial_prompt = (prompt != NULL && prompt[0] != '\0') ? prompt : NULL;
    params.abort_callback = lasr_abort;
    params.abort_callback_user_data = &cb;
    params.progress_callback = lasr_progress;
    params.progress_callback_user_data = &cb;

    int result = whisper_full(handle->ctx, params, samples, n_samples);
    if (result != 0 && abort_flag != NULL && *abort_flag != 0) return 1;
    return result;
}

LASR_API int lasr_n_segments(struct lasr_context * handle) {
    return handle == NULL ? 0 : whisper_full_n_segments(handle->ctx);
}

LASR_API int64_t lasr_segment_t0(struct lasr_context * handle, int index) {
    return whisper_full_get_segment_t0(handle->ctx, index);
}

LASR_API int64_t lasr_segment_t1(struct lasr_context * handle, int index) {
    return whisper_full_get_segment_t1(handle->ctx, index);
}

LASR_API const char * lasr_segment_text(struct lasr_context * handle, int index) {
    return whisper_full_get_segment_text(handle->ctx, index);
}

LASR_API const char * lasr_detected_language(struct lasr_context * handle) {
    if (handle == NULL) return "";
    int id = whisper_full_lang_id(handle->ctx);
    return id < 0 ? "" : whisper_lang_str(id);
}
