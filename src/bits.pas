(*
 * SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 1986-2026 https://github.com/robert-j
 *
 * Extracted from a SysUtils-like unit.
 *
 * GitHub: this is a stripped-down version for pktndis.
 * Memory routines were replaced by less optimal BASM versions of the
 * respective 386+ implementation.
 *)

unit Bits;

interface

type
  { Pointers of fundamental types }
  Long  = Longint;
  PLong = ^Long;
  PLongint = ^Longint;
  PInteger = ^Integer;
  PWord = ^Word;
  PByte = ^Byte;
  PBoolean = ^Boolean;
  PString = ^String;
  PPString = ^PString;
  PPointer = ^Pointer;

  { 32-bit cracker }
  LongRec = record
    Lo, Hi: Word;
  end;

  { 16-bit cracker }
  WordRec = record
    Lo, Hi: Byte;
  end;

  { Pointer cracker }
  PtrRec = record
    Ofs, Seg: Word;
  end;

  { Arrays of fundamental types, compatible with Borland's Objects unit
    and Delphi's SysUtils unit. }
  TByteArray = array[0..32767] of Byte;
  TCharArray = array[0..32767] of Char;
  TWordArray = array[0..16383] of Word;
  TLongArray = array[0..8191]  of Long;

  { Pointers to arrays of fundamental types }
  PByteArray = ^TByteArray;
  PCharArray = ^TCharArray;
  PWordArray = ^TWordArray;
  PLongArray = ^TLongArray;

  { Sets }
  PCharSet = ^TCharSet;
  TCharSet = set of Char;

  { Generic procedure }
  TProcedure = procedure;

  { Like stdint.h. Use these to define records that must have the same
    layout on all architectures. }
  Int8    = ShortInt;
  UInt8   = Byte;
  Int16   = Integer;
  UInt16  = Word;
  Int32   = Longint;
  UInt32  = Longint;
  IntPtr  = Longint;
  UIntPtr = Longint;

  PInt8    = ^Int8;
  PUInt8   = ^UInt8;
  PInt16   = ^Int16;
  PUInt16  = ^UInt16;
  PInt32   = ^Int32;
  PUInt32  = ^UInt32;
  PIntPtr  = ^IntPtr;
  PUIntPtr = ^UIntPtr;

const
  MaxInt8 = 127;
  MaxUInt8 = 255;
  MaxInt16 = MaxInt;
  MaxUInt16 = $ffff;
  MaxInt32 = MaxLongInt;
  MaxUInt32 = MaxLongInt;

(*
 * Normalizes a pointer such that its offset is zero and returns
 * only the segment part of the pointer. It basically aligns the pointer at
 * paragraph boundary.
 *
 * Makes no sense in Protected Mode.
 *)
function AlignPtr(P: Pointer): Word;
  inline(
    $58/            { pop  ax     -> ofs(p) }
    $5a/            { pop  dx     -> seg(p) }
    $50/            { push ax }
  {$ifopt G+}
    $c1/$e8/$04/    { shr  ax, 4  -> ofs = ofs >> 4 }
  {$else}           { 8086: }
    $b1/$04/        { mov  cl, 4 }
    $d3/$e8/        { shr  ax, cl }
  {$endif}
    $01/$c2/        { add  dx, ax -> seg = seg + ofs }
    $58/            { pop  ax }
    $25/$0f/$00/    { and  ax, $f -> ofs = ofs & 0xf }
    $74/$01/        { jz   +1 }
    $42/            { inc  dx }
    $89/$d0         { mov  ax, dx }
  );

(*
 * Clears CPU's interrupt flag.
 *)
procedure Cli; inline($FA);

(*
 * Sets CPU's interrupt flag.
 *)
procedure Sti; inline($FB);

(*
 * Disables interrupts and saves the interrupt mask.
 * Must be used pairwise with EndDisableInterrupts.
 *)
procedure BeginDisableInterrupts;
  inline(
    $9c/        { pushf }
    $fa         { cli }
  );

(*
 * Restores the interrupt mask saved by BeginDisableInterrupts.
 * Must be used pairwise with BeginDisableInterrupts.
 *)
procedure EndDisableInterrupts;
  inline(
    $9d         { popf }
  );

(*
 * Compares two memory blocks.
 *)
function CompareMem(const A; const B; Len: Word): Boolean;

(*
 * Fast (word-wise) memory copy w/out overlapping checks.
 *)
procedure CopyMem(const Source; var Dest; Len: Word);

(*
 * Fast (word-wise) memory fill.
 *)
procedure FillMem(var Dest; Len: Word; Value: Byte);

(*
 * Fast (word-wise) memory fill with zero.
 *)
procedure ZeroMem(var Dest; Len: Word);

(*
 * Microsoft C "far pascal loadds" calling convention prologue.
 *
 * When a Borland Pascal procedure/function must be exposed to programs
 * implemented in MS C, MscPrologue must be invoked on function's entry
 * and MscEpilogue on function's exit:
 *
 * procedure IAmExportedToMsc(Arg: Word); far;
 * begin
 *   MscPrologue(GetDSeg);
 *   ...
 *   MscEpilogue;
 * end;
 *)
procedure MscPrologue(DSeg: Word);
  inline(
    $58/          { pop  ax }
    $1E/          { push ds }
    $56/          { push si }
    $57/          { push di }
    $8E/$D8       { mov  ds, ax }
  );

(*
 * Microsoft C "far pascal loadds" calling convention epilogue.
 * Must be used pairwise with MscPrologue.
 *
 * See MscPrologue.
 *)
procedure MscEpilogue;
  inline(
    $5F/          { pop  di }
    $5E/          { pop  si }
    $1F/          { pop  ds }
    $FC           { cld     }
  );

(*
 * Gets the data segment of the application.
 *
 * Useful for MscPrologue because unlike assembler functions, inline functions
 * don't have a means for 'SEG @Data'.
 *)
function GetDSeg: Word;

(*
 * Serves no other purpose than referencing a symbol (variable, proc, etc.)
 * so it gets linked into the executable even if it's never referenced.
 *
 * Needed for unusual program structures like DOS device drivers and DPMS
 * apps, which don't use the normal Borland Pascal entry point.
 *)
procedure ReferenceSymbol(Addr: Pointer);
  inline(
    $58/      { pop ax }
    $5a       { pop dx }
  );

implementation

(*
 *
 *)
function CompareMem(const A; const B; Len: Word): Boolean; assembler;
asm
  push ds
  mov  ax, 1
  mov  cx, Len
  jcxz @done
  lds  si, A
  les  di, B
  cld
  rep  cmpsb
  je   @done
  xor  ax, ax
@done:
  pop  ds
end;

(*
 * Branchless
 *)
procedure CopyMem(const Source; var Dest; Len: Word); assembler;
asm
  push ds
  les  di, Dest
  lds  si, Source
  mov  cx, Len
  shr  cx,1
  cld
  rep  movsw
  adc  cx, cx
  rep  movsb
  pop  ds
end;

(*
 * Branchless
 *)
procedure FillMem(var Dest; Len: Word; Value: Byte); assembler;
asm
  les  di, Dest
  mov  cx, Len
  mov  al, Value
  mov  ah, al
  shr  cx, 1
  cld
  rep  stosw
  adc  cx, cx
  rep  stosb
end;

(*
 * Branchless
 *)
procedure ZeroMem(var Dest; Len: Word); assembler;
asm
  les  di, Dest
  mov  cx, Len
  xor  ax, ax
  shr  cx, 1
  cld
  rep  stosw
  adc  cx, cx
  rep  stosb
end;

(*
 *
 *)
function GetDSeg: Word; assembler;
asm
  mov  ax, seg @Data
end;

end.
