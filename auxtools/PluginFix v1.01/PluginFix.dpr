//======================================================================================================================
//
//  PluginFix v1.01
//  By BoB / Team PEiD
//
//======================================================================================================================
//
//  This simple tool converts OllyDbg and ImmuntiyDebugger plugins to be used with the new ImmDbg v1.80
//  It needs to change the Imports and Exports of a plugin to do this, so it will NOT work on packed plugins!
//
//=============================================================================================================[ v1.01 ]
//
//  Changes:
//    o  Fixed problem that if any section raw pointer was 0 then no dos/pe header written
//    o  Added support for OllyDbg Plugins
//
//======================================================================================================================


Program PluginFix;

{$APPTYPE CONSOLE}

Uses
  Windows;


//======================================================================================================================
// Conversion list of ordinals in order of old ImmDbg, containing ordinal in new v1.80 ..  $FF = Ignore ..

Const
  ExportCount = $FD;
  ExportTable : Array [1 .. ExportCount-1] Of Byte = (
    $03, $04, $05, $09, $0B, $0C, $0D, $0E, $10, $11, $12, $16, $1A, $1C, $1D, $1E,
    $1F, $20, $21, $22, $24, $25, $26, $28, $29, $2A, $2C, $2D, $2F, $30, $31, $32,
    $33, $34, $36, $38, $39, $3C, $3D, $3E, $40, $41, $42, $43, $44, $45, $46, $4D,
    $4E, $4F, $50, $51, $53, $55, $57, $59, $5A, $5C, $5D, $5F, $60, $61, $62, $65,
    $67, $68, $6A, $6C, $6E, $73, $76, $77, $78, $7A, $7D, $7F, $81, $82, $84, $89,
    $8B, $8C, $90, $91, $92, $94, $96, $98, $99, $9A, $9B, $9C, $9D, $A0, $A1, $A2,
    $A3, $A5, $CC, $CD, $CF, $D0, $D1, $D2, $D9, $DC, $DE, $E1, $E2, $E7, $E9, $EC,
    $ED, $EF, $F1, $F3, $F5, $3F, $48, $4A, $74, $75, $93, $D6, $D8, $14, $1B, $23,
    $2B, $2E, $3B, $47, $49, $4B, $4C, $52, $54, $58, $5B, $63, $64, $66, $69, $6B,
    $6D, $6F, $70, $79, $7B, $7C, $83, $85, $87, $8A, $95, $A4, $CE, $D4, $D5, $DF,
    $EA, $EB, $F4, $06, $15, $17, $18, $19, $27, $35, $80, $DA, $E0, $E4, $3A, $56,
    $72, $88, $EE, $0A, $13, $E5, $E6, $5E, $DD, $8E, $E8, $08, $9E, $CA, $07, $C6,
    $C4, $C2, $D7, $B9, $BA, $BC, $FF, $F0, $C7, $BF, $B7, $7E, $FF, $B6, $B4, $C0,
    $C5, $B8, $A6, $AB, $B3, $F2, $FF, $D3, $8D, $BE, $B5, $71, $C3, $01, $A9, $FF,
    $C9, $AD, $B1, $A8, $F7, $AA, $AF, $BD, $C1, $F8, $8F, $37, $AE, $FF, $9F, $E3,
    $CB, $BB, $86, $0F, $B0, $AC, $DB, $FF, $97, $FF, $00, $B2
  );


//======================================================================================================================

Type
  TMemRec = Packed Record
    Address : Pointer;
    Size    : DWord;
  End;

  PImageSectionHeader = ^TImageSectionHeader;
  TImageSectionHeader = Packed Record
    Name                 : Array [1 .. 8] Of Char;
    VirtualSize          : DWord;
    VirtualRva           : DWord;
    RawSize              : DWord;
    RawOffset            : DWord;
    Unused               : Array [1 .. 3] Of DWord;  // Depreciated / Coff only ..
    Characteristics      : DWord;
  End;

  PImageImportDescriptor = ^TImageImportDescriptor;
  TImageImportDescriptor = Packed Record
    OriginalFirstThunk, TimeDateStamp,
    ForwarderChain, Name,
    FirstThunk: DWord;
  End;

  PImageExportDirectory = ^TImageExportDirectory;
  TImageExportDirectory = Packed Record
    Characteristics, TimeDateStamp: DWord;
    MajorVersion, MinorVersion: Word;
    RvaOfName, OrdinalBase, NumberOfFunctions,
    NumberOfNames, RvaOfFunctions,
    RvaOfNames, RvaOfNameOrdinals: DWord;
  End;


//======================================================================================================================
// Useful functions ..

Function  Ptr(Const P : Pointer; Const Offset : Integer) : Pointer;
Begin
  Result := Pointer(Int64(P) + Offset);
End;

Function  ALIGN_DOWN(Const a, b : DWord) :  DWord;
Begin
  Result := a;
  If (a <> 0) And (b <> 0) Then Result := ((a Div b) * b);
End;

Function  ALIGN_UP(Const a, b : DWord) :  DWord;
Begin
  Result := ALIGN_DOWN(a + (b - 1), b);
End;

Function  IntToStr(Const Value : DWord) : String;
Begin
  Str(Value, Result);
End;

Function  StrLen(Const PC : PChar) : DWord;
Begin
  Result := 0;
  While (PC[Result] <> #0) Do Inc(Result);
End;

Function  Pad(Const Text : String; Const Len : Integer) : String;
Begin
  Result := Text;
  While (Length(Result) < Len) Do Result := Result + ' ';
End;

Function  UpperCase(Const S: String): String;
Var
  I, L : DWord;
Begin
  L := Length(S);
  SetLength(Result, L);
  If (L > 0) Then For I := 1 To L Do Result[I] := UpCase(S[I]);
End;

Function  AllocMem(Const Size : DWord) : Pointer;
Begin
  GetMem(Result, Size);
  ZeroMemory(Result, Size);
End;




//======================================================================================================================
// Load and map a PE file as an image ..

Function  LoadFileAsImage(Const Filename : String) : PImageDosHeader;
Var
  hFile, I, Size, Attr : DWord;
  Raw : Pointer;

  // Map a raw module to image ..  MUST be Valid PE, cos only basic testing done!
  Function  MapRawPE(Const RawMem : Pointer; Const Size : DWord) : TMemRec;
  Var
    Dos : PImageDosHeader Absolute RawMem;
    NT  : PImageNtHeaders;
    Sec : PImageSectionHeader;
    Mem : Pointer;
    Idx : DWord;
    Val : DWord;
  Begin
    Result.Address := Nil;
    Result.Size := 0;
    If IsBadReadPtr(RawMem, Size) Or (Dos^.e_magic <> IMAGE_DOS_SIGNATURE) Then Exit;
    NT := Ptr(RawMem, Dos^._lfanew);
    If (NT^.Signature <> IMAGE_NT_SIGNATURE) Then Exit;
    // Allocate 1 page more so it's possible to enlarge the image without reallocating ..
    Val := Align_Up(NT^.OptionalHeader.SizeOfImage + $1000, NT^.OptionalHeader.SectionAlignment);
    Mem := VirtualAlloc(Nil, Val, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
    Result.Address := Mem;
    If (Mem = Nil) Then Exit;
    // Copy section data ..
    Sec := Ptr(NT, 4 + SizeOf(TImageFileHeader) + NT^.FileHeader.SizeOfOptionalHeader);
    Val := Size;
    Idx := 0;
    While (Idx < NT^.FileHeader.NumberOfSections) Do Begin
      If (Sec^.RawOffset > 0) Then Begin
        CopyMemory(Ptr(Mem, Sec^.VirtualRva), Ptr(RawMem, Sec^.RawOffset), Sec^.RawSize);
        If (Sec^.RawOffset < Val) Then Val := Sec^.RawOffset;  // Val = Lowest Raw offset ..
      End;
      Inc(Sec);
      Inc(Idx);
    End;
    // Copy all headers ..
    CopyMemory(Mem, RawMem, Val);
  End;

Begin
  Result := Nil;
  Raw := Nil;
  // Get/Set Attr so we can read hidden / read only files ..
  Attr := GetFileAttributes(PChar(Filename));
  If (Attr <> $FFFFFFFF) Then Try
    SetFileAttributes(PChar(Filename), FILE_ATTRIBUTE_NORMAL);
    hFile := CreateFile(PChar(Filename), GENERIC_READ, FILE_SHARE_READ, Nil, Open_Existing, FILE_ATTRIBUTE_NORMAL, 0);
    If (hFile <> INVALID_HANDLE_VALUE) Then Try
      Size := GetFileSize(hFile, Nil);
      Raw := AllocMem(Size);
      ReadFile(hFile, Raw^, Size, I, Nil);
      Result := MapRawPE(Raw, I).Address;
    Finally
      CloseHandle(hFile);
      FreeMem(Raw);
    End;
  Finally
    SetFileAttributes(PChar(Filename), Attr);
  End;
End;


//======================================================================================================================
// Save a mapped module to raw image file ..

Procedure SaveModuleToRawFile(Const Module : PImageDosHeader; Const Filename : String);
Var
  Mem : TMemRec;

  // Save a mapped module to raw image memory block ..
  Function  BuildRawPEFromModule : TMemRec;
  Var
    NT  : PImageNtHeaders;
    Sec : PImageSectionHeader;
    I,J : DWord;
  Begin
    Result.Address := Nil;
    Result.Size := 0;
    If IsBadReadPtr(Module, SizeOf(TImageDosHeader)) Or (Module^.e_magic <> IMAGE_DOS_SIGNATURE) Then Exit;
    NT := Ptr(Module, Module^._lfanew);
    If (NT^.Signature <> IMAGE_NT_SIGNATURE) Then Exit;

    // Calc raw size ..
    Sec := Ptr(NT, 4 + SizeOf(TImageFileHeader) + NT^.FileHeader.SizeOfOptionalHeader);
    Result.Size := Sec^.RawOffset;
    J := NT^.OptionalHeader.SizeOfImage;
    I := 0;
    While (I < NT^.FileHeader.NumberOfSections) Do Begin
      If (Sec^.RawOffset < J) And (Sec^.RawOffset > 0) Then J := Sec^.RawOffset;  // J = Lowest Raw offset ..
      Inc(Result.Size, Align_up(Sec^.RawSize, NT^.OptionalHeader.FileAlignment));
      Inc(Sec);
      Inc(I);
    End;

    // Alloc mem and build Raw image ..
    Result.Address := AllocMem(Result.Size);
    CopyMemory(Result.Address, Module, J);
    Sec := Ptr(NT, 4 + SizeOf(TImageFileHeader) + NT^.FileHeader.SizeOfOptionalHeader);
    I := 0;
    While (I < NT^.FileHeader.NumberOfSections) Do Begin
      CopyMemory(Ptr(Result.Address, Sec^.RawOffset), Ptr(Module, Sec^.VirtualRva), Sec^.RawSize);
      Inc(Sec);
      Inc(I);
    End;
  End;

  // Save memory block to file ..
  Procedure SaveMemToFile(Const Mem : TMemRec; Const Filename : String);
  Var
    hFile, I : DWord;
  Begin
    If (Mem.Address = Nil) Or (Mem.Size = 0) Then Exit;
    If SetFileAttributes(PChar(Filename), FILE_ATTRIBUTE_NORMAL) Then DeleteFile(PChar(Filename));
    hFile := CreateFile(PChar(Filename), GENERIC_READ Or GENERIC_WRITE, FILE_SHARE_READ, Nil, Create_Always, FILE_ATTRIBUTE_NORMAL, 0);
    If (hFile = INVALID_HANDLE_VALUE) Then Exit;
    Try
      WriteFile(hFile, Mem.Address^, Mem.Size, I, Nil);
      FlushFileBuffers(hFile);
    Finally
      CloseHandle(hFile);
    End;
  End;

Begin
  Mem := BuildRawPEFromModule;
  SaveMemToFile(Mem, Filename);
  FreeMem(Mem.Address);
End;


//======================================================================================================================
// Fix the imports and exports of a plugin ..

Procedure FixPlugin(Const Filename : String);
Const
  ImmDbg = 'ImmunityDebugger.Exe';
Var
  Dos : PImageDosHeader;
  NT  : PImageNtHeaders;
  Sec : PImageSectionHeader;
  Ex  : PImageExportDirectory;
  Imp : PImageImportDescriptor;
  PC  : PAnsiChar;
  PD  : PDWord;
  I   : DWord;
  Name: String;
  Size: DWord;
  Rva : DWord;

  // Fix an import thunk for ImmunityDebugger.exe ..
  Function  FixThunk(Const Thunk : DWord) : Boolean;
  Var
    J : DWord;
  Begin
    Result := False;
    If (Thunk > 0) Then Begin
      PD := Ptr(Dos, Thunk);
      If IsBadReadPtr(PD, 4) Or (PD^ = 0) Then Exit;
      While (PD^ <> 0) Do Begin
        If (PD^ And $80000000 <> 0) Then Begin
          // Change old ordinal to new ordinal value ..
          J := PD^ And $0FFF;
          If (Not Result) Then WriteLn('  Fixing Import Thunk');
          WriteLn('    #' + Pad(IntToStr(J), 3) + ' -> #' + IntToStr(ExportTable[J]));
          PD^ := (ExportTable[J] Or $80000000);
          Result := True;
        End Else Begin
          // Fix imported name string by skipping underscore in name ..
          PC := Ptr(Dos, PD^ + 2);
          If (Not IsBadReadPtr(PC, 4)) And (PC^ = '_') Then Begin
            PWord(Ptr(Dos, PD^))^ := 0;
            If (Not Result) Then WriteLn('  Fixing Import Thunk');
            Write('    ' + Pad(PC, 22) + ' -> ');
            PC^ := #0;
            Inc(PD^);
            Result := True;
            Inc(PC);
            WriteLn(PC);
          End;
        End;
        Inc(PD);
      End;
      WriteLn;
    End;
  End;

Begin
  // Load and map plugin dll as image ..
  Dos := LoadFileAsImage(Filename);
  If (Dos <> Nil) Then Try
    WriteLn('Processing ' + Filename);

    // Find export names ..
    NT := Ptr(Dos, Dos^._lfanew);
    Ex := Ptr(Dos, NT^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress);
    PD := Ptr(Dos, Ex.RvaOfNames);

    // Find size of empty space needed to write new export strings ..
    I := 0;
    Rva := 0;
    Size := 0;
    While (I < Ex^.NumberOfNames) Do Begin
      PC := Ptr(Dos, PD^);
      If IsBadReadPtr(PC, 4) Then Begin
        WriteLn('    Error reading export string!');
        Exit;
      End;
      If ((PC^ = '_') And (PC[5] = '_')) Then Inc(Size, 3 + StrLen(PC));
      Inc(I);
      Inc(PD);
    End;
    // Fixup image for adding OllyDbg strings..
    If (Size > 0) Then Begin
      Sec := Ptr(NT, 4 + SizeOf(TImageFileHeader) + NT^.FileHeader.SizeOfOptionalHeader + ((NT^.FileHeader.NumberOfSections - 1) * SizeOf(TImageSectionHeader)));
      Rva := Align_Up(Sec^.VirtualRva + Sec^.RawSize, NT^.OptionalHeader.FileAlignment);
      While (PDWord(DWord(Dos) + Rva)^ = 0) Do Dec(Rva, 4);
      Rva := Align_Up(Rva + 12, 16);
      Sec^.RawSize := Align_Up((Rva - Sec^.VirtualRva) + Size + StrLen(ImmDbg) + 1, NT^.OptionalHeader.FileAlignment);
      Sec^.VirtualSize := Align_Up(Sec^.RawSize, NT^.OptionalHeader.SectionAlignment);
      NT^.OptionalHeader.SizeOfImage := Sec^.VirtualRva + Sec^.VirtualSize;
    End;

    // Fix exports ..
    WriteLn('  Fixing Exports');
    PD := Ptr(Dos, Ex.RvaOfNames);
    I := 0;
    While (I < Ex^.NumberOfNames) Do Begin
      PC := Ptr(Dos, PD^);
      If ((PC^ = '_') And (PC[1] <> '_')) Then Begin
        Write('    ' + Pad(PC, 22) + ' -> ');
        // Check for Olly export ..
        If (PC[5] = '_') Then Begin
          // Add new export string ..
          PD^ := Rva;
          Inc(PC, 5);
          Move('IMMDBG', Ptr(Dos, Rva)^, 6);
          Move(PC^, Ptr(Dos, Rva + 6)^, StrLen(PC));
          Inc(Rva, 7 + StrLen(PC));
        End Else
          Inc(PD^);  // Fix for old ImmDbg is simpler .. :)
        PC := Ptr(Dos, PD^);
        WriteLn(PC);
      End;
      Inc(I);
      Inc(PD);
    End;
    WriteLn;

    // Fix imports ..
    Imp := Ptr(Dos, NT^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress);
    While (Imp^.Name <> 0) Do Begin
      PC := Ptr(Dos, Imp^.Name);
      If IsBadReadPtr(PC, Length(ImmDbg)) Then Begin
        WriteLn('Error: Cannot read imported Dll string!');
        Exit;
      End;
      // Importing from an EXE ?
      If (Uppercase(Copy(PC, StrLen(PC) - 3, 4)) = '.EXE') Then Begin
        If (Uppercase(Copy(PC, 1, 8)) <> 'IMMUNITY') Then Begin
          // If OllyDbg then imported module name needs to be fixed to ImmunityDebugger.EXE ..
          Move(ImmDbg, Ptr(Dos, Rva)^, Length(ImmDbg));
          Imp^.Name := Rva;
        End;
        // Convert the import thunks ..
        If (Not FixThunk(Imp^.OriginalFirstThunk)) And (Not FixThunk(Imp^.FirstThunk)) Then WriteLn('Warning: No Imports were processed!');
      End;
      Inc(Imp);
    End;
    WriteLn;

    // Build new plugin raw file ..
    I := Length(FileName);
    While (FileName[I] <> '.') Do Dec(I);
    Name := Copy(Filename, 1, I-1) + '_Fixed.DLL';
    SaveModuleToRawFile(Dos, Name);
    WriteLn('Saved as ' + Name);

  Finally
    VirtualFree(Dos, 0, MEM_RELEASE);
    WriteLn;
    WriteLn;
  End;
End;


//======================================================================================================================

Procedure Main;
Var
  I : DWord;
Begin
  If (ParamCount = 0) Then WriteLn('Usage: Drop one or more plugin DLLs onto this exe to fix them')
  Else For I := 1 To ParamCount Do FixPlugin(ParamStr(I));
End;


//======================================================================================================================

Begin
  WriteLn('PluginFix v1.01');
  WriteLn('Simple Tool to convert OllyDbg and ImmDbg plugins for use with ImmDbg v1.80');
  WriteLn('By BoB -> Team PEiD');
  WriteLn;

  Main;

  Write('Press ENTER');
  ReadLn;
End.
