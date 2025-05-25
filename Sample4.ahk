#Requires AutoHotkey v2.0
#SingleInstance Off
#MaxThreadsPerHotkey 2

; ------------- [ ALWAYS RUN AS ADMIN ] -------------
if !A_IsAdmin {
    try {
        Run('*RunAs "' A_ScriptFullPath '"')
        ExitApp
    } catch {
        MsgBox("Right Click me `nThen 'Run as Administrator'.")
        ExitApp
    }
}

; ------------- [ VERSION & UPDATE CONSTANTS ] -------------
CurrentVersion := "1"
VersionURL     := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/version.txt"
ScriptURL      := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/Sample4.ahk"
PatchNotesURL  := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/patch.txt"
TempFile       := A_ScriptDir "\update_temp.ahk"

; ------------- [ AUTO-UPDATE LOGIC ] -------------
CheckForUpdate() {
    global CurrentVersion, VersionURL, ScriptURL, PatchNotesURL, TempFile

    ; Get Latest Version Number
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

    ; Fetch Patch Notes (if available)
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

    ; Ask User to Confirm Update
    answer := MsgBox(
        "A new version is available!`n`nPatch notes:`n" patchnotes
        . "`n`nCurrent version: v" CurrentVersion " | Latest version: v" latest "`n`nUpdate now?",
        "Update Available",
        "YesNo Icon!"
    )
    if (answer != "Yes")
        return

    ; Download New Script to Temp File
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

    ; Replace Script and Restart as Admin
    try {
        FileMove(TempFile, A_ScriptFullPath, true)
        MsgBox("Update complete! Script will now restart as administrator.", "Update Successful", 0x40)
        ;Run('*RunAs "' A_ScriptFullPath '"')
        ;cmd := "*RunAs " . Chr(34) . A_ScriptFullPath . Chr(34)
        ;Run(cmd)
        Run(A_ScriptFullPath, "", "UseErrorLevel", "RunAs")
        ExitApp
    } catch {
        MsgBox("Failed to apply update. Try updating manually.", "Update Error", 0x10)
        return
    }
}
CheckForUpdate()

; ------------- [ LICENSE LOGIC V5 ] -------------
LicenseURL := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/users.txt"
hwid := GetHWID()
today := FormatTime(, "yyyyMMdd")

; Download License List
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

; Validate HWID and License Expiry
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
    ; Continue to show macro GUI
} else if foundLicense && isExpired {
    MsgBox("? Your license for '" clientName "' expired on: " expiry ".`nPlease contact the developer to renew or extend your license.", "License Expired", 0x10)
    ExitApp
} else {
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
}

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

; ========== [ MACRO GUI & LOGIC ] ==========

DetectHiddenWindows true
SetTitleMatchMode 1
Target_Window := ""
SetControlDelay -1

mainGui := Gui("+AlwaysOnTop", "Macro")
mainGui.SetFont("s10", "Candara")
mainGui.Add("GroupBox", "x5 w250 h90 center cBlue", "CABAL Set Window")
mainGui.Add("Button", "x12 y25 w230 h30", "Set Window").OnEvent("Click", (*) => Set_Location(mainGui))
mainGui.Add("Edit", "x10 y60 w235 h25 ReadOnly center vTarget_Window", Target_Window)

mainGui.Add("GroupBox", "x5 y100 w250 h90 center cGreen", "CABAL Controls")
mainGui.SetFont("s10", "Candara")
btnRetarget := mainGui.Add("Button", "x12 y120 w235 h30 vTheRetarget", "Start Retarget")
btnRetarget.OnEvent("Click", (*) => RETARGET(btnRetarget))

btnAttack := mainGui.Add("Button", "x12 y155 w235 h30 vTheAttack", "Start Attack")
btnAttack.OnEvent("Click", (*) => ATTACK(btnAttack))

mainGui.Add("GroupBox", "x5 y195 w250 h90 center cRed", "CABAL Settings Guide")
mainGui.SetFont("s10 underline", "Candara")
mainGui.Add("Text", "x67 y220 w200 h30 c0000cc", "(Game Settings Setup)").OnEvent("Click", (*) => Run("Bin\\guideSettings.png"))
mainGui.Add("Text", "x71 y250 w200 h30 c0000cc", "(Skills/Looting Setup)").OnEvent("Click", (*) => Run("Bin\\guideSkills.png"))

; --------- [ LICENSE/VERSION INFO DISPLAY ] ---------
mainGui.SetFont("s9", "Segoe UI")
mainGui.Add("GroupBox", "x5 y285 w250 h60 center", "License Info")
mainGui.Add("Text", "x12 y305 w235 h20", "Client: " clientName)
mainGui.Add("Text", "x12 y325 w235 h20", "Type: " licType " | Expires: " expiry)
mainGui.SetFont("s10 underline", "Candara")
mainGui.Add("Text", "x215 y355 w130 h20 cGreen", "v" CurrentVersion)

mainGui.OnEvent("Close", (*) => ExitApp())
mainGui.Show("w258 h375")

Started_Attack := false
Started_Retarget := false
global AttackCTR := 0
global RetargetCTR := 0

; ------------------ CORE FUNCTIONS ------------------

Set_Location(guiRef) {
    global Target_Window
    Target_Window := Set_Window()
    if !WinExist(Target_Window) {
        MsgBox("Target window not found: " Target_Window)
        return
    }
    guiRef["Target_Window"].Value := Target_Window
}

Set_Window() {
    isPressed := false
    i := 0
    loop {
        if !GetKeyState("RButton") && !isPressed
            isPressed := true
        else if GetKeyState("RButton") && isPressed {
            i += 1
            isPressed := false
            if i >= 2 {
                winTitle := WinGetTitle("A")
                ToolTip()
                return winTitle
            }
        }
        tempWindow := WinGetTitle("A")
        ToolTip("Right Click on the target window twice to set`n`nCurrent Window: " tempWindow)
        Sleep 50
    }
}

GetWindowHwnd(winTitle) {
    return WinExist(winTitle)
}

SendRightClick(hwnd, x, y) {
    lParam := (y << 16) | (x & 0xFFFF)
    PostMessage(0x204, 1, lParam, , hwnd)  ; WM_RBUTTONDOWN
    Sleep(10)
    PostMessage(0x205, 0, lParam, , hwnd)  ; WM_RBUTTONUP
}

SendMiddleClick(hwnd, x, y) {
    lParam := (y << 16) | (x & 0xFFFF)
    PostMessage(0x207, 1, lParam, , hwnd)  ; WM_MBUTTONDOWN
    Sleep(10)
    PostMessage(0x208, 0, lParam, , hwnd)  ; WM_MBUTTONUP
}

; ------------------ BUTTON LOGIC ------------------

ATTACK(btn) {
    global Started_Attack
    Started_Attack := !Started_Attack
    btn.Text := Started_Attack ? "Stop Attacking" : "Start Attack"
    SetTimer ATTACKREF, Started_Attack ? 100 : 0
}

RETARGET(btn) {
    global Started_Retarget
    Started_Retarget := !Started_Retarget
    btn.Text := Started_Retarget ? "Stop Retarget" : "Start Retarget"
    SetTimer RETARGETREF, Started_Retarget ? 1000 : 0
}

; ------------------ CLICK LOGIC ------------------

ATTACKREF() {
    global AttackCTR, Target_Window
    hwnd := GetWindowHwnd(Target_Window)
    if !hwnd {
        MsgBox("Invalid target window.")
        return
    }

    AttackCTR++
    if AttackCTR = 1 {
        coords := [
            [236, 576], [272, 582], [300, 582], [328, 581],
            [365, 580], [387, 582], [420, 580], [449, 577],
            [475, 579], [512, 583], [534, 581], [571, 578]
        ]
        for xy in coords {
            x := xy[1], y := xy[2]
            SendRightClick(hwnd, x, y)
            Sleep(30)
        }
        AttackCTR := 0
    }
}

RETARGETREF() {
    global RetargetCTR, Target_Window
    hwnd := GetWindowHwnd(Target_Window)
    if !hwnd
        return

    RetargetCTR++
    if RetargetCTR = 1 {
        SendMiddleClick(hwnd, 0, 0)
        RetargetCTR := 0
    }
}

; ------------------ HOTKEY TO EXIT ------------------

;`::ExitApp
;Esc::ExitApp

; ========== END OF SCRIPT ==========