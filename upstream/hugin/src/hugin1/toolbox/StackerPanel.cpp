// -*- c-basic-offset: 4 -*-
/** @file StackerPanel.cpp
 *
 *  @brief implementation of panel for stacker GUI
 *
 *  @author T. Modes
 *
 */

/*  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This software is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public
 *  License along with this software. If not, see
 *  <http://www.gnu.org/licenses/>.
 *
 */

#include "StackerPanel.h"
#include <wx/stdpaths.h>
#include <wx/propgrid/advprops.h>
#include "base_wx/platform.h"
#include "base_wx/wxPlatform.h"
#include "base_wx/MyExternalCmdExecDialog.h"
#include "base_wx/Executor.h"
#include <wx/fileconf.h>
#include <wx/wfstream.h>
#include <wx/sstream.h>
#include <wx/filepicker.h>
#include <wx/dir.h>
#include "hugin_utils/utils.h"
#include "hugin_base/panodata/SrcPanoImage.h"
#include "base_wx/LensTools.h"
#include "base_wx/wxutils.h"
#include "CreateBrightImgDlg.h"

/** dialog for selection of directory and file name/type */
class SelectDirectoryFileDialog :public wxDialog
{
public:
    /** Constructor, read from xrc ressource; restore last uses settings, size and position */
    SelectDirectoryFileDialog(wxWindow* parent)
    {
        wxXmlResource::Get()->LoadDialog(this, parent, "select_dir_dialog");
        m_dirPicker = XRCCTRL(*this, "select_dir_picker", wxDirPickerCtrl);
        wxConfigBase* config = wxConfigBase::Get();
        wxString path = config->Read("/actualPath", "");
        if (!path.IsEmpty())
        {
            m_dirPicker->SetPath(path);
        }
        m_recursiveCheck = XRCCTRL(*this, "select_dir_recursive", wxCheckBox);
        if (config->HasEntry("/ToolboxFrame/Stacker/AddDirRecursive"))
        {
            m_recursiveCheck->SetValue(config->ReadBool("/ToolboxFrame/Stacker/AddDirRecursive", false));
        };
        m_filenameCtrl = XRCCTRL(*this, "select_dir_filename", wxTextCtrl);
        if (config->HasEntry("/ToolboxFrame/Stacker/AddDirFilenames"))
        {
            m_filenameCtrl->SetValue(config->Read("/ToolboxFrame/Stacker/AddDirFilenames", "*"));
        };
        m_filetypeChoice = XRCCTRL(*this, "select_dir_filetype", wxChoice);
        FillFileTypeChoice();
        if (config->HasEntry("/ToolboxFrame/Stacker/AddDirFileType"))
        {
            m_filetypeChoice->SetSelection(config->ReadLong("/ToolboxFrame/Stacker/AddDirFileType", 0l));
        };
        Bind(wxEVT_BUTTON, &SelectDirectoryFileDialog::OnOk, this, wxID_OK);
        hugin_utils::RestoreFramePosition(this, "ToolboxFrame/Stacker/AddDirDialog");
    }
    // return list which matches the given criterium
    wxArrayString GetFilenames()
    {
        return m_filenames;
    }
protected:
    void OnOk(wxCommandEvent& e)
    {
        // save positions and settings
        wxConfigBase* config = wxConfigBase::Get();
        config->Write("/actualPath", m_dirPicker->GetPath());
        config->Write("/ToolboxFrame/Stacker/AddDirRecursive", m_recursiveCheck->GetValue());
        config->Write("/ToolboxFrame/Stacker/AddDirFilenames", m_filenameCtrl->GetValue());
        config->Write("/ToolboxFrame/Stacker/AddDirFileType", m_filetypeChoice->GetSelection());
        hugin_utils::StoreFramePosition(this, "ToolboxFrame/Stacker/AddDirDialog");
        // now try to find all images
        wxString filename = m_filenameCtrl->GetValue();
        if (filename.IsEmpty())
        {
            filename = "*";
        };
        m_filenames.Clear();
        int flags = wxDIR_FILES | wxDIR_HIDDEN | wxDIR_NO_FOLLOW;
        if (m_recursiveCheck->GetValue())
        {
            flags = flags | wxDIR_DIRS;
        };
        wxArrayString ext = wxSplit(m_filetypeExtensions[m_filetypeChoice->GetSelection()], ';');
        for (auto& currExt : ext)
        {
            wxString currFilename(currExt);
            currFilename.Replace("*", filename, true);
            wxDir::GetAllFiles(m_dirPicker->GetPath(), &m_filenames, currFilename, flags);
        };
        hugin_utils::HuginMessageBox(wxString::Format("Found %zu images", m_filenames.size()), _("Hugin_toolbox"), wxOK | wxICON_INFORMATION, this);
        if (!m_filenames.IsEmpty())
        {
            EndModal(wxID_OK);
        };
    }
private:
    void FillFileTypeChoice()
    {
        wxArrayString fileTypes = wxSplit(GetMainImageFilters(), '|');
        size_t i = 0;
        while (i < fileTypes.size())
        {
            if (i + 1 >= fileTypes.size())
            {
                break;
            };
            m_filetypeChoice->AppendString(fileTypes[i]);
            ++i;
            m_filetypeExtensions.Add(fileTypes[i]);
            ++i;
        };
        m_filetypeChoice->SetSelection(0);
    }
    wxDirPickerCtrl* m_dirPicker;
    wxCheckBox* m_recursiveCheck;
    wxTextCtrl* m_filenameCtrl;
    wxChoice* m_filetypeChoice;
    wxArrayString m_filenames;
    wxArrayString m_filetypeExtensions;
};

 /** file drag and drop handler method */
class StackerDropTarget : public wxFileDropTarget
{
public:
    StackerDropTarget(StackerPanel* parent) : wxFileDropTarget()
    {
        m_stackerPanel = parent;
    }

    bool OnDropFiles(wxCoord x, wxCoord y, const wxArrayString& filenames)
    {
        // try to add as images
        wxArrayString files;
        for (unsigned int i = 0; i < filenames.GetCount(); i++)
        {
            wxFileName file(filenames[i]);
            if (file.GetExt().CmpNoCase("jpg") == 0 ||
                file.GetExt().CmpNoCase("jpeg") == 0 ||
                file.GetExt().CmpNoCase("tif") == 0 ||
                file.GetExt().CmpNoCase("tiff") == 0 ||
                file.GetExt().CmpNoCase("png") == 0 ||
                file.GetExt().CmpNoCase("bmp") == 0 ||
                file.GetExt().CmpNoCase("gif") == 0 ||
                file.GetExt().CmpNoCase("pnm") == 0 ||
                file.GetExt().CmpNoCase("sun") == 0 ||
                file.GetExt().CmpNoCase("hdr") == 0 ||
                file.GetExt().CmpNoCase("viff") == 0)
            {
                files.push_back(file.GetFullPath());
            };
        };
        // we got some images to add.
        if (!files.empty())
        {
            for (auto& f : files)
            {
                m_stackerPanel->AddFile(f);
            };
        };
        return true;
    }
private:
    StackerPanel* m_stackerPanel;
};

// destructor, save settings
StackerPanel::~StackerPanel()
{
    wxConfigBase* config = wxConfigBase::Get();
    config->Write("/ToolboxFrame/Stacker/Splitter", XRCCTRL(*this, "stacker_splitter", wxSplitterWindow)->GetSashPosition());

    config->Write("/ToolboxFrame/Stacker/Mode", m_modeChoice->GetSelection());
    config->Write("/ToolboxFrame/Stacker/WinsorTrim", m_winsorTrim->GetValue());
    config->Write("/ToolboxFrame/Stacker/Sigma", m_sigma->GetValue());
    config->Write("/ToolboxFrame/Stacker/SigmaIter", m_sigmaMaxIter->GetValue());
    for (int j = 0; j < m_fileListCtrl->GetColumnCount(); j++)
    {
        config->Write(wxString::Format("/ToolboxFrame/Stacker/FileListColumnWidth%d", j), m_fileListCtrl->GetColumnWidth(j));
    };
    config->Write("/ToolboxFrame/Stacker/FileListSortColumn", m_sortCol);
    config->Write("/ToolboxFrame/Stacker/FileListSortAscending", m_sortAscending);

    config->Flush();
    CleanUpTempFiles();
}

bool StackerPanel::Create(wxWindow* parent, MyExecPanel* logPanel)
{
    if (!wxPanel::Create(parent, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxTAB_TRAVERSAL, "panel"))
    {
        return false;
    }
    // create preview window
    m_preview = new PreviewWindow();
    m_preview->Create(this);

    m_logWindow = logPanel;
    // load from xrc file and attach unknown controls
    wxXmlResource::Get()->LoadPanel(this, "stacker_panel");
    wxXmlResource::Get()->AttachUnknownControl("stacker_preview_window", m_preview, this);
    // add to sizer
    wxPanel* mainPanel = XRCCTRL(*this, "stacker_panel", wxPanel);
    wxBoxSizer* topsizer = new wxBoxSizer(wxVERTICAL);
    topsizer->Add(mainPanel, wxSizerFlags(1).Expand());
    // create columns in wxListCtrl
    m_fileListCtrl = XRCCTRL(*this, "stacker_files", wxListCtrl);
    m_fileListCtrl->InsertColumn(0, _("Filename"), wxLIST_FORMAT_LEFT, 200);
    m_fileListCtrl->InsertColumn(1, _("Width"), wxLIST_FORMAT_LEFT, 50);
    m_fileListCtrl->InsertColumn(2, _("Height"), wxLIST_FORMAT_LEFT, 50);
    m_fileListCtrl->InsertColumn(3, _("Path"), wxLIST_FORMAT_LEFT, 200);
    m_fileListCtrl->EnableCheckBoxes(true);
    SetSizer(topsizer);
    // store some controls for easier access
    m_modeChoice = XRCCTRL(*this, "stacker_mode_choice", wxChoice);
    m_winsorTrim = XRCCTRL(*this, "stacker_winsor_trim_spinctrl", wxSpinCtrlDouble);
    m_sigma = XRCCTRL(*this, "stacker_sigma_spinctrl", wxSpinCtrlDouble);
    m_sigmaMaxIter = XRCCTRL(*this, "stacker_sigma_iterations_spinctrl", wxSpinCtrl);

    SetDropTarget(new StackerDropTarget(this));

    wxConfigBase* config = wxConfigBase::Get();
    // restore splitter position
    if (config->HasEntry("/ToolboxFrame/Stacker/Splitter"))
    {
        XRCCTRL(*this, "stacker_splitter", wxSplitterWindow)->SetSashPosition(config->ReadLong("/ToolboxFrame/Stacker/Splitter", 300));
    }
    m_modeChoice->SetSelection(config->ReadLong("/ToolboxFrame/Stacker/Mode", 0));
    m_winsorTrim->SetValue(config->ReadDouble("/ToolboxFrame/Stacker/WinsorTrim", 0.2));
    m_sigma->SetValue(config->ReadDouble("/ToolboxFrame/Stacker/Sigma", 2));
    m_sigmaMaxIter->SetValue(config->ReadLong("/ToolboxFrame/Stacker/SigmaIter", 5));
    //get saved width of list ctrl column width
    for (int j = 0; j < m_fileListCtrl->GetColumnCount(); j++)
    {
        // -1 is auto
        int width = config->Read(wxString::Format("/ToolboxFrame/Stacker/FileListColumnWidth%d", j), -1);
        if (width != -1)
        {
            m_fileListCtrl->SetColumnWidth(j, width);
        };
    };
    m_sortCol = config->Read("/ToolboxFrame/Stacker/FileListSortColumn", -1);
    m_sortAscending = config->Read("/ToolboxFrame/Stacker/FileListSortAscending", 1) == 1 ? true : false;
    if (m_sortCol != -1)
    {
        m_fileListCtrl->ShowSortIndicator(m_sortCol, m_sortAscending);
    };

    // bind event handler
    Bind(wxEVT_BUTTON, &StackerPanel::OnAddFiles, this, XRCID("stacker_add_file"));
    Bind(wxEVT_BUTTON, &StackerPanel::OnAddDirectory, this, XRCID("stacker_add_files_dir"));
    Bind(wxEVT_BUTTON, &StackerPanel::OnRemoveFile, this, XRCID("stacker_remove_file"));
    m_fileListCtrl->Bind(wxEVT_CHAR, &StackerPanel::OnFileListChar, this);
    m_fileListCtrl->Bind(wxEVT_LIST_ITEM_SELECTED, &StackerPanel::OnFileSelectionChanged, this);
    m_fileListCtrl->Bind(wxEVT_LIST_ITEM_DESELECTED, &StackerPanel::OnFileSelectionChanged, this);
    m_fileListCtrl->Bind(wxEVT_LIST_ITEM_CHECKED, &StackerPanel::OnFileCheckStateChanged, this);
    m_fileListCtrl->Bind(wxEVT_LIST_ITEM_UNCHECKED, &StackerPanel::OnFileCheckStateChanged, this);
    m_fileListCtrl->Bind(wxEVT_LIST_COL_CLICK, &StackerPanel::OnFileColumnHeaderClick, this);
    Bind(wxEVT_CHOICE, &StackerPanel::OnModeChanged, this, XRCID("stacker_mode_choice"));
    Bind(wxEVT_BUTTON, &StackerPanel::OnGeneratePreview, this, XRCID("stacker_preview"));
    Bind(wxEVT_BUTTON, &StackerPanel::OnGenerateOutput, this, XRCID("stacker_output"));
    Bind(wxEVT_CHOICE, &StackerPanel::OnZoom, this, XRCID("stacker_choice_zoom"));

    EnableFileButtons();
    EnableOutputButtons(false);
    wxCommandEvent e;
    OnModeChanged(e);
    return true;
}

void StackerPanel::AddFile(const wxString& filename)
{
    wxFileName fullFilename(filename);
    // add image dimensions
    vigra::ImageImportInfo info(fullFilename.GetFullPath().c_str());
    vigra::Size2D imageSize = info.getCanvasSize();
    if (imageSize.area() == 0)
    {
        imageSize = info.size();
    };
    // add to array
    m_files.push_back(FileInfo(fullFilename.GetFullPath(), fullFilename.GetFullName(), fullFilename.GetPath(), imageSize.width(), imageSize.height()));
    AddFileInfo(m_files.back());
    EnableOutputButtons(GetCheckedItemCount() > 0);
}

void StackerPanel::OnAddFiles(wxCommandEvent& e)
{
    wxConfigBase* config = wxConfigBase::Get();
    wxString path = config->Read("/actualPath", "");
    wxFileDialog dlg(this, _("Add images"), path, wxEmptyString,
        GetFileDialogImageFilters(), wxFD_OPEN | wxFD_MULTIPLE | wxFD_FILE_MUST_EXIST | wxFD_PREVIEW, wxDefaultPosition);
    dlg.SetDirectory(path);

    // remember the image extension
    wxString img_ext;
    if (config->HasEntry("lastImageType"))
    {
        img_ext = config->Read("lastImageType").c_str();
    }
    if (img_ext == "all images")
        dlg.SetFilterIndex(0);
    else if (img_ext == "jpg")
        dlg.SetFilterIndex(1);
    else if (img_ext == "tiff")
        dlg.SetFilterIndex(2);
    else if (img_ext == "png")
        dlg.SetFilterIndex(3);
    else if (img_ext == "hdr")
        dlg.SetFilterIndex(4);
    else if (img_ext == "exr")
        dlg.SetFilterIndex(5);
    else if (img_ext == "all files")
        dlg.SetFilterIndex(6);

    // call the file dialog
    if (dlg.ShowModal() == wxID_OK)
    {
        // get the selections
        wxArrayString Pathnames;
        dlg.GetPaths(Pathnames);
        // save the current path to config
        config->Write("/actualPath", dlg.GetDirectory());
        // save the image extension
        switch (dlg.GetFilterIndex())
        {
            case 0: config->Write("lastImageType", "all images"); break;
            case 1: config->Write("lastImageType", "jpg"); break;
            case 2: config->Write("lastImageType", "tiff"); break;
            case 3: config->Write("lastImageType", "png"); break;
            case 4: config->Write("lastImageType", "hdr"); break;
            case 5: config->Write("lastImageType", "exr"); break;
            case 6: config->Write("lastImageType", "all files"); break;
        };
        m_fileListCtrl->Freeze();
        for (auto& f : Pathnames)
        {
            AddFile(f);
        };
        SortList();
        m_fileListCtrl->Thaw();
    }
}

void StackerPanel::OnAddDirectory(wxCommandEvent& e)
{
    SelectDirectoryFileDialog dlg(this);
    if (dlg.ShowModal() == wxID_OK)
    {
        const wxArrayString filenames = dlg.GetFilenames();
        wxBusyCursor cur;
        m_fileListCtrl->Freeze();
        for (auto& f : filenames)
        {
            AddFile(f);
        };
        SortList();
        m_fileListCtrl->Thaw();
    };
}

void StackerPanel::OnRemoveFile(wxCommandEvent& e)
{
    HuginBase::UIntSet selected;
    if (m_fileListCtrl->GetSelectedItemCount() >= 1)
    {
        for (int i = 0; i < m_fileListCtrl->GetItemCount(); ++i)
        {
            if (m_fileListCtrl->GetItemState(i, wxLIST_STATE_SELECTED) & wxLIST_STATE_SELECTED)
            {
                selected.insert(m_fileListCtrl->GetItemData(i));
            };
        };
    };
    if (!selected.empty())
    {
        // remove selected file from internal file list
        for (auto it = selected.rbegin(); it != selected.rend(); ++it)
        {
            m_files.erase(m_files.begin() + (*it));
        };
        // now refill list again
        m_fileListCtrl->DeleteAllItems();
        FillFileList();
        EnableFileButtons();
        EnableOutputButtons(GetCheckedItemCount() > 0);
    }
    else
    {
        wxBell();
    };
}

void StackerPanel::OnFileListChar(wxKeyEvent& e)
{
    // ctrl + a, select all files
    if (e.GetKeyCode() == 1 && e.CmdDown())
    {
        // select all
        for (int i = 0; i < m_fileListCtrl->GetItemCount(); i++)
        {
            m_fileListCtrl->SetItemState(i, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED);
        };
    };
    // insert key, add file
    if ((e.GetKeyCode() == WXK_INSERT || e.GetKeyCode() == WXK_NUMPAD_INSERT) && !e.HasAnyModifiers())
    {
        wxCommandEvent e(wxEVT_BUTTON, XRCID("stacker_add_file"));
        this->GetEventHandler()->AddPendingEvent(e);
    };
    // delete key, delete selected file
    if ((e.GetKeyCode() == WXK_DELETE || e.GetKeyCode() == WXK_NUMPAD_DELETE) && !e.HasAnyModifiers())
    {
        if (m_fileListCtrl->GetSelectedItemCount() > 0)
        {
            wxCommandEvent e(wxEVT_BUTTON, XRCID("stacker_remove_file"));
            this->GetEventHandler()->AddPendingEvent(e);
        }
        else
        {
            wxBell();
        };
    };
    e.Skip();
}

void StackerPanel::OnFileSelectionChanged(wxCommandEvent& e)
{
    // enable/disable button according to selected files
    EnableFileButtons();
}

void StackerPanel::OnFileCheckStateChanged(wxListEvent& e)
{
    const long index = m_fileListCtrl->GetItemData(e.GetItem());
    m_files[index].isChecked = m_fileListCtrl->IsItemChecked(e.GetItem());
    EnableOutputButtons(GetCheckedItemCount() > 0);
}

void StackerPanel::OnFileColumnHeaderClick(wxListEvent& e)
{
    const int newCol = e.GetColumn();
    if (m_sortCol == newCol)
    {
        m_sortAscending = !m_sortAscending;
    }
    else
    {
        m_sortCol = newCol;
        m_sortAscending = true;
    };
    m_fileListCtrl->ShowSortIndicator(m_sortCol, m_sortAscending);
    SortList();
    Refresh();
}

void StackerPanel::OnModeChanged(wxCommandEvent& e)
{
    const int mode = m_modeChoice->GetSelection();
    // hide controls which are not necessary for current mode
    XRCCTRL(*this, "stacker_winsor_trim_label", wxStaticText)->Show(mode == 2);
    m_winsorTrim->Show(mode == 2);
    XRCCTRL(*this, "stacker_sigma_label", wxStaticText)->Show(mode == 3);
    m_sigma->Show(mode == 3);
    XRCCTRL(*this, "stacker_sigma_iterations_label", wxStaticText)->Show(mode == 3);
    m_sigmaMaxIter->Show(mode == 3);
    m_modeChoice->GetParent()->Layout();
}

void StackerPanel::OnGeneratePreview(wxCommandEvent& e)
{
    // create temp file name, set extension to tif
    m_outputFilenames.resize(2);
    wxFileName tempfile(wxFileName::CreateTempFileName(HuginQueue::GetConfigTempDir(wxConfig::Get()) + "he"));
    m_outputFilenames[1] = tempfile.GetFullPath();
    tempfile.SetExt("tif");
    m_outputFilenames[0] = tempfile.GetFullPath();
    m_cleanupOutput = true;
    // get command line and execute
    ExecuteStacker();
}

void StackerPanel::ExecuteStacker()
{
    wxString cmd = GetStackerCommandLine();
    if (!cmd.IsEmpty())
    {
        EnableOutputButtons(false);
        m_logWindow->ClearOutput();
        cmd = HuginQueue::wxEscapeFilename(HuginQueue::GetInternalProgram(wxFileName(wxStandardPaths::Get().GetExecutablePath()).GetPath(wxPATH_GET_VOLUME | wxPATH_GET_SEPARATOR), "hugin_stacker")) + cmd;
        m_logWindow->AddString(cmd);
        m_logWindow->ExecWithRedirect(cmd);
    }
}

void StackerPanel::ExecuteStackerExiftool()
{
    wxString cmd = GetStackerCommandLine();
    if (!cmd.IsEmpty())
    {
        EnableOutputButtons(false);
        m_logWindow->ClearOutput();
        HuginQueue::CommandQueue* queue = new HuginQueue::CommandQueue();
        wxString exePath = wxFileName(wxStandardPaths::Get().GetExecutablePath()).GetPath(wxPATH_GET_VOLUME | wxPATH_GET_SEPARATOR);
        queue->push_back(new HuginQueue::NormalCommand(HuginQueue::GetInternalProgram(exePath, "hugin_stacker"), cmd, _("Stacking images") + " (" + cmd + ")"));
        // get first image
        long index = -1;
        for (long i = 0; i < m_fileListCtrl->GetItemCount(); ++i)
        {
            if (m_fileListCtrl->IsItemChecked(i))
            {
                index = m_fileListCtrl->GetItemData(i);
                break;
            };
        };
        wxString exiftoolArgs(" -overwrite_original -tagsfromfile " + HuginQueue::wxEscapeFilename(m_files[index].fullFilename));
        exiftoolArgs.Append(" -all:all --thumbnail --thumbnailimage --xposition --yposition --imagefullwidth --imagefullheight ");
        exiftoolArgs.Append(HuginQueue::wxEscapeFilename(m_outputFilenames[0]));
        queue->push_back(new HuginQueue::OptionalCommand(HuginQueue::GetExternalProgram(wxConfig::Get(), exePath, "exiftool"), exiftoolArgs, _("Updating EXIF")));
        m_logWindow->ExecQueue(queue);
    };
}

void StackerPanel::OnGenerateOutput(wxCommandEvent& e)
{
    if (m_files.empty())
    {
        wxBell();
        return;
    };
    wxConfigBase* config = wxConfigBase::Get();
    wxString path = config->Read("/actualPath", "");
    wxFileDialog dlg(this, _("Save output"), path, wxEmptyString, GetMainImageFilters(), wxFD_SAVE | wxFD_OVERWRITE_PROMPT, wxDefaultPosition);
    dlg.SetDirectory(path);

    // remember the image extension
    wxString img_ext;
    if (config->HasEntry("lastImageType"))
    {
        img_ext = config->Read("lastImageType").c_str();
    }
    if (img_ext == "jpg")
    {
        dlg.SetFilterIndex(0);
    }
    else
    {
        if (img_ext == "tiff")
        {
            dlg.SetFilterIndex(1);
        }
        else
        {
            if (img_ext == "png")
            {
                dlg.SetFilterIndex(2);
            };
        };
    };
    wxFileName outputfilename(m_files[0].fullFilename);
    outputfilename.SetName(outputfilename.GetName() + "_stacked");
    dlg.SetFilename(outputfilename.GetFullPath());
    // call the file dialog
    if (dlg.ShowModal() == wxID_OK)
    {
        m_outputFilenames.resize(1);
        m_outputFilenames[0] = dlg.GetPath();
        // save the current path to config
        config->Write("/actualPath", dlg.GetDirectory());
        // save the image extension
        switch (dlg.GetFilterIndex())
        {
            case 0:
                config->Write("lastImageType", "jpg");
                break;
            case 1:
                config->Write("lastImageType", "tiff");
                break;
            case 2:
                config->Write("lastImageType", "png");
                break;
        };
        m_cleanupOutput = false;
        ExecuteStackerExiftool();
    };
}

void StackerPanel::OnZoom(wxCommandEvent& e)
{
    double factor;
    switch (e.GetSelection())
    {
        case 0:
            factor = 1;
            break;
        case 1:
            // fit to window
            factor = 0;
            break;
        case 2:
            factor = 2;
            break;
        case 3:
            factor = 1.5;
            break;
        case 4:
            factor = 0.75;
            break;
        case 5:
            factor = 0.5;
            break;
        case 6:
            factor = 0.25;
            break;
        default:
            DEBUG_ERROR("unknown scale factor");
            factor = 1;
    }
    m_preview->setScale(factor);
}

void StackerPanel::OnProcessFinished(wxCommandEvent& e)
{
    wxFileName output(m_outputFilenames[0]);
    if (output.FileExists() && output.GetSize()>0)
    {
        m_preview->setImage(output.GetFullPath());
    };
    EnableOutputButtons(true);
    if (m_cleanupOutput && output.FileExists())
    {
        // cleanup up preview files
        for (const auto& f : m_outputFilenames)
        {
            wxRemoveFile(f);
        };
    };
    CleanUpTempFiles();
}

wxString StackerPanel::GetStackerOptions()
{
    wxString commandline;
    switch (XRCCTRL(*this, "stacker_mode_choice", wxChoice)->GetSelection())
    {
    case 0: 
        // mean or average 
        commandline.Append(" --mode=mean ");
        break;
    case 1:
        // Median
        commandline.Append(" --mode=median ");
        break;
    case 2:
        // Winsor trimmed mean
        commandline.Append(" --mode=winsor ");
        commandline.Append("--winsor-trim=" + wxString::FromCDouble(m_winsorTrim->GetValue()) + " ");
        break;
    case 3:
        // Sigma clipped mean
        commandline.Append(" --mode=sigma ");
        commandline.Append("--max-sigma=" + wxString::FromCDouble(m_sigma->GetValue()) + wxString::Format(" --max-iterations=%d ", m_sigmaMaxIter->GetValue()));
        break;
    case 4:
        //Minimum
        commandline.Append(" --mode=minimum ");
        break;
    case 5:
        //Maximum
        commandline.Append(" --mode=maximum ");
        break;
    }
    return commandline;
}

wxString StackerPanel::GetStackerCommandLine()
{
    wxString commandline(" --output=" + hugin_utils::wxQuoteFilename(m_outputFilenames[0]));
    // add options from control
    commandline.Append(" ");
    commandline.Append(GetStackerOptions());
    // now build image list
    wxArrayInt selectedFiles;
    for (int i = 0; i < m_fileListCtrl->GetItemCount(); ++i)
    {
        if (m_fileListCtrl->IsItemChecked(i))
        {
            selectedFiles.push_back(m_fileListCtrl->GetItemData(i));
        };
    };
    if (selectedFiles.IsEmpty())
    {
        hugin_utils::HuginMessageBox(_("Please activate at least one file."), _("Hugin_toolbox"), wxOK | wxOK_DEFAULT | wxICON_WARNING, this);
        return wxEmptyString;
    }
    if (selectedFiles.size() > 5)
    {
        // for more than 5 files use response file
        // first create a temp file
        wxString tempFilename = wxFileName::CreateTempFileName(HuginQueue::GetConfigTempDir(wxConfig::Get()) + "hsfl");
        wxTextFile textfile(tempFilename);
        textfile.Open();
        if (textfile.IsOpened())
        {
            m_tempFiles.push_back(tempFilename);
            // write filenames to response file
            for (int i = 0; i < selectedFiles.size(); ++i)
            {
                textfile.AddLine(m_files[selectedFiles[i]].fullFilename);
            };
            // write file and do some checking for erros
            if (textfile.Write(wxTextFileType_None, wxConvLocal))
            {
                textfile.Close();
                // add response file to command line
                commandline.Append(" @ ");
                commandline.Append(hugin_utils::wxQuoteFilename(tempFilename));
                return commandline;
            }
            else
            {
                textfile.Close();
                hugin_utils::HuginMessageBox(wxString::Format(_("Could not write to temporary file (%s)."), tempFilename), _("Hugin_toolbox"), wxOK | wxOK_DEFAULT | wxICON_WARNING, this);
                return wxEmptyString;

            };
        }
        else
        {
            hugin_utils::HuginMessageBox(wxString::Format(_("Could not write to temporary file (%s)."), tempFilename), _("Hugin_toolbox"), wxOK | wxOK_DEFAULT | wxICON_WARNING, this);
            return wxEmptyString;
        };
    }
    else
    {
        // use filename direct on command line, if there are only up to 5 files
        for (int i = 0; i < selectedFiles.size(); ++i)
        {
            commandline.Append(" ");
            commandline.Append(hugin_utils::wxQuoteFilename(m_files[selectedFiles[i]].fullFilename));
        }
        return commandline;
    };
}

void StackerPanel::EnableFileButtons()
{
    // enable/disable button according to selected files
    XRCCTRL(*this, "stacker_remove_file", wxButton)->Enable(m_fileListCtrl->GetSelectedItemCount() >= 1);
}

long StackerPanel::GetCheckedItemCount() const
{
    // count checked items
    long count = 0;
    for (int i = 0; i < m_fileListCtrl->GetItemCount(); ++i)
    {
        if (m_fileListCtrl->IsItemChecked(i))
        {
            ++count;
        };
    };
    return count;
}

void StackerPanel::EnableOutputButtons(bool enable)
{
    XRCCTRL(*this, "stacker_preview", wxButton)->Enable(enable);
    XRCCTRL(*this, "stacker_output", wxButton)->Enable(enable);
}

void StackerPanel::CleanUpTempFiles()
{
    for (const auto& f : m_tempFiles)
    {
        wxRemoveFile(f);
    };
    m_tempFiles.clear();
}

void StackerPanel::FillFileList()
{
    m_fileListCtrl->Freeze();
    for (auto& info : m_files)
    {
        AddFileInfo(info);
    };
    SortList();
    m_fileListCtrl->Thaw();
}

void StackerPanel::AddFileInfo(const FileInfo& info)
{
    const long index = m_fileListCtrl->InsertItem(m_fileListCtrl->GetItemCount(), info.name);
    // store index as client data for sorting
    m_fileListCtrl->SetItemData(index, index);
    // add image dimensions
    m_fileListCtrl->SetItem(index, 1, wxString::Format("%zu", info.width));
    m_fileListCtrl->SetItem(index, 2, wxString::Format("%zu", info.height));
    m_fileListCtrl->SetItem(index, 3, info.path);
    // set checkbox
    m_fileListCtrl->CheckItem(index, info.isChecked);
}

#define SORTASCENDING(functionName, var) \
int wxCALLBACK functionName(wxIntPtr item1, wxIntPtr item2, wxIntPtr sortData)\
{\
    StackerPanel::FileInfoVector* data = (StackerPanel::FileInfoVector*)(sortData);\
    if (data->at(item1).var > data->at(item2).var)\
        return 1;\
    if (data->at(item1).var < data->at(item2).var)\
        return -1;\
    return 0;\
}

#define SORTDESCENDING(functionName, var) \
int wxCALLBACK functionName(wxIntPtr item1, wxIntPtr item2, wxIntPtr sortData)\
{\
    StackerPanel::FileInfoVector* data = (StackerPanel::FileInfoVector*)(sortData); \
    if (data->at(item1).var < data->at(item2).var)\
        return 1; \
    if (data->at(item1).var > data->at(item2).var)\
        return -1; \
    return 0; \
}

SORTASCENDING(SortFilenameAscending, name)
SORTDESCENDING(SortFilenameDescending, name)
SORTASCENDING(SortImageWidthAscending, width)
SORTDESCENDING(SortImageWidthDescending, width)
SORTASCENDING(SortImageHeightAscending, height)
SORTDESCENDING(SortImageHeightDescending, height)
SORTASCENDING(SortPathAscending, path)
SORTDESCENDING(SortPathDescending, path)

#undef SORTASCENDING
#undef SORTDESCENDING

void StackerPanel::SortList()
{
    if (m_sortCol > -1)
    {
        switch (m_sortCol)
        {
        case 0:  // filename
            if (m_sortAscending)
            {
                m_fileListCtrl->SortItems(SortFilenameAscending, wxIntPtr(&m_files));
            }
            else
            {
                m_fileListCtrl->SortItems(SortFilenameDescending, wxIntPtr(&m_files));
            };
            break;
        case 1: // image width
            if (m_sortAscending)
            {
                m_fileListCtrl->SortItems(SortImageWidthAscending, wxIntPtr(&m_files));
            }
            else
            {
                m_fileListCtrl->SortItems(SortImageWidthDescending, wxIntPtr(&m_files));
            };
            break;
        case 2: // image height
            if (m_sortAscending)
            {
                m_fileListCtrl->SortItems(SortImageHeightAscending, wxIntPtr(&m_files));
            }
            else
            {
                m_fileListCtrl->SortItems(SortImageHeightDescending, wxIntPtr(&m_files));
            };
            break;
        case 3:  // path
            if (m_sortAscending)
            {
                m_fileListCtrl->SortItems(SortPathAscending, wxIntPtr(&m_files));
            }
            else
            {
                m_fileListCtrl->SortItems(SortPathDescending, wxIntPtr(&m_files));
            };
            break;
        };
    };
}

IMPLEMENT_DYNAMIC_CLASS(StackerPanel, wxPanel)
