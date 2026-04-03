(*
 * SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 2020-2026 https://github.com/robert-j
 *
 * NDIS Driver for a Packet Driver Media Access Controller (MAC or NIC).
 *
 * This program is actually a DOS character device driver using XRTL[1]
 * as a run-time library. As such, it has a quite unique structure and
 * limitations:
 *
 * - The first proc must be DeviceHeader, which isn't even code.
 * - The last proc must be BeforeMain.
 * - The code (only of this file) must be compiled with G-.
 * - The RTL isn't available until InitRuntime is invoked.
 * - Everything dependend on a valid PSP won't work (GetEnv, ParamStr, etc.).
 * - No RTL stack but we provide our own.
 * - Custom heap (see TinyHeap).
 * - No floating point support, neither x87, nor emulation. enforced by XRTL.
 *
 * [1] The Github version of PKTNDIS does not use XRTL because it's based
 * on Borland RTL source code that cannot be released under an OSS license.
 * InitRuntime and the general structure of this file is much more concise
 * and regular when compiled against XRLT.
 *)

program PktNdis;

{ Mininum allowed stack size, no heap.
  The actual stack size is defined by StackSize.
  The actual heap size is defined by HeapSize. }
{$M $400, 0, 0}

{ No 286 code in this code segment. See InitRuntime. FAR calls. }
{$G-,F+}

uses
  Dos, Bits, Driver, TinyHeap;

const
  StackSize = 128;                  { Stack size in bytes }
  HeapSize = 6 * 1024;              { Heap size in bytes }
  HeapSizeParas = (HeapSize + 15) div 16;  { Heap size in paragraphs. }

  { DOS Device Driver consts }

  DevIsCharacter = $8000;
  DevSupportsIoCtl = $4000;

  DevCmdInit = 0;
  DevCmdIoCtl = 3;

  DevStatusError = $8000;
  DevStatusDone = $100;
  DevStatusGeneralFailure = $c;

type
  { DOS Device Request Block }
  PRequestBlock = ^TRequestBlock;
  TRequestBlock = object
    { Size of the request structure, which may be variable. }
    Size: Byte;

    { For block devices. }
    SubUnit: Byte;

    { Command opcode. We support only DevCmdInit. }
    Command: Byte;

    { On return, this field keeps the return status (DevStatus*) of the
      command being requested. }
    Status: Word;

    { Reserved by the system. }
    Reserved: array[0..7] of Byte;
  end;

  { DOS Device Request Block of the DevCmdInit opcode. }
  PDevInitRequestBlock = ^TDevInitRequestBlock;
  TDevInitRequestBlock = object (TRequestBlock)
    { On return, this field must be 0. }
    Units: Byte;

    { On return, this field must point right above the top of the memory
      of the driver. The system then keeps only the memory between
      DeviceHeader and MemTop resident.
      On error, return Ptr(CSeg, 0) to release all memory of the driver. }
    MemTop: Pointer;

    { On input, this field points to the command line from CONFIG.SYS, so
      the driver can read its parameters from there. }
    CommandLine: PChar;

    { Not used for character devices. }
    DriveNumber: Byte;
  end;

const
  { These variables must be declared const because the data segment
    isn't zeroed until InitRuntime is invoked, so they would contain
    garbage if they were 'vars'. We also don't want that InitRuntime
    is zapping our vars later. }

  Request: PDevInitRequestBlock = nil;
  SavedSS: Word = 0;
  SavedSP: Word = 0;
  Stack: array[0..StackSize-1] of Char = '';

(*
 * Forwards
 *)
procedure DeviceStrategyAsm; forward;
procedure DeviceInterruptAsm; forward;
procedure InitRuntime; forward;
procedure BeforeMain; forward;

(*
 * This is actually the device header (data).
 * Must be the first procedure of the program.
 *)
procedure DeviceHeader; assembler;
asm
  dd  -1
  dw  DevIsCharacter
  dw  offset DeviceStrategyAsm
  dw  offset DeviceInterruptAsm
  db  'PKTNDIS$'
end;

(*
 *
 *)
procedure DeviceStrategyAsm; assembler;
asm
  push ds
  push ax
  mov  ax, seg @Data
  mov  ds, ax
  mov  Request.word[0], bx
  mov  Request.word[2], es
  pop  ax
  pop  ds
end;

(*
 * High level handler.
 *)
procedure DeviceInterruptHandler;
const
  Initialized: Boolean = false;
begin
  if Request^.Command = DevCmdInit then
  begin
    if not Initialized then
    begin
      Initialized := true;
      InitRuntime;
      if InitDriver then
      begin
        Request^.Units := 0;  { character device }
        Request^.Status := DevStatusDone;
        Request^.MemTop := HeapEnd; { our memtop is the end of the heap }
        exit;
      end else
        Request^.MemTop := Ptr(CSeg, 0); { unload device }
    end
  end;
  { default: return an error }
  Request^.Status := DevStatusDone or DevStatusError or DevStatusGeneralFailure;
end;

(*
 * Low level handler.
 *)
procedure DeviceInterruptAsm; assembler;
asm
  pushf
  push ds
  push ax

  mov  ax, seg @Data        { set our DS }
  mov  ds, ax

  mov  SavedSS, ss          { save ss, sp }
  mov  SavedSP, sp
  mov  ss, ax               { switch stack }
  mov  sp, offset Stack + StackSize;

  { Now that we have a lot of stack space, save all regs and invoke
    the Pascal handler. }
  push ax
  push bx
  push cx
  push dx
  push di
  push si
  push es

  call DeviceInterruptHandler

  pop  es
  pop  si
  pop  di
  pop  dx
  pop  cx
  pop  bx
  pop  ax

  mov  ss, SavedSS          { switch stack back }
  mov  sp, SavedSP

  pop  ax
  pop  ds
  popf
end;

(*
 * Executes InitTurbo (RTL's entry point) and sets up the RTL for our needs.
 *
 * This file requires G- (no 286+ codegen) because the stack frame handling
 * and the code segment aligment is different for G+, and we don't want to
 * handle both. This is no performance-critical code so we get along with G-.
 *
 * All other units can be compiled with G+.
 *)
procedure InitRuntime;
begin
  { Invoke RTL's InitTurbo. Its address is part of a CALL instruction
    at the start of the unnamed main block 3 bytes (offset 2) after BeforeMain:
      BeforeMain:
        retf              ; offset 0
      Unnamed Main:
        call InitTurbo    ; offset 1: CALL opcode
                          ; offset 2: DWORD of InitTurbo
    We extract its address and invoke it with the next statement: }

  TProcedure(Pointer(PChar(@BeforeMain) + 2)^);

  { undo RTL changes to IVs }
  SwapVectors;

  { Initialize the RTL's heap vars so they point to the end of the
    data segment, overriding the RTL stack, which we don't use.
    The heap size is controlled by the HeapSizeParas constant.

    There are several approaches of determining the end of the data segment:

    The last symbol of the data segment is actually System.SaveInt75,
    so we could start the heap at SaveInt75 + SizeOf(SaveInt75).
    However, we don't need these SaveInts at all (we do a SwapVectors)
    so we can set the end of the data segment at SaveInt00.
    But since we don't need I/O support, we can save even more by setting
    the end of the data segment at System.Input.
    Have a look at the MAP file of pktndis. }

  HeapOrg := Ptr(AlignPtr(@System.Input), 0);
  HeapPtr := HeapOrg;
  HeapEnd := HeapOrg;
  Inc(PtrRec(HeapEnd).Seg, HeapSizeParas);
  FreeList := HeapOrg;

  { initialize TinyHeap using the memory block we'd otherwise use
    for the system heap. }
  InitTinyHeap(HeapOrg, HeapSizeParas * 16);

  { we don't have a PSP }
  PrefixSeg := 0;
end;

(*
 * This proc must be declared last, just before the main block, and must
 * remain empty.
 *)
procedure BeforeMain; assembler;
asm
end;

(*
 * Not invoked when the program is executed as a driver.
 *)
begin
  { Prevent linker from optimizing out DeviceHeader }
  ReferenceSymbol(@DeviceHeader);
end.
