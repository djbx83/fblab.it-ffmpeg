/*
 * NewTek NDI common code
 * Copyright (c) 2017 Maksym Veremeyenko
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

#ifndef AVDEVICE_LIBNDI_NEWTEK_COMMON_H
#define AVDEVICE_LIBNDI_NEWTEK_COMMON_H

#include <Processing.NDI.Lib.h>

/*
 * fblab.it: the NDI runtime is loaded at run time (NDIlib_v6_load / NDIlib_v5_load)
 * instead of being linked, so ffmpeg has no hard dependency on libndi.
 * After a successful ff_ndi_load() every NDIlib_* call below goes through the table.
 */
extern const NDIlib_v5 *ff_ndi_lib;
const NDIlib_v5 *ff_ndi_load(void *log_ctx);

#define NDIlib_initialize                       ff_ndi_lib->initialize
#define NDIlib_destroy                          ff_ndi_lib->destroy
#define NDIlib_find_create_v2                   ff_ndi_lib->find_create_v2
#define NDIlib_find_destroy                     ff_ndi_lib->find_destroy
#define NDIlib_find_get_current_sources         ff_ndi_lib->find_get_current_sources
#define NDIlib_find_wait_for_sources            ff_ndi_lib->find_wait_for_sources
#define NDIlib_recv_capture_v2                  ff_ndi_lib->recv_capture_v2
#define NDIlib_recv_create_v3                   ff_ndi_lib->recv_create_v3
#define NDIlib_recv_destroy                     ff_ndi_lib->recv_destroy
#define NDIlib_recv_free_audio_v2               ff_ndi_lib->recv_free_audio_v2
#define NDIlib_recv_free_metadata               ff_ndi_lib->recv_free_metadata
#define NDIlib_recv_free_video_v2               ff_ndi_lib->recv_free_video_v2
#define NDIlib_recv_set_tally                   ff_ndi_lib->recv_set_tally
#define NDIlib_send_create                      ff_ndi_lib->send_create
#define NDIlib_send_destroy                     ff_ndi_lib->send_destroy
#define NDIlib_send_send_video_async_v2         ff_ndi_lib->send_send_video_async_v2
#define NDIlib_util_audio_to_interleaved_16s_v2 ff_ndi_lib->util_audio_to_interleaved_16s_v2
#define NDIlib_util_send_send_audio_interleaved_16s ff_ndi_lib->util_send_send_audio_interleaved_16s

#define NDI_TIME_BASE 10000000
#define NDI_TIME_BASE_Q (AVRational){1, NDI_TIME_BASE}

#endif
