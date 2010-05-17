/* spek.vala
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

using Spek;

bool version = false;
// TODO: move into main() when bgo#530623 is fixed.
const OptionEntry[] options = {
	{ "version", 'V', 0, OptionArg.NONE, &version, N_("Display the version and exit"), null },
	{ null }
};

int main (string[] args) {
	Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
	Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
	Intl.textdomain (Config.GETTEXT_PACKAGE);

	try {
		Gtk.init_with_args (ref args, _("[FILE]"), (OptionEntry[]) options, Config.GETTEXT_PACKAGE);
	} catch (Error e) {
		print (e.message);
		print ("\n");
		print (_("Run `%s --help` to see a full list of available command line options.\n"), args[0]);
		return 1;
	}

	if (version) {
		print (_("%s version %s\n"), Config.PACKAGE_NAME, Config.PACKAGE_VERSION);
		return 0;
	}

	Gst.init (ref args);
	var window = new Window ();
	Gtk.main ();
	window.destroy ();
	return 0;
}
