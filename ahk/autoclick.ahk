#Requires AutoHotkey v2.0
#SingleInstance Force

SetBatchLines(-1)
SetDefaultMouseSpeed(0)

global toggle := false

F6:: {
	global toggle
	toggle := !toggle
	if toggle {
		SetTimer AutoClick, 25
		ToolTip "Auto-click enabled."
	} else {
		SetTimer AutoClick, 0
		ToolTip "Auto-click disabled."
	}
	SetTimer RemoveToolTip, -1000
}

AutoClick(*) {
	Click
}

RemoveToolTip(*) {
	ToolTip
}

F7:: ExitApp()
