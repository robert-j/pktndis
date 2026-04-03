(*
 * SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 1993-2026 https://github.com/robert-j
 *
 * Low level DOS APIs with PChar file name arguments.
 *
 * GitHub: this is a stripped-down version for pktndis.
 *)

unit DosLib;

interface

const
  DOS_READ_ACCESS = $00;
  DOS_WRITE_ACCESS = $01;
  DOS_READ_WRITE_ACCESS  = $02;

function DosOpen(FileName: PChar; mode: Byte): Word;
function DosClose(handle: Word): Boolean;
function DosIoctlRead(Handle: Word; var Buffer; Size: Word): Word;

var
  { Keeps the last DOS error }
  DosLastError: Word;

implementation

uses
  {$ifndef MSDOS} WinApi, {$endif} Bits;

(*
 * https://fd.lod.bz/rbil/interrup/dos_kernel/213d.html#2818
 *
 *)
function DosOpen(FileName: PChar; mode: Byte): Word; assembler;
asm
  mov  ah, $3d
  mov  al, mode
  push ds
  lds  dx, FileName
{$ifdef MSDOS}
  int  $21
{$else}
  call Dos3Call
{$endif}
  pop  ds
  jnc  @1
  mov  DosLastError, ax
  xor  ax, ax
  jmp  @2
@1:
  mov  DosLastError, 0
@2:
end;

(*
 * https://fd.lod.bz/rbil/interrup/dos_kernel/213e.html
 *
 * No tests, in use.
 *)
function DosClose(handle: Word): Boolean; assembler;
asm
  mov ah, $3e
  mov bx, handle
{$ifdef MSDOS}
  int  $21
{$else}
  call Dos3Call
{$endif}
  jnc  @1
  mov  DosLastError, ax
  xor  ax, ax
  jmp  @2
@1:
  mov  DosLastError, 0
  mov  al, 1
@2:
end;

(*
 * https://fd.lod.bz/rbil/interrup/dos_kernel/214402.html
 *)
function DosIoctlRead(Handle: Word; var Buffer; Size: Word): Word; assembler;
asm
  push ds
  mov  ax, $4402
  mov  bx, Handle
  lds  dx, Buffer
  mov  cx, Size
{$ifdef MSDOS}
  int  $21
{$else}
  call Dos3Call
{$endif}
  pop  ds
  jnc  @1
  mov  DosLastError, ax
  xor  ax, ax
  jmp @2
@1:
  mov  DosLastError, 0
@2:
end;

end.
