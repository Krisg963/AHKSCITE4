;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; AutoHotkey Toolbar for SciTE4AutoHotkey ;
; Version 3.5                             ;
; by fincs                                ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;TillaGoto.iIncludeMode = 0x10111111

#NoEnv
#NoTrayIcon
#SingleInstance Ignore
#Include %A_ScriptDir%
#Include PlatformRead.ahk
#Include ComInterface.ahk
#Include SciTEDirector.ahk
#Include SciTEMacros.ahk
#Include ProfileUpdate.ahk
SetWorkingDir, %A_ScriptDir%
DetectHiddenWindows, On

CurrentSciTEVersion = 3 rc1

; CLSID and APPID for this script: don't reuse, please!
CLSID_SciTE4AHK := "{D7334085-22FB-416E-B398-B5038A5A0784}"
APPID_SciTE4AHK := "SciTE4AHK.Application"

ATM_OFFSET     := 0x1000
ATM_STARTDEBUG := ATM_OFFSET+0
ATM_STOPDEBUG  := ATM_OFFSET+1
ATM_RELOAD     := ATM_OFFSET+2
ATM_DIRECTOR   := ATM_OFFSET+3

; Uncompiled toolbar support
if !A_IsCompiled
	SetWorkingDir, %A_WorkingDir%\..
SciTEDir := A_WorkingDir

/* No longer necessary: compiled with AutoHotkey_L Unicode (Win2000+)
if A_OSType = WIN32_WINDOWS
{
	MsgBox, 16, AutoHotkey Toolbar for SciTE, This executable can only be run under Windows 2000+.
	ExitApp
}
*/

MAXTOOLS = 50

; Check if the properties file exists
IfNotExist, toolbar.properties
{
	MsgBox, 16, SciTE4AutoHotkey Toolbar, The property file doesn't exist!
	ExitApp
}

; Check if a SciTE window exists
IfWinNotExist, ahk_class SciTEWindow
{
	; Five seconds to let SciTE start up
	WinWait, ahk_class SciTEWindow,, 5
	if ErrorLevel
	{
		; Now we can err.
		MsgBox, 16, SciTE4AutoHotkey Toolbar, SciTE not found!
		ExitApp
	}
}

; Activate it
WinActivate
WinWaitActive

; Get the HWND of the SciTE window
scitehwnd := WinExist()

; Get the HMENU of the "Files" menu
scitemenu := DllCall("GetMenu", "ptr", scitehwnd, "ptr")
filesmenu := DllCall("GetSubMenu", "ptr", scitemenu, "int", 7, "ptr")

; Get the HWND of its Scintilla control
ControlGet, scintillahwnd, Hwnd,, Scintilla1

IsPortable := FileExist(SciTEDir "\$PORTABLE")
if !IsPortable
	LocalSciTEPath = %A_MyDocuments%\AutoHotkey\SciTE
else
	LocalSciTEPath = %SciTEDir%\user
LocalPropsPath = %LocalSciTEPath%\UserToolbar.properties

FileEncoding, UTF-8

; Read toolbar settings from properties file
FileRead, GlobalSettings, toolbar.properties
FileRead, LocalSettings, %LocalPropsPath%
FileRead, SciTEVersion, %LocalSciTEPath%\$VER
if SciTEVersion = 3 beta3
	gosub Update_3_beta3
else if SciTEVersion = 3 beta4
	gosub Update_3_beta4
else if SciTEVersion = 3 beta5
	gosub Update_3_beta5
else if !IsPortable && (!FileExist(LocalPropsPath) || SciTEVersion != CurrentSciTEVersion)
{
	;WinClose, ahk_class SciTEWindow
	
	; Create the SciTE user folder of this user
	RunWait, "%SciTEDir%\AutoHotkey.exe" "%SciTEDir%\tools\NewUser.ahk"
	FileAppend, %CurrentSciTEVersion%, %LocalSciTEPath%\$VER

	; Reload properties & reload user toolbar settings
	SendMessage, 1024+1, 0, 0,, ahk_id %scitehwnd%
	FileRead, LocalSettings, %LocalPropsPath%
	FirstTime := true
}

ToolbarProps := GlobalSettings "`n" LocalSettings

platforms := Util_ParsePlatforms("platforms.properties", platlist)
IfExist, %LocalSciTEPath%\_platform.properties
{
	FileReadLine, ov, %LocalSciTEPath%\_platform.properties, 2
	curplatform := SubStr(ov, 14)
}else
	curplatform = Default

Util_PopulatePlatformsMenu()

FileRead, temp, %LocalSciTEPath%\_platform.properties
if platforms[curplatform] != temp
	gosub changeplatform

; Load the tools
ntools = 12
_ToolButs =
(LTrim Join`n
-
Set current platform,1,,autosize
-
Run script (F5),2,,autosize
Debug script (F7),3,,autosize
Stop script,4,hidden,autosize
Run current line of code (F10),5,hidden,autosize
Run until next line of code (F11),6,hidden,autosize
Run until function/label exit (Shift+F11),7,hidden,autosize
Callstack,8,hidden,autosize
Variable list,9,hidden,autosize
---

)
_ToolIL := IL_Create(MAXTOOLS)
_IconLib := SciTEDir "\toolicon.icl"

Tools := []

; Set up the stock buttons
IL_Add(_ToolIL, _IconLib, 18)
IL_Add(_ToolIL, _IconLib, 2)
IL_Add(_ToolIL, _IconLib, 1)
IL_Add(_ToolIL, _IconLib, 3)
IL_Add(_ToolIL, _IconLib, 4)
IL_Add(_ToolIL, _IconLib, 5)
IL_Add(_ToolIL, _IconLib, 6)
IL_Add(_ToolIL, _IconLib, 7)
IL_Add(_ToolIL, _IconLib, 8)
Tools[2]  := { Path: "?switch" }
Tools[4]  := { Path: "?run" }
Tools[5]  := { Path: "?debug" }
Tools[6]  := { Path: "?stop" }
Tools[7]  := { Path: "?stepinto" }
Tools[8]  := { Path: "?stepover" }
Tools[9]  := { Path: "?stepout" }
Tools[10] := { Path: "?stacktrace" }
Tools[11] := { Path: "?varlist" }
i := 10

Loop, Parse, ToolbarProps, `n, `r
{
	curline := Trim(A_LoopField)
	if (curline = "")
		|| SubStr(curline, 1, 1) = ";"
		continue
	else if SubStr(curline, 1, 2) = "--"
	{
		_ToolButs .= "---`n"
		ntools++
		continue
	}else if SubStr(curline, 1, 1) = "-"
	{
		_ToolButs .= "-`n"
		ntools++
		continue
	}else if !RegExMatch(curline, "^=(.*?)\x7C(.*?)(?:\x7C(.*?)(?:\x7C(.*?))?)?$", varz)
		|| varz1 = ""
		continue
	else if (MAXTOOLS+2) = ntools
		break
	ntools ++
	IfInString, varz1, `,
	{
		MsgBox, 16, SciTE4AutoHotkey Toolbar, A tool name can't contain a comma! Specified:`n%varz1%
		ExitApp
	}
	varz4 := ParseCmdLine(varz4 = "" ? varz2 : varz4)
	curtool := Tools[ntools] := { Name: Trim(varz1), Path: Trim(varz2), Hotkey: Trim(varz3) }
	IfInString, varz4, `,
	{
		curtool.Picture := Trim(SubStr(varz4, 1, InStr(varz4, ",")-1))
		curtool.IconNumber := Trim(SubStr(varz4, InStr(varz4, ",")+1))
	}else
	{
		curtool.Picture := Trim(varz4)
		curtool.IconNumber := 1
	}
	
	_ToolButs .= curtool.Name "," i ",,autosize`n"
	IL_Add(_ToolIL, curtool.Picture, curtool.IconNumber)
	i ++
}

;  Get HWND of real SciTE toolbar. ~L
ControlGet, scitool, Hwnd,, ToolbarWindow321, ahk_id %scitehwnd%
ControlGetPos,,, guiw, guih,, ahk_id %scitool% ; Get size of real SciTE toolbar. ~L
; Get width of real SciTE toolbar to determine placement for our toolbar. ~L
SendMessage, 1024, 0, 0,, ahk_id %scitehwnd% ; send our custom message to SciTE
x := ErrorLevel

; Create and show the AutoHotkey toolbar
Gui, New, hwndhwndgui +Parent%scitool% -Caption, AHKToolbar4SciTE
Gui, +0x40000000 -0x80000000 ; Must be done *after* the GUI is created. Fixes focus issues. ~L
Gui, Show, x%x% y-2 w%guiw% h%guih% NoActivate
WinActivate, ahk_id %scitehwnd%

OnMessage(ATM_STARTDEBUG, "Msg_StartDebug")
OnMessage(ATM_STOPDEBUG, "Msg_StopDebug")
OnMessage(ATM_RELOAD, "Msg_Reload")
hToolbar := Toolbar_Add(hwndgui, "OnToolbar", "FLAT TOOLTIPS", _ToolIL)
Toolbar_Insert(hToolbar, _ToolButs)
Toolbar_SetMaxTextRows(hToolbar, 0)

; Build the menu
Menu, ToolMenu, Add, Edit User toolbar properties, editprops
Menu, ToolMenu, Add, Edit User autorun script, editautorun
Menu, ToolMenu, Add, Edit User Lua script, editlua
Menu, ToolMenu, Add
Menu, ToolMenu, Add, Edit Global toolbar properties, editglobalprops
Menu, ToolMenu, Add, Edit Global autorun script, editglobalautorun
Menu, ToolMenu, Add
Menu, ToolMenu, Add, Edit platform properties, editplatforms
Menu, ToolMenu, Add, Reload platforms, reloadplatforms
Menu, ToolMenu, Add
Menu, ToolMenu, Add, Reload toolbar, reloadtoolbar
Menu, ToolMenu, Add, Reload toolbar (with autorun), reloadtoolbarautorun
Menu, ToolMenu, Add
Menu, ToolMenu, Add, Check for updates..., check4updates
Menu, ToolMenu, Add, Close SciTE, exitroutine

; Create group for our windows
GroupAdd, SciTE4AutoHotkey, ahk_id %scitehwnd%
GroupAdd, SciTE4AutoHotkey, ahk_id %hwndgui%

; Set initial variables
dbg_active := false

; Build hotkeys
Hotkey, IfWinActive, ahk_id %scitehwnd%
Loop, %ntools%
	if Tools[A_Index].Hotkey != ""
		Hotkey, % Tools[A_Index].Hotkey, ToolHotkeyHandler

; Create the COM interface
InitComInterface()

; Register the SciTE director
Director_Init()

; Initialize the macro recorder
Macro_Init()

; Check for SciTE every 10 ms
; This must still be done as SciTE sometimes doesn't send the closing message
SetTimer, check4scite, 10

; Run the autorun script
var1 = %1%
var2 = %2%
if (var1 != "/NoAutorun" && var2 != "/NoAutorun")
	Run, "%SciTEDir%\AutoHotkey.exe" "%SciTEDir%\Autorun.ahk"

if FirstTime
{
	Director_Send("open:" CEscape(A_ScriptDir "\..\TestSuite.ahk"))
	MsgBox, 64, SciTE4AutoHotkey, Welcome to SciTE4AutoHotkey!
	Run, "%SciTEDir%\AutoHotkey.exe" "%SciTEDir%\tools\PropEdit.ahk"
}
return

; Toolbar event handler
OnToolbar(hToolbar, pEvent, pTxt, pPos, pId)
{
	Global
	Critical

	if pEvent = click
		RunTool(pPos)
}

GuiClose:
ExitApp

GuiContextMenu:
; Right click
Menu, ToolMenu, Show
return

check4updates:
Run, "%SciTEDir%\AutoHotkey.exe" "%SciTEDir%\tools\updater\SciTEUpdate.ahk"
return

exitroutine:
IfWinExist, ahk_id %scitehwnd%
{
	WinClose
	Sleep 100
	IfWinExist, SciTE ahk_class #32770
		WinWaitClose
	WinWaitClose, ahk_id %scitehwnd%,, 2
	if ErrorLevel = 1
		return
}
ExitApp

editprops:
Run, SciTE.exe "%LocalPropsPath%"
return

editautorun:
Run, SciTE.exe "%LocalSciTEPath%\Autorun.ahk"
return

editlua:
Run, SciTE.exe "%LocalSciTEPath%\UserLuaScript.lua"
return

editglobalprops:
if !A_IsAdmin
	DllCall("shell32\ShellExecute", "uint", 0, "str", "RunAs", "str", "notepad.exe" 
		, "str", """" SciTEDir "\toolbar.properties""", "str", SciTEDir, "int", 1)
else
	Run, notepad.exe "%SciTEDir%\toolbar.properties"
goto exitroutine

editglobalautorun:
if !A_IsAdmin
	DllCall("shell32\ShellExecute", "uint", 0, "str", "RunAs", "str", "SciTE.exe" 
		, "str", """" SciTEDir "\Autorun.ahk""", "str", SciTEDir, "int", 1)
else
	Run, SciTE.exe "%SciTEDir%\Autorun.ahk"
return

editplatforms:
if !A_IsAdmin
	DllCall("shell32\ShellExecute", "uint", 0, "str", "RunAs", "str", "SciTE.exe" 
		, "str", """" SciTEDir "\platforms.properties""", "str", SciTEDir, "int", 1)
else
	Run, SciTE.exe "%SciTEDir%\platforms.properties"
return

reloadplatforms:
Menu, PlatformMenu, DeleteAll
platforms := Util_ParsePlatforms("platforms.properties", platlist)
Util_PopulatePlatformsMenu()
goto changeplatform

reloadtoolbar:
Director_Send("closing:")
Msg_Reload()
return

reloadtoolbarautorun:
Director_Send("closing:")
Reload
return

check4scite:
; Close the application if the user has closed SciTE
IfWinNotExist, ahk_id %scitehwnd%
	gosub, exitroutine
return

/*
SciTE_OnClosed(filename)
{
	; Workaround: SciTE sometimes doesn't send the closing message
	SetTimer, check4scite, -10
}
*/

SciTE_OnClosing()
{
	Critical
	SetTimer, check4scite, -10
}

; Hotkey handler
ToolHotkeyHandler:
curhotkey := A_ThisHotkey
Loop, %ntools%
	toolnumber := A_Index
until Tools[toolnumber].Hotkey = curhotkey
RunTool(toolnumber)
return

platswitch:
curplatform := A_ThisMenuItem
platswitch2:
for i,plat in platlist
	Menu, PlatformMenu, Uncheck, %plat%
Menu, PlatformMenu, Check, %curplatform%
changeplatform:
FileDelete, %LocalSciTEPath%\_platform.properties
FileAppend, % platforms[curplatform], %LocalSciTEPath%\_platform.properties
SendMessage, 1024+1, 0, 0,, ahk_id %scitehwnd%
return

; Function to run a tool
RunTool(toolnumber)
{
	global Tools, dbg_active
	if SubStr(t := Tools[toolnumber].Path, 1, 1) = "?"
		p := "Cmd_" SubStr(t, 2), (IsFunc(p)) ? p.() : ""
	else if !dbg_active
	{
		Run, % ParseCmdLine(cmd := Tools[toolnumber].Path),, UseErrorLevel
		if ErrorLevel = ERROR
			MsgBox, 16, SciTE4AutoHotkey Toolbar, Couldn't launch specified command line! Specified:`n%cmd%
	}
}

Cmd_Switch()
{
	Menu, PlatformMenu, Show
}

Cmd_Run()
{
	global
	if !dbg_active
		PostMessage, 0x111, 303, 0,, ahk_id %scitehwnd%
	else
		SendMessage, 0x111, 1127, 0,, ahk_id %scitehwnd%
}

Cmd_Stop()
{
	global
	SendMessage, 0x111, 1128, 0,, ahk_id %scitehwnd%
}

Cmd_Debug()
{
	global
	;PostMessage, 0x111, 1106, 0,, ahk_id %scitehwnd%
	PostMessage, 0x111, 302, 0,, ahk_id %scitehwnd%
}

Cmd_StepInto()
{
	global
	SendMessage, 0x111, 1129, 0,, ahk_id %scitehwnd%
}

Cmd_StepOver()
{
	global
	SendMessage, 0x111, 1130, 0,, ahk_id %scitehwnd%
}

Cmd_StepOut()
{
	global
	SendMessage, 0x111, 1131, 0,, ahk_id %scitehwnd%
}

Cmd_Stacktrace()
{
	global
	SendMessage, 0x111, 1132, 0,, ahk_id %scitehwnd%
}

Cmd_Varlist()
{
	global
	SendMessage, 0x111, 1133, 0,, ahk_id %scitehwnd%
}

Msg_StartDebug(a,b,msg)
{
	global
	Toolbar_SetButton(hToolbar, 5, "hidden")
	Toolbar_SetButton(hToolbar, 6, "-hidden")
	Toolbar_SetButton(hToolbar, 7, "-hidden")
	Toolbar_SetButton(hToolbar, 8, "-hidden")
	Toolbar_SetButton(hToolbar, 9, "-hidden")
	Toolbar_SetButton(hToolbar, 10, "-hidden")
	Toolbar_SetButton(hToolbar, 11, "-hidden")
	dbg_active := true
}

Msg_StopDebug()
{
	global
	Toolbar_SetButton(hToolbar, 5, "-hidden")
	Toolbar_SetButton(hToolbar, 6, "hidden")
	Toolbar_SetButton(hToolbar, 7, "hidden")
	Toolbar_SetButton(hToolbar, 8, "hidden")
	Toolbar_SetButton(hToolbar, 9, "hidden")
	Toolbar_SetButton(hToolbar, 10, "hidden")
	Toolbar_SetButton(hToolbar, 11, "hidden")
	dbg_active := false
}

Msg_Reload()
{
	;Run, "%A_ScriptFullPath%" /restart /NoAutorun
	Run, "%A_AhkPath%" /restart "%A_ScriptFullPath%" /NoAutorun
}

GetSciTEOpenedFile()
{
	global scitehwnd, DirectorReady
	
	if DirectorReady
		return Director_Send("askfilename:", true).value
	else
	{
		WinGetTitle, sctitle, ahk_id %scitehwnd%
		if !RegExMatch(sctitle, "^(.+?) [-*] SciTE", o)
		{
			MsgBox, 16, SciTE4AutoHotkey Toolbar, Bad SciTE window!
			ExitApp
		}else
			return o1
	}
	;return Director_Send("askfilename:", true).value
}

GetFilename(txt)
{
	SplitPath, txt, o
	return o
}

GetPath(txt)
{
	SplitPath, txt,, o
	return o
}

ParseCmdLine(cmdline)
{
	global _IconLib, curplatform, LocalSciTEPath, SciTEDir
	a := GetSciTEOpenedFile()

	StringReplace, cmdline, cmdline, `%FILENAME`%, % GetFilename(a), All
	StringReplace, cmdline, cmdline, `%FILEPATH`%, % GetPath(a), All
	StringReplace, cmdline, cmdline, `%FULLFILENAME`%, % a, All
	StringReplace, cmdline, cmdline, `%LOCALAHK`%, "%SciTEDir%\AutoHotkey.exe", All
	StringReplace, cmdline, cmdline, `%AUTOHOTKEY`%, "%SciTEDir%\..\AutoHotkey.exe", All
	StringReplace, cmdline, cmdline, `%AUTOHOTKEYLA`%, "%SciTEDir%\..\AutoHotkey_L\AutoHotkey_La.exe", All
	StringReplace, cmdline, cmdline, `%AUTOHOTKEYLW`%, "%SciTEDir%\..\AutoHotkey_L\AutoHotkey_Lw.exe", All
	StringReplace, cmdline, cmdline, `%AUTOHOTKEYL64`%, "%SciTEDir%\..\AutoHotkey_L\AutoHotkey_L64.exe", All
	StringReplace, cmdline, cmdline, `%ICONRES`%, %_IconLib%, All
	StringReplace, cmdline, cmdline, `%SCITEDIR`%, % SciTEDir, All
	StringReplace, cmdline, cmdline, `%USERDIR`%, % LocalSciTEPath, All
	StringReplace, cmdline, cmdline, `%PLATFORM`%, %curplatform%, All

	return cmdline
}

Util_PopulatePlatformsMenu()
{
	global platlist, curplatform
	
	for i,plat in platlist
	{
		Menu, PlatformMenu, Add, %plat%, platswitch
		if (plat = curplatform)
			Menu, PlatformMenu, Check, %plat%
	}
}

Util_Is64bitWindows()
{
	DllCall("IsWow64Process", "ptr", DllCall("GetCurrentProcess", "ptr"), "uint*", retval)
	return ErrorLevel ? 0 : retval
}

Util_Is64bitProcess(pid)
{
	if !Util_Is64bitWindows()
		return 0
	
	proc := DllCall("OpenProcess", "uint", 0x0400, "uint", 0, "uint", pid, "ptr")
	DllCall("IsWow64Process", "ptr", proc, "uint*", retval)
	DllCall("CloseHandle", "ptr", proc)
	return retval ? 0 : 1
}
