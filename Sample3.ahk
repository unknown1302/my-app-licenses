#Requires AutoHotkey v2.0
#SingleInstance Force

CurrentVersion := "1"
VersionURL := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/version.txt"
ScriptURL  := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/Sample3.ahk"
PatchNotesURL := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/patch.txt"
TempFile   := A_ScriptDir "\update_temp.ahk"

CheckForUpdate() {
    global CurrentVersion, VersionURL, ScriptURL, PatchNotesURL, TempFile
    ; Step 1: Get Latest Version Number
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

    ; Step 2: Get Patch Notes (if available)
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

    ; Step 3: Ask User for Confirmation
    answer := MsgBox("A new version is available!`n`nPatch notes:`n" patchnotes "`n`nCurrent version: v" CurrentVersion " | Latest version: v" latest "`n`nUpdate now?", "Update Available", "YesNo Icon!")
    if (answer != "Yes")
        return

    ; Step 4: Download New Script to Temp File
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

    ; Step 5: Replace Running Script and Restart
    try {
        FileMove(TempFile, A_ScriptFullPath, true)
        MsgBox("Update complete! Script will now restart.", "Update Successful", 0x40)
        Run('"' A_AhkPath '" "' A_ScriptFullPath '"')
        ExitApp
    } catch {
        MsgBox("Failed to apply update. Try updating manually.", "Update Error", 0x10)
        return
    }
}

; --- Call the updater at script start ---
CheckForUpdate()

; --- Main Script Logic Below (license, GUI, etc) ---

ShowWelcomeGui(version) {
    myGui := Gui("+AlwaysOnTop", "Welcome!")
    myGui.SetFont("s11", "Segoe UI")
    myGui.AddText(, "? Script is running!")
    myGui.AddText(, "Version: " version)
    myGui.AddButton("w120", "OK").OnEvent("Click", (*) => ExitApp())
    myGui.Show("w250 h150")
}

; Example usage (you can replace this with your real license logic)
ShowWelcomeGui(CurrentVersion)