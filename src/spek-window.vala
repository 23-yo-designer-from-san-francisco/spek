using Gdk;
using Gtk;

namespace Spek {
	public class Window : Gtk.Window {

		private Spectrogram spectrogram;

		public Window () {
			this.title = Config.PACKAGE_STRING;
			this.set_default_size (640, 480);
			this.destroy.connect (Gtk.main_quit);

			var group = new AccelGroup ();
			this.add_accel_group (group);

			var toolbar = new Toolbar ();
			toolbar.set_style (ToolbarStyle.BOTH_HORIZ);

			var open = new ToolButton.from_stock (STOCK_OPEN);
			open.is_important = true;
			open.add_accelerator (
				"clicked", group, 'O', ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
			open.clicked.connect (on_open_clicked);
			toolbar.insert (open, -1);

			toolbar.insert (new SeparatorToolItem (), -1);

			var quit = new ToolButton.from_stock (STOCK_QUIT);
			quit.is_important = true;
			quit.add_accelerator (
				"clicked", group, 'Q', ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
			quit.clicked.connect (s => this.destroy());
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

			this.spectrogram = new Spectrogram ();

			var vbox = new VBox (false, 0);
			vbox.pack_start (toolbar, false, true, 0);
			vbox.pack_start (spectrogram, true, true, 0);
			this.add (vbox);
			this.show_all ();
		}

		private void on_open_clicked () {
			var chooser = new FileChooserDialog (
				_ ("Open File"), this, FileChooserAction.OPEN,
				STOCK_CANCEL, ResponseType.CANCEL,
				STOCK_OPEN, ResponseType.ACCEPT, null);
			if (chooser.run () == ResponseType.ACCEPT) {
				spectrogram.open (chooser.get_filename ());
			}
			chooser.destroy ();
		}

		private void on_about_clicked () {
			string[] authors = {
				"Alexander Kojevnikov <alexander@kojevnikov.com>"
			};

			show_about_dialog (
				this,
				"program-name", "Spek",
				"version", Config.PACKAGE_VERSION,
				"copyright", _("Copyright © 2010 Alexander Kojevnikov"),
				"comments", _("Spek - Audio Spectrum Viewer"),
				"authors", authors,
				// TODO
//				"documenters", documenters,
//				"artists", artists,
//				"website-label", _("Spek Website"),
//				"website", "http://TODO",
//				"license", "GPLv3+",
				"wrap-license", true,
				"logo-icon-name", "spek",
				"translator-credits", _("translator-credits"));
		}
	}
}
