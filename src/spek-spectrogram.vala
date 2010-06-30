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
using Pango;

namespace Spek {
	class Spectrogram : DrawingArea {

		public string file_name { get; private set; }
		private Source source;
		private string info;
		private const int THRESHOLD = -92;
		// For faster FFT BANDS*2-2 should be a multiple of 2,3,5
		private const int BANDS = 1025;

		private ImageSurface image;
		private ImageSurface palette;

		private const int LPAD = 60;
		private const int TPAD = 60;
		private const int RPAD = 60;
		private const int BPAD = 40;
		private const int GAP = 10;
		private const int RULER = 10;
		private double FONT_SCALE = 1.0;

		public Spectrogram () {
			// Pango/Quartz fonts are smaller than on X.
			if (Config.HOST_OS.down ().has_prefix ("darwin")) {
				FONT_SCALE = 1.4;
			}

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
			this.info = "";

			// TODO
			var pipeline = new Pipeline (file_name);
			print ("%s:\nbr=%i sr=%i ch=%i\n\n", pipeline.file_name, pipeline.bit_rate, pipeline.sample_rate, pipeline.channels);

			start ();
		}

		public void save (string file_name) {
			var surface = new ImageSurface (Format.RGB24, allocation.width, allocation.height);
			draw (new Cairo.Context (surface));
			surface.write_to_png (file_name);
		}

		private void start () {
			if (this.source != null) {
				this.source.stop ();
			}

			// The number of samples is the number of pixels available for the image.
			// The number of bands is fixed, FFT results are very different for
			// different values but we need some consistency.
			int samples = allocation.width - LPAD - RPAD;
			if (samples > 0) {
				image = new ImageSurface (Format.RGB24, samples, BANDS);
				source = new Source (file_name, BANDS, samples, THRESHOLD, data_cb, info_cb);
			} else {
				image = null;
				source = null;
			}
			queue_draw ();
		}

		private override void size_allocate (Gdk.Rectangle allocation) {
			base.size_allocate (allocation);

			if (file_name != null) {
				start ();
			}
		}

		private void data_cb (int sample, float[] values) {
			for (int y = 0; y < values.length; y++) {
				var level = double.min (
					1.0, Math.log10 (1.0 - THRESHOLD + values[y]) / Math.log10 (-THRESHOLD));
				put_pixel (image, sample, y, get_color (level));
			}
			queue_draw_area (LPAD + sample, TPAD, 1, allocation.height - TPAD - BPAD);
		}

		private void info_cb () {
			string[] items = {};
			if (source.audio_codec != null) {
				items += source.audio_codec;
			}
			if (source.bitrate != 0) {
				items += _("%d kbps").printf (source.bitrate / 1000);
			}
			if (source.rate != 0) {
				items += _("%d Hz").printf (source.rate);
			}
			// Show sample rate only if there is no bitrate.
			if (source.depth != 0 && source.bitrate == 0) {
				items += ngettext ("%d bit", "%d bits", source.depth).printf (source.depth);
			}
			if (source.channels != 0) {
				items += ngettext ("%d channel", "%d channels", source.channels).
					printf (source.channels);
			}
			if (items.length > 0) {
				info = string.joinv (", ", items);
				queue_draw_area (LPAD, 0, allocation.width - LPAD - RPAD, TPAD);
			}
		}

		private override bool expose_event (EventExpose event) {
			var cr = cairo_create (this.window);

			// Clip to the exposed area.
			cr.rectangle (event.area.x, event.area.y, event.area.width, event.area.height);
			cr.clip ();

			draw (cr);
			return true;
		}

		private void draw (Cairo.Context cr) {
			double w = allocation.width;
			double h = allocation.height;

			// Clean the background.
			cr.set_source_rgb (0, 0, 0);
			cr.paint ();

			if (image != null) {
				// Draw the spectrogram.
				cr.translate (LPAD, h - BPAD);
				cr.scale (1, -(h - TPAD - BPAD) / image.get_height ());
				cr.set_source_surface (image, 0, 0);
				cr.paint ();
				cr.identity_matrix ();

				// Prepare to draw the rulers.
				cr.set_source_rgb (1, 1, 1);
				cr.set_line_width (1);
				cr.set_antialias (Antialias.NONE);
				var layout = cairo_create_layout (cr);
				layout.set_font_description (FontDescription.from_string (
					"Sans " + (8 * FONT_SCALE).to_string ()));
				layout.set_width (-1);

				// Time ruler.
				var duration_seconds = (int) (source.duration / 1000000000);
				var time_ruler = new Ruler (
					"00:00",
					{1, 2, 5, 10, 20, 30, 1*60, 2*60, 5*60, 10*60, 20*60, 30*60},
					duration_seconds,
					1.5,
					unit => (w - LPAD - RPAD) * unit / duration_seconds,
					unit => "%d:%02d".printf (unit / 60, unit % 60));
				cr.translate (LPAD, h - BPAD);
				time_ruler.draw (cr, layout, true);
				cr.identity_matrix ();

				// Frequency ruler.
				var freq = source.rate / 2;
				var rate_ruler = new Ruler (
					"00 kHz",
					{1000, 2000, 5000, 10000, 20000},
					freq,
					3.0,
					unit => (h - TPAD - BPAD) * unit / freq,
					unit => "%d kHz".printf (unit / 1000));
				cr.translate (LPAD, TPAD);
				rate_ruler.draw (cr, layout, false);
				cr.identity_matrix ();

				// File properties.
				cr.move_to (LPAD, TPAD - GAP);
				layout.set_font_description (FontDescription.from_string (
					"Sans " + (9 * FONT_SCALE).to_string ()));
				layout.set_width ((int) (w - LPAD - RPAD) * Pango.SCALE);
				layout.set_ellipsize (EllipsizeMode.END);
				layout.set_text (info, -1);
				cairo_show_layout_line (cr, layout.get_line (0));
				int text_width, text_height;
				layout.get_pixel_size (out text_width, out text_height);

				// File name.
				cr.move_to (LPAD, TPAD - 2 * GAP - text_height);
				layout.set_font_description (FontDescription.from_string (
					"Sans Bold " + (10 * FONT_SCALE).to_string ()));
				layout.set_width ((int) (w - LPAD - RPAD) * Pango.SCALE);
				layout.set_ellipsize (EllipsizeMode.START);
				layout.set_text (file_name, -1);
				cairo_show_layout_line (cr, layout.get_line (0));
			}

			// Border around the spectrogram.
			cr.set_source_rgb (1, 1, 1);
			cr.set_line_width (1);
			cr.set_antialias (Antialias.NONE);
			cr.rectangle (LPAD, TPAD, w - LPAD - RPAD, h - TPAD - BPAD);
			cr.stroke ();

			// The palette.
			cr.translate (w - RPAD + GAP, h - BPAD);
			cr.scale (1, -(h - TPAD - BPAD) / palette.get_height ());
			cr.set_source_surface (palette, 0, 0);
			cr.paint ();
			cr.identity_matrix ();
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
