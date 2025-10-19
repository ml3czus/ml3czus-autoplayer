#Requires AutoHotkey v1.1
; Auto-player for Roblox
; Created by @ml3czus_
Version := "1.2.0 (Settings Menu Test)"

; --- Global variables ---
CurrentLoop := 0
Paused := false
StopPlay := false
isPlaying := false
Songs := []
nosheet := 0
selectedSong := {}
isShuffling := false
prev_mx := -1
prev_my := -1
PauseReason := ""
AutoPaused := false
IsUserInChat := false
GuitarUnequipped := false
PauseDelay := 100
KeyDelay := 200
UseLoop := false
LoopOptionInfinity := false
LoopOptionLimit := false
LoopCount := 1
SheetsURL := "https://mleczus-autoplayer.vercel.app/songs.json"
ScriptURL := "https://mleczus-autoplayer.vercel.app/auto-player.ahk"

; --- JSON parser (simple embedded) ---
; coz autohotkey didn't have one so i needed to use chatgpt to import one here
JSON_Parse(str) {
    pos := 1
    return JSON_ParseValue(str, pos)
}
JSON_ParseValue(str, ByRef pos) {
    SkipWhitespace(str, pos)
    if (SubStr(str, pos, 1) = "{")
        return JSON_ParseObject(str, pos)
    else if (SubStr(str, pos, 1) = "[")
        return JSON_ParseArray(str, pos)
    else if (SubStr(str, pos, 1) = """")
        return JSON_ParseString(str, pos)
    else if (RegExMatch(SubStr(str, pos), "^\d", m))
        return JSON_ParseNumber(str, pos)
    else if (SubStr(str, pos, 4) = "true") {
        pos += 4
        return true
    } else if (SubStr(str, pos, 5) = "false") {
        pos += 5
        return false
    } else if (SubStr(str, pos, 4) = "null") {
        pos += 4
        return ""
    }
    return ""
}
SkipWhitespace(str, ByRef pos) {
    while (pos <= StrLen(str) && InStr(" `t`n`r", SubStr(str, pos, 1)))
        pos++
}
JSON_ParseObject(str, ByRef pos) {
    obj := {}
    pos++
    SkipWhitespace(str, pos)
    while (pos <= StrLen(str) && SubStr(str, pos, 1) != "}") {
        key := JSON_ParseString(str, pos)
        SkipWhitespace(str, pos)
        pos++
        SkipWhitespace(str, pos)
        val := JSON_ParseValue(str, pos)
        obj[key] := val
        SkipWhitespace(str, pos)
        if (SubStr(str, pos, 1) = ",")
            pos++
        SkipWhitespace(str, pos)
    }
    pos++
    return obj
}
JSON_ParseArray(str, ByRef pos) {
    arr := []
    pos++
    SkipWhitespace(str, pos)
    while (pos <= StrLen(str) && SubStr(str, pos, 1) != "]") {
        val := JSON_ParseValue(str, pos)
        arr.Push(val)
        SkipWhitespace(str, pos)
        if (SubStr(str, pos, 1) = ",")
            pos++
        SkipWhitespace(str, pos)
    }
    pos++
    return arr
}
JSON_ParseString(str, ByRef pos) {
    pos++
    result := ""
    while (pos <= StrLen(str)) {
        ch := SubStr(str, pos, 1)
        if (ch = "\") {
            pos++
            nextChar := SubStr(str, pos, 1)
            if (nextChar = "n")
                result .= "`n"
            else if (nextChar = "r")
                result .= "`r"
            else if (nextChar = "t")
                result .= "`t"
            else if (nextChar = """")
                result .= """"
            else if (nextChar = "/")
                result .= "/"
            else if (nextChar = "b")
                result .= Chr(8)
            else if (nextChar = "f")
                result .= Chr(12)
            else
                result .= nextChar
            pos++
            continue
        }
        if (ch = """") {
            pos++
            return result
        }
        result .= ch
        pos++
    }
    return ""
}
JSON_ParseNumber(str, ByRef pos) {
    re := "^\-?\d+(\.\d+)?([eE][+\-]?\d+)?"
    if RegExMatch(SubStr(str, pos), re, m)
    {
        val := m.Value
        pos += StrLen(val)
        return val + 0
    }
    return 0
}

; --- Menu Bar ---
Menu, FileMenu, Add, Load from File`tCtrl+O, LoadFromFile
Menu, FileMenu, Add, Reload Online Sheets, ReloadOnlineSheets
Menu, FileMenu, Add, Open Trello Board, OpenTrelloBoard
Menu, FileMenu, Add
Menu, FileMenu, Add, Exit`tAlt+F4, GuiClose

Menu, OptionsMenu, Add, Enable Tooltip, ToggleTooltip
Menu, OptionsMenu, Add
Menu, OptionsMenu, Add, Manual Pause Delay, TogglePauseDelay
Menu, OptionsMenu, Add, Configure Pause Delay..., ConfigurePauseDelay
Menu, OptionsMenu, Add
Menu, OptionsMenu, Add, Manual Key Delay, ToggleKeyDelay
Menu, OptionsMenu, Add, Configure Key Delay..., ConfigureKeyDelay
Menu, OptionsMenu, Add
Menu, OptionsMenu, Add, Enable Loop, ToggleLoop
Menu, OptionsMenu, Add, Configure Loop..., ConfigureLoop
Menu, OptionsMenu, Add
Menu, OptionsMenu, Add, Enable Shuffle (Simple), ToggleShuffle
Menu, OptionsMenu, Add, Enable Shuffle (Advanced), ToggleShuffleAdvanced
Menu, OptionsMenu, Add
Menu, OptionsMenu, Add, Unequipped Guitar Pause (WIP), ToggleUnequippedGuitarPause

Menu, OptionsMenu, Check, 1&
Menu, OptionsMenu, Disable, 4&
Menu, OptionsMenu, Disable, 7&
Menu, OptionsMenu, Disable, 10&

Menu, HelpMenu, Add, Check for Updates, CheckForUpdates
Menu, HelpMenu, Add, Give Feedback, FeedbackDiscord
Menu, HelpMenu, Add, Open Changelog, OpenChangelog
Menu, HelpMenu, Add
Menu, HelpMenu, Add, About Auto-player, AboutWindow

Menu, MenuBar, Add, File, :FileMenu
Menu, MenuBar, Add, Options, :OptionsMenu
Menu, MenuBar, Add, Help, :HelpMenu
Gui, Menu, MenuBar

; --- Sheet ---
Gui, Add, GroupBox, x10 y5 w320 h170 Center, Piano/Guitar Sheet
Gui, Add, Edit, R10 x20 y25 w300 h130 vSheet, Insert your Piano/Guitar sheet here :3

; --- Info ---
Gui, Add, GroupBox, x10 y385 w320 h75 Center, Info
Gui, Add, Text, x30 y400 w280 Center, F4 To Play`nPress F5 To Skip (i need to fix it)`nPress F6 To Pause/Resume`nPress F7 To Stop

; --- Online Sheets ---
Gui, Add, GroupBox, x10 y175 w320 h210 Center, Desert Bus Online Sheets
Gui, Add, ListBox, r13 x20 y195 w300 vSheetList AltSubmit gSheetList,

; --- Gui ---
Gui, Add, StatusBar,, Ready.
Gui, Color, FFFFFF
Gui, Show, w340 h495, Auto-player for Roblox

CheckForUpdates(false)
LoadSongsFromURL()

return

; --- Load from File ---
^o::
LoadFromFile:
    SB_SetText("Loading file...")

    SetTimer, ClearStatusBar, Off

    FileSelectFile, SelectedFile, 3,, Open a Sheet File, Text Documents (*.txt)
    if (!SelectedFile) {
        SB_SetText("No file selected.")
        SetTimer, ClearStatusBar, -3000
        return
    }

    SplitPath, SelectedFile, FileNameOnly, FileDir, FileExt
    
    if (FileExt != "txt") {
        SB_SetText("Only .txt files are supported.")
        SetTimer, ClearStatusBar, -3000
        return
    }

    FileRead, FileContent, %SelectedFile%

    GuiControl,, Sheet, %FileContent%
    SB_SetText("Loaded file: " . FileNameOnly)

    SetTimer, ClearStatusBar, -3000
return

; --- ListBox selection changed ---
SheetList:
    selectedIndex := A_EventInfo
    if (selectedIndex > 0) {
        selectedSong := Songs[selectedIndex]
        if (selectedSong) {
            GuiControl,, Sheet, % selectedSong.sheet
        }
}

; --- Load songs JSON ---
LoadSongsFromURL() {
    global Songs, SheetsURL
    try {
        http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", SheetsURL, false)
        http.Send()

        if (http.Status == 429) {
            MsgBox, 16, Rate Limit Exceeded, % "Rate limit exceeded. Please try again in a minute."
            return
        }
        if (http.Status != 200) {
            MsgBox, 16, HTTP Error, % "HTTP Error: " http.Status
            return
        }

        response := http.ResponseText

        Songs := JSON_Parse(response)
        if !IsObject(Songs) {
            MsgBox, 16, JSON Error, Failed to parse songs JSON.
            return
        }

        GuiControl,, SheetList, |

        listItems := ""
        for index, song in Songs {
            if IsObject(song) && song.HasKey("name") {
                listItems .= (listItems = "" ? "" : "|") . song.name
            }
        }
        GuiControl,, SheetList, %listItems%

        for index, song in Songs {
            if (song.sheet = "")
            nosheet++
        }

        SB_SetText("Loaded " . Songs.MaxIndex()-nosheet . " songs from online.")
        SetTimer, ClearStatusBar, -3000
    } 
    catch e {
        MsgBox, 16, Connection Error, % "Failed to connect to server.`nOnline Sheets won't be loaded.`nMake sure you are connected to the internet."
    }
}
return

; --- Reload Online Sheets ---
ReloadOnlineSheets:
    SB_SetText("Reloading online sheets...")
    LoadSongsFromURL()
return

; --- Check for Updates ---
CheckForUpdates(isManual := false) {
    global Version
    
    if (isManual) {
        SB_SetText("Checking for updates...")
    }
    
    apiURL := "https://api.github.com/repos/ml3czus/ml3czus-autoplayer/releases/latest"
    
    maxRetries := 3
    attempt := 0
    success := false
    http := ""
    
    Loop, %maxRetries%
    {
        attempt++
        
        http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        http.SetTimeouts(5000, 5000, 5000, 5000)
        http.Open("GET", apiURL, false)
        http.SetRequestHeader("User-Agent", "ml3czus-AutoPlayer-UpdateChecker")
        http.Send()
        success := true
        break
    }
    
    if (!success) {
        if (isManual) {
            MsgBox, 16, Update Checker, Failed to connect to GitHub after multiple attempts. Check your internet connection.
        }
        return
    }
    
    if (http.Status = 429) {
        MsgBox, 16, Update Checker, Rate limited by GitHub. Try again later.
        return
    }
    
    if (http.Status != 200) {
        MsgBox, 16, Update Checker, % "Failed to check for updates.`nHTTP Error: " . http.Status . " " . http.StatusText
        return
    }
    
    response := http.ResponseText
    
    if (response = "") {
        MsgBox, 16, Update Checker, Received empty response from GitHub API.
        return
    }
    
    tag_regex := """tag_name""\s*:\s*""([^""]+)"""
    if !RegExMatch(response, tag_regex, m) {
        MsgBox, 16, Update Checker, Could not parse latest version from GitHub response.
        return
    }
    
    latestVersion := Trim(StrReplace(m1, "v", ""))
    
    if (latestVersion = "") {
        MsgBox, 16, Update Checker, Invalid version format received from GitHub.
        return
    }
    
    if (latestVersion = Version) {
        if (isManual) {
            MsgBox, 64, Update Checker, % "You are using the latest version (" . Version . ")."
        }
        return
    }
    
    MsgBox, 68, Auto-player Update, % "A new version is available!`n`nCurrent: " . Version . "`nLatest: " . latestVersion . "`n`nDownload and install?"
    IfMsgBox No
        return
    
    jsonObj := JSON_Parse(response)
    if !IsObject(jsonObj) {
        MsgBox, 16, Update Checker, Failed to parse GitHub response.
        return
    }
    
    if !jsonObj.HasKey("assets") {
        MsgBox, 16, Update Checker, No assets found in release.
        return
    }
    
    assets := jsonObj["assets"]
    exeURL := ""
    
    for index, asset in assets {
        if (asset.HasKey("browser_download_url") && asset.HasKey("name")) {
            if (InStr(asset["name"], ".exe")) {
                exeURL := asset["browser_download_url"]
                break
            }
        }
    }
    
    if (exeURL = "") {
        MsgBox, 16, Update Checker, Could not find .exe download URL.
        return
    }
    
    MsgBox, 4, Update Available, % "A new version was downloaded: " . latestVersion . "`n`nChoose Yes to automatically replace the current installation (recommended), No to choose a save location."
    IfMsgBox No
    {
        defaultName := "Auto-player-" . latestVersion . ".exe"
        FileSelectFile, savePath, S16, %defaultName%, Save update as, Executable Files (*.exe)
        if (savePath = "") {
            SB_SetText("Update canceled.")
            SetTimer, ClearStatusBar, -3000
            return
        }
        
        UrlDownloadToFile, %exeURL%, %savePath%
        Sleep, 1000
        if !FileExist(savePath) {
            MsgBox, 16, Update Checker, Failed to download update to the selected location.
            return
        }
        
        MsgBox, 4, Update downloaded, % "Update saved to:`n" . savePath . "`n`nRun it now?"
        IfMsgBox Yes
            Run, %savePath%
        
        SB_SetText("Downloaded update to: " . savePath)
        SetTimer, ClearStatusBar, -3000
        return
    }
    
    tempFile := A_Temp . "\auto-player-" . latestVersion . ".exe"
    
    maxRetries := 3
    attempt := 0
    downloadOk := false
    
    Loop, %maxRetries%
    {
        attempt++
        UrlDownloadToFile, %exeURL%, %tempFile%
        Sleep, 500
        if FileExist(tempFile) {
            downloadOk := true
            break
        }
        Sleep, 1000
    }
    
    if (!downloadOk) {
        MsgBox, 16, Update Checker, Failed to download update after multiple attempts.
        return
    }
    
    currentFile := A_ScriptFullPath
    pid := DllCall("GetCurrentProcessId")
    helperFile := A_Temp . "\update_helper_" . A_TickCount . ".bat"
    
    FileDelete, %helperFile%
    
    helperContent := "@echo off`r`n"
    . "setlocal enabledelayedexpansion`r`n"
    . "set PID=" . pid . "`r`n"
    . "set MAXWAIT=120`r`n"
    . "set WAITED=0`r`n`r`n"
    . ":check_process`r`n"
    . "tasklist /FI ""PID eq !PID!"" 2>nul | find /i "".exe"" >nul`r`n"
    . "if errorlevel 1 goto process_closed`r`n"
    . "if !WAITED! geq !MAXWAIT! goto timeout`r`n`r`n"
    . "timeout /t 1 /nobreak >nul`r`n"
    . "set /a WAITED+=1`r`n"
    . "goto check_process`r`n`r`n"
    . ":process_closed`r`n"
    . "timeout /t 2 >nul`r`n"
    . "move /y """ . tempFile . """ """ . currentFile . """`r`n"
    . "if !errorlevel! equ 0 (`r`n"
    . "    start """" """ . currentFile . """`r`n"
    . "    exit /b 0`r`n"
    . ") else (`r`n"
    . "    echo Failed to replace executable`r`n"
    . "    goto cleanup`r`n"
    . ")`r`n`r`n"
    . ":timeout`r`n"
    . "echo Timeout waiting for process to close`r`n`r`n"
    . ":cleanup`r`n"
    . "timeout /t 2 >nul`r`n"
    . "del /f /q """ . helperFile . """ >nul 2>&1`r`n"
    . "exit /b`r`n"
    
    FileAppend, %helperContent%, %helperFile%
    
    if ErrorLevel {
        MsgBox, 16, Update Error, Failed to create update helper script.
        return
    }
    
    Run, %helperFile%, , Hide
    MsgBox, 64, Updating, The Auto-player will now close and update...
    ExitApp
}
return

CheckForUpdatesMenu:
    CheckForUpdates(true)
return

; --- Status Bar text stuff ---
SetStatusBarText(status := "") { ; status can be "playing", "paused", "stop", "shuffle" everything auto-lowercase
    global CurrentLoop, LoopLimit, isShuffleEnabled, isShuffleEnabledAdvanced, StopPlay, PauseReason, AutoPaused, selectedSong, isShuffling

    loopText := "Loop " . CurrentLoop . "/" . (LoopLimit = 0 ? "inf" : LoopLimit)
    text := ""

    StringLower, status, status

    if (status = "playing") {
        text := "Playing - " . loopText
    } else if (status = "paused") {
        statusText := AutoPaused ? "Auto-Paused" : "Paused"
        text := statusText . " - " . loopText

        if (PauseReason != "" || isShuffleEnabled) {
            text .= " ("
            if (PauseReason != "")
                text .= PauseReason
            if (PauseReason != "" && isShuffleEnabled)
                text .= ", "
            if (isShuffleEnabled)
                text .= "Shuffle Enabled"
            text .= ")"
        }
    } else if (status = "stop" || StopPlay) {
        text := "Stopped."
    } else if (status = "shuffle" && isShuffling) {
        text := "Shuffle - Shuffled song: " . selectedSong.name
    }

    SB_SetText(text)
}

; --- Tooltip text stuff ---
SetTooltipText(status := "", force := false) { ; status can be "playing", "paused", "stop", "shuffle" everything auto-lowercase 
    global CurrentLoop, LoopLimit, isShuffleEnabled, isShuffleEnabledAdvanced, EnableTooltipOption, selectedSong, isShuffling, StopPlay, PauseReason, AutoPaused, isShufflingSkip
    static prev_mx := "", prev_my := ""

    if (StopPlay) {
        return
    }

    if (!EnableTooltipOption || status = "") {
        ToolTip
        return
    }

    StringLower, status, status
    MouseGetPos, mx, my

    TooltipText := ""
    loopText := "Loop " . CurrentLoop . "/" . (LoopLimit = 0 ? "inf" : LoopLimit)

    if (status = "playing") {
        TooltipText := "Auto-player running`n" . loopText
        if (isShuffleEnabled || isShuffleEnabledAdvanced) {
            TooltipText .= " (Shuffle Enabled)"
        }
    } else if (status = "paused") {
        statusText := AutoPaused ? "Auto-Paused" : "Paused"
        TooltipText := "Auto-player running`n" . loopText . " (" . statusText
        if (isShuffleEnabled || isShuffleEnabledAdvanced) {
            TooltipText .= ", Shuffle Enabled"
        }
        TooltipText .= ")"

        if (PauseReason != "") {
            TooltipText .= "`nReason: " . PauseReason
        }
    } else if (status = "shuffle" && isShuffling) {
        TooltipText := "Shuffle - Shuffled song:`n" . selectedSong.name
    } else if (status = "shuffle-skip" && isShufflingSkip) {
        TooltipText := "Shuffle - Skipped song:`n" . selectedSong.name
    }

    if (force || mx != prev_mx || my != prev_my) {
        ToolTip, % TooltipText, , , (status = "shuffle" ? 2 : 1)
        prev_mx := mx
        prev_my := my
    }
}

ShowShuffleTooltip:
    SetTooltipText("shuffle")
return

ClearShuffleTooltip:
    SetTimer, ShowShuffleTooltip, Off
    Tooltip,,,, 2
    isShuffling := false
return

ClearStatusBar:
    SB_SetText("Ready.")
return

; --- Play (F4) ---
F4::
Play:
    Gui, Submit, NoHide
    global Sheet, isPlaying, Paused, UsePauseDelay, PauseDelay, UseKeyDelay, KeyDelay, UseLoop, LoopOptionLimit, LoopCount, LoopLimit, LoopOptionInfinity, isShuffleEnabled, isShuffleEnabledAdvanced, Songs, selectedSong, EnableTooltipOption
    startIndex := "", endIndex := ""

    if (isPlaying)
        return

    if (Sheet = "Insert your Piano/Guitar sheet here :3") {
        MsgBox, 16, Anti-placeholder Exception, % "Stop playing the placeholder text.`nChoose a sheet from the list or load a txt file."
        isPlaying := false
        return
    }

    if WinExist("ahk_exe RobloxPlayerBeta.exe") {
        WinActivate
    } else {
        MsgBox, 16, Roblox Not Found, % "Roblox Player is not running.`nPlease start Roblox and try again."
        return
    }

    isPlaying := true, Paused := false, AutoPaused := false, PauseReason := ""

    KeyDelayFound := false, SkipLines := true, NewSheet := "", found_key := false, found_pause := false

    if !RegExMatch(Sheet, "i)^.*delay[^\d\-]{0,10}(-?\d+).*", delayMatch)
    {
        SkipLines := false
    }

    Loop, Parse, Sheet, `n, `r
    {
        line := A_LoopField
    
        if (SkipLines) {
        
            if (!PauseDelayFound && RegExMatch(line, "i)pause\s+delay[^\d\-]{0,10}(-?\d+)", pauseMatch)) {
                PauseDelay := pauseMatch1
                PauseDelayText := "Auto set: " . PauseDelay
                GuiControl,, PauseDelay, %PauseDelayText%
                PauseDelayFound := true
                found_pause := true
                continue
            }
          
            if (!KeyDelayFound && !InStr(line, "i)pause\s+delay") && RegExMatch(line, "i)delay[^\d\-]{0,10}(-?\d+)", delayMatch)) {
                KeyDelay := delayMatch1
                KeyDelayText := "Auto set: " . KeyDelay
                GuiControl,, KeyDelay, %KeyDelayText%
                KeyDelayFound := true
                found_key := true
                continue
            }
          
            if (found_key || found_pause) {
                SkipLines := false
            }
            continue
        }
        NewSheet .= line "`n"
    }

    if RegExMatch(PauseDelay, "i)Auto set:\s*(\d+)", autoMatch) {
        extractedPauseDelay := autoMatch1 + 0
    } else if RegExMatch(PauseDelay, "^\d+$") {
        extractedPauseDelay := PauseDelay + 0
    } else {
        if (UsePauseDelay = false) {
            extractedPauseDelay := 100
        } else {
            MsgBox, 4,, Invaded value in Pause Delay.`nMust be a whole number.`nUse default value 100?`nChoosing "No" will stop the auto-player.
            IfMsgBox, Yes
                extractedPauseDelay := 100
            else {
                isPlaying := false
                return
            }
        }
    }

    if RegExMatch(KeyDelay, "i)Auto set:\s*(\d+)", autoMatch) {
        extractedKeyDelay := autoMatch1 + 0
    } else if RegExMatch(KeyDelay, "^\d+$") {
        extractedKeyDelay := KeyDelay + 0
    } else {
        if (UseKeyDelay = false) {
            extractedKeyDelay := 200
        } else {
            MsgBox, 4,, Invalid value in Key Delay.`nMust be a whole number.`nUse default value 200?`nChoosing "No" will stop the auto-player.
            IfMsgBox, Yes
                extractedKeyDelay := 200
            else {
                isPlaying := false
                return
            }
        }
    }

    if (extractedPauseDelay < 0 || extractedPauseDelay > 500) {
        MsgBox, 4,, Pause Delay value out of range (0-500).`nUse default value 100?`nChoosing "No" will stop the auto-player.
        IfMsgBox, Yes
            extractedPauseDelay := 100
        else {
            isPlaying := false
            return
        }
    }

    if (extractedKeyDelay < 0 || extractedKeyDelay > 500) {
        MsgBox, 4,, Key Delay value out of range (0-500).`nUse default value 200?`nChoosing "No" will stop the auto-player.
        IfMsgBox, Yes
            extractedKeyDelay := 200
        else {
            isPlaying := false
            return
        }
    }

    KeyDelayValue := extractedKeyDelay, PauseDelayValue := extractedPauseDelay

    NewSheet := RTrim(NewSheet, "`n"), Sheet := NewSheet
    GuiControl,, Sheet, %Sheet%

    if (!UseLoop) {
        LoopLimit := 1
    } else if (LoopOptionLimit) {
        if (!RegExMatch(LoopCount, "^\d+$") || LoopCount < 1) {
            MsgBox, 4,, Invalid Loop Count value.`nMust be a whole number >=1.`nUse infinite loops instead?`nChoosing "No" will stop the auto-player.
            IfMsgBox, Yes
                LoopLimit := 0
            else {
                isPlaying := false
                return
            }
        } else {
            LoopLimit := LoopCount + 0
        }
    } else {
        LoopLimit := 0
    }

    CurrentLoop := 0, StopPlay := false

    if  (EnableTooltipOption) {
        SetTimer, UpdateTooltip, 30
    }

    SetTimer, ManagePauseStateAndUI, 50

    while (!StopPlay) {
        CurrentLoop++
    
        SetStatusBarText("playing")
        SetTooltipText("playing", true)
    
        X := 1
        while (X := RegExMatch(Sheet, "U)(\[[^\[\]]+\]|.)", Match, X))
        {
            if (StopPlay) {
                break
            }
          
            WaitWhilePaused()
          
            X += StrLen(Match)
            Note := Trim(Match)
          
            if (RegExMatch(Note, "^\[.*\]$")) {
                NotesOnly := SubStr(Note, 2, -1)
                Loop, Parse, NotesOnly 
    	          {
                    WaitWhilePaused()
    		            if (StopPlay)
    		              break
                    SendInput, %A_LoopField%
                }
                Sleep, %KeyDelayValue%
                }
                else if (Note ~= "^[\r\n]+$") {
                    continue
                }
                else if (Note ~= "^[|/\\\n\r]$") {
                    Sleep, %PauseDelayValue%
                }
    	          else if (Note ~= "-") {
    	              Sleep, %KeyDelayValue%
    	          }
                else if !(Note ~= "[\[\]|/\\\n\r]") {
                    WaitWhilePaused()
    	              if (StopPlay)
    		                break
                SendInput, %Note%
                Sleep, %KeyDelayValue%
                }
        }
      
        if (StopPlay || (LoopLimit != 0 && CurrentLoop >= LoopLimit))
            break
    }

    ; --- Shuffler ---
    if (isShuffleEnabled) {
        SetTimer, UpdateTooltip, Off
        SetTimer, ManagePauseStateAndUI, Off
        ToolTip
        isPlaying := false
    
        if !(StopPlay || Paused) {
        
            if (isShuffleEnabled) {
                for index, song in Songs {
                  if (startIndex = "" && InStr(song.name, "Simple Guitar")) {
                      startIndex := index + 1
                  }
                  if (endIndex = "" && InStr(song.name, "Advanced Guitar")) {
                      endIndex := index - 1
                  }
                
                  if (startIndex != "" && endIndex != "")
                      break
                }
            }
          
            if (isShuffleEnabledAdvanced) {
                for index, song in Songs {
                    if (startIndex = "" && InStr(song.name, "Advanced Guitar")) {
                        startIndex := index + 1
                    }
                    endIndex := Songs.MaxIndex()
                  
                    if (startIndex != "" && endIndex != "")
                        break
                }
            }
          
            loop {
                Random, randIndex, startIndex, endIndex
                selectedSong := Songs[randIndex]
                if !InStr(selectedSong.name, "Simplified")
                    break
            }
          
            if IsObject(selectedSong) && selectedSong.HasKey("sheet") {
                Sheet := selectedSong.sheet
                GuiControl, Choose, SheetList, %randIndex%
                GuiControl,, Sheet, %Sheet%
            } else {
                MsgBox, 16, Shuffle Error, % "Shuffled item has no sheet!`nSelected song: " . selectedSong.name
                return
            }
          
            isShuffling := true
            if (EnableTooltipOption) {
                SetTooltipText("shuffle", true)
                SetStatusBarText("shuffle")
                SetTimer, ShowShuffleTooltip, 30
                SetTimer, ClearShuffleTooltip, -1500
            }
          
            Sleep, 1500
            Gosub, Play
            SetTimer, UpdateTooltip, On
            SetTimer, ManagePauseStateAndUI, On
        }
        return
    } else {
        SetTimer, UpdateTooltip, Off
        SetTimer, ManagePauseStateAndUI, Off
        ToolTip
        SetStatusBarText("stop")
        SetTimer, ClearStatusBar, -3000 
        isPlaying := false
        return
    }
return

ManagePauseStateAndUI() {
    static lastPausedState := ""
    global AutoPaused, PauseReason, IsUserInChat, Paused, GuitarUnequipped

    if (Paused)
        return

    shouldAutoPause := false
    reason := ""

    if (!WinActive("ahk_exe RobloxPlayerBeta.exe")) {
        shouldAutoPause := true
        reason := "Roblox unfocused"
    }

    if (IsUserInChat) {
        shouldAutoPause := true
        reason := "Chat interaction (Unfocus chat to unpause)"
    }

    if (GuitarUnequipped) {
        shouldAutoPause := true
        reason := "Guitar Unequipped"
    }

    if (shouldAutoPause) {
        AutoPaused := true
        PauseReason := reason
    } else {
        AutoPaused := false
        PauseReason := ""
    }

    if (AutoPaused != lastPausedState) {
        if (AutoPaused) {
            SetStatusBarText("paused")
            SetTooltipText("paused", true)
        } else {
            SetStatusBarText("playing")
            SetTooltipText("playing", true)
        }
        lastPausedState := AutoPaused
    }
}

WaitWhilePaused() {
    global Paused, AutoPaused, StopPlay

    if (StopPlay)
        return

    if (Paused || AutoPaused) {
        SetStatusBarText("paused")
        SetTooltipText("paused", true)
    }

    while ((Paused || AutoPaused) && !StopPlay) {
        SetTooltipText("paused")
        Sleep, 20
    }
}

UpdateTooltip() {
    global Paused, AutoPaused, StopPlay
    static prev_mx := "", prev_my := ""

    if (Paused || AutoPaused)
        return

    if (StopPlay)
        return

    MouseGetPos, mx, my
    if (mx != prev_mx || my != prev_my) {
        SetTooltipText("playing")
        prev_mx := mx
        prev_my := my
    }
}

; --- Chat Interaction key ---
#If !Paused
~/::
    global IsUserInChat, isPlaying, Paused
    IsUserInChat := true
return
#If

; --- Unfocus chat keys ---
#If IsUserInChat, !Paused
~LButton::
    global IsUserInChat, Paused, AutoPaused, PauseReason
    IsUserInChat := false
    AutoPaused := false
    PauseReason := ""
    Sleep, 300
return
#If

#If IsUserInChat, !Paused
~Enter::
    global IsUserInChat, Paused, AutoPaused, PauseReason
    IsUserInChat := false
    AutoPaused := false
    PauseReason := ""
    Sleep, 300
return
#If

; --- Guitar unequipped detection ---
#If isPlaying, !Paused, !IsUserInChat, !UnequippedGuitarPause,
1::
    global AutoPaused, PauseReason, Paused, GuitarUnequipped
    Send, 1
    GuitarUnequipped := !GuitarUnequipped
    if (GuitarUnequipped) {
        AutoPaused := true
        PauseReason := "Guitar Unequipped"
    } else {
        AutoPaused := false
        PauseReason := ""
    }
return

2::
    global AutoPaused, PauseReason, Paused, GuitarUnequipped
    Send, 2
    GuitarUnequipped := true
    AutoPaused := true
    PauseReason := "Guitar Unequipped"
return

3::
    Send, 3
    global AutoPaused, PauseReason, Paused, GuitarUnequipped
    GuitarUnequipped := true
    AutoPaused := true
    PauseReason := "Guitar Unequipped"
return

4::
    Send, 4
    global AutoPaused, PauseReason, Paused, GuitarUnequipped
    GuitarUnequipped := true
    AutoPaused := true
    PauseReason := "Guitar Unequipped"
return

5::
    Send, 5
    global AutoPaused, PauseReason, Paused, GuitarUnequipped
    GuitarUnequipped := true
    AutoPaused := true
    PauseReason := "Guitar Unequipped"
return

6::
    Send, 6
    global AutoPaused, PauseReason, Paused, GuitarUnequipped
    GuitarUnequipped := true
    AutoPaused := true
    PauseReason := "Guitar Unequipped"
return

7::
    Send, 7
    global AutoPaused, PauseReason, Paused, GuitarUnequipped
    GuitarUnequipped := true
    AutoPaused := true
    PauseReason := "Guitar Unequipped"
return

8::
    Send, 8
    global AutoPaused, PauseReason, Paused, GuitarUnequipped
    GuitarUnequipped := true
    AutoPaused := true
    PauseReason := "Guitar Unequipped"
return

9::
    Send, 9
    global AutoPaused, PauseReason, Paused, GuitarUnequipped
    GuitarUnequipped := true
    AutoPaused := true
    PauseReason := "Guitar Unequipped"
return

0::
    Send, 0
    global AutoPaused, PauseReason, Paused, GuitarUnequipped
    GuitarUnequipped := true
    AutoPaused := true
    PauseReason := "Guitar Unequipped"
return
#If

; --- Skip (F5 | Choosing from Online Sheet Database, if none selected it will play the first song from the list) ---
F5::
{
    global isShuffleEnabled, EnableTooltipOption, isShufflingSkip, selectedSong, Songs
    startIndex := "", endIndex := ""

    SetTimer, UpdateTooltip, Off
    SetTimer, ManagePauseStateAndUI, Off
    ToolTip
    isPlaying := false

    if (isShuffleEnabled) {
        startIndex := "", endIndex := ""
        for index, song in Songs {
            if (startIndex = "" && InStr(song.name, "DB Guitar Sheets by @phrogfibsh"))
                startIndex := index + 1
            endIndex := Songs.MaxIndex()
            if (startIndex != "" && endIndex != "")
                break
        }

        loop {
            Random, randIndex, startIndex, endIndex
            selectedSong := Songs[randIndex]
            if !InStr(selectedSong.name, "Simplified")
                break
        }

        if IsObject(selectedSong) && selectedSong.HasKey("sheet") {
            Sheet := selectedSong.sheet
            GuiControl, Choose, SheetList, %randIndex%
            GuiControl,, Sheet, %Sheet%
        } else {
            MsgBox, 16, Shuffle Error, % "Shuffled item has no sheet!`nSelected song: " . selectedSong.name
            isPlaying := false
            return
        }

        isShufflingSkip := true
        if (EnableTooltipOption) {
            SetTooltipText("shuffle-skip", true)
            SetStatusBarText("shuffle-skip")
            SetTimer, ShowShuffleTooltip, 30
            SetTimer, ClearShuffleTooltip, -1500
        }

        Sleep, 1500
        Gosub, Play
        SetTimer, UpdateTooltip, On
        SetTimer, ManagePauseStateAndUI, On

    } else {
        GuiControlGet, currentIndex, , SheetList
        if (currentIndex = "") {
            nextIndex := 1
        } else {
            nextIndex := currentIndex + 1
            if (nextIndex > Songs.MaxIndex())
                nextIndex := 1
        }

        selectedSong := Songs[nextIndex]
        if IsObject(selectedSong) && selectedSong.HasKey("sheet") {
            Sheet := selectedSong.sheet
            GuiControl, Choose, SheetList, %nextIndex%
            GuiControl,, Sheet, %Sheet%
        } else {
            MsgBox, 16, Selection Error, % "Selected item has no sheet!`nSelected song: " . selectedSong.name
            isPlaying := false
            return
        }

        Sleep, 1500
        Gosub, Play
        SetTimer, UpdateTooltip, On
        SetTimer, ManagePauseStateAndUI, On
    }
}
return

; --- Suspend/Resume (F6) ---
#If isPlaying
F6::
  Paused := !Paused
  if (Paused) {
      SetStatusBarText("paused")
      SetTooltipText("paused", true)
  } else {
      SetStatusBarText("playing")
      SetTooltipText("playing", true)
  }
return
#If

; --- Stop (F7) ---
#If isPlaying
F7::
    Critical
    StopPlay := true
    Paused := false
    SetTimer, UpdateTooltip, Off
    SetTimer, ManagePauseStateAndUI, Off
    SetStatusBarText("stop")
    ToolTip
    SetTimer, ClearStatusBar, -3000
return
#If

GuiClose:
ExitApp

; --- About Window ---
AboutWindow:
    Gui, About:Destroy
    Gui, About:+AlwaysOnTop +ToolWindow -SysMenu
    Gui, About:Add, Text, x20 y15 w260 Center, Auto-player for Roblox
    Gui, About:Add, Text, x20 y40 w260 Center, Version: %Version%
    Gui, About:Add, Text, x20 y65 w260 Center, Auto-player by @ml3czus_
    Gui, About:Add, Text, x20 y90 w260 Center, Sheets by @phrogfibsh (DB Guitar)
    Gui, About:Add, Text, x20 y105 w260 Center, and Others/Websites (Piano)
    Gui, About:Add, Text, x20 y135 w260 Center, Special thanks to:
    Gui, About:Add, Text, x20 y150 w260 Center, zekuuu <3333 (first tester and my beloved one <3)
    Gui, About:Add, Text, x20 y165 w260 Center, phrog (for sharing the autoplayer on trello <3)
    Gui, About:Add, Text, x20 y180 w260 Center, and you (%A_UserName%) for using it!
    Gui, About:Add, Button, x100 y235 w100 gAboutClose, Close
    Gui, About:Show, w300 h275, About Auto-player
return

AboutClose:
    Gui, About:Destroy
return

FeedbackDiscord:
    Run, https://discord.com/users/1345183564655890544
return

; --- Menu Actions ---
ToggleTooltip:
    global EnableTooltipOption
    EnableTooltipOption := !EnableTooltipOption
    Menu, OptionsMenu, % (EnableTooltipOption ? "Check" : "Uncheck"), 1&
return

TogglePauseDelay:
    global UsePauseDelay
    UsePauseDelay := !UsePauseDelay
    Menu, OptionsMenu, % (UsePauseDelay ? "Check" : "Uncheck"), 3&
    Menu, OptionsMenu, % (UsePauseDelay ? "Enable" : "Disable"), 4&
return

ConfigurePauseDelay:
    Gui, ConfigPauseDelay:Destroy
    Gui, ConfigPauseDelay:+AlwaysOnTop +ToolWindow -SysMenu
    Gui, ConfigPauseDelay:Add, Text, x20 y15 w260 Center, Current Value: %PauseDelay% ms
    Gui, ConfigPauseDelay:Add, Text, x20 y30 w260 Center, Set the Value between 0-500.
    Gui, ConfigPauseDelay:Add, Edit, x50 y50 w200 vPauseDelay,
    Gui, ConfigPauseDelay:Add, Button, x70 y90 w70 gSavePauseDelay, Save
    Gui, ConfigPauseDelay:Add, Button, x160 y90 w70 gCancelPauseDelay, Cancel
    Gui, ConfigPauseDelay:Show, w300 h130, Manual Pause Delay Configuration
return

SavePauseDelay:
    Gui, ConfigPauseDelay:Submit, NoHide
    PauseDelay := PauseDelay + 0
    Gui, ConfigPauseDelay:Destroy
return

CancelPauseDelay:
    Gui, ConfigPauseDelay:Destroy
return

ToggleKeyDelay:
    global UseKeyDelay
    UseKeyDelay := !UseKeyDelay
    Menu, OptionsMenu, % (UseKeyDelay ? "Check" : "Uncheck"), 6&
    Menu, OptionsMenu, % (UseKeyDelay ? "Enable" : "Disable"), 7&
return

ConfigureKeyDelay:
    Gui, ConfigKeyDelay:Destroy
    Gui, ConfigKeyDelay:+AlwaysOnTop +ToolWindow -SysMenu
    Gui, ConfigKeyDelay:Add, Text, x20 y15 w260 Center, Current Value: %KeyDelay% ms
    Gui, ConfigKeyDelay:Add, Text, x20 y30 w260 Center, Set the Value between 0-500.
    Gui, ConfigKeyDelay:Add, Edit, x50 y50 w200 vKeyDelay,
    Gui, ConfigKeyDelay:Add, Button, x70 y90 w70 gSaveKeyDelay, Save
    Gui, ConfigKeyDelay:Add, Button, x160 y90 w70 gCancelKeyDelay, Cancel
    Gui, ConfigKeyDelay:Show, w300 h130, Manual Key Delay Configuration
return

SaveKeyDelay:
    Gui, ConfigKeyDelay:Submit, NoHide
    KeyDelay := KeyDelay + 0
    Gui, ConfigKeyDelay:Destroy
return

CancelKeyDelay:
    Gui, ConfigKeyDelay:Destroy
return

ToggleLoop:
    global UseLoop
    UseLoop := !UseLoop
    Menu, OptionsMenu, % (UseLoop ? "Check" : "Uncheck"), 9&
    Menu, OptionsMenu, % (UseLoop ? "Enable" : "Disable"), 10&
return

ConfigureLoop:
    Gui, ConfigLoop:Destroy
    Gui, ConfigLoop:+AlwaysOnTop +ToolWindow -SysMenu
    Gui, ConfigLoop:Add, Text, x0 y15 w260 Center, Configure Loop Options
    Gui, ConfigLoop:Add, Radio, x30 y45 vLoopOptionInfinity gLoopOptionChanged Checked, Infinite Loop
    Gui, ConfigLoop:Add, Radio, x30 y75 vLoopOptionLimit gLoopOptionChanged, Limited Loops
    Gui, ConfigLoop:Add, Edit, x140 y73 w50 vLoopCount Disabled, 1+
    Gui, ConfigLoop:Add, Button, x50 y115 w70 gSaveLoopOptions, Save
    Gui, ConfigLoop:Add, Button, x130 y115 w70 gCancelLoopOptions, Cancel

    GuiControl,, LoopOptionInfinity, %LoopOptionInfinity%
    GuiControl,, LoopOptionLimit, %LoopOptionLimit%
    GuiControl,, LoopCount, %LoopCount%

    Gui, ConfigLoop:Show, w260 h150, Loop Configuration
return

LoopOptionChanged:
    Gui, Submit, NoHide
    if (LoopOptionLimit && UseLoop)
        GuiControl, Enable, LoopCount
    else {
        GuiControl, Disable, LoopCount
        if (LoopCount = "")
            GuiControl,, LoopCount, 1+
    }
    if (LoopOptionLimit && UseLoop) {
        GuiControl,, LoopOptionInfinity, 0
    }
    if (LoopOptionInfinity && UseLoop) {
        GuiControl,, LoopOptionLimit, 0
        GuiControl,, LoopCount, 1+
    }

return

SaveLoopOptions:
    Gui, ConfigLoop:Submit, NoHide
    LoopOptionInfinity := LoopOptionInfinity
    LoopOptionLimit := LoopOptionLimit
    LoopCount := LoopCount + 0
    Gui, ConfigLoop:Destroy
return

CancelLoopOptions:
    Gui, ConfigLoop:Destroy
return

ToggleShuffle:
    global isShuffleEnabled
    isShuffleEnabled := !isShuffleEnabled
    Menu, OptionsMenu, % (isShuffleEnabled ? "Check" : "Uncheck"), 12&
    if (isShuffleEnabled) {
        Menu, OptionsMenu, Uncheck, 13&
        isShuffleEnabledAdvanced := false
        Menu, OptionsMenu, Uncheck, 9&
        Menu, OptionsMenu, Disable, 9&
        Menu, OptionsMenu, Disable, 10&
        UseLoop := false
    } else {
        Menu, OptionsMenu, Enable, 9&
    }
Return

ToggleShuffleAdvanced:
    global isShuffleEnabledAdvanced
    isShuffleEnabledAdvanced := !isShuffleEnabledAdvanced
    Menu, OptionsMenu, % (isShuffleEnabledAdvanced ? "Check" : "Uncheck"), 13&
    if (isShuffleEnabledAdvanced) {
        Menu, OptionsMenu, Uncheck, 12&
        isShuffleEnabled := false
        Menu, OptionsMenu, Uncheck, 9&
        Menu, OptionsMenu, Disable, 9&
        Menu, OptionsMenu, Disable, 10&
        UseLoop := false
    } else {
        Menu, OptionsMenu, Enable, 9&
    }
return

ToggleUnequippedGuitarPause:
    global UnequippedGuitarPause
    UnequippedGuitarPause := !UnequippedGuitarPause
    Menu, OptionsMenu, % (UnequippedGuitarPause ? "Check" : "Uncheck"), 15&

OpenTrelloBoard:
    Run, https://trello.com/b/ue1LfwEa/
return

OpenChangelog:
    Run, https://mleczus-autoplayer.vercel.app/changelog/
return
