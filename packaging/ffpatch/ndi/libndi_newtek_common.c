/*
 * NewTek NDI runtime loader (fblab.it)
 *
 * The NDI SDK only ships dynamic libraries; open-source projects are expected
 * to load them at run time through NDIlib_vX_load() (Processing.NDI.DynamicLoad.h).
 * ffmpeg therefore keeps no link-time dependency on libndi: the runtime is
 * looked up only when the libndi_newtek device is opened.
 *
 * This file is part of FFmpeg.
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#include "config.h"

#include <stdio.h>
#include <stdlib.h>

#include "libavutil/avstring.h"
#include "libavutil/log.h"
#include "libavutil/thread.h"

#include "libndi_newtek_common.h"

#ifdef _WIN32
#include "compat/w32dlfcn.h"
#define NDI_LIB_NAME     NDILIB_LIBRARY_NAME   /* Processing.NDI.Lib.x64.dll */
#else
#include <dlfcn.h>
#define NDI_LIB_NAME     "libndi.so.6"
#define NDI_LIB_NAME_V5  "libndi.so.5"
#define NDI_LIB_NAME_ANY "libndi.so"
#endif

typedef const NDIlib_v5 *(*ndi_load_fn)(void);

const NDIlib_v5 *ff_ndi_lib;

static AVOnce ndi_once = AV_ONCE_INIT;
static char   ndi_tried[1024];

static void *ndi_open(const char *path)
{
    void *h;
#ifdef _WIN32
    wchar_t *wpath;
    if (utf8towchar(path, &wpath))
        return NULL;
    /* absolute path from NDI_RUNTIME_DIR_*: let the DLL find its own dependencies */
    h = LoadLibraryExW(wpath, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    av_free(wpath);
#else
    h = dlopen(path, RTLD_NOW | RTLD_LOCAL);
#endif
    av_strlcatf(ndi_tried, sizeof(ndi_tried), "\n    %s: %s", path, h ? "ok" : "not found");
    return h;
}

static void *ndi_open_dir(const char *env, const char *name)
{
    const char *dir = getenv(env);
    char path[1024];
    if (!dir || !*dir)
        return NULL;
#ifdef _WIN32
    snprintf(path, sizeof(path), "%s\\%s", dir, name);
#else
    snprintf(path, sizeof(path), "%s/%s", dir, name);
#endif
    return ndi_open(path);
}

static void ndi_do_load(void)
{
    void *h = NULL;
    ndi_load_fn load = NULL;

    /* 1. the folder the NDI runtime installer advertises */
#ifdef _WIN32
    if (!h) h = ndi_open_dir("NDI_RUNTIME_DIR_V6", NDI_LIB_NAME);
    if (!h) h = ndi_open_dir("NDI_RUNTIME_DIR_V5", NDI_LIB_NAME);
#else
    if (!h) h = ndi_open_dir("NDI_RUNTIME_DIR_V6", NDI_LIB_NAME);
    if (!h) h = ndi_open_dir("NDI_RUNTIME_DIR_V5", NDI_LIB_NAME_V5);
#endif
#ifdef _WIN32
    /* 2. next to ffmpeg.exe or in System32 (safe search, no cwd/PATH) */
    if (!h) {
        h = win32_dlopen(NDI_LIB_NAME);
        av_strlcatf(ndi_tried, sizeof(ndi_tried), "\n    %s (exe dir, System32): %s",
                    NDI_LIB_NAME, h ? "ok" : "not found");
    }
#else
    /* 2. standard dynamic linker search (ld.so.cache, LD_LIBRARY_PATH) */
    if (!h) h = ndi_open(NDI_LIB_NAME);
    if (!h) h = ndi_open(NDI_LIB_NAME_V5);
    if (!h) h = ndi_open(NDI_LIB_NAME_ANY);
#endif
    if (!h)
        return;

#ifdef _WIN32
    load = (ndi_load_fn)(void *)GetProcAddress(h, "NDIlib_v6_load");
    if (!load)
        load = (ndi_load_fn)(void *)GetProcAddress(h, "NDIlib_v5_load");
#else
    load = (ndi_load_fn)dlsym(h, "NDIlib_v6_load");
    if (!load)
        load = (ndi_load_fn)dlsym(h, "NDIlib_v5_load");
#endif
    if (!load) {
        av_strlcat(ndi_tried, "\n    NDIlib_v6_load/NDIlib_v5_load: symbol not found", sizeof(ndi_tried));
        return;
    }
    ff_ndi_lib = load();
    if (!ff_ndi_lib)
        av_strlcat(ndi_tried, "\n    NDIlib_vX_load() returned NULL", sizeof(ndi_tried));
}

const NDIlib_v5 *ff_ndi_load(void *log_ctx)
{
    ff_thread_once(&ndi_once, ndi_do_load);
    if (!ff_ndi_lib)
        av_log(log_ctx, AV_LOG_ERROR,
               "NDI runtime not available, install the NDI Runtime (https://ndi.video/tools/).%s\n",
               ndi_tried);
    return ff_ndi_lib;
}
