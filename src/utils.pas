(*
 * SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 1986-2026 https://github.com/robert-j
 *
 * Extracted from a SysUtils-like unit.
 *
 * GitHub: this is a stripped-down version for pktndis.
 * Contains only console and debugging I/O routines.
 *)

unit Utils;

interface

uses
  Bits;

procedure PrintCStr(S: PChar);
procedure PrintPStr(const S: String);
procedure PrintHexByte(Value: Byte);
procedure PrintHexWord(Value: Word);
procedure PrintHexLong(Value: Longint);
procedure PrintHexPtr(Value: Pointer);

{ Debug output using a Bochs-compatible protocol. }

const
  BochsDebugPort = $e9;

procedure EmitDebugChar(Value: Char);
procedure EmitDebugWord(Value: Word);
procedure EmitDebugLong(Value: Longint);
procedure EmitDebugPtr(Value: Pointer);
procedure EmitDebugCStr(Msg: PChar);
procedure EmitDebugPStr(const Msg: String);

implementation

uses
  Strings;

const
  Dig16: array[0..15] of Char = '0123456789abcdef';

(*
 *
 *)
procedure PrintCStr(S: PChar); assembler;
asm
  push  ds
  les   di, S
  xor   al, al
  mov   cx, $ffff
  cld
  repnz scasb
  dec   di
  lds   dx, S
  sub   di, dx
  mov   cx, di
  mov   bx, 2
  mov   ah, 40h
  int   21h
  pop   ds
end;

(*
 *
 *)
procedure PrintPStr(const S: String); assembler;
asm
  push  ds
  lds   si, s
  cld
  lodsb
  xor   ah, ah
  xchg  ax, cx
  mov   ah, 40h
  mov   dx, si
  mov   bx, 2
  int   21h
  pop   ds
end;

(*
 *
 *)
procedure PrintHexByte(Value: Byte);
var
  S: array[0..2] of Char;
begin
  S[0] := Dig16[Value shr $04];
  S[1] := Dig16[Value and $0F];
  S[2] := #0;
  PrintCStr(S);
end;

(*
 *
 *)
procedure PrintHexWord(Value: Word);
begin
  PrintHexByte(WordRec(Value).Hi);
  PrintHexByte(WordRec(Value).Lo);
end;

(*
 *
 *)
procedure PrintHexLong(Value: Longint);
begin
  PrintHexWord(LongRec(Value).Hi);
  PrintHexWord(LongRec(Value).Lo);
end;

(*
 *
 *)
procedure PrintHexPtr(Value: Pointer);
begin
  PrintHexWord(LongRec(Value).Hi);
  PrintCStr(':');
  PrintHexWord(LongRec(Value).Lo);
end;

(*
 *
 *)
procedure EmitDebugChar(Value: Char);
begin
  Port[BochsDebugPort] := Byte(Value);
end;

(*
 *
 *)
procedure EmitDebugWord(Value: Word);
begin
  Port[BochsDebugPort] := Byte(Dig16[Hi(Value) shr $04]);
  Port[BochsDebugPort] := Byte(Dig16[Hi(Value) and $0F]);
  Port[BochsDebugPort] := Byte(Dig16[Lo(Value) shr $04]);
  Port[BochsDebugPort] := Byte(Dig16[Lo(Value) and $0F]);
end;

(*
 *
 *)
procedure EmitDebugLong(Value: Longint);
begin
  EmitDebugWord(LongRec(Value).Hi);
  EmitDebugWord(LongRec(Value).Lo);
end;

(*
 *
 *)
procedure EmitDebugPtr(Value: Pointer);
begin
  EmitDebugWord(LongRec(Value).Hi);
  Port[BochsDebugPort] := Byte(':');
  EmitDebugWord(LongRec(Value).Lo);
end;

(*
 *
 *)
procedure EmitDebugCStr(Msg: PChar);
var
  I: Word;
  Len: Word;
begin
  Len := StrLen(Msg);
  if Len = 0 then exit;
  for I := 0 to Len - 1 do Port[BochsDebugPort] := Byte(Msg[I]);
end;

(*
 *
 *)
procedure EmitDebugPStr(const Msg: String);
var
  Len: Byte absolute Msg;
  I: Integer;
begin
  for I := 1 to Len do Port[BochsDebugPort] := Byte(Msg[I]);
end;

end.
