#Requires AutoHotkey v2.0
#SingleInstance Force

CurrentVersion := "1"
VersionURL := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/version.txt"          ; Edit this!
ScriptURL  := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/Sample3.ahk"       ; Edit this!
TempFile   := A_ScriptDir "\update_temp.ahk"

CheckForUpdate() {
    global CurrentVersion, VersionURL, ScriptURL, TempFile
    ; Step 1: Fetch the latest version number
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

    ; Step 2: Download new script to temp file
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", ScriptURL)
        whr.Send()
        whr.WaitForResponse()
        file := FileOpen(TempFile, "w")
        if !IsObject(file)
            throw Error("Failed to open temp file for writing.")
        file.Write(whr.ResponseText)
        file.Close()
    } catch {
        MsgBox("Failed to download update.", "Update Error", 0x10)
        return
    }

    ; Step 3: Replace running script with update (after exit)
    try {
        FileMove(TempFile, A_ScriptFullPath, true) ; true=overwrite
        MsgBox("Update complete! Script will now restart.")
        Run('"' A_AhkPath '" "' A_ScriptFullPath '"')
        ExitApp
    } catch {
        MsgBox("Failed to apply update. Try updating manually.", "Update Error", 0x10)
        return
    }
}

; --- Call the updater at script start ---
CheckForUpdate()

; --- Your main logic below ---
MsgBox("Script is running! Version: " CurrentVersion)