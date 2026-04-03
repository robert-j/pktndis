(*
 * SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 2020-2026 https://github.com/robert-j
 *
 * Implementation of an NDIS MAC Device Driver.
 *)

unit Driver;

interface

uses
  Ndis;

function InitDriver: Boolean;

implementation

uses
  WinDos, DosLib, PktDrv, Bits, Utils, Strings, TinyHeap, TinyQue;

{$I stamp.inc}    { source build stamp }

const
  DriverName = 'PKTNDIS$';
  DriverMajorVersion = 0;
  DriverMinorVersion = 1;

  MaxFrameSize = MTU + SizeOf(TMac);

  MulticastTable: MCastBuf = (
    McbMax: 8;
    McbCnt: 0;
    McbAddrs: (
      (mAddr: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
      (mAddr: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    )
  );

  SpecificCharacteristics: MACSpecChar = (
    MscSize: SizeOf(MACSpecChar);
    MscType: 'DIX+802.3';   { crucial for MSTCP }
    MscStnAdrSz: 6;
    MscPermStnAdr: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    MscCurrStnAdr: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    MscCurrFncAdr: 0;
    MscMCp: @MulticastTable;
    MscLinkSpd: 100000000;  { 100 Mbit/s }
    MscService: SV_BROADCAST + SV_PROMISCUOUS + SV_CURSTAT + SV_MULTIXFER +
      SV_RXCHAININD + SV_INTERRUPT + SV_MULTICAST;
    MscMaxFrame: MaxFrameSize;
    MscTBufCap: MaxFrameSize;
    MscTBlkSz: MaxFrameSize;
    MscRBufCap: 0;  { calculated at run-time }
    MscRBlkSz: MaxFrameSize;
    MscVenCode: ($ff, $ff, $ff);
    MscVenAdapter: 0;
    MscVenAdaptDesc: 'PKTNDIS Adapter';
    MscInterrupt: 0;
    MscTxQDepth: 1;
    MscMaxNumDataBlks: 8
  );

  SpecificStatus: MACSpecStat = (
    MssSize: SizeOf(MACSpecStat);
    MssDiagDT: NOT_MAINTAINED;
    MssStatus: ST_OK + ST_MAC_IS_OPEN;
    MssFilter: 0;
    MssM8Sp: nil;
    MssClearDT: NOT_MAINTAINED;
    MssFR: 0;
    MssRFCRC: 0;
    MssFRByt: NOT_MAINTAINED;
    MssRFLack: 0;
    MssFRMC: NOT_MAINTAINED;
    MssFRBC: NOT_MAINTAINED;
    MssRFErr: NOT_MAINTAINED;
    MssRFMax: NOT_MAINTAINED;
    MssRFMin: NOT_MAINTAINED;
    MssFRMCByt: NOT_MAINTAINED;
    MssFRBCByt: NOT_MAINTAINED;
    MssRFHW: NOT_MAINTAINED;
    MssFS: 0;
    MssFSByt: NOT_MAINTAINED;
    MssFSMC: NOT_MAINTAINED;
    MssFSBC: NOT_MAINTAINED;
    MssFSBCByt: NOT_MAINTAINED;
    MssFSMCByt: NOT_MAINTAINED;
    MssSFTime: NOT_MAINTAINED;
    MssSFHW: NOT_MAINTAINED
  );

  UpperDispatch: MACUprDisp = (
    MudCCp: nil;
    MudGenReq: nil;
    MudXmitChain: nil;
    MudXferData: nil;
    MudRcvRelease: nil;
    MudIndOn: nil;
    MudIndOff: nil
  );

  LowerDispatch: ProtLwrDisp = (
    PldCCp: nil;
    PldIFF: 0;
    PldReqConfirm: nil;
    PldXmitConfirm: nil;
    PldRcvLkAhead: nil;
    PldIndComplete: nil;
    PldRcvChain: nil;
    PldStatInd: nil
  );

  Characteristics: CommChar = (
    CcSize: SizeOf(CommChar);
    CcNdisMjr: NDIS_VERSION_MAJOR;
    CcNdisMnr: NDIS_VERSION_MINOR;
    CcRsv0: 0;
    CcModMjr: DriverMajorVersion;
    CcModMnr: DriverMinorVersion;
    CcBindFnc: UPPERBIND;
    CcName: DriverName;
    CcUPLevel: UL_MAC;
    CcUIType: UI_MAC;
    CcLPLevel: 0;
    CcLIType: 0;
    CcModuleID: 0;
    CcDataSeg: 0;
    CcSysReq: nil;
    CcSCp: @SpecificCharacteristics;
    CcSSp: @SpecificStatus;
    CcUDp: @UpperDispatch;
    CcLDp: nil;
    CcRsv1: nil;
    CcRsv2: nil
  );

const
  { Characteristics and upcalls of the bound protocol. }
  ProtoCharacteristics: PCommChar = nil;
  ProtoUpCalls: PProtLwrDisp = nil;
  ProtoInterruptRequested: Boolean = false;

  IndicationLevel: Word = 0;    { Keeps the indication level }
  PktHandle: Word = 0;          { Keeps the Packet Driver handle }

  { Configuration params read from PROTOCOL.INI at initialization time }
  Params: record
    IntNo: Byte;      { interrupt number of the Packet Driver }
    Hide: Byte        { whether to hide the Packet Driver }
  end = (
    IntNo: 0;         { defaults to auto-detect }
    Hide: 1           { defaults to yes }
  );

var
  PktInfo: TDriverInfo;
  IndicatedPacket: Pointer;
  Queue: TTinyQueue;
  TxPacket: array[0..MaxFrameSize - 1] of Char;

(*
 *
 *)
procedure OutputDebugInfo;
begin
  PrintCStr('Chars:     '); PrintHexPtr(@Characteristics);
  PrintCStr(', Len: '); PrintHexWord(Characteristics.CcSize);
  PrintCStr(', CcModuleID: '); PrintHexWord(Characteristics.CcModuleID);
  PrintCStr(^m^j);

  PrintCStr('SpecChars: '); PrintHexPtr(@SpecificCharacteristics);
  PrintCStr(', Len: '); PrintHexWord(SpecificCharacteristics.MscSize);
  PrintCStr(', MscService: '); PrintHexLong(SpecificCharacteristics.MscService);
  PrintCStr(^m^j);

  PrintCStr('SpecStat:  '); PrintHexPtr(@SpecificStatus);
  PrintCStr(', Len: '); PrintHexWord(SpecificStatus.MssSize);
  PrintCStr(^m^j);
end;

(*
 * Turns off indications.
 * Returns true if IndicationLevel transitions to 1.
 *
 * Must be used pairwise with EndIndicateOff.
 *)
function BeginIndicateOff: Boolean; assembler;
asm
  inc  IndicationLevel
  cmp  IndicationLevel, 1
  mov  al, 0
  jne  @done
  mov  al, 1
@done:
end;

(*
 * Turns on indications.
 * Returns true if IndicationLevel transitions to 0.
 *
 * Must be used pairwise with BeginIndicateOff.
 *)
function EndIndicateOff: Boolean; assembler;
asm
  mov  al, 0
  cmp  IndicationLevel, 0
  je   @done
  dec  IndicationLevel
  jnz  @done
  mov  al, 1
@done:
end;

(*
 * Invokes protocol's IndicationComplete.
 *)
function InvokeIndicationComplete: Word;
begin
  STI;
  InvokeIndicationComplete := ProtoUpCalls^.PldIndComplete(
    Characteristics.CcModuleID,
    ProtoCharacteristics^.CcDataSeg
  );
  CLI;
end;

(*
 * Invokes protocol's StatusIndication.
 * Returns true if the protocol cleared the indicate byte.
 *)
function InvokeStatusIndication(OpCode: Word): Boolean;
var
  Indicate: Byte;
begin
  Indicate := INDICATION_INIT;

  STI;
  ProtoUpCalls^.PldStatInd(
    Characteristics.CcModuleID,
    0,
    Indicate,
    OpCode,
    ProtoCharacteristics^.CcDataSeg
  );
  CLI;

  InvokeStatusIndication := Indicate = 0;
end;

(*
 * Invokes protocols's ReceiveLookAhead for the specified packet.
 * Returns true if the protocol cleared the indicate byte.
 *)
function InvokeReceiveLookAhead(Packet: Pointer): Boolean;
var
  Indicate: Byte;
  PacketSize: Word;
begin
  Indicate := INDICATION_INIT;

  { expose packet to TransferData }
  IndicatedPacket := Packet;
  PacketSize := TinySize(Packet);

  STI;
  ProtoUpCalls^.PldRcvLkAhead(
    Characteristics.CcModuleID,
    PacketSize, { PALOFF }
    PacketSize,
    Packet^,
    Indicate,
    ProtoCharacteristics^.CcDataSeg
  );
  CLI;

  { release packet }
  TinyFree(Packet);

  InvokeReceiveLookAhead := Indicate = 0;
end;

(*
 * Invokes protocols's ReceiveChain for the specified packet.
 * Returns true if the protocol cleared the indicate byte.
 *)
function InvokeReceiveChain(Packet: Pointer): Boolean;
const
  { save stack. safe, because InvokeReceiveChain is not reentered.}
  Desc: RxBufDesc = ();
var
  Indicate: Byte;
  Res: Word;
begin
  { construct Desc }
  Desc.RxDataCount := 1;
  Desc.RxDataBlk[0].RxDataLen := TinySize(Packet);
  Desc.RxDataBlk[0].RxDataPtr := Packet;

  Indicate := INDICATION_INIT;

  STI;
  Res := ProtoUpCalls^.PldRcvChain(
    Characteristics.CcModuleID,
    Desc.RxDataBlk[0].RxDataLen,
    PtrRec(Packet).Ofs, { the offset of the packet is our handle }
    Desc,
    Indicate,
    ProtoCharacteristics^.CcDataSeg
  );
  CLI;

  { free unless protocol deferred (takes ownership until ReceiveRelease) }
  if Res <> NDIS_ERR_WAIT_FOR_RELEASE then
    TinyFree(Packet);

  InvokeReceiveChain := Indicate = 0;
end;

(*
 * Packet Driver Receiver, Pascal part.
 *)
procedure PktReceiver(ax, bx, cx, dx, si, di, ds, es, bp: Word); interrupt;
var
  Mem: Pointer;
  ProtocolWantsOff: Boolean;
begin
  { ax = 0 => allocate packet }
  if ax = 0 then
  begin
    Mem := TinyAlloc(cx);
    if Mem = nil then
    begin
      { drop }
      Inc(SpecificStatus.MssRFLack);
      es := 0;
      di := 0;
      exit;
    end;

    es := PtrRec(Mem).Seg;
    di := PtrRec(Mem).Ofs;
    exit;
  end;

  { ax <> 0 => process packet }

  { get the TinyAlloc pointer back that we allocated before }
  Mem := Ptr(ds, si);

  { we must queue when indications are off, as per spec }
  if IndicationLevel <> 0 then
  begin
    { note how we enqueue only the offset. segment is known (TinySeg) }
    if not Queue.Enqueue(si) then
    begin
      { drop }
      TinyFree(Mem);
      Inc(SpecificStatus.MssRFLack);
    end;
    exit;
  end;

  { disable indications. nested PktReceiver calls will queue
    because IndicationLevel is now > 0. }
  BeginIndicateOff;

  ProtocolWantsOff := false;

  { drain queue first. since we've queued only the offset of Mem,
    reconstruct the pointer using TinySeg }
  while not Queue.IsEmpty do
    if InvokeReceiveLookAhead(Ptr(TinySeg, Queue.Deqeue)) then
      ProtocolWantsOff := true;

  { low water? }
  if TinyAvail < MaxFrameSize then
  begin
    { synchronous }
    if InvokeReceiveLookAhead(Mem) then
      ProtocolWantsOff := true;
  end
  else
  begin
    { asynchronous }
    if InvokeReceiveChain(Mem) then
      ProtocolWantsOff := true;
  end;

  { give protocol a call }
  if ProtoInterruptRequested then
  begin
    ProtoInterruptRequested := false;
    if InvokeStatusIndication(SiInterruptStatus) then
      ProtocolWantsOff := true;
  end;

  { always call IndicationComplete after indications, as per spec.
    IndicationLevel is still > 0, so nested interrupts will queue.
    if protocol cleared the indicate byte, it will call IndicationOn
    during IndicationComplete to re-enable indications. }
  InvokeIndicationComplete;

  { re-enable indications unless protocol already did via IndicationOn }
  if not ProtocolWantsOff then
    EndIndicateOff;
end;

(*
 * Packet Driver Receiver trampoline. We need it because the Packet Driver
 * is expecting a FAR proc, but we want to handle the receptions with an
 * interrupt proc (PktReceiver).
 *)
procedure PktReceiverAsm; far; assembler;
asm
  pushf { construct IRET frame }
  cli   { we want interrupts disabled }
  cld   { we want to adhere to MSC's ABI }
  call  far [PktReceiver]
end;

(*
 * Configures the Packet Driver receiver mode from the specified NDIS mode.
 *)
procedure PktSetReceiverModeFromNdis(NdisMode: Word);
begin
  if (NdisMode = 0) then
    SetReceiverMode(PktHandle, RecvModeOff)
  else if (NdisMode and FM_PROMISCUOUS) <> 0 then
    SetReceiverMode(PktHandle, RecvModeAll)
  else if (NdisMode and FM_BROADCAST) <> 0 then
    SetReceiverMode(PktHandle, RecvModeBroadcast)
  else if (NdisMode and FM_DIRECTED) <> 0 then
    SetReceiverMode(PktHandle, RecvModeDirect)
end;

(*
 * Finds and configures a Packet Driver.
 * Sets global vars PktHandle, PktInfo.
 *)
function PktFindAndConfig: Boolean;
var
  PktIntVec: PChar;
  Access: TAccessEther;
  PktAvail: Boolean;
begin
  PktFindAndConfig := false;

  { initialize packet driver at int# we've got from PROTOCOL.INI params }
  if Params.IntNo = 0 then
    PktAvail := PktDrv.FindPktDrv <> 0
  else
    PktAvail := PktDrv.InitPktDrv(Params.IntNo);

  if not PktAvail then
  begin
    PrintCStr('PKTNDIS: unable to find a packet driver'^m^j);
    exit;
  end;

  { request access to all frames from the Packet Driver }
  Access.Number := 0;
  Access.EtherType := EtherTypeAll;
  Access.Receiver := @PktReceiverAsm;

  if AccessEther(Access) <> err_OK then
  begin
    PrintCStr('PKTNDIS: packet driver already in use'^m^j);
    exit;
  end;

  PktHandle := Access.Handle;
  GetDriverInfo(PktHandle, PktInfo);

  { hide packet driver }
  if Params.Hide <> 0 then
  begin
    GetIntVec(PktDrv.PktInt, Pointer(PktIntVec));
    PktIntVec[3] := '-';
  end;

  PktFindAndConfig := true;
end;

(*
 * NDIS MAC System Request.
 * Function must adhere to MSC far pascal calling convensions.
 *)
function SystemRequest(ProtCCTab: PCommChar; var MacCCTab: PCommChar;
  Param3, Opcode, MacDs: ushort): Integer; far;
label
  leave;
begin
  MscPrologue(MacDs);

  SystemRequest := NDIS_ERR_INVALID_FUNCTION;

  { turn off receiver. no locking needed, as we're alone during initialization. }
  IndicationLevel := 1;

  { we only support Bind... }
  if OpCode <> SrBind then goto leave;

  { ... that and only once. }
  if (SpecificStatus.MssStatus and ST_MAC_IS_BOUND) <> 0 then goto leave;

  SystemRequest := NDIS_ERR_HARDWARE_ERROR;

  { kick Packet Driver }
  if not PktFindAndConfig then goto leave;

  { initialize characteristics from Packet Driver }
  GetMacAddress(PktHandle, PEthAddr(@SpecificCharacteristics.MscPermStnAdr)^);
  GetMacAddress(PktHandle, PEthAddr(@SpecificCharacteristics.MscCurrStnAdr)^);

  { as by the spec, we must start with packet reception disabled }
  SetReceiverMode(PktHandle, RecvModeOff);

  { exchange tables }
  MacCCTab := @Characteristics;
  ProtoCharacteristics := ProtCCTab;
  ProtoUpCalls := ProtoCharacteristics^.CcLDp;

  { turn on receiver. no locking needed, as we're alone during initialization. }
  IndicationLevel := 0;

  { save state }
  SpecificStatus.MssStatus := SpecificStatus.MssStatus or ST_MAC_IS_BOUND;

  PrintCStr('PKTNDIS: using packet driver found at interrupt 0x');
  PrintHexByte(PktDrv.PktInt);
  PrintCStr(^m^j);

  {$ifdef debug}
  OutputDebugInfo;
  {$endif}

  SystemRequest := NDIS_ERR_SUCCESS;

leave:
  MscEpilogue;
end;

(*
 * NDIS MAC Primitive.
 * Function must adhere to MSC far pascal calling convensions.
 *)
function GeneralRequest(ProtID, ReqHandle, Param1: ushort; Param2: Pointer;
  Opcode, MacDs: ushort): ushort; far;
begin
  MscPrologue(MacDs);

  case OpCode of
    GrSetPacketFilter:
    begin
      SpecificStatus.MssFilter := Param1;
      PktSetReceiverModeFromNdis(SpecificStatus.MssFilter);
      GeneralRequest := NDIS_ERR_SUCCESS;
    end;

    GrSetLookAhead, GrUpdateStatistics, GrClearStatistics:
    begin
      GeneralRequest := NDIS_ERR_SUCCESS;
    end;

    GrInterrupt:
    begin
      ProtoInterruptRequested := true;
      GeneralRequest := NDIS_ERR_SUCCESS;
    end;

    GrAddMulticastAddress,
    GrDeleteMulticastAddress:
    begin
      GeneralRequest := NDIS_ERR_SUCCESS;
    end;

    else
      GeneralRequest := NDIS_ERR_INVALID_FUNCTION
  end;

  MscEpilogue;
end;

(*
 * NDIS MAC Direct Primitive.
 * Function must adhere to MSC far pascal calling convensions.
 *)
function TransmitChain(ProtID, ReqHandle: ushort;
  const BufDesc: TxBufDesc; MacDs: ushort): ushort; far;
label
  leave;
var
  TotalLen, PartLen: Word;
  I: Integer;
begin
  MscPrologue(MacDs);

  TransmitChain := NDIS_ERR_OUT_OF_RESOURCE;
  TotalLen := 0;

  with BufDesc do
  begin
    if TxImmedLen > 0 then
    begin
      if TxImmedLen > SizeOf(TxPacket) then goto leave;
      CopyMem(TxImmedPtr^, TxPacket[0], TxImmedLen);
      Inc(TotalLen, TxImmedLen);
    end
    else if TxDataCount = 1 then
    begin
      { optimization:
        when BufDesc does not provide an immediate packet, and it only contains
        one packet, then send it right away w/out copying it into our TxPacket. }
      if SendPkt(TxDataBlk[0].TxDataPtr^, TxDataBlk[0].TxDataLen) <> err_OK then
        TransmitChain := NDIS_ERR_TRANSMIT_ERROR
      else
        TransmitChain := NDIS_ERR_SUCCESS;
      goto leave;
    end;

    for I := 0 to TxDataCount - 1 do
    begin
      PartLen := TxDataBlk[I].TxDataLen;
      if PartLen = 0 then continue; { TxDataLen may be 0 as by the spec }

      if TotalLen + PartLen > SizeOf(TxPacket) then goto leave;
      CopyMem(TxDataBlk[I].TxDataPtr^, TxPacket[TotalLen], PartLen);
      Inc(TotalLen, PartLen);
    end;
  end;

  if SendPkt(TxPacket, TotalLen) <> err_OK then
    TransmitChain := NDIS_ERR_TRANSMIT_ERROR
  else
    TransmitChain := NDIS_ERR_SUCCESS;

leave:
  MscEpilogue;
end;

(*
 * A protocol calls this synchronous routine from within its ReceiveLookahead
 * handler before return, to ask the MAC to transfer data for a received frame
 * to protocol storage. That's the reason why we pass the packet via a global
 * IndicatedPacket: it's local to the call context.
 *
 * NDIS MAC Direct Primitive.
 * Function must adhere to MSC far pascal calling convensions.
 *)
function TransferData(var BytesCopied: ushort; FrameOfs: ushort;
  const BufDesc: TDBufDesc; MacDs: ushort): ushort; far;
var
  PacketSize, TotalLen, PartLen: Word;
  I: Integer;
begin
  MscPrologue(MacDs);

  PacketSize := TinySize(IndicatedPacket);
  TotalLen := 0;
  with BufDesc do
  begin
    for I := 0 to TDDataCount - 1 do
    begin
      PartLen := TDDataBlk[I].TDDataLen;
      if PartLen = 0 then continue; { TDDataLen may be 0 as by the spec }

      if FrameOfs + PartLen > PacketSize then
        PartLen := PacketSize - FrameOfs;
      CopyMem(PChar(IndicatedPacket)[FrameOfs], TDDataBlk[I].TDDataPtr^, PartLen);
      Inc(FrameOfs, PartLen);
      Inc(TotalLen, PartLen);
      if FrameOfs >= PacketSize then break;
    end;
  end;

  BytesCopied := TotalLen;
  TransferData := NDIS_ERR_SUCCESS;

  MscEpilogue;
end;

(*
 * NDIS MAC Direct Primitive.
 * Function must adhere to MSC far pascal calling convensions.
 *)
function ReleaseData(ReqHandle, MacDs: ushort): ushort; far;
begin
  MscPrologue(MacDs);
  { release packet from TinyHeap }
  TinyFree(Ptr(TinySeg, ReqHandle));
  ReleaseData := NDIS_ERR_SUCCESS;
  MscEpilogue;
end;

(*
 * NDIS MAC Direct Primitive.
 * Function must adhere to MSC far pascal calling convensions.
 *)
function IndicationOn(MacDs: ushort): ushort; far;
begin
  MscPrologue(MacDs);
  { disable ints and leave them disabled as per spec }
  CLI;
  EndIndicateOff;
  IndicationOn := NDIS_ERR_SUCCESS;
  MscEpilogue;
end;

(*
 * NDIS MAC Direct Primitive.
 * Function must adhere to MSC far pascal calling convensions.
 *)
function IndicationOff(MacDs: ushort): ushort; far;
begin
  MscPrologue(MacDs);
  { disable ints and leave them disabled as per spec }
  CLI;
  BeginIndicateOff;
  IndicationOff := NDIS_ERR_SUCCESS;
  MscEpilogue;
end;

(*
 *
 *)
function InitDriver: Boolean;
var
  Handle: Word;
  Cfg: PModCfg;
begin
  InitDriver := false;

  { initialization of globals }
  SpecificCharacteristics.MscRBufCap := TinyAvail;
  Queue.Init;

  { open protocol manager }
  Handle := DosOpen('PROTMAN$', DOS_READ_WRITE_ACCESS);
  if DosLastError <> 0 then
  begin
    PrintCStr('PKTNDIS: unable to open PROTMAN$'^m^j);
    exit;
  end;

  Cfg := ProtmanGetInfo(Handle);
  if Cfg = nil then
  begin
    PrintCStr('PKTNDIS: unable to obtain info from PROTMAN$'^m^j);
    DosClose(Handle);
    exit;
  end;

  { get our module config from PROTMAN }
  Cfg := FindModuleConfig(Cfg, DriverName);
  if Cfg = nil then
  begin
    PrintCStr('PKTNDIS: there is no section containing drivername=');
    PrintCStr(DriverName);
    PrintCStr(' in PROTOCOL.INI.'^m^j);
    DosClose(Handle);
    exit;
  end;

  { read our parameters from PROTOCOL.INI }
  Params.IntNo := GetModuleParamLong(Cfg, 'interrupt', Params.IntNo);
  Params.Hide := GetModuleParamLong(Cfg, 'hide', Params.Hide);

  { configure Characteristics }
  StrLCopy(Characteristics.CcName, Cfg^.ModName, NAME_LEN - 1);
  Characteristics.CcSysReq := SystemRequest;
  Characteristics.CcDataSeg := DSeg;

  { configure UpperDispatch }
  UpperDispatch.MudCCp := @Characteristics;
  UpperDispatch.MudGenReq := GeneralRequest;
  UpperDispatch.MudXmitChain := TransmitChain;
  UpperDispatch.MudXferData := TransferData;
  UpperDispatch.MudRcvRelease := ReleaseData;
  UpperDispatch.MudIndOn := IndicationOn;
  UpperDispatch.MudIndOff := IndicationOff;

  if not ProtmanRegisterModule(Handle, Characteristics) then
  begin
    PrintCStr('PKTNDIS: unable to register the module with PROTMAN$'^m^j);
    DosClose(Handle);
    exit;
  end;

  DosClose(Handle);

  PrintCStr('PKTNDIS - Packet Driver to NDIS Adapter - ' + ProductDateTime + ^m^j);
  PrintCStr('NDIS Device Name: ');  PrintCStr(Characteristics.CcName);
  PrintCStr(^m^j);

  {$ifdef debug}
  OutputDebugInfo;
  {$endif}

  InitDriver := true;
end;

end.
