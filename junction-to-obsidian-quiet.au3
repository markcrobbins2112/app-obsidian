#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Change2NoAdmin=n ; Ensures the script requests Administrator privileges to run mklink
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <MsgBoxConstants.au3>
#include <FileConstants.au3>
#include <WinAPIShellEx.au3> ; Required for SHChangeNotify

; 1. Check if the parameter1 directory argument was passed from the context menu
If $CmdLine[0] < 1 Then
    MsgBox($MB_ICONERROR, "Error", "No target folder parameter was provided. Please use the right-click context menu.")
    Exit 1
EndIf

Local $sParameter1Dir = $CmdLine[1]

; 2. Fetch the OBSIDIAN_ROOT environment variable (The Physical Source)
Local $sObsidianRoot = EnvGet("OBSIDIAN_ROOT")
If $sObsidianRoot = "" Then
    MsgBox($MB_ICONERROR, "Error", "The environment variable 'OBSIDIAN_ROOT' is not defined.")
    Exit 2
EndIf

; Clean up any trailing backslashes from the root path
If StringRight($sObsidianRoot, 1) = "\" Then
    $sObsidianRoot = StringTrimRight($sObsidianRoot, 1)
EndIf

Local $sPhysicalSourceFolder = $sObsidianRoot & "\.obsidian"

; 3. Define the Link path to be created inside parameter1
; Clean up trailing backslash from parameter1 if present
If StringRight($sParameter1Dir, 1) = "\" Then
    $sParameter1Dir = StringTrimRight($sParameter1Dir, 1)
EndIf

Local $sNewJunctionLink = $sParameter1Dir & "\.obsidian"

; 4. Safety Validation Checks
If Not FileExists($sPhysicalSourceFolder) Then
    MsgBox($MB_ICONERROR, "Error", "The physical source folder does not exist:" & @CRLF & $sPhysicalSourceFolder)
    Exit 3
EndIf

If Not FileExists($sParameter1Dir) Then
    MsgBox($MB_ICONERROR, "Error", "The destination directory parameter1 does not exist:" & @CRLF & $sParameter1Dir)
    Exit 4
EndIf

If FileExists($sNewJunctionLink) Then
    MsgBox($MB_ICONERROR, "Error", "A folder or junction named '.obsidian' already exists inside:" & @CRLF & $sParameter1Dir)
    Exit 5
EndIf

; 5. Execute mklink via cmd.exe to form the Directory Junction
Local $sCommand = '/c mklink /J "' & $sNewJunctionLink & '" "' & $sPhysicalSourceFolder & '"'
Local $iPID = Run(@ComSpec & " " & $sCommand, "", @SW_HIDE)
ProcessWaitClose($iPID)

; 6. Verify successful creation and apply desktop.ini
If FileExists($sNewJunctionLink) Then
    
    ; --- START OF DESKTOP.INI MODIFICATION ---
    Local $sIniPath = $sParameter1Dir & "\desktop.ini"
    
    ; Clear old attributes on desktop.ini if it exists so we can overwrite it safely
    If FileExists($sIniPath) Then FileSetAttrib($sIniPath, "-RHS")

    ; Write configuration using native IniWrite. AutoIt automatically manages formatting 
    ; and structural compliance required by Windows Shell components.
    IniWrite($sIniPath, ".ShellClassInfo", "IconFile", "C:\$res\icon\extensions\obsidian.ico")
    IniWrite($sIniPath, ".ShellClassInfo", "IconIndex", "0")
    IniWrite($sIniPath, "{F29F85E0-4FF9-1068-AB91-08002B27B3D9}", "Prop5", "31,obsidian.ico")
    IniWrite($sIniPath, "FolderMarkerInfo", "Tag", "obsidian.ico")

    ; 1. Hide the desktop.ini file (Hidden + System required for file itself)
    FileSetAttrib($sIniPath, "+HS")
    
    ; 2. Apply ONLY Read-Only (+R) to the parent folder. No system attribute used.
    FileSetAttrib($sParameter1Dir, "-S") ; Strip any previous system attributes to be safe
    FileSetAttrib($sParameter1Dir, "+R")
    
    ; 3. Explicitly signal the Windows shell to clear cache and redraw this specific folder
    _WinAPI_ShellChangeNotify($SHCNE_UPDATEDIR, $SHCNF_PATH, $sParameter1Dir, 0)
    _WinAPI_ShellChangeNotify($SHCNE_ASSOCCHANGED, $SHCNF_IDLIST, 0, 0)
    ; --- END OF DESKTOP.INI MODIFICATION ---

    ;MsgBox($MB_ICONINFORMATION, "Success", "Junction created and folder icon applied using Read-Only attribute!" & @CRLF & @CRLF & "New Link: " & $sNewJunctionLink & @CRLF & "Points To: " & $sPhysicalSourceFolder)
Else
    MsgBox($MB_ICONERROR, "Error", "Failed to create junction point. Please ensure you approved the Administrator prompt.")
    Exit 6
EndIf
