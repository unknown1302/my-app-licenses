#Requires AutoHotkey v2.0
#SingleInstance Force

; === CONFIGURATION ===
LicenseListURL := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/users.txt"
VersionURL := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/version.txt"
ScriptDownloadURL := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/Sample3.ahk"
CurrentVersion := "1"

;Latest Update Testing

; === AUTO-UPDATE ===
CheckForUpdate() {
    global VersionURL, CurrentVersion, ScriptDownloadURL
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", VersionURL)
        whr.SetRequestHeader("User-Agent", "Mozilla/5.0")
        whr.Send()
        whr.WaitForResponse()
        remoteVersion := Trim(whr.ResponseText)
    } catch {
        remoteVersion := ""
    }
    if (remoteVersion && remoteVersion != CurrentVersion) {
        ; Download new EXE as update.tmp
        try {
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("GET", ScriptDownloadURL)
            whr.SetRequestHeader("User-Agent", "Mozilla/5.0")
            whr.Send()
            whr.WaitForResponse()
            bytes := whr.ResponseBody
            FileDelete("update.tmp")
            f := FileOpen("update.tmp", "w")
            f.RawWrite(bytes, bytes.Length)
            f.Close()
        } catch {
            MsgBox("Failed to download update!", "Error", 0x10)
            ExitApp
        }
        ; Write/Run updater script
        updater :=
        (
        '#Requires AutoHotkey v2.0
        oldFile := A_Args[1]
        newFile := A_Args[2]
        Sleep(1500)
        Try {
            FileDelete(oldFile)
            FileMove(newFile, oldFile)
            Run(' . Chr(34) . oldFile . Chr(34) . ')
        } catch {
            MsgBox("Failed to update application!", "Error", 0x10)
        }
        ExitApp
        ')
        FileDelete("updater.ahk")
        FileAppend(updater, "updater.ahk")
        Run('"' A_AhkPath '" "' A_ScriptDir '\updater.ahk" "' A_ScriptFullPath '" "update.tmp"')
        ExitApp
    }
}

CheckForUpdate()

; === LICENSE CHECK ===
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
    whr := ComObject("WinHttp.WinHttpRequest.5.1")
    whr.Open("GET", LicenseListURL)
    whr.SetRequestHeader("User-Agent", "Mozilla/5.0")
    whr.Send()
    whr.WaitForResponse()
    usersTxt := whr.ResponseText
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
    MsgBox("❌ Your license for '" clientName "' expired on: " expiry ".`nPlease contact the developer to renew or extend your license.", "License Expired", 0x10)
    ExitApp
}

A_Clipboard := hwid
MsgBox("Your HWID has been copied to the clipboard.`nSend it to the developer to activate your license:`n`n" hwid "`n`nIf you just sent your HWID, please wait 5-10 minutes and try again.", "License Request", 0x40)
ExitApp

ShowWelcomeGui(clientName, licType, expiry, version) {
    myGui := Gui("+AlwaysOnTop", "Welcome!")
    myGui.SetFont("s11", "Segoe UI")
    myGui.AddText(, "✅ License OK!")
    myGui.AddText(, "Client: " clientName)
    myGui.AddText(, "Type: " licType)
    myGui.AddText(, "Expires: " expiry)
    myGui.AddText(, "Version: " version)
    myGui.AddButton("w120", "OK").OnEvent("Click", (*) => ExitApp())
    myGui.Show("w250 h190")
}