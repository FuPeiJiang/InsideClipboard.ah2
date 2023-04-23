#SingleInstance force
ListLines 0
KeyHistory 0
SendMode "Input" ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir A_ScriptDir ; Ensures a consistent starting directory.

sortArrByKey(arr, key, ASC := true) {
    str := ""
    for k, v in arr {
      str .= v.%key% "+" k "|"
    }
    length := arr.Length
    str := Sort(str, "D|N" (ASC ? "" : "R"))
    finalAr := []
    finalAr.Capacity := length
    barPos := 1
    loop length {
      plusPos := InStr(str, "+", false, barPos)
      barPos := InStr(str, "|", false, plusPos)
      num := SubStr(str, plusPos + 1, barPos - plusPos - 1)
      finalAr.Push(arr[num])
    }
    return finalAr
}

refreshListView_using_globalArr() {
    global globalArr, LV
    for obj in globalArr {
        LV.Add(,obj.Format_ID,obj.Format_Name,obj.Size,obj.Index)
    }
    LV.ModifyCol(1,"Integer Left")
    LV.ModifyCol(2,"AutoHdr")
    LV.ModifyCol(3,"AutoHdr Integer Left")
    LV.ModifyCol(4,"Integer Left")
}

globalArr_from_Clipboard() {
    global globalArr, LV, MyGui

    clip_format:=0
    finalStr:=""
    globalArr:=[]
    standard_clipboard_formats:=Map(2,"CF_BITMAP",8,"CF_DIB",17,"CF_DIBV5",5,"CF_DIF",0x0082,"CF_DSPBITMAP",0x008E,"CF_DSPENHMETAFILE",0x0083,"CF_DSPMETAFILEPICT",0x0081,"CF_DSPTEXT",14,"CF_ENHMETAFILE",0x0300,"CF_GDIOBJFIRST",0x03FF,"CF_GDIOBJLAST",15,"CF_HDROP",16,"CF_LOCALE",3,"CF_METAFILEPICT",7,"CF_OEMTEXT",0x0080,"CF_OWNERDISPLAY",9,"CF_PALETTE",10,"CF_PENDATA",0x0200,"CF_PRIVATEFIRST",0x02FF,"CF_PRIVATELAST",11,"CF_RIFF",4,"CF_SYLK",1,"CF_TEXT",6,"CF_TIFF",13,"CF_UNICODETEXT",12,"CF_WAVE")

    DllCall("OpenClipboard", "Ptr",DllCall("GetClipboardOwner","Ptr"))
    Index:=1
    while (clip_format:=DllCall("EnumClipboardFormats", "Uint", clip_format, "Uint")) {
        buf:=Buffer(202,0)

        if (standard_clipboard_formats.Has(clip_format)) {
            Format_Name:=standard_clipboard_formats[clip_format]
        } else {
            DllCall("GetClipboardFormatNameW","Uint",clip_format,"Ptr",buf,"Int",100)
            Format_Name:=StrGet(buf,"UTF-16")
        }

        dataPtr:=DllCall("GetClipboardData","Uint",clip_format,"Ptr")
        if (A_LastError) {
            continue
        }
        if (dataPtr==0) {
            Size:=0
            HGLOBAL:=0
        } else {

            Size:=DllCall("GlobalSize","Ptr",dataPtr,"Ptr")

            HGLOBAL:=DllCall("GlobalAlloc","Uint",0x0002,"Ptr",Size)
            Data:=DllCall("GlobalLock","Ptr",HGLOBAL)
            src:=DllCall("GlobalLock","Ptr",dataPtr)
            DllCall("ntdll\memcpy","Ptr",Data,"Ptr",src,"Ptr",Size)
            DllCall("GlobalUnlock","Ptr",dataPtr) ;always fails(return value of 1)
            DllCall("GlobalUnlock","Ptr",HGLOBAL)
        }

        globalArr.Push({Format_ID:clip_format,Format_Name:Format_Name,Size:Size,Index:Index,HGLOBAL:HGLOBAL})
        ++Index
    }
    DllCall("CloseClipboard")

    globalArr:=sortArrByKey(globalArr,"Format_ID")

    refreshListView_using_globalArr()

}

MyGui := Gui()
MyGui.SetFont("Q0 s9 w400","Segoe UI")


reloadButton := MyGui.Add("Button",, "Reload")
reloadClicked(GuiCtrlObj, Info) {
    LV.Delete()
    globalArr_from_Clipboard()
}
reloadButton.OnEvent("Click",reloadClicked)

deleteButton := MyGui.Add("Button","x+0", "Delete")
deleteClicked(GuiCtrlObj, Info) {
    global globalArr, LV, MyGui
    arr:=[]
    i:=0
    while (i:=LV.GetNext(i)) {
        arr.Push(i)
    }

    j:=arr.Length
    while (j) {
        globalArr.RemoveAt(arr[j])
        --j
    }


    DllCall("OpenClipboard", "Ptr",DllCall("GetClipboardOwner","Ptr"))
    DllCall("EmptyClipboard")
    for obj in globalArr {

        OLD_HGLOBAL:=obj.HGLOBAL
        if (OLD_HGLOBAL!==0) {
            ;attempts to prevent ahk Error:  GlobalLock
            HGLOBAL:=DllCall("GlobalAlloc","Uint",0x0002,"Ptr",obj.Size)
            Data:=DllCall("GlobalLock","Ptr",HGLOBAL)
            src:=DllCall("GlobalLock","Ptr",OLD_HGLOBAL)
            DllCall("ntdll\memcpy","Ptr",Data,"Ptr",src,"Ptr",obj.Size)
            DllCall("GlobalUnlock","Ptr",OLD_HGLOBAL)
            DllCall("GlobalUnlock","Ptr",HGLOBAL)
            obj.HGLOBAL:=HGLOBAL
        }

        DllCall("SetClipboardData","Uint",obj.Format_ID,"Ptr",OLD_HGLOBAL)
    }
    DllCall("CloseClipboard")


    LV.Delete()
    refreshListView_using_globalArr()
    if (arr.Length) {
        ; LV.Modify(0, "-Select") ; De-select all.
        rowToSelect:=arr[arr.Length]
        if (rowToSelect > globalArr.Length) {
            rowToSelect := globalArr.Length
        }
        LV.Modify(rowToSelect, "+Focus +Select")
    }
}
deleteButton.OnEvent("Click",deleteClicked)

reloadButton.GetPos(,&reloadButtonY:=0,,&reloadButtonHeight:=0)

LV := MyGui.Add("ListView", "r20 w500 x11 y" reloadButtonY + reloadButtonHeight + 7, ["Format ID","Format Name","Size","Index"])
LV.GetPos(&LVX,&LVY:=0)

globalArr_from_Clipboard()
myGui_Closed(thisGui) {
    ExitApp
}
MyGui.OnEvent("Close",myGui_Closed)
MyGui.Show()

return

#HotIf WinActive(MyGui.Hwnd)
Delete::{
    deleteClicked(0,0)
}
^c::{
    global globalArr, LV, MyGui
    i:=0
    i:=LV.GetNext(i)
    if (!i) {
        return
    }

    if (globalArr[i].Format_ID == 15) {
        HGLOBAL:=globalArr[i].HGLOBAL
        Size:=DllCall("GlobalSize","Ptr",HGLOBAL,"Ptr")
        Data:=DllCall("GlobalLock","Ptr",HGLOBAL)
        Data+=20
        finalStr:=""
        while(path:=StrGet(Data,"UTF-16")) {
            if (A_Index > 1) {
                finalStr.="`n"
            }
            finalStr.=path
            Data+=StrPut(path,"UTF-16")
        }
        ; DllCall("GlobalUnlock","Ptr",HGLOBAL)
        MsgBox finalStr
    }
}
#HotIf



f3::Exitapp