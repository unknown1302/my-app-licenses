#Requires AutoHotkey v2.0
#SingleInstance Force

; --------- [ ALWAYS RUN AS ADMIN ] ---------
; If not running as admin, restart itself as admin and exit.
if !A_IsAdmin {
    try {
        Run('*RunAs "' A_ScriptFullPath '"')
        ExitApp
    } catch {
        MsgBox("Please run this script as administrator.", "Error", 0x10)
        ExitApp
    }
}

; --------- [ VERSION & UPDATE CONSTANTS ] ---------
CurrentVersion := "1"
VersionURL     := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/version.txt"
ScriptURL      := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/Sample3.ahk"
PatchNotesURL  := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/patch.txt"
TempFile       := A_ScriptDir "\update_temp.ahk"

; --------- [ AUTO-UPDATE LOGIC ] ---------
CheckForUpdate() {
    global CurrentVersion, VersionURL, ScriptURL, PatchNotesURL, TempFile

    ; -- Step 1: Get Latest Version Number --
    latest := ""
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", VersionURL)
        whr.Send()
        whr.WaitForResponse()
        latest := Trim(whr.ResponseText)
    } catch {
        latest := ""
    }
    if !latest or (latest = CurrentVersion)
        return  ; No update needed

    ; -- Step 2: Fetch Patch Notes (if available) --
    patchnotes := ""
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", PatchNotesURL)
        whr.Send()
        whr.WaitForResponse()
        if (whr.Status = 200)
            patchnotes := Trim(whr.ResponseText)
    } catch {
        patchnotes := ""
    }
    if !patchnotes
        patchnotes := "(No patch notes available)"

    ; -- Step 3: Ask User to Confirm Update --
    answer := MsgBox(
        "A new version is available!`n`nPatch notes:`n" patchnotes
        . "`n`nCurrent version: v" CurrentVersion " | Latest version: v" latest "`n`nUpdate now?",
        "Update Available",
        "YesNo Icon!"
    )
    if (answer != "Yes")
        return

    ; -- Step 4: Download New Script to Temp File --
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", ScriptURL)
        whr.Send()
        whr.WaitForResponse()
        if (whr.Status != 200) {
            MsgBox("Update failed! Server returned: " whr.Status "`n" whr.ResponseText, "Update Error", 0x10)
            return
        }
        file := FileOpen(TempFile, "w")
        if !IsObject(file)
            throw Error("Failed to open temp file for writing.")
        file.Write(whr.ResponseText)
        file.Close()
    } catch {
        MsgBox("Failed to download update.", "Update Error", 0x10)
        return
    }

    ; -- Step 5: Replace Script and Restart as Admin --
    try {
        FileMove(TempFile, A_ScriptFullPath, true)
        MsgBox("Update complete! Script will now restart as administrator.", "Update Successful", 0x40)
        Run('*RunAs "' A_ScriptFullPath '"') ; Always restart as admin!
        ExitApp
    } catch {
        MsgBox("Failed to apply update. Try updating manually.", "Update Error", 0x10)
        return
    }
}

; --------- [ RUN THE UPDATER AT START ] ---------
CheckForUpdate()

; --------- [ LICENSE LOGIC V5 ] ---------
LicenseURL := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/users.txt"
hwid := GetHWID()
today := FormatTime(, "yyyyMMdd")

; -- Step 1: Download License List --
try {
    http := ComObject("WinHttp.WinHttpRequest.5.1")
    http.Open("GET", LicenseURL)
    http.Send()
    http.WaitForResponse()
    usersTxt := http.ResponseText
} catch {
    MsgBox("Could not connect to the license server.`nCheck your internet connection.", "License Error", 0x10)
    ExitApp
}

; -- Step 2: Validate HWID and License Expiry --
foundLicense := false
isExpired := false
clientName := ""
expiry := ""
licType := ""

for line in StrSplit(usersTxt, "`n", "`r") {
    parts := StrSplit(Trim(line), " - ")
    if (parts.Length >= 4 && parts[2] = hwid) {
        clientName := parts[1]
        expiry := parts[3]
        licType := parts[4]
        foundLicense := true
        expiryCheck := StrReplace(expiry, "-", "")
        if (expiryCheck < today)
            isExpired := true
        break
    }
}

if foundLicense && !isExpired {
    ShowWelcomeGui(clientName, licType, expiry, CurrentVersion)
    return
}

if foundLicense && isExpired {
    MsgBox("? Your license for '" clientName "' expired on: " expiry ".`nPlease contact the developer to renew or extend your license.", "License Expired", 0x10)
    ExitApp
}

; -- Step 3: If no license, copy HWID & inform user --
A_Clipboard := hwid
MsgBox(
    "Your HWID has been copied to the clipboard.`n"
    . "Send it to the developer to activate your license:`n`n"
    . hwid
    . "`n`nIf you just sent your HWID, please wait 5-10 minutes and try again.",
    "License Request",
    0x40
)
ExitApp

; --------- [ HWID RETRIEVAL FUNCTION ] ---------
GetHWID() {
    try {
        svc := ComObjGet("winmgmts:\\.\root\cimv2")
        items := svc.ExecQuery("Select * from Win32_ComputerSystemProduct")
        for item in items
            if (val := item.UUID) != ""
                return val
    } catch {
        return ""
    }
    return ""
}

; --------- [ WELCOME GUI FUNCTION ] ---------
ShowWelcomeGui(clientName, licType, expiry, version) {
    myGui := Gui("+AlwaysOnTop", "Welcome!")
    myGui.SetFont("s11", "Segoe UI")
    myGui.AddText(, "? License OK!")
    myGui.AddText(, "Client: " clientName)
    myGui.AddText(, "Type: " licType)
    myGui.AddText(, "Expires: " expiry)
    myGui.AddText(, "Version: " version)
    myGui.AddButton("w120", "OK").OnEvent("Click", (*) => ExitApp())
    myGui.Show("w250 h210")
}

; --------- [ END OF SCRIPT ] ---------