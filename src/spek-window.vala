/* spek-window.vala
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

using Gdk;
using Gtk;

namespace Spek {
	public class Window : Gtk.Window {

		private MessageBar message_bar;
		private Spectrogram spectrogram;
		private string cur_dir;
		private FileFilter filter_all;
		private FileFilter filter_audio;
		private FileFilter filter_png;
		private const Gtk.TargetEntry[] DEST_TARGET_ENTRIES = {
			{ "text/uri-list", 0, 0 }
		};

		public Window (string? file_name) {
		        title = _("Spek - Acoustic Spectrum Analyser");
			set_default_icon_name ("spek");
			set_default_size (640, 480);
			destroy.connect (Gtk.main_quit);

			var group = new AccelGroup ();
			add_accel_group (group);

			var toolbar = new Toolbar ();
			toolbar.set_style (ToolbarStyle.BOTH_HORIZ);

			var open = new ToolButton.from_stock (STOCK_OPEN);
			open.is_important = true;
			open.add_accelerator (
				"clicked", group, 'O', ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
			open.clicked.connect (on_open_clicked);
			toolbar.insert (open, -1);

			var save = new ToolButton.from_stock (STOCK_SAVE);
			save.is_important = true;
			save.add_accelerator (
				"clicked", group, 'S', ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
			save.clicked.connect (on_save_clicked);
			toolbar.insert (save, -1);

			toolbar.insert (new SeparatorToolItem (), -1);

			var quit = new ToolButton.from_stock (STOCK_QUIT);
			quit.is_important = true;
			quit.add_accelerator (
				"clicked", group, 'Q', ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
			quit.clicked.connect (s => destroy());
			toolbar.insert (quit, -1);

			// This separator forces the rest of the items to the end of the toolbar.
			var sep = new SeparatorToolItem ();
			sep.set_expand (true);
			sep.draw = false;
			toolbar.insert (sep, -1);

			var about = new ToolButton.from_stock (STOCK_ABOUT);
			about.is_important = true;
			about.add_accelerator ("clicked", group, keyval_from_name ("F1"), 0, AccelFlags.VISIBLE);
			about.clicked.connect (on_about_clicked);
			toolbar.insert (about, -1);

			message_bar = new MessageBar (_("A new version of Spek is available on <a href=\"http://www.spek-project.org\">www.spek-project.org</a>"));

			spectrogram = new Spectrogram ();
			cur_dir = Environment.get_home_dir ();

			filter_all = new FileFilter ();
			filter_all.set_name (_("All files"));
			filter_all.add_pattern ("*");
			filter_png = new FileFilter ();
			filter_png.set_name (_("PNG images"));
			filter_png.add_pattern ("*.png");
			filter_audio = new FileFilter ();
			filter_audio.set_name (_("Audio files"));
			foreach (var ext in audio_extensions) {
				filter_audio.add_pattern (ext);
			}

			var vbox = new VBox (false, 0);
			vbox.pack_start (toolbar, false, true, 0);
			vbox.pack_start (message_bar, false, true, 0);
			vbox.pack_start (spectrogram, true, true, 0);
			add (vbox);
			toolbar.show_all ();
			spectrogram.show_all ();
			vbox.show ();
			show ();

			// Set up Drag and Drop
			drag_dest_set (this, DestDefaults.ALL, DEST_TARGET_ENTRIES, DragAction.COPY);
			drag_data_received.connect (on_dropped);

			if (file_name != null) {
				open_file (file_name);
			}

			try {
				Thread.create (check_version, false);
			} catch (ThreadError e) {
			}
		}

		void on_dropped (DragContext cx, int x, int y, SelectionData data, uint info, uint time) {
			if (data.length > 0 && data.format == 8) {
				string[] files = data.get_uris ();
				if (files.length > 0) {
					try {
						open_file (Filename.from_uri (files[0]));
						drag_finish (cx, true, false, time);
						return;
					} catch (ConvertError e) {}
				}
			}
			drag_finish (cx, false, false, time);
		}

		private void open_file (string file_name) {
			cur_dir = Path.get_dirname (file_name);
			spectrogram.open (file_name);

			// Note to translators: window title, %s is replaced with the file name
			title = _("Spek - %s").printf (Path.get_basename (file_name));
		}

		private void on_open_clicked () {
			var chooser = new FileChooserDialog (
				_("Open File"), this, FileChooserAction.OPEN,
				STOCK_CANCEL, ResponseType.CANCEL,
				STOCK_OPEN, ResponseType.ACCEPT, null);
			chooser.set_default_response (ResponseType.ACCEPT);
			chooser.select_multiple = false;
			chooser.set_current_folder (cur_dir);
			chooser.add_filter (filter_all);
			chooser.add_filter (filter_audio);
			chooser.set_filter (filter_audio);
			if (chooser.run () == ResponseType.ACCEPT) {
				open_file (chooser.get_filename ());
			}
			chooser.destroy ();
		}

		private void on_save_clicked () {
			var chooser = new FileChooserDialog (
				_("Save Spectrogram"), this, FileChooserAction.SAVE,
				STOCK_CANCEL, ResponseType.CANCEL,
				STOCK_SAVE, ResponseType.ACCEPT, null);
			chooser.set_default_response (ResponseType.ACCEPT);
			chooser.set_current_folder (cur_dir);

			// Suggested name is <file_name>.png
			var file_name = Path.get_basename (spectrogram.file_name ?? _("Untitled"));
			file_name += ".png";
			chooser.set_current_name (file_name);
			chooser.add_filter (filter_png);
			chooser.set_filter (filter_png);
			if (chooser.run () == ResponseType.ACCEPT) {
				file_name = chooser.get_filename ();
				cur_dir = Path.get_dirname (file_name);
				spectrogram.save (file_name);
			}
			chooser.destroy ();
		}

		private void on_about_clicked () {
			string[] authors = {
				"Primary Development:",
				"\tAlexander Kojevnikov (maintainer) <alexander@kojevnikov.com>",
				"",
				"Contributors:",
				"\tFabian Deutsch"
			};
			string[] artists = {
				"Olga Vasylevska"
			};
			string license = "Copyright (C) 2010  Alexander Kojevnikov";
			license += "\n\n";
			license += "Spek is free software: you can redistribute it and/or modify ";
			license += "it under the terms of the GNU General Public License as published by ";
			license += "the Free Software Foundation, either version 3 of the License, or ";
			license += "(at your option) any later version.";
			license += "\n\n";
			license += "Spek is distributed in the hope that it will be useful, ";
			license += "but WITHOUT ANY WARRANTY; without even the implied warranty of ";
			license += "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the ";
			license += "GNU General Public License for more details.";
			license += "\n\n";
			license += "You should have received a copy of the GNU General Public License ";
			license += "along with Spek.  If not, see http://www.gnu.org/licenses/";

			var dlg = new AboutDialog ();
			dlg.program_name = "Spek";
			dlg.version = Config.PACKAGE_VERSION;
			dlg.copyright = _("Copyright \xc2\xa9 2010 Alexander Kojevnikov");
			dlg.comments = title;
			dlg.set ("authors", authors);
//			dlg.set ("documenters", documenters);
			dlg.set ("artists", artists);
			dlg.website_label = _("Spek Website");
			dlg.website = "http://www.spek-project.org/";
			dlg.license = license;
			dlg.wrap_license = true;
			try {
				dlg.logo = IconTheme.get_default ().load_icon ("spek", 128, 0);
			} catch (Error e) {
				dlg.logo_icon_name = "spek";
			}
			dlg.translator_credits = _("translator-credits");
			dlg.set_transient_for (this);
			dlg.destroy_with_parent = true;
			dlg.response.connect (id => dlg.destroy ());
			dlg.set_url_hook (url_hook);
			dlg.modal = true;
			dlg.present ();
		}

		private void url_hook (AboutDialog about, string link) {
			Platform.show_uri (link);
		}

		private string[] audio_extensions = {
			"*.3gp",
			"*.aac",
			"*.aif",
			"*.aifc",
			"*.aiff",
			"*.amr",
			"*.awb",
			"*.ape",
			"*.au",
			"*.dts",
			"*.flac",
			"*.gsm",
			"*.m4a",
			"*.m4p",
			"*.mp3",
			"*.mp4",
			"*.mp+",
			"*.mpc",
			"*.mpp",
			"*.oga",
			"*.ogg",
			"*.ra",
			"*.ram",
			"*.snd",
			"*.wav",
			"*.wma",
			"*.wv"
		};

		private void * check_version () {
			var config = Path.build_filename (Environment.get_user_config_dir (), "spek");
			DirUtils.create_with_parents (config, 0755);
			config = Path.build_filename (config, "config.ini");
			var key_file = new KeyFile ();
			try {
				key_file.load_from_file (config, KeyFileFlags.NONE);
			} catch (KeyFileError e) {
			} catch (FileError e) {
			}

			// Does the user want to check for updates?
			bool check = true;
			try {
				check = key_file.get_boolean ("update", "check");
			} catch (KeyFileError e) {
				check = true;
			}
			if (!check) {
				return null;
			}

			// When was the last update?
			var time_val = TimeVal ();
			time_val.get_current_time ();
			Date today = Date ();
			today.set_time_val (time_val);
			int day = 0;
			try {
				day = key_file.get_integer ("update", "last_update");
			} catch (KeyFileError e) {
				day = 0;
			}
			int diff = (int) today.get_julian () - day;
			if (diff < 7) {
				return null;
			}

			// Get the version number.
			var file = File.new_for_uri ("http://www.spek-project.org/version");
			if (!file.query_exists (null)) {
				return null;
			}
			string version;
			try {
				var stream = new DataInputStream (file.read (null));
				version = stream.read_line (null, null);
			} catch (Error e) {
				return null;
			}

			// Write to the config file.
			key_file.set_boolean ("update", "check", check);
			key_file.set_integer ("update", "last_update", (int) today.get_julian ());
			var output = FileStream.open (config, "w+");
			output.puts (key_file.to_data ());

			if (version != null && version > Config.PACKAGE_VERSION) {
				Idle.add (() => { message_bar.show_all (); return false; });
			}
			return null;
		}
	}
}
