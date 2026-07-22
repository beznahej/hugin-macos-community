// -*- c-basic-offset: 4 -*-
/** @file StackerPanel.h
 *
 *  @brief declaration of panel for stacker GUI
 *
 *  @author T. Modes
 *
 */

/*  This is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This software is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public
 *  License along with this software. If not, see
 *  <http://www.gnu.org/licenses/>.
 *
 */

#ifndef STACKERANEL_H
#define STACKERANEL_H

#include "panoinc_WX.h"
#include "PreviewWindow.h"
#include <vector>
#include "base_wx/MyExternalCmdExecDialog.h"

/** panel for stacker GUI
 *
 */
class StackerPanel : public wxPanel
{
public:
    struct FileInfo
    {
    public:
        FileInfo(const wxString& file, const wxString& new_name, const wxString& new_path, const size_t& new_width, const size_t& new_height)
        {
            fullFilename = file;
            name = new_name;
            path = new_path;
            width = new_width;
            height = new_height;
            isChecked = true;
        };
        wxString fullFilename, name, path;
        size_t width, height;
        bool isChecked;
    };
    typedef std::vector<FileInfo> FileInfoVector;
    /** destructor, save state and settings */
    ~StackerPanel();
    /** creates the control and populates all controls with their settings */
    bool Create(wxWindow* parent, MyExecPanel* logPanel);
    /** adds the given file to the list */
    void AddFile(const wxString& filename);
    /** call at the end of the enfuse command, to load result back and enable buttons again */
    void OnProcessFinished(wxCommandEvent& e);

protected:
    /** event handler */
    void OnAddFiles(wxCommandEvent& e);
    void OnAddDirectory(wxCommandEvent& e);
    void OnRemoveFile(wxCommandEvent& e);
    void OnFileListChar(wxKeyEvent& e);
    void OnFileSelectionChanged(wxCommandEvent& e);
    void OnFileCheckStateChanged(wxListEvent& e);
    void OnFileColumnHeaderClick(wxListEvent& e);
    void OnModeChanged(wxCommandEvent& e);
    void OnGeneratePreview(wxCommandEvent& e);
    void OnGenerateOutput(wxCommandEvent& e);
    void OnZoom(wxCommandEvent& e);

private:
    /** build the command line and execute enfuse command */
    void ExecuteStacker();
    /** build the command line and execute enfuse and exiftool afterwards */
    void ExecuteStackerExiftool();
    /** build string with all stacker options from values in wxPropertyGrid 
     *  this are the mainly the fusion options without the filesnames  
     */
    wxString GetStackerOptions();
    /** get the full commandline for enfuse without program, but with files and output options, the output filename is read from m_outputFilename */
    wxString GetStackerCommandLine();
    /** enable/disable the file(s) remove and create buttons depending on selection of wxListCtrl */
    void EnableFileButtons();
    /** return the number of check images */
    long GetCheckedItemCount() const;
    /** enable/disable output buttons */
    void EnableOutputButtons(bool enable);
    /** delete all temporary files, to be called mainly at end */
    void CleanUpTempFiles();
    /** sort filename list */
    void SortList();
    /** fill the list from internal file list */
    void FillFileList();
    void AddFileInfo(const FileInfo& info);
    // member variables
    wxListCtrl* m_fileListCtrl{ nullptr };
    wxChoice* m_modeChoice{ nullptr };
    wxSpinCtrlDouble* m_winsorTrim{ nullptr };
    wxSpinCtrlDouble* m_sigma{ nullptr };
    wxSpinCtrl* m_sigmaMaxIter{ nullptr };
    FileInfoVector m_files;
    PreviewWindow* m_preview{ nullptr };
    MyExecPanel* m_logWindow{ nullptr };
    wxArrayString m_outputFilenames;
    wxArrayString m_tempFiles;
    bool m_cleanupOutput = false;
    // store current sorting column
    long m_sortCol{ -1 };
    bool m_sortAscending{ true };

    DECLARE_DYNAMIC_CLASS(StackerPanel)
};

#endif // STACKERPANEL_H
