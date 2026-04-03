(*
 * SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 1993-2026 https://github.com/robert-j
 *
 * Packet Driver Interface
 *)

unit PktDrv;

interface

const
  MTU = 1500;      { Ethernet Maximal Transfer Unit w/out MAC headers }

const
  PktInt: Byte = 0;           { keeps the INT# of the packet driver }

  { Driver Interface Classes }
  cl_Ethernet = 1;            { DIX Ethernet }

  { Driver Interface Type }
  tp_Any = $ffff;             { Wildcard: support all network cards }

  { Error Codes }
  err_OK           = 0;
  err_HandleInval  = 1;
  err_Class        = 2;
  err_Type         = 3;
  err_Number       = 4;
  err_TypeInval    = 5;
  err_Multi        = 6;
  err_Terminate    = 7;
  err_ModeInval    = 8;
  err_Space        = 9;
  err_InUse        = 10;
  err_Command      = 11;
  err_Send         = 12;
  err_SetAddr      = 13;
  err_Address      = 14;

  { Capabilities }
  cap_Basic        = 1;
  cap_Extended     = 2;
  cap_Perf         = 5;
  cap_ExtPerf      = 6;
  cap_Unknown      = $ff;

  { Tries to find a packet driver in the interrupt range $20-$ff, initializes it,
    and returns the interrupt number. Returns 0 if no packet driver was found.
    Sets PktInt as a side effect. }
  function FindPktDrv: Byte;

  { Initializes a packet driver at the specified interrupt number. Returns
    false if no packet driver was found. Sets PktInt as a side effect. }
  function InitPktDrv(IntNo: Byte): Boolean;

  { Configures the unit for using a packet driver at the specified interrupt
    number. Assumes that there is actually a packet driver at the specified
    IntNo. No validation is performed. }
  procedure ConfigPktDrv(IntNo: Byte);

type
  TDriverInfo  = record
    Ver: Word;
    Cls: Byte;
    Typ: Word;
    Number: Byte;
    Name: PChar;
    Cap: Byte;
  end;

  function GetDriverInfo(Handle: Word; var Info: TDriverInfo): Byte;

const

  { DIX MAC Ether Types in host byte order.
   See https://en.wikipedia.org/wiki/EtherType }

  EtherTypeIp     = $0800;    { IP }
  EtherTypeArp    = $0806;    { ARP }
  EtherTypeAll    = $0000;    { wildcard, all ether types }

type

  { TAccess*.Receiver must be an interrupt proc with an RETF frame, but
  Borland Pascal only supports IRET.

  We can use an ad-hoc thunk to overcome this limitation:

      procedure Recv(args..); interrupt;
      begin
      end;

      procedure RecvThunk; far; assembler;
      asm
        pushf
        call far [Recv]   ; invoke the actual Recv interrupt proc
      end;

  Then register RecvThunk as a receiver with AccessType or AccessEther.

  The register arguments passed to Recv are:

    bx:   handle as returned by AccessType/Ether
    cx:   buffer size including MAC
    ax:   stage
          when ax = 0:
              return buffer for reception in es:di
          when ax = 1:
              use buffer in ds:si

  See also the Packet Driver specs. }

  TAccess = record
    Cls: Byte;
    Typ: Word;
    Number: Byte;
    EtherType: Pointer;     { MAC Ether Type in net byte order }
    EtherTypeLen: Word;
    Receiver: Pointer;      { See comment above }
    Handle: Word;           { Output only: the Packet Driver handle }
  end;

  TAccessEther = record
    Number: Byte;
    EtherType: Word;        { MAC Ether Type in net byte order }
    Receiver: Pointer;      { See comment above }
    Handle: Word;           { Output only: the Packet Driver handle }
  end;

  { Ethernet Address }
  PEthAddr = ^TEthAddr;
  TEthAddr = array[0..5] of Byte;

  { MAC Header }
  TMAC = record
    Dest: TEthAddr;
    Send: TEthAddr;
    EtherType: Word;
  end;

  { Registers the frame type specified by Access and, when successful,
    returns its handle in Access.Handle. }
  function AccessType(var Access: TAccess): Byte;

  { Registers the Ethernet frame type specified by Access and, when
    successful, returns its handle in Access.Handle. }
  function AccessEther(var Access: TAccessEther): Byte;

  { Releases a type registered with AccessType }
  function ReleaseType(Handle: Word): Byte;

  { Releases a type registered with AccessEther. The handle is taken from
    the Access.Handle, which is set to 0 when the operation wa successful. }
  function ReleaseEther(var Access: TAccessEther): Byte;

  { Terminates the handle and unloads the packet driver. We don't use this
    function. Untested. }
  function Terminate(Handle: Word): Byte;

  { Sends a packet. You may wonder, which handle this function is using:
    It doesn't need one, because you have to supply 'real' network packets
    with Buffer. They are simply send out over the network interface,
    regardless which type they are. }
  function SendPkt(const Buffer; Len: Word): Byte;

  { Returns the local MAC address. The handle must have been obtained with
    AccessType/Ether. }
  function GetMacAddress(Handle: Word; var hwaddr: TEthAddr): Byte;

  { Resets the interface specified by handle, which must have been obtained
    with AccessType/Ether. We don't use this function. Untested. }
  function ResetInterface(Handle: Word): Byte;

  { Receiver Modes}

const
  RecvModeOff = 1;
  RecvModeDirect = 2;
  RecvModeBroadcast = 3;
  RecvModeLimitedMulticast = 4;
  RecvModeAllMulticast = 5;
  RecvModeAll = 6;

  { Sets a receiver mode }
  function SetReceiverMode(Handle: Word; Mode: Word): Byte;

  { Returns the receiver mode currently in use }
  function GetReceiverMode(Handle: Word; var Mode: Word): Byte;

type
  { Result of GetStatistics }
  PStatistics = ^TStatistics;
  TStatistics = record
    PacketsIn: Longint;   { Totals across all handles }
    PacketsOut: Longint;
    BytesIn: Longint;     { Including MAC headers }
    BytesOut: Longint;
    ErrorsIn: Longint;    { Totals across all error types }
    ErrorsOut: Longint;
    PacketsLost: Longint; { No buffer from receiver(), out of resources, etc. }
  end;

  function GetStatistics(Handle: Word; var Stats: PStatistics): Byte;

type
  { Result of GetDriverParams }
  PDriverParams = ^TDriverParams;
  TDriverParams = record
    MajorRev: Byte;       { Revision of Packet Driver spec }
    MinorRev: Byte;
    Length: Byte;         { Length of this record in bytes }
    AddrLen: Byte;        { Length of a MAC-layer address }
    Mtu: Word;            { MTU, including MAC headers }
    McastAvail: Word;     { Buffer size for multicast addr }
    RcvBufs: Word;        { (# of back-to-back MTU rcvs) - 1 }
    XmtBufs: Word;        { (# of successive xmits) - 1 }
    IntNum: Word;         { Interrupt # to hook for post-EOI processing, 0 = none }
  end;

  function GetDriverParams(var Params: PDriverParams): Byte;

implementation

uses
  WinDos, Strings, Bits;

const
  { Function Calls }
  pf_DriverInfo    = 1;
  pf_AccessType    = 2;
  pf_ReleaseType   = 3;
  pf_SendPkt       = 4;
  pf_Terminate     = 5;
  pf_GetAddress    = 6;
  pf_Reset         = 7;
  pf_GetParams     = 10;
  pf_AsyncSendPkt  = 11;
  pf_SetRecvMode   = 20;
  pf_GetRecvMode   = 21;
  pf_GetStatistics = 24;
  pf_SetAddress    = 25;

var
  PktIntVec: Pointer;

(*
 *
 *)
function GetDriverInfo(Handle: Word; var Info: TDriverInfo): Byte;
var
  Regs: TRegisters;
begin
  with Regs do
  begin
    ah := pf_DriverInfo;
    al := $ff;
    bx := Handle;
    Intr(PktInt, Regs);
    if not Odd(Flags) then
    begin
      Info.Ver := bx;
      Info.Cls := ch;
      Info.Typ := dx;
      Info.Number := cl;
      Info.Name := PChar(Ptr(ds, si));
      Info.Cap := al;
      GetDriverInfo := err_OK;
    end
    else
      GetDriverInfo := dh;
  end;
end;

(*
 *
 *)
function AccessType(var Access: TAccess): Byte;
var
  Regs: TRegisters;
begin
  with Regs, Access do
  begin
    ah := pf_AccessType;
    al := Cls;
    bx := Typ;
    dl := Number;
    ds := PtrRec(EtherType).Seg;
    si := PtrRec(EtherType).Ofs;
    cx := EtherTypeLen;
    es := PtrRec(Receiver).Seg;
    di := PtrRec(Receiver).Ofs;
    Intr(PktInt, Regs);
    if not Odd(Flags) then
    begin
      Handle := ax;
      AccessType := err_OK;
    end
    else
    begin
      Handle := 0;
      AccessType := dh;
    end;
  end;
end;

(*
 *
 *)
function AccessEther(var Access: TAccessEther): Byte;
var
  Regs: TRegisters;
begin
  with Regs, Access do
  begin
    ah := pf_AccessType;
    al := cl_Ethernet;
    bx := tp_Any;
    dl := Number;
    if EtherType = EtherTypeAll then
    begin
      ds := 0;
      si := 0;
      cx := 0;
    end else
    begin
      ds := Seg(EtherType);
      si := Ofs(EtherType);
      cx := SizeOf(EtherType); { 2 Bytes }
    end;
    es := PtrRec(Receiver).Seg;
    di := PtrRec(Receiver).Ofs;
    Intr(PktInt, Regs);
    if not Odd(Flags) then
    begin
      Handle := ax;
      AccessEther := err_OK;
    end
    else
    begin
      Handle := 0;
      AccessEther := dh;
    end;
  end;
end;

(*
 *
 *)
function ReleaseType(Handle: Word): Byte;
var
  Regs: TRegisters;
begin
  with Regs do
  begin
    ah := pf_ReleaseType;
    bx := Handle;
    Intr(PktInt, Regs);
    if not Odd(Flags) then
      ReleaseType := err_OK
    else
      ReleaseType := dh;
  end;
end;

(*
 *
 *)
function ReleaseEther(var Access: TAccessEther): Byte;
var
  Res: Byte;
begin
  Res := ReleaseType(Access.Handle);
  if Res = err_OK then
    Access.Handle := 0;
  ReleaseEther := Res;
end;

(*
 *
 *)
function SendPkt(const Buffer; Len: Word): Byte; assembler;
asm
  push ds

  mov  ah, pf_SendPkt     { function code }

  { set es = ds }
  push ds
  pop  es

  lds  si, Buffer
  mov  cx, Len

  { simulate interrupt }
  pushf
  cli
  call es:PktIntVec
  jnc  @ok

  { return error code in AL }
  mov  al, dh
  jmp  @out

@ok:
  xor  ax, ax

@out:
  pop  ds
end;

(*
 *
 *)
function Terminate(Handle: Word): Byte;
var
  Regs: TRegisters;
begin
  with Regs do
  begin
    ah := pf_Terminate;
    bx := Handle;
    Intr(PktInt, Regs);
    if not Odd(Flags) then
      Terminate := err_OK
    else
      Terminate := dh;
  end;
end;

(*
 *
 *)
function GetMacAddress(Handle: Word; var hwaddr: TEthAddr): Byte;
var
  Regs: TRegisters;
begin
  with Regs do
  begin
    ah := pf_GetAddress;
    bx := Handle;
    es := Seg(hwaddr);
    di := Ofs(hwaddr);
    cx := SizeOf(hwaddr);
    Intr(PktInt, Regs);
    if not Odd(Flags) then
      GetMacAddress := err_OK
    else
      GetMacAddress := dh;
  end;
end;

(*
 *
 *)
function ResetInterface(Handle: Word): Byte;
var
  Regs: TRegisters;
begin
  with Regs do
  begin
    ah := pf_Reset;
    bx := Handle;
    Intr(PktInt, Regs);
    if not Odd(Flags) then
      ResetInterface := err_OK
    else
      ResetInterface := dh;
  end;
end;

(*
 *
 *)
function GetStatistics(Handle: Word; var Stats: PStatistics): Byte;
var
  Regs: TRegisters;
begin
  with Regs do
  begin
    ah := pf_GetStatistics;
    bx := Handle;
    Intr(PktInt, Regs);
    if not Odd(Flags) then
    begin
      Stats := Ptr(ds, si);
      GetStatistics := err_OK
    end
    else
    begin
      Stats := nil;
      GetStatistics := dh
    end;
  end;
end;

(*
 *
 *)
function GetDriverParams(var Params: PDriverParams): Byte;
var
  Regs: TRegisters;
begin
  with Regs do
  begin
    ah := pf_GetParams;
    Intr(PktInt, Regs);
    if not Odd(Flags) then
    begin
      Params := Ptr(es, di);
      GetDriverParams := err_OK
    end
    else
    begin
      Params := nil;
      GetDriverParams := dh
    end;
  end;
end;

(*
 *
 *)
function SetReceiverMode(Handle: Word; Mode: Word): Byte;
var
  Regs: TRegisters;
begin
  with Regs do
  begin
    ah := pf_SetRecvMode;
    bx := Handle;
    cx := Mode;
    Intr(PktInt, Regs);
    if not Odd(Flags) then
      SetReceiverMode := err_OK
    else
      SetReceiverMode := dh;
  end;
end;

(*
 *
 *)
function GetReceiverMode(Handle: Word; var Mode: Word): Byte;
var
  Regs: TRegisters;
begin
  with Regs do
  begin
    ah := pf_GetRecvMode;
    bx := Handle;
    Intr(PktInt, Regs);
    if not Odd(Flags) then
    begin
      Mode := ax;
      GetReceiverMode := err_OK;
    end
    else
      GetReceiverMode := dh;
  end;
end;

(*
 *
 *)
function InitPktDrv(IntNo: Byte): Boolean;
const
  JmpLen = 3;       { length of jmp short + nop instructions }
  PktDrvLen = 8;    { length('PKT DRVR') }
var
  Instance: PChar;
begin
  GetIntVec(IntNo, Pointer(Instance));
  if (Instance <> nil) and
     (StrLComp(@Instance[JmpLen], 'PKT DRVR', PktDrvLen) = 0) then
  begin
    PktInt := IntNo;
    PktIntVec := Instance;
    InitPktDrv := true;
  end
  else
    InitPktDrv := false;
end;

(*
 *
 *)
function FindPktDrv: Byte;
var
  I: Byte;
begin
  FindPktDrv := 0;
  for I := $20 to $ff do
  begin
    if InitPktDrv(I) then
    begin
      FindPktDrv := I;
      exit;
    end;
  end;
end;

(*
 *
 *)
procedure ConfigPktDrv(IntNo: Byte);
begin
  PktInt := IntNo;
  GetIntVec(IntNo, PktIntVec);
end;

end.
