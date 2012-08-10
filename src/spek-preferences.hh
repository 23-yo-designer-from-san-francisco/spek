/* spek-preferences.hh
 *
 * Copyright (C) 2011-2012  Alexander Kojevnikov <alexander@kojevnikov.com>
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

#ifndef SPEK_PREFERENCES_HH_
#define SPEK_PREFERENCES_HH_

#include <wx/fileconf.h>
#include <wx/intl.h>

class SpekPreferences
{
public:
    static SpekPreferences& Get();

    void Init();
    bool GetCheckUpdate();
    void SetCheckUpdate(bool value);
    long GetLastUpdate();
    void SetLastUpdate(long value);
    wxString GetLanguage();
    void SetLanguage(const wxString& value);

private:
    SpekPreferences();
    SpekPreferences(const SpekPreferences&);
    void operator=(const SpekPreferences&);

    wxLocale *locale;
    wxFileConfig *config;
};

#endif
