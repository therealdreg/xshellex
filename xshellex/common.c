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

#include "common.h"

void
ExecShellexClipboard(void)
{
    static wchar_t clipb[0x1000];
    size_t i;

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
            for (i = 0; clipb[i] != L'\0'; i++)
            {
                if (clipb[i] == L'\n')
                {
                    clipb[i] = L' ';
                }
            }
            ExecShellex(clipb);
        }
    }
}

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
        size_str = 0;
#ifdef XSHELLEX_X64
        size_str = wcslen(current_path);
        if (size_str > 6)
        {
            current_path[size_str - 5] = L'\0';
        }
        else
        {
            current_path[0] = L'\0';
        }
#endif
        if (current_path[0] != '\0')
        {
            wcscat(current_path, L"\\shellex.exe");
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