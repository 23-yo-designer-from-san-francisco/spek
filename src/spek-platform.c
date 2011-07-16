/* spek-platform.c
 *
 * Copyright (C) 2010,2011  Alexander Kojevnikov <alexander@kojevnikov.com>
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

#include <glib.h>
#include <gtk/gtk.h>

#ifdef G_OS_WIN32
#include <windows.h>
#include <shellapi.h>
#endif

#ifdef G_OS_DARWIN
#include <gtkosxapplication.h>
#include <CoreFoundation/CoreFoundation.h>
#include <ApplicationServices/ApplicationServices.h>
#endif

#include "spek-platform.h"

void spek_platform_init () {
#ifdef G_OS_DARWIN
    g_object_new (GTK_TYPE_OSX_APPLICATION, NULL);
#endif
}

void spek_platform_fix_args (gchar **argv, gint argc) {
#ifdef G_OS_WIN32
    /* Because MinGW does not support Unicode arguments we are going to
     * get them using Windows API. In addition, GLib's option parser
     * doesn't work well with utf-8 strings on Windows, converting
     * them to URIs works around this problem.
     */
    int i;
    gchar *s, *t;
    wchar_t **wargv;
    int wargc;
    wargv = CommandLineToArgvW (GetCommandLineW (), &wargc);
    for (i = 0; i < argc; i++) {
        s = g_utf16_to_utf8 (wargv[i], -1, NULL, NULL, NULL);
        if (s) {
            t = g_filename_to_uri (s, NULL, NULL);
            g_free (s);
            if (t) {
                g_free (argv[i]);
                argv[i] = t;
            }
        }
    }
    LocalFree (wargv);
#endif
}

#ifdef G_OS_DARWIN
static void accel_map_foreach (gpointer data, const gchar *accel_path, guint accel_key, GdkModifierType 
accel_mods, gboolean changed)
{
    if (accel_mods & GDK_CONTROL_MASK) {
        accel_mods &= ~GDK_CONTROL_MASK;
        accel_mods |= GDK_META_MASK;
        gtk_accel_map_change_entry (accel_path, accel_key, accel_mods, FALSE);
    }
}
#endif

void spek_platform_fix_ui (GtkUIManager *ui)
{
#ifdef G_OS_DARWIN
    GtkOSXApplication *app = NULL;
    GtkOSXApplicationMenuGroup *group = NULL;
    GtkWidget *menubar = NULL;
    GtkWidget *file_quit = NULL;
    GtkWidget *edit_preferences = NULL;
    GtkWidget *help_about = NULL;

    app = g_object_new (GTK_TYPE_OSX_APPLICATION, NULL);
    menubar = gtk_ui_manager_get_widget (ui, "/MenuBar");
    file_quit = gtk_ui_manager_get_widget (ui, "/MenuBar/File/FileQuit");
    edit_preferences = gtk_ui_manager_get_widget (ui, "/MenuBar/Edit/EditPreferences");
    help_about = gtk_ui_manager_get_widget (ui, "/MenuBar/Help/HelpAbout");

    gtk_widget_hide (menubar);
    gtk_widget_hide (file_quit);
    gtk_osxapplication_set_menu_bar (app, GTK_MENU_SHELL (menubar));

    group = gtk_osxapplication_add_app_menu_group (app);
    gtk_osxapplication_add_app_menu_item (app, group, GTK_MENU_ITEM (help_about));
    group = gtk_osxapplication_add_app_menu_group (app);
    gtk_osxapplication_add_app_menu_item (app, group, GTK_MENU_ITEM (edit_preferences));

    gtk_accel_map_foreach (NULL, accel_map_foreach);

    gtk_osxapplication_ready (app);
#endif
}

gchar *spek_platform_locale_dir () {
    static gchar *locale_dir = NULL;

    if (!locale_dir) {
#ifdef G_OS_WIN32
        gchar *win32_dir;

        win32_dir = g_win32_get_package_installation_directory_of_module (NULL);
        locale_dir = g_build_filename (win32_dir, "share", "locale", NULL);

        g_free (win32_dir);
#else
#ifdef G_OS_DARWIN
        GtkOSXApplication *app = NULL;
        const gchar *res_dir;

        app = g_object_new (GTK_TYPE_OSX_APPLICATION, NULL);
        res_dir = gtk_osxapplication_get_resource_path (app);
        locale_dir = g_build_filename (res_dir, "share", "locale", NULL);
#else
        locale_dir =  LOCALEDIR;
#endif
#endif
    }

    return locale_dir;
}

void spek_platform_show_uri (const gchar *uri) {
#ifdef G_OS_WIN32
    /* gtk_show_uri doesn't work on Windows... */
    ShellExecuteA (NULL, "open", uri, "", NULL, SW_SHOWNORMAL);
#else
#ifdef G_OS_DARWIN
    /* ...or on OS X */
    CFStringRef str = NULL;
    CFURLRef url = NULL;

    str = CFStringCreateWithCString (NULL, uri, kCFStringEncodingASCII);
    url = CFURLCreateWithString (NULL, str, NULL);
    LSOpenCFURLRef (url, NULL);
    CFRelease (url);
    CFRelease (str);
#else
    gtk_show_uri (NULL, uri, gtk_get_current_event_time (), NULL);
#endif
#endif
}

gchar *spek_platform_read_line (const gchar *uri) {
#ifdef G_OS_DARWIN
    /* GIO doesn't work on OS X */
    CFStringRef str = NULL;
    CFURLRef url = NULL;
    CFDataRef data = NULL;
    CFIndex length = 0;
    gchar *buf = NULL;

    str = CFStringCreateWithCString (NULL, uri, kCFStringEncodingASCII);
    url = CFURLCreateWithString (NULL, str, NULL);
    if (CFURLCreateDataAndPropertiesFromResource (NULL, url, &data, NULL, NULL, NULL)) {
        length = CFDataGetLength (data);
        buf = (gchar *) g_malloc (length + 1);
        CFDataGetBytes (data, CFRangeMake (0, length), (UInt8 *) buf);
        buf[length] = '\0';
        g_strchomp (buf);
        CFRelease (data);
    }
    CFRelease (url);
    CFRelease (str);
    return buf;
#else
    gchar *line = NULL;
    GFile *file = NULL;
    GFileInputStream *file_stream = NULL;

    file = g_file_new_for_uri (uri);
    file_stream = g_file_read (file, NULL, NULL);
    if (file_stream) {
        GDataInputStream *data_stream = NULL;

        data_stream = g_data_input_stream_new (G_INPUT_STREAM (file_stream));
        line = g_data_input_stream_read_line (data_stream, NULL, NULL, NULL);

        g_object_unref (data_stream);
        g_object_unref (file_stream);
    }
    g_object_unref (file);
    return line;
#endif
}

gdouble spek_platform_get_font_scale () {
#ifdef G_OS_DARWIN
    /* Pango/Quartz fonts are smaller than on X. */
    return 1.4;
#endif
    return 1.0;
}
