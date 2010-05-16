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

		public string file_name { get; private set; }
		private Source source;
		private const int THRESHOLD = -92;
		private const int BANDS = 1024;

		private ImageSurface image;
		private ImageSurface palette;
		private const int PADDING = 40;
		private const int GAP = 10;
		private const int RULER = 10;

		public Spectrogram () {
			// Pre-draw the palette.
			palette = new ImageSurface (Format.RGB24, RULER, BANDS);
			for (int y = 0; y < BANDS; y++) {
				var color = get_color (y / (double) BANDS);
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

		public void save (string file_name) {
			var surface = new ImageSurface (Format.RGB24, allocation.width, allocation.height);
			draw (new Context (surface));
			surface.write_to_png (file_name);
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
				var level = double.min (
					1.0, Math.log10 (1.0 - THRESHOLD + values[y]) / Math.log10 (-THRESHOLD));
				put_pixel (image, sample, y, get_color (level));
			}
			queue_draw_area (PADDING + sample, PADDING, 1, allocation.height - 2 * PADDING);
		}

		private override bool expose_event (EventExpose event) {
			var cr = cairo_create (this.window);

			// Clip to the exposed area.
			cr.rectangle (event.area.x, event.area.y, event.area.width, event.area.height);
			cr.clip ();

			draw (cr);
			return true;
		}

		private void draw (Context cr) {
			double w = allocation.width;
			double h = allocation.height;

			// Clean the background.
			cr.set_source_rgb (0, 0, 0);
			cr.paint ();

			if (image != null) {
				// Draw the spectrogram.
				cr.translate (PADDING, h - PADDING);
				cr.scale (1, -(h - 2 * PADDING) / image.get_height ());
				cr.set_source_surface (image, 0, 0);
				cr.paint ();
				cr.identity_matrix ();

				// Prepare to draw the time ruler.
				cr.set_source_rgb (1, 1, 1);
				cr.set_line_width (1);
				cr.set_antialias (Antialias.NONE);
				cr.select_font_face ("sans-serif", FontSlant.NORMAL, FontWeight.NORMAL);
				cr.set_font_size (10.0);

				// Mesure the label text.
				TextExtents ext;
				cr.text_extents ("00:00", out ext);
				double label_width = ext.width;

				// Select the factor to use, we want some space between the labels.
				int duration_seconds = (int) (source.duration / 1000000000);
				int[] time_factors = {1, 2, 5, 10, 20, 30, 1*60, 2*60, 5*60, 10*60, 20*60, 30*60};
				int time_factor = 0;
				foreach (var factor in time_factors) {
					if (time_to_px (factor, w, duration_seconds) >= 1.5 * label_width) {
						time_factor = factor;
						break;
					}
				}

				// Add the ticks.
				int[] ticks = { 0, duration_seconds };
				if (time_factor > 0) {
					for (var tick = time_factor; tick < duration_seconds; tick += time_factor) {
						ticks += tick;
					}
					// The last item should be skipped, it's too close to the end tick.
					// TODO: `ticks = ticks[0:-1]` crashes, file a bug.
					ticks = ticks[0:ticks.length - 1];
				}

				// Draw the ticks.
				foreach (var tick in ticks) {
					var label = "%d:%02d".printf (tick / 60, tick % 60);
					var pos = PADDING + time_to_px (tick, w, duration_seconds);
					cr.text_extents (label, out ext);
					// TODO: use font measurements instead ext.height
					cr.move_to (pos - ext.width / 2, h - PADDING + GAP + ext.height);
					cr.show_text (label);
					cr.move_to (pos, h - PADDING);
					cr.rel_line_to (0, 4);
					cr.stroke ();
				}
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
		}

		// TODO: factor out the ruler logic and pass this as an anonymous method.
		private double time_to_px (int time, double w, int duration_seconds) {
			return (w - 2 * PADDING) * time / duration_seconds;
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
		private uint32 get_color (double level) {
			level *= 0.6625;
			double r = 0.0, g = 0.0, b = 0.0;
			if (level >= 0 && level < 0.15) {
				r = (0.15 - level) / (0.15 + 0.075);
				g = 0.0;
				b = 1.0;
			} else if (level >= 0.15 && level < 0.275) {
				r = 0.0;
				g = (level - 0.15) / (0.275 - 0.15);
				b = 1.0;
			} else if (level >= 0.275 && level < 0.325) {
				r = 0.0;
				g = 1.0;
				b = (0.325 - level) / (0.325 - 0.275);
			} else if (level >= 0.325 && level < 0.5) {
				r = (level - 0.325) / (0.5 - 0.325);
				g = 1.0;
				b = 0.0;
			} else if (level >= 0.5 && level < 0.6625) {
				r = 1.0;
				g = (0.6625 - level) / (0.6625 - 0.5f);
				b = 0.0;
			}

			// Intensity correction.
			double cf = 1.0;
			if (level >= 0.0 && level < 0.1) {
				cf = level / 0.1;
			}
			cf *= 255.0;

			// Pack RGB values into Cairo-happy format.
			uint32 rr = (uint32) (r * cf + 0.5);
			uint32 gg = (uint32) (g * cf + 0.5);
			uint32 bb = (uint32) (b * cf + 0.5);
			return (rr << 16) + (gg << 8) + bb;
		}
	}
}