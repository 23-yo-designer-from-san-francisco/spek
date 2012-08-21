/* spek-window.cc
 *
 * Copyright (C) 2010-2012  Alexander Kojevnikov <alexander@kojevnikov.com>
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

#include <wx/aboutdlg.h>
#include <wx/artprov.h>
#include <wx/dnd.h>
#include <wx/filename.h>

#include "spek-spectrogram.hh"

#include "spek-window.hh"

BEGIN_EVENT_TABLE(SpekWindow, wxFrame)
    EVT_MENU(wxID_OPEN, SpekWindow::on_open)
    EVT_MENU(wxID_SAVE, SpekWindow::on_save)
    EVT_MENU(wxID_EXIT, SpekWindow::on_exit)
    EVT_MENU(wxID_PREFERENCES, SpekWindow::on_preferences)
    EVT_MENU(wxID_ABOUT, SpekWindow::on_about)
END_EVENT_TABLE()

class SpekDropTarget : public wxFileDropTarget
{
public:
    SpekDropTarget(SpekWindow *window) : wxFileDropTarget(), window(window) {}

protected:
    virtual bool OnDropFiles(wxCoord x, wxCoord y, const wxArrayString& filenames){
        if (filenames.GetCount() == 1) {
            window->open(filenames[0]);
            return true;
        }
        return false;
    }

private:
    SpekWindow *window;
};

SpekWindow::SpekWindow(const wxString& path) :
    path(path), wxFrame(NULL, -1, wxEmptyString)
{
    this->description = _("Spek - Acoustic Spectrum Analyser");
    SetTitle(this->description);
    // TODO: test on all platforms
    //SetIcon(wxIcon(wxT("spek")));

    wxMenuBar *menu = new wxMenuBar();

    wxMenu *menu_file = new wxMenu();
    wxMenuItem *menu_file_open = new wxMenuItem(menu_file, wxID_OPEN);
    menu_file->Append(menu_file_open);
    wxMenuItem *menu_file_save = new wxMenuItem(menu_file, wxID_SAVE);
    menu_file->Append(menu_file_save);
    menu_file->AppendSeparator();
    menu_file->Append(wxID_EXIT);
    menu->Append(menu_file, _("&File")); // TODO: stock text

    wxMenu *menu_edit = new wxMenu();
    wxMenuItem *menu_edit_prefs = new wxMenuItem(menu_edit, wxID_PREFERENCES);
    // TODO: check if this is needed
    menu_edit_prefs->SetItemLabel(menu_edit_prefs->GetItemLabelText() + wxT("\tCtrl+E"));
    menu_edit->Append(menu_edit_prefs);
    menu->Append(menu_edit, _("&Edit")); // TODO: stock text

    wxMenu *menu_help = new wxMenu();
    wxMenuItem *menu_help_about = new wxMenuItem(menu_help, wxID_ABOUT);
    // TODO: check if this is needed
    menu_help_about->SetItemLabel(menu_help_about->GetItemLabelText() + wxT("\tF1"));
    menu_help->Append(menu_help_about);
    menu->Append(menu_help, _("&Help")); // TODO: stock text

    SetMenuBar(menu);

    wxToolBar *toolbar = CreateToolBar();
    // TODO: bundled file open/save icons suck, provide our own (tango?)
    toolbar->AddTool(
        wxID_OPEN,
        menu_file_open->GetItemLabelText(),
        wxArtProvider::GetBitmap(wxART_FILE_OPEN)
    );
    toolbar->AddTool(
        wxID_SAVE,
        menu_file_save->GetItemLabelText(),
        wxArtProvider::GetBitmap(wxART_FILE_SAVE)
    );
    toolbar->Realize();

    wxSizer *sizer = new wxBoxSizer(wxVERTICAL);

    // wxInfoBar is too limited, construct a custom one.
    wxPanel *info_bar = new wxPanel(this);
    info_bar->SetForegroundColour(wxSystemSettings::GetColour(wxSYS_COLOUR_INFOTEXT));
    info_bar->SetBackgroundColour(wxSystemSettings::GetColour(wxSYS_COLOUR_INFOBK));
    wxSizer *info_sizer = new wxBoxSizer(wxHORIZONTAL);
    wxStaticText *label = new wxStaticText(
        info_bar, -1, _("A new version of Spek is available, click to download."));
    label->SetCursor(*new wxCursor(wxCURSOR_HAND));
    label->Connect(wxEVT_LEFT_DOWN, wxCommandEventHandler(SpekWindow::on_visit));
    // This second Connect() handles clicks on the border
    info_bar->Connect(wxEVT_LEFT_DOWN, wxCommandEventHandler(SpekWindow::on_visit));
    info_sizer->Add(label, 1, wxALIGN_CENTER_VERTICAL | wxALL, 6);
    // TODO: gtk-close won't work on win/osx
    wxBitmapButton *button = new wxBitmapButton(
        info_bar, -1, wxArtProvider::GetBitmap(wxT("gtk-close")),
        wxDefaultPosition, wxDefaultSize, wxNO_BORDER);
    button->Connect(wxEVT_COMMAND_BUTTON_CLICKED, wxCommandEventHandler(SpekWindow::on_close));
    info_sizer->Add(button, 0, 0);
    info_bar->SetSizer(info_sizer);
    sizer->Add(info_bar, 0, wxEXPAND);

    this->spectrogram = new SpekSpectrogram(this);
    sizer->Add(this->spectrogram, 1, wxEXPAND);

    this->cur_dir = wxGetHomeDir();

    if (!path.IsEmpty()) {
        open(path);
    }

    SetDropTarget(new SpekDropTarget(this));

    SetSizer(sizer);
}

void SpekWindow::open(const wxString& path)
{
    wxFileName file_name(path);
    if (file_name.FileExists()) {
        this->path = path;
        wxString full_name = file_name.GetFullName();
        // TRANSLATORS: window title, %s is replaced with the file name
        wxString title = wxString::Format(_("Spek - %s"), full_name.c_str());
        // TODO: make sure the above works on all platforms, both in x32 and x64.
        SetTitle(title);

        this->spectrogram->open(path);
    }
}

// TODO: s/audio/media/
static const char *audio_extensions[] = {
    "3gp",
    "aac",
    "aif",
    "aifc",
    "aiff",
    "amr",
    "awb",
    "ape",
    "au",
    "dts",
    "flac",
    "gsm",
    "m4a",
    "m4p",
    "mp3",
    "mp4",
    "mp+",
    "mpc",
    "mpp",
    "oga",
    "ogg",
    "ra",
    "ram",
    "snd",
    "wav",
    "wma",
    "wv",
    NULL
};

void SpekWindow::on_open(wxCommandEvent& event)
{
    static wxString filters = wxEmptyString;
    static int filter_index = 1;

    if (filters.IsEmpty()) {
        filters.Alloc(1024);
        filters += _("All files");
        filters += wxT("|*.*|");
        filters += _("Audio files");
        filters += wxT("|");
        for (int i = 0; audio_extensions[i]; ++i) {
            if (i) {
                filters += wxT(";");
            }
            filters += wxT("*.");
            filters += wxString::FromAscii(audio_extensions[i]);
        }
        filters.Shrink();
    }

    wxFileDialog *dlg = new wxFileDialog(
        this,
        _("Open File"),
        this->cur_dir,
        wxEmptyString,
        filters,
        wxFD_OPEN
    );
    dlg->SetFilterIndex(filter_index);

    if (dlg->ShowModal() == wxID_OK) {
        this->cur_dir = dlg->GetDirectory();
        filter_index = dlg->GetFilterIndex();
        open(dlg->GetPath());
    }

    dlg->Destroy();
}

void SpekWindow::on_save(wxCommandEvent& event)
{
    static wxString filters = wxEmptyString;

    if (filters.IsEmpty()) {
        filters = _("PNG images");
        filters += wxT("|*.png");
    }

    wxFileDialog *dlg = new wxFileDialog(
        this,
        _("Save Spectrogram"),
        this->cur_dir,
        wxEmptyString,
        filters,
        wxFD_SAVE
    );

    // Suggested name is <file_name>.png
    wxString name = _("Untitled");
    if (!this->path.IsEmpty()) {
        wxFileName file_name(this->path);
        name = file_name.GetFullName();
    }
    name += wxT(".png");
    dlg->SetFilename(name);

    if (dlg->ShowModal() == wxID_OK) {
        this->cur_dir = dlg->GetDirectory();
        this->spectrogram->save(dlg->GetPath());
    }

    dlg->Destroy();
}

void SpekWindow::on_exit(wxCommandEvent& event)
{
    Close(true);
}

void SpekWindow::on_preferences(wxCommandEvent& event)
{
}

void SpekWindow::on_about(wxCommandEvent& event)
{
    wxAboutDialogInfo info;
    info.AddDeveloper(wxT("Alexander Kojevnikov"));
    info.AddDeveloper(wxT("Fabian Deutsch"));
    info.AddDeveloper(wxT("Jonathan Gonzalez V"));
    info.AddDeveloper(wxT("Stefan Kost"));
    info.AddDeveloper(wxT("Thibault North"));
    info.AddArtist(wxT("Olga Vasylevska"));
    // TRANSLATORS: Add your name here
    wxString translator = _("translator-credits");
    if (translator != wxT("translator-credits")) {
        info.AddTranslator(translator);
    }
    info.SetName(wxT("Spek"));
    info.SetVersion(wxT(PACKAGE_VERSION));
    info.SetCopyright(_("Copyright (c) 2010-2012 Alexander Kojevnikov and contributors"));
    info.SetDescription(this->description);
#ifdef OS_UNIX
    info.SetWebSite(wxT("http://spek-project.org/"), _("Spek Website"));
    // TODO
    // info.SetIcon();
#endif
    wxAboutBox(info);
}

void SpekWindow::on_visit(wxCommandEvent& event)
{
    wxLaunchDefaultBrowser(wxT("http://spek-project.org"));
}

void SpekWindow::on_close(wxCommandEvent& event)
{
    wxWindow *self = ((wxWindow *)event.GetEventObject())->GetGrandParent();
    self->GetSizer()->Hide((size_t)0);
    self->Layout();
}
