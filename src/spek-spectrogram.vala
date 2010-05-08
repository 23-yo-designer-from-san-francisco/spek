/* spek-spectrogram.vala
 *
 * Copyright (C) 2010  Alexander Kojevnikov <alexander@kojevnikov.com>
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

using Cairo;
using Gdk;
using Gtk;

namespace Spek {
	class Spectrogram : DrawingArea {

		private Source source;
		private string file_name;
		private const int THRESHOLD = -92;
		private const int BANDS = 1024;

		private ImageSurface image;
		private ImageSurface palette;
		private const int PADDING = 60;
		private const int GAP = 10;
		private const int RULER = 10;

		public Spectrogram () {
			// Pre-draw the palette.
			palette = new ImageSurface (Format.RGB24, RULER, BANDS);
			for (int y = 0; y < BANDS; y++) {
				var color = get_color (y / (float) BANDS);
				for (int x = 0; x < RULER; x++) {
					put_pixel (palette, x, y, color);
				}
			}
			show_all ();
		}

		public void open (string file_name) {
			this.file_name = file_name;
			start ();
		}

		private void start () {
			// The number of samples is the number of pixels available for the image.
			// The number of bands is fixed, FFT results are very different for
			// different values but we need some consistency.
			this.image = new ImageSurface (Format.RGB24, allocation.width - 2 * PADDING, BANDS);

			if (this.source != null) {
				this.source.stop ();
			}
			this.source = new Source (
				file_name, image.get_height (), image.get_width (),
				THRESHOLD, source_callback);
			queue_draw ();
		}

		private override void size_allocate (Gdk.Rectangle allocation) {
			base.size_allocate (allocation);

			if (file_name != null) {
				start ();
			}
		}

		private void source_callback (int sample, float[] values) {
			for (int y = 0; y < values.length; y++) {
				var level = float.min (
					1f, Math.log10f (1f - THRESHOLD + values[y]) / Math.log10f (-THRESHOLD));
				put_pixel (image, sample, y, get_color (level));
			}
			queue_draw_area (PADDING + sample, PADDING, 1, allocation.height - 2 * PADDING);
		}

		private override bool expose_event (EventExpose event) {
			double w = allocation.width;
			double h = allocation.height;

			var cr = cairo_create (this.window);

			// Clip to the exposed area.
			cr.rectangle (event.area.x, event.area.y, event.area.width, event.area.height);
			cr.clip ();

			// Clean the background.
			cr.set_source_rgb (0, 0, 0);
			cr.paint ();

			// Draw the spectrogram.
			if (image != null) {
				cr.translate (PADDING, h - PADDING);
				cr.scale (1, -(h - 2 * PADDING) / image.get_height ());
				cr.set_source_surface (image, 0, 0);
				cr.paint ();
				cr.identity_matrix ();
			}

			// Border around the spectrogram.
			cr.set_source_rgb (1, 1, 1);
			cr.set_line_width (1);
			cr.set_antialias (Antialias.NONE);
			cr.rectangle (PADDING, PADDING, w - 2 * PADDING, h - 2 * PADDING);
			cr.stroke ();

			// The palette.
			cr.translate (w - PADDING + GAP, h - PADDING);
			cr.scale (1, -(h - 2 * PADDING) / palette.get_height ());
			cr.set_source_surface (palette, 0, 0);
			cr.paint ();
			cr.identity_matrix ();

			return true;
		}

		private void put_pixel (ImageSurface surface, int x, int y, uint32 color) {
			var i = y * surface.get_stride () + x * 4;
			unowned uchar[] data = surface.get_data ();

			// Translate uchar* to uint32* to avoid dealing with endianness.
			uint32 *p = &data[i];
			*p = color;
		}

		// Modified version of Dan Bruton's algorithm:
		// http://www.physics.sfasu.edu/astro/color/spectra.html
		private uint32 get_color (float level) {
			level *= 0.6625f;
			float r = 0.0f, g = 0.0f, b = 0.0f;
			if (level >= 0f && level < 0.15f) {
				r = (0.15f - level) / (0.15f + 0.075f);
				g = 0.0f;
				b = 1.0f;
			} else if (level >= 0.15f && level < 0.275f) {
				r = 0.0f;
				g = (level - 0.15f) / (0.275f - 0.15f);
				b = 1.0f;
			} else if (level >= 0.275f && level < 0.325f) {
				r = 0.0f;
				g = 1.0f;
				b = (0.325f - level) / (0.325f - 0.275f);
			} else if (level >= 0.325f && level < 0.5f) {
				r = (level - 0.325f) / (0.5f - 0.325f);
				g = 1.0f;
				b = 0.0f;
			} else if (level >= 0.5f && level < 0.6625f) {
				r = 1.0f;
				g = (0.6625f - level) / (0.6625f - 0.5f);
				b = 0.0f;
			}

			// Intensity correction.
			float cf = 1.0f;
			if (level >= 0 && level < 0.1f) {
				cf = level / 0.1f;
			}
			cf *= 255f;

			// Pack RGB values into Cairo-happy format.
			uint32 rr = (uint32) (r * cf + 0.5f);
			uint32 gg = (uint32) (g * cf + 0.5f);
			uint32 bb = (uint32) (b * cf + 0.5f);
			return (rr << 16) + (gg << 8) + bb;
		}
	}
}