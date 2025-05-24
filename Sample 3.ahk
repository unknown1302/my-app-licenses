#Requires AutoHotkey v2.0
#SingleInstance Force

; --- CONFIG ---
CurrentVersion := "1"
VersionURL := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/version.txt"
PatchNotesURL := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/patch.txt"
ScriptURL := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/Sample3.ahk"
LicenseListURL := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/users.txt"

; --- Version Check ---
try {
    http := ComObject("WinHttp.WinHttpRequest.5.1")
    http.Open("GET", VersionURL)
    http.SetRequestHeader("User-Agent", "Mozilla/5.0")
    http.Send()
    http.WaitForResponse()
    urlversion := Trim(http.ResponseText, "`n")
} catch {
    urlversion := CurrentVersion
}

if (urlversion != CurrentVersion) {
    ; Fetch patch notes
    try {
        patch := ComObject("WinHttp.WinHttpRequest.5.1")
        patch.Open("GET", PatchNotesURL)
        patch.SetRequestHeader("User-Agent", "Mozilla/5.0")
        patch.Send()
        patch.WaitForResponse()
        patchnotes := Trim(patch.ResponseText, "`n")
    } catch {
        patchnotes := "(No patch notes available)"
    }

    answer := MsgBox(
        "A new Version is available!`n`nUpdate now?`n`nPatchnotes:`n" patchnotes "`n`nCurrent Version: v" CurrentVersion " | Latest Version: v" urlversion,
        "Application Update",
        "YesNo Icon!"
    )
    if (answer = "Yes") {
        try {
            ; Download new script and run it
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.Open("GET", ScriptURL)
            http.SetRequestHeader("User-Agent", "Mozilla/5.0")
            http.Send()
            http.WaitForResponse()
            file := FileOpen("Sample3_update.ahk", "w")
            file.Write(http.ResponseText)
            file.Close()
            Run('"' A_AhkPath '" "Sample3_update.ahk"')
            ExitApp
        } catch {
            MsgBox("Failed to download or run the update.", "Update Error", 0x10)
            ExitApp
        }
    }
    ; If "No", continue to license check
}

; --- LICENSE CHECK LOGIC ---
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

hwid := GetHWID()
today := FormatTime(, "yyyyMMdd")

try {
    http := ComObject("WinHttp.WinHttpRequest.5.1")
    http.Open("GET", LicenseListURL)
    http.SetRequestHeader("User-Agent", "Mozilla/5.0")
    http.Send()
    http.WaitForResponse()
    usersTxt := http.ResponseText
} catch {
    MsgBox("Could not connect to the license server.`nCheck your internet connection.", "Error", 0x10)
    ExitApp
}

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

A_Clipboard := hwid
MsgBox("Your HWID has been copied to the clipboard.`nSend it to the developer to activate your license:`n`n" hwid "`n`nIf you just sent your HWID, please wait 5-10 minutes and try again.", "License Request", 0x40)
ExitApp

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