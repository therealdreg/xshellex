#define SHELLEX_VER "0.1b"

/*
xshellex - MIT License - Copyright 2020
David Reguera Garcia aka Dreg - dreg@fr33project.org
http://github.com/David-Reguera-Garcia-Dreg/ - http://www.fr33project.org/
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
IN THE SOFTWARE.
-
C-shellcode to hex
-
WARNING! this is a POC, the code is CRAP
*/

#include "xshellex.h"

// function prototypes


// Variables
#define szxshellexInfo "xshellex plugin v0.1b by Dreg 2020 - https://github.com/David-Reguera-Garcia-Dreg/ - http://www.fr33project.org\n\nFeatures & Usage:\n" 


// Plugin SDK required variables
#define plugin_name "xshellex" // rename to your plugins name 
#define plugin_version 1

// GLOBAL Plugin SDK variables
int pluginHandle;
HWND hwndDlg;
int hMenu;
int hMenuDisasm;
int hMenuDump;
int hMenuStack;


void
GetCurrentPath(WCHAR* current_path)
{
    wchar_t* tmp_ptr;

    ZeroMemory(current_path, sizeof(wchar_t) * MAX_PATH);

    GetModuleFileNameW(GetModuleHandleW(NULL), current_path, sizeof(wchar_t) * MAX_PATH);
    tmp_ptr = current_path;
    tmp_ptr += wcslen(current_path);
    while (tmp_ptr[0] != '\\')
    {
        tmp_ptr--;
        if (tmp_ptr <= current_path)
        {
            ZeroMemory(current_path, sizeof(wchar_t) * MAX_PATH);
            return;
        }
    }
    tmp_ptr[1] = 0;
}



void ExecShellex(wchar_t* clipb)
{
    static wchar_t current_path[0x1000] = { 0 };
    size_t size_str;

    if (current_path[0] == '\0')
    {
        GetCurrentPath(current_path);
        size_str = wcslen(current_path);
        if (size_str > 6)
        {
            current_path[size_str - 5] = L'\0';
            wcscat(current_path, L"\\shellex.exe");
        }
        else
        {
            current_path[0] = L'\0';
        }
    }

    if (current_path[0] == '\0')
    {
        MessageBoxA(NULL, "error getting current path", "error getting current path", MB_OK | MB_ICONWARNING);
        return;
    }

    //MessageBoxW(NULL, current_path, current_path, MB_OK | MB_ICONWARNING);

    ShellExecuteW(NULL, L"open", current_path, (clipb == NULL) ? L"-w" : clipb, NULL, SW_SHOWNORMAL);
}

/*====================================================================================
  Main entry function for a DLL file  - required.
--------------------------------------------------------------------------------------*/
extern "C" DLL_EXPORT BOOL APIENTRY DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved)
{
    return TRUE;
}

static bool cbCommand(int argc, char* argv[])
{
    ExecShellex(NULL);

    return true;
}


/*====================================================================================
  pluginit - Called by debugger when plugin.dp32 is loaded - needs to be EXPORTED
  
  Arguments: initStruct - a pointer to a PLUG_INITSTRUCT structure

  Notes:     you must fill in the pluginVersion, sdkVersion and pluginName members. 
             The pluginHandle is obtained from the same structure - it may be needed in
             other function calls.
 
             you can call your own setup routine from within this function to setup 
             menus and commands, and pass the initStruct parameter to this function.
 
--------------------------------------------------------------------------------------*/
DLL_EXPORT bool pluginit(PLUG_INITSTRUCT* initStruct)
{
    initStruct->pluginVersion = plugin_version;
    initStruct->sdkVersion = PLUG_SDKVERSION;
    strcpy(initStruct->pluginName, plugin_name);
    pluginHandle = initStruct->pluginHandle;

    if (!_plugin_registercommand(pluginHandle, plugin_name, cbCommand, false))
        _plugin_logputs("[" plugin_name "] Error registering the \"" plugin_name "\" command!");

	// place any additional initialization code here
    return true;
}


/*====================================================================================
  plugstop - Called by debugger when the plugin.dp32 is unloaded - needs to be EXPORTED
 
  Arguments: none
  
  Notes:     perform cleanup operations here, clearing menus and other housekeeping
 
--------------------------------------------------------------------------------------*/
DLL_EXPORT bool plugstop()
{
    _plugin_menuclear(hMenu);

	// place any cleanup code here
	
    return true;
}


/*====================================================================================
  plugsetup - Called by debugger to initialize your plugins setup - needs to be EXPORTED
 
  Arguments: setupStruct - a pointer to a PLUG_SETUPSTRUCT structure
  
  Notes:     setupStruct contains useful handles for use within x64_dbg, mainly Qt 
             menu handles (which are not supported with win32 api) and the main window
             handle with this information you can add your own menus and menu items 
             to an existing menu, or one of the predefined supported right click 
             context menus: hMenuDisam, hMenuDump & hMenuStack
             
             plugsetup is called after pluginit. 
--------------------------------------------------------------------------------------*/
DLL_EXPORT void plugsetup(PLUG_SETUPSTRUCT* setupStruct)
{
    hwndDlg = setupStruct->hwndDlg;
    hMenu = setupStruct->hMenu;
    hMenuDisasm = setupStruct->hMenuDisasm;
    hMenuDump = setupStruct->hMenuDump;
    hMenuStack = setupStruct->hMenuStack;
    
	GuiAddLogMessage, szxshellexInfo;
	// place any additional setup code here

    _plugin_menuaddentry(hMenu, 3, "&launch");
    _plugin_menuaddentry(hMenu, 4, "&clipboard to c-shellcode-string");
}

/*====================================================================================
  CBMENUENTRY - Called by debugger when a menu item is clicked - needs to be EXPORTED
 
  Arguments: cbType
             cbInfo - a pointer to a PLUG_CB_MENUENTRY structure. The hEntry contains 
             the resource id of menu item identifiers
   
  Notes:     hEntry can be used to determine if the user has clicked on your plugins
             menu item(s) and to do something in response to it.
             
--------------------------------------------------------------------------------------*/
extern "C" __declspec(dllexport) void CBMENUENTRY(CBTYPE cbType, PLUG_CB_MENUENTRY* info)
{
    static wchar_t clipb[0x1000];

    switch(info->hEntry)
    {
        case 3:
            ExecShellex(NULL);
        break;

        case 4:
            if (clipb[0] != L'\0')
            {
                memset(clipb, 0, sizeof(clipb));
            }

            if (OpenClipboard(NULL))
            {
                HANDLE hClipboardData = GetClipboardData(CF_UNICODETEXT);
                if (hClipboardData)
                {
                    WCHAR *pchData = (WCHAR*)GlobalLock(hClipboardData);
                    if (pchData)
                    {
                        wcscpy(clipb, L"-w -h ");
                        wcscat(clipb, pchData);
                        GlobalUnlock(hClipboardData);
                    }
                }
                CloseClipboard();

                if (clipb[0] != L'\0')
                {
                    ExecShellex(clipb);
                }
            }

        break;
    }
}


/*====================================================================================
  CBINITDEBUG - Called by debugger when a program is debugged - needs to be EXPORTED

  Arguments: cbType
             cbInfo - a pointer to a PLUG_CB_INITDEBUG structure. 
             The szFileName item contains name of file being debugged. 

--------------------------------------------------------------------------------------*/
extern "C" __declspec(dllexport) void CBINITDEBUG(CBTYPE cbType, PLUG_CB_INITDEBUG* info)
{

}



/*====================================================================================
  CBSYSTEMBREAKPOINT - Called by debugger at system breakpoint - needs to be EXPORTED
 
  Arguments: cbType
             cbInfo - reserved 

--------------------------------------------------------------------------------------*/
extern "C" __declspec(dllexport) void CBSYSTEMBREAKPOINT(CBTYPE cbType, PLUG_CB_SYSTEMBREAKPOINT* info)
{

}














