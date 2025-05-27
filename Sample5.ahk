#Requires AutoHotkey v2.0
#Include GuiEnhancerKit.ahk
#Include ColorButton.ahk

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

; ------------- [ GLOBALS & SETTINGS ] -------------
global INI_PATH := A_ScriptDir "\settings.ini"
global FollowerGui := false
global FollowerSettings := Map("Window", "", "Resolution", "")
global WindowNames := []
global winDDL, resDDL
global toggleState := false
global Target_Window := ""
global macroRunning := false
global Started_Attack := false
global Started_Retarget := false
global AttackCTR := 0
global RetargetCTR := 0
global clientName := "", expiry := "", licType := "", SubscriptionDate := "", CurrentVersion := "1"

LoadSettings()

; ------------- [ LICENSE & UPDATE LOGIC ] -------------
LicenseURL := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/users.txt"
VersionURL := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/version.txt"
ScriptURL  := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/Sample5.ahk"
PatchNotesURL := "https://raw.githubusercontent.com/unknown1302/my-app-licenses/main/patch.txt"
TempFile := A_ScriptDir "\update_temp.ahk"

CheckForUpdate()
CheckLicense()

; ------------- [ MAIN GUI ] -------------
main := Gui(, "MACROS")
main.BackColor := 0x222222
main.SetFont("s9 cWhite", "Segoe UI")
main.SetDarkTitle()
WinWidth := 300

main.Add("Text", "x10 y10 w200 h20 +0x200", "CABAL MACROS")
settingsBtn := main.Add("Button", "x+0 yp w80 h20 +0x8000", "Settings")
settingsBtn.SetBackColor(0x2E2E2E,, 0)
settingsBtn.TextColor := 0xFFFFFF
settingsBtn.OnEvent("Click", ShowFollowerGui)

main.Add("Text", "x10 y35 w280 h1 Background0x555555")
main.Add("Text", "x15 y45 vSubText", "Subscription Until : " SubscriptionDate)
main.Add("Text", "x15 y65 vVerText", "Version : " CurrentVersion)
main.Add("Text", "x10 y85 w280 h1 Background0x555555")

; --- TABS ---
tabNames := ["Fast Macro", "Return Spot", "Extract"]
tabMargin := 10
tabW := Floor((WinWidth - 2 * tabMargin) / tabNames.Length)
tabButtons := []

loop tabNames.Length {
    name := tabNames[A_Index]
    x := tabMargin + (A_Index - 1) * tabW
    w := (A_Index = tabNames.Length) ? WinWidth - x - tabMargin : tabW
    btn := main.Add("Button", Format("x{} y90 w{} h25 +0x8000", x, w), name)
    btn.SetBackColor(0x2E2E2E,, 0)
    btn.TextColor := 0xFFFFFF
    btn.OnEvent("Click", ShowTab.Bind(name))
    tabButtons.Push(btn)
}
highlight := main.Add("Text", Format("x{} y115 w{} h2 Background0x77DD77", tabMargin, tabW))

tabContent := Map()
tabY := 120, tabH := 140

; --- FAST MACRO TAB ---
fastPage := []
fastPage.Push(main.Add("GroupBox", Format("x10 y{} w280 h{} +0x200 cWhite", tabY, tabH), "Fast Macro"))
fastPage.Push(main.Add("Text", Format("x20 y{} w260", tabY + 25), "Overview of this Fast Macro page"))
startBtn := main.AddButton("x" (WinWidth - 100)//2 " y275 w100 h36 +0x8000", "Start")
startBtn.TextColor := 0xFFFFFF
startBtn.SetBackColor(0x2E2E2E,, 0)
startBtn.OnEvent("Click", ToggleMacro)
tabContent["Fast Macro"] := fastPage

; --- OTHER TABS (placeholders) ---
returnPage := []
returnPage.Push(main.Add("GroupBox", Format("x10 y{} w280 h170 +0x200 cWhite", tabY), "Return Spot"))
returnPage.Push(main.Add("Text", Format("x20 y{} w260", tabY + 25), "Configure spot where your character returns"))
tabContent["Return Spot"] := returnPage

extractPage := []
extractPage.Push(main.Add("GroupBox", Format("x10 y{} w280 h170 +0x200 cWhite", tabY), "Extract"))
extractPage.Push(main.Add("Text", Format("x20 y{} w260", tabY + 25), "Configure which values to extract"))
tabContent["Extract"] := extractPage

ShowTab(tabName, *) {
    global tabNames, tabContent, highlight, tabW, tabMargin, startBtn
    loop tabNames.Length {
        if (tabNames[A_Index] = tabName)
            highlight.Move(tabMargin + (A_Index - 1) * tabW, 115, tabW, 2)
    }
    for k, controls in tabContent
        for ctrl in controls
            ctrl.Visible := (k = tabName)
    startBtn.Visible := (tabName = "Fast Macro")
}

ShowTab("Fast Macro")
main.Show("w" WinWidth " h320")

; --- FOLLOWER GUI (SETTINGS) ---
ShowFollowerGui(*) {
    global FollowerGui, WindowNames, FollowerSettings, main, winDDL, resDDL
    if (FollowerGui && WinExist("ahk_id " FollowerGui.Hwnd)) {
        FollowerGui.Destroy(), FollowerGui := false
        return
    }
    main.GetPos(&mx, &my, &mw, &mh)
    fx := mx + mw + 5
    fy := my

    FollowerGui := Gui("+Owner" main.Hwnd " -Caption +ToolWindow")
    FollowerGui.BackColor := 0x222222
    FollowerGui.SetFont("s9 cWhite", "Segoe UI")
    FollowerGui.SetFont("s10 cWhite Bold Italic")
    FollowerGui.Add("Text", "x0 y10 w300 Center", "Client Settings")
    FollowerGui.SetFont("s9 cWhite Norm")

    FollowerGui.Add("Text", "x10 y40 w90", "Window Name:")
    winDDL := FollowerGui.Add("DropDownList", "x100 y38 w140 AltSubmit", WindowNames)
    winDDL.Text := FollowerSettings["Window"]
    addBtn := FollowerGui.Add("Button", "x245 y38 w40 h24 +0x8000", "ADD")
    addBtn.SetBackColor(0x1c98da,, 0)
    addBtn.TextColor := 0xFFFFFF
    addBtn.OnEvent("Click", (*) => ShowAddWindowGui(winDDL))

    FollowerGui.Add("Text", "x10 y75 w90", "Resolution:")
    resDDL := FollowerGui.Add("DropDownList", "x100 y73 w140", ["800x600", "1024x768", "1280x720", "1920x1080"])
    resDDL.Text := FollowerSettings["Resolution"]

    saveBtn := FollowerGui.Add("Button", "x80 y110 w140 h30 +0x8000", "Save && Close")
    saveBtn.SetBackColor(0x2E2E2E,, 0)
    saveBtn.TextColor := 0xFFFFFF
    saveBtn.OnEvent("Click", SaveFollowerSettings)

    ; --- SETUP GUIDE RESTORED ---
    FollowerGui.Add("GroupBox", "x10 y150 w280 h120 cWhite", "Setup Guide")
    steps := ["100% Display Scaling", "Game Client Settings", "Skills & Looting Setup", "Side by Side Window"]
    colors := [0x1c98da, 0x118800, 0xdc3141, 0x6f42c1]
    Loop 4 {
        y := 175 + (A_Index - 1) * 22
        FollowerGui.Add("Text", Format("x20 y{} w60 h20 Center 0x200 Border Background{:06X} cWhite", y, colors[A_Index]))
            .Text := "STEP " A_Index
        link := FollowerGui.Add("Text", Format("x90 yp+2 w190 BackgroundTrans c4A90E2"), steps[A_Index])
        link.SetFont("Underline")
    }

    FollowerGui.Show("x" fx " y" fy " w300 h300")
}

SaveFollowerSettings(*) {
    global FollowerGui, winDDL, resDDL, FollowerSettings, Target_Window
    FollowerSettings["Window"] := winDDL.Text
    FollowerSettings["Resolution"] := resDDL.Text
    SaveSettings()
    Target_Window := FollowerSettings["Window"] ; update macro target
    if (FollowerGui && WinExist("ahk_id " FollowerGui.Hwnd))
        FollowerGui.Destroy(), FollowerGui := false
}

ShowAddWindowGui(winDDL) {
    local modal := Gui("+Owner" FollowerGui.Hwnd " -Caption +ToolWindow")
    modal.BackColor := 0x222222
    modal.SetFont("s9 cWhite", "Segoe UI")
    modal.Add("Text", "x10 y10 w260", "Enter new window name:")
    input := modal.Add("Edit", "x10 y30 w260 Background333333 cWhite")
    ok := modal.Add("Button", "x30 y70 w100 h30 +0x8000", "OK")
    ok.SetBackColor(0x416629,, 0)
    ok.TextColor := 0xFFFFFF
    cancel := modal.Add("Button", "x140 y70 w100 h30 +0x8000", "Cancel")
    cancel.SetBackColor(0xB40000,, 0)
    cancel.TextColor := 0xFFFFFF
    ok.OnEvent("Click", (*) => (
        txt := input.Text,
        (txt != "" && !WindowNames.Has(txt)) ? (
            WindowNames.Push(txt),
            winDDL.Add([txt]),
            winDDL.Text := txt
        ) : "",
        modal.Destroy()
    ))
    cancel.OnEvent("Click", (*) => modal.Destroy())
    modal.Show("w280 h120")
}

; ------------- [ MACRO LOGIC ] -------------
ToggleMacro(*) {
    global macroRunning, startBtn
    macroRunning := !macroRunning
    startBtn.Text := macroRunning ? "Stop" : "Start"
    startBtn.SetBackColor(macroRunning ? 0xB40000 : 0x2E2E2E,, 0)
    if macroRunning {
        StartFastMacro()
    } else {
        StopFastMacro()
    }
}

StartFastMacro() {
    global Started_Attack, Started_Retarget
    Started_Attack := true
    Started_Retarget := true
    SetTimer ATTACKREF, 100
    SetTimer RETARGETREF, 1000
}

StopFastMacro() {
    global Started_Attack, Started_Retarget
    Started_Attack := false
    Started_Retarget := false
    SetTimer ATTACKREF, 0
    SetTimer RETARGETREF, 0
}

; --- Macro Action Functions ---
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
ATTACKREF() {
    global AttackCTR, Target_Window, Started_Attack
    if !Started_Attack
        return
    hwnd := GetWindowHwnd(Target_Window)
    if !hwnd
        return
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
    global RetargetCTR, Target_Window, Started_Retarget
    if !Started_Retarget
        return
    hwnd := GetWindowHwnd(Target_Window)
    if !hwnd
        return
    RetargetCTR++
    if RetargetCTR = 1 {
        SendMiddleClick(hwnd, 0, 0)
        RetargetCTR := 0
    }
}

; ========== [ LICENSE, VERSION, SETTINGS, UPDATE LOGIC ] ==========

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
        return
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
    answer := MsgBox(
        "A new version is available!`n`nPatch notes:`n" patchnotes
        . "`n`nCurrent version: v" CurrentVersion " | Latest version: v" latest "`n`nUpdate now?",
        "Update Available",
        "YesNo Icon!"
    )
    if (answer != "Yes")
        return
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
    try {
        FileMove(TempFile, A_ScriptFullPath, true)
        MsgBox("Update complete! Script will now restart as administrator.", "Update Successful", 0x40)
        Run('*RunAs "' A_ScriptFullPath '"')
        ExitApp
    } catch {
        MsgBox("Failed to apply update. Try updating manually.", "Update Error", 0x10)
        return
    }
}

CheckLicense() {
    global LicenseURL, clientName, expiry, licType, SubscriptionDate, CurrentVersion, main
    hwid := GetHWID()
    today := FormatTime(, "yyyyMMdd")
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
    foundLicense := false, isExpired := false
    for line in StrSplit(usersTxt, "`n", "`r") {
        parts := StrSplit(Trim(line), " - ")
        if (parts.Length >= 4 && parts[2] = hwid) {
            clientName := parts[1]
            expiry := parts[3]
            licType := parts[4]
            SubscriptionDate := expiry
            foundLicense := true
            expiryCheck := StrReplace(expiry, "-", "")
            if (expiryCheck < today)
                isExpired := true
            break
        }
    }
    if foundLicense && !isExpired {
        ; OK
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
    ; Update subscription/version display
    if IsSet(main)
        main["SubText"].Text := "Subscription Until : " SubscriptionDate
    if IsSet(main)
        main["VerText"].Text := "Version : " CurrentVersion
}

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

; --- Settings Persistence ---
SaveSettings() {
    global FollowerSettings, WindowNames, INI_PATH
    IniWrite(FollowerSettings["Window"], INI_PATH, "Settings", "Window")
    IniWrite(FollowerSettings["Resolution"], INI_PATH, "Settings", "Resolution")
    IniDelete(INI_PATH, "Windows")
    Loop WindowNames.Length
        IniWrite(WindowNames[A_Index], INI_PATH, "Windows", A_Index)
}
LoadSettings() {
    global INI_PATH, WindowNames, FollowerSettings, Target_Window
    i := 1
    while val := IniRead(INI_PATH, "Windows", i, "")
        WindowNames.Push(val), i++
    if !WindowNames.Length
        WindowNames := ["CABAL"]
    FollowerSettings["Window"] := IniRead(INI_PATH, "Settings", "Window", WindowNames[1])
    FollowerSettings["Resolution"] := IniRead(INI_PATH, "Settings", "Resolution", "800x600")
    Target_Window := FollowerSettings["Window"]
}

; --- MOVE FOLLOWER GUI WITH MAIN ---
OnMessage(0x201, WM_LBUTTONDOWN)
OnMessage(0x0112, WM_SYSCOMMAND)
OnMessage(0x0003, WM_MOVE)
WM_LBUTTONDOWN(*) => PostMessage(0xA1, 2)
WM_SYSCOMMAND(wParam, lParam, msg, hwnd) {
    static SC_MOVE := 0xF010
    global last_pos
    if (hwnd = main.Hwnd && (wParam & 0xFFF0) = SC_MOVE)
        main.GetPos(&x, &y), last_pos := {x: x, y: y}
}
WM_MOVE(wParam, lParam, msg, hwnd) {
    global last_pos
    if (FollowerGui && WinExist("ahk_id " FollowerGui.Hwnd)) {
        main.GetPos(&x, &y)
        if last_pos {
            dx := x - last_pos.x, dy := y - last_pos.y
            FollowerGui.GetPos(&fx, &fy)
            FollowerGui.Move(fx + dx, fy + dy)
            last_pos := {x: x, y: y}
        }
    }
}

; --- CLOSE FOLLOWER GUI WHEN MAIN IS CLOSED ---
main.OnEvent("Close", CloseAllAndExit)
CloseAllAndExit(*) {
    global FollowerGui
    if (FollowerGui && WinExist("ahk_id " FollowerGui.Hwnd)) {
        FollowerGui.Destroy()
        FollowerGui := false
    }
    ExitApp()
}