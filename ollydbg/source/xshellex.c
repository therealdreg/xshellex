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

#define _CRT_SECURE_NO_DEPRECATE

#include <Windows.h>
#include <stdio.h>
#include <string.h>
#include "Plugin.h"
#include "common.h"


HINSTANCE hinst;
HWND      hwmain;
char      safesehwinclass[32];
char      handlerwinclass[32];

typedef struct
{
	ulong  index;
	ulong  size;
	ulong  type;
	DWORD  address;
}t_handler;

BOOL WINAPI DllEntryPoint(HINSTANCE hi,DWORD reason,LPVOID reserved) {
	if (reason==DLL_PROCESS_ATTACH)
		hinst=hi;                         
	return 1;                            
};

void PluginError(void)
{
	MessageBoxA(hwmain,"Internal plugin error!","Error!",MB_ICONWARNING);
	ExitThread(0);
}

extc int _export cdecl ODBG_Plugindata(char shortname[32]) {
	strcpy(shortname,"xshellex");
	return PLUGIN_VERSION;
};

extc int _export cdecl ODBG_Plugininit(int OdbgVersion,HWND hw,ulong *features) 
{
	int retval = -1;

	if ( OdbgVersion >= PLUGIN_VERSION )
	{
		retval = 0;
	}	
	return retval;
}

extc int _export cdecl ODBG_Pluginmenu(int origin,char *data,void *item) 
{
	int retval = 0;

	if (origin==PM_MAIN)
	{
		strcpy(data,"0 &launch|1 &clipboard to c-shellcode-string");
		retval = 1;
	}
	
	return retval;
}

extc void _export cdecl ODBG_Pluginaction(int origin,int action,void *item) {
	if (origin == PM_MAIN)	
	{
		switch (action) 
		{
		    case 0:
                ExecShellex(NULL);
			break;

		    case 1:
                ExecShellexClipboard();
            break;

		};
	}
};

extc int _export cdecl ODBG_Pluginclose(void) 
{	
	return 0;
}; 