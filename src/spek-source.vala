using Gst;

namespace Spek {
	public class Source : GLib.Object {

		public string file_name { get; construct; }
		public int bands { get; construct; }
		public int samples { get; construct; }
		// TODO: file a bug, cannot s/set/construct/
		public Callback callback {get; set; }

		public delegate void Callback (int sample, float[] values);

		private Pipeline pipeline = null;
		private Element spectrum = null;
		private Pad pad = null;
		private int sample;
		private float[] values;

		public Source (string file_name, int bands, int samples, Callback callback) {
			GLib.Object (file_name: file_name, bands: bands, samples: samples);
			this.callback = callback;
		}

		~Source () {
			pipeline.set_state (State.NULL);
		}

		construct {
			sample = 0;
			values = new float[bands];

			// TODO: catch errors
			pipeline = new Pipeline ("pipeline");
			var filesrc = ElementFactory.make ("filesrc", null);
			var decodebin = ElementFactory.make ("decodebin", null);
			pipeline.add_many (filesrc, decodebin);
			filesrc.link (decodebin);
			filesrc.set ("location", file_name);

			// decodebin's src pads are not constructed immediately.
			// See gst-plugins-base/tree/gst/playback/test6.c
			Signal.connect (
				decodebin, "new-decoded-pad",
				(GLib.Callback) on_new_decoded_pad, this);

			pipeline.get_bus ().add_watch (on_bus_watch);
			if (pipeline.set_state (State.PAUSED) == StateChangeReturn.ASYNC) {
				pipeline.get_state (null, null, -1);
			}

			// TODO: replace with Pad.query_duration when bgo#617260 is fixed
			var query = new Query.duration (Format.TIME);
			pad.query (query);
			Format format;
			int64 duration;
			query.parse_duration (out format, out duration);
			spectrum.set ("interval", duration / (samples + 1));

			pipeline.set_state (State.PLAYING);
		}

		// TODO: get rid of the last parameter when bgo#615979 is fixed
		private static void on_new_decoded_pad (
			Element decodebin, Pad new_pad, bool last, Source source) {
			if (spectrum != null) {
				// We want to construct the spectrum element only for the first decoded pad.
				return;
			}
			source.spectrum = ElementFactory.make ("spectrum", null);
			source.pipeline.add (source.spectrum);
			var sinkpad = source.spectrum.get_static_pad ("sink");
			source.pad = new_pad;
			source.pad.link (sinkpad);
			source.spectrum.set ("bands", source.bands);
			source.spectrum.set ("threshold", -100);
			source.spectrum.set ("message-magnitude", true);
			source.spectrum.set ("post-messages", true);
			source.spectrum.set_state (State.PAUSED);

			var fakesink = ElementFactory.make ("fakesink", null);
			source.pipeline.add (fakesink);
			source.spectrum.link (fakesink);
			fakesink.set_state (State.PAUSED);
		}

		private bool on_bus_watch (Bus bus, Message message) {
			var structure = message.get_structure ();
			if (message.type == MessageType.ELEMENT && structure.get_name () == "spectrum") {
				var magnitudes = structure.get_value ("magnitude");
				for (int i = 0; i < bands; i++) {
					values[i] = magnitudes.list_get_value (i).get_float ();
				}
				callback (sample++, values);
			}
			return true;
		}
	}
}