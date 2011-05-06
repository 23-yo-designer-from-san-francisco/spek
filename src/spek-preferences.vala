/* spek-preferences.vala
 *
 * Copyright (C) 2011  Alexander Kojevnikov <alexander@kojevnikov.com>
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

namespace Spek {
	public class Preferences {
		private KeyFile key_file;
		private string file_name;

		private Preferences () {
			file_name = Path.build_filename (Environment.get_user_config_dir (), "spek");
			DirUtils.create_with_parents (file_name, 0755);
			file_name = Path.build_filename (file_name, "preferences");
			this.key_file = new KeyFile ();
			try {
				key_file.load_from_file (file_name, KeyFileFlags.NONE);
			} catch (KeyFileError e) {
			} catch (FileError e) {
			}
		}

		~Preferences () {
			save ();
		}

		private static Preferences _instance;
		public static Preferences instance {
			get {
				if (_instance == null) {
					_instance = new Preferences ();
				}
				return _instance;
			}
		}

		public void save () {
			var output = FileStream.open (file_name, "w+");
			if (output != null) {
				output.puts (key_file.to_data ());
			}
		}

		public bool check_update {
			get {
				try {
					return key_file.get_boolean ("update", "check");
				} catch (KeyFileError e) {
				}
				return true;
			}
			set {
				key_file.set_boolean ("update", "check", value);
			}
		}

		public int last_update {
			get {
				try {
					return key_file.get_integer ("update", "last");
				} catch (KeyFileError e) {
				}
				return 0;
			}
			set {
				key_file.set_integer ("update", "last", value);
			}
		}

		public string language {
			owned get {
				try {
					return key_file.get_string ("general", "language");
				} catch (KeyFileError e) {
				}
				return "";
			}
			set {
				key_file.set_string ("general", "language", value);
			}
		}
	}
}