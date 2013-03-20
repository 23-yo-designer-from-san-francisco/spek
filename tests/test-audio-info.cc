/* test-audio-info.cc
 *
 * Copyright (C) 2013  Alexander Kojevnikov <alexander@kojevnikov.com>
 *
 * Spek is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Spek is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Spek.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <map>

#include "spek-audio.h"

#include "test.h"

struct FileInfo
{
    std::string codec_name;
    int bit_rate;
    int sample_rate;
    int bits_per_sample;
    int channels;
    double duration;
};

static void test_file(const std::string& name, const FileInfo& info)
{
    Audio audio;
    auto file = audio.open(SAMPLES_DIR "/" + name);
    test("error", AudioError::OK, file->get_error());
    test(file->get_codec_name(), true, !file->get_codec_name().compare(
        0, info.codec_name.length(), info.codec_name
    ));
    test("bit rate", info.bit_rate, file->get_bit_rate());
    test("sample rate", info.sample_rate, file->get_sample_rate());
    test("bps", info.bits_per_sample, file->get_bits_per_sample());
    test("channels", info.channels, file->get_channels());
    test("duration", info.duration, file->get_duration());
}

void test_audio_info()
{
    const double MP3_T = 5.0 * 1152 / 44100; // 5 frames * duration per mp3 frame

    std::map<std::string, FileInfo> files = {
        {"1ch-96000Hz-24bps.flac", {"FLAC", 0, 96000, 24, 1, 0.1}},
        {"2ch-48000Hz-16bps.flac", {"FLAC", 0, 48000, 16, 2, 0.1}},
        {"1ch-96000Hz-24bps.ape", {"Monkey", 0, 96000, 24, 1, 0.1}},
        {"2ch-48000Hz-16bps.ape", {"Monkey", 0, 48000, 16, 2, 0.1}},
        {"1ch-96000Hz-24bps.wv", {"WavPack", 0, 96000, 24, 1, 0.1}},
        {"2ch-48000Hz-16bps.wv", {"WavPack", 0, 48000, 16, 2, 0.1}},
        {"2ch-44100Hz-16bps.wav", {"PCM", 0, 44100, 16, 2, 0.1}},
        {"2ch-44100Hz-128cbr.mp3", {"MP3", 128000, 44100, 0, 2, MP3_T}},
        {"2ch-44100Hz-320cbr.mp3", {"MP3", 320000, 44100, 0, 2, MP3_T}},
        {"2ch-44100Hz-V0.mp3", {"MP3", 201329, 44100, 0, 2, MP3_T}},
        {"2ch-44100Hz-V2.mp3", {"MP3", 150124, 44100, 0, 2, MP3_T}},
    };
    for (const auto& item : files) {
        run(
            "audio info: " + item.first,
            [&] () { test_file(item.first, item.second); }
        );
    }
}
