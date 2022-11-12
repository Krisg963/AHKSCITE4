#Requires AutoHotkey v2-b+
#Include "Common.ahk"

FileEncoding "UTF-8-RAW"
SetWorkingDir A_ScriptDir "\..\source"

if A_PtrSize != 4 {
	MsgBox "This script only works with the 32-bit version of AutoHotkey."
	ExitApp
}

g_ahk2DocsPath := A_WorkingDir "\..\..\AutoHotkey_v2_Docs"

sc := ComObject("ScriptControl"), sc.Language := "JScript"
sc.AddCode(FileRead(g_ahk2DocsPath "\docs\static\source\data_index.js"))
ji := sc.Eval("indexData")
if !ji || !ji.length
	throw Error("Failed to read/parse data_index.js")

; XX: Overrides for expression-directives. For some reason these are tagged as
; taking a string, even though they really take an integer (or a boolean).
g_directivesExpr := Set("ClipboardTimeout","HotIfTimeout","InputLevel","MaxThreads",
	"MaxThreadsBuffer","MaxThreadsPerHotkey","SuspendExempt","UseHook","WinActivateForce")
g_directivesStr := Set()

; XX: Some of these have missing entries - manually add them in.
; We also recategorize true/false as reserved words, as they aren't actually variables.
g_controlFlow := Set("Loop")
g_reserved := Set("as", "contains", "false", "in", "IsSet", "super", "true", "unset")
g_knownVars := Set("this", "ThisHotkey")
g_knownFuncs := Set()
g_knownClasses := Set()

g_knownProps := Set(
	; Meta-properties and other conventions
	"__Item", "__Class", "Ptr", "Size", "Handle", "Hwnd",

	; Any
	"base",

	; Func
	"Name", "IsBuiltIn", "IsVariadic", "MinParams", "MaxParams",

	; Class
	"Prototype",

	; Array
	"Length", "Capacity",

	; Map
	"Count", "Capacity", "CaseSense", "Default",

	; Error
	"Message", "What", "Extra", "File", "Line", "Stack",

	; File
	"Pos", "Length", "AtEOF", "Encoding",
)

g_knownMethods := Set(
	; Meta-methods and other conventions
	"__Init", "__New", "__Delete", "__Get", "__Set", "__Call", "__Enum", "Call",

	; Any
	"GetMethod", "HasBase", "HasMethod", "HasProp",

	; Object
	"Clone", "DefineProp", "DeleteProp", "GetOwnPropDesc", "HasOwnProp", "OwnProps",

	; Func
	"Bind", "IsByRef", "IsOptional",

	; Array
	"Clone", "Delete", "Has", "InsertAt", "Pop", "Push", "RemoveAt",

	; Map
	"Clear", "Clone", "Delete", "Get", "Has", "Set",

	; File
	"Read", "Write", "ReadLine", "WriteLine", "RawRead", "RawWrite", "Seek", "Close",

)

; File methods
for typ in ["UInt","Int","Int64","Short","UShort","Char","UChar","Double","Float"] {
	g_knownMethods.Add "Read" typ
	g_knownMethods.Add "Write" typ
}

ignoreKeywords := Set("byref", "default")

Loop ji.length {
	item_name := ji.%A_Index-1%.0
	item_path := ji.%A_Index-1%.1
	try item_type := ji.%A_Index-1%.2
	catch Any
		item_type := -1

	if !RegExMatch(item_name, "^(#?[a-zA-Z_][0-9a-zA-Z_]*)", &o) or ignoreKeywords.Has(o[1])
		continue

	/*
	0 - directive
	1 - built-in var
	2 - built-in function
	3 - control flow statement
	4 - operator
	5 - declaration
	6 - built-in class
	99 - Ahk2Exe compiler
	*/

	item_name := o[1]
	switch item_type {
		; Directives
		case 0:
			item_name := SubStr(item_name, 2) ; remove initial #
			if InStr(ji.%A_Index-1%.3, 'E')
				g_directivesExpr.Add item_name
			else
				g_directivesStr.Add item_name

		; Other keyword types
		case 1:   g_knownVars.Add    item_name
		case 2:   g_knownFuncs.Add   item_name
		case 6:   g_knownClasses.Add item_name
		case 4,5: g_reserved.Add     item_name
		case 3:   g_controlFlow.Add  ControlFlowCasing(item_name)
	}
}

try g_reserved.Delete "class"

; Make sure each keyword is only in the first keyword set it appears in
Set.FilterAll(g_directivesExpr, g_directivesStr)
Set.FilterAll(g_controlFlow, g_reserved, g_knownClasses, g_knownFuncs, g_knownVars)
Set.FilterAll(g_knownMethods, g_knownProps)

props := "# This file is autogenerated by " A_ScriptName " - DO NOT UPDATE MANUALLY`n`n"
props .= "ahk2.keywords.directives.expr=\`n"
props .= CreateKeywordList(g_directivesExpr) "`n"
props .= "ahk2.keywords.directives.str=\`n"
props .= CreateKeywordList(g_directivesStr) "`n"
props .= "ahk2.keywords.flow=\`n"
props .= CreateKeywordList(g_controlFlow) "`n"
props .= "ahk2.keywords.reserved=\`n"
props .= CreateKeywordList(g_reserved) "`n"
props .= "ahk2.keywords.known.vars=\`n"
props .= CreateKeywordList(g_knownVars) "`n"
props .= "ahk2.keywords.known.funcs=\`n"
props .= CreateKeywordList(g_knownFuncs) "`n"
props .= "ahk2.keywords.known.classes=\`n"
props .= CreateKeywordList(g_knownClasses) "`n"
props .= "ahk2.keywords.known.props=\`n"
props .= CreateKeywordList(g_knownProps) "`n"
props .= "ahk2.keywords.known.methods=\`n"
props .= CreateKeywordList(g_knownMethods)

FileRewrite "ahk2.keywords.properties", props

api := CreateApiList(["default", "class", "extends", "get", "set", "Parse", "Read", "Files", "Reg"])
api .= CreateApiList(g_directivesExpr, "#")
api .= CreateApiList(g_directivesStr, "#")
api .= CreateApiList(g_controlFlow)
api .= CreateApiList(g_reserved)
api .= CreateApiList(g_knownVars)
api .= CreateApiList(g_knownFuncs)
api .= CreateApiList(g_knownClasses)
api .= CreateApiList(g_knownProps, ".")
api .= CreateApiList(g_knownMethods, ".")

FileRewrite "ahk2.standard.api", api
