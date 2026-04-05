(*
 * SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 2020-2026 https://github.com/robert-j
 *
 * NDIS 2.0.1 Defines.
 *
 * References
 *
 * - IBM OS/2 DDK - LAN Device Driver Documentation
 *
 *   3Com/Microsoft LAN Manager Network Driver Interface Specification
 *
 *   NDIS Driver Developer's Tool Kit for OS/2 and DOS:
 *     Programmer's Guide
 *
 *   NDIS Driver Developer's Tool Kit for OS/2 and DOS:
 *     Programmer's Performance Guide
 *)

unit Ndis;

interface

type
  ushort = Word;
  uchar = Byte;
  ulong = Longint;
  LPBUF = Pointer;

const
  NAME_LEN = 16;
  ADDR_LEN = 16;
  ADDR_SIZE = 1;
  NUM_MCADDRS = 2;

  (*
   * System request function - opcodes
   *)
  SrInitiateBind = 1;
  SrBind = 2;
  SrUnBind = 5;

  (*
   * General Request opcodes
   *)
  GrInitiateDiagnostics = 1;
  GrReadErrorLog = 2;
  GrSetStationAddress = 3;
  GrOpenAdapter = 4;
  GrCloseAdapter = 5;
  GrResetMAC = 6;
  GrSetPacketFilter = 7;
  GrAddMulticastAddress = 8;
  GrDeleteMulticastAddress = 9;
  GrUpdateStatistics = 10;
  GrClearStatistics = 11;
  GrInterrupt = 12;
  GrSetFunctionalAddress = 13;
  GrSetLookAhead = 14;

  { NDIS 2.02 enhancement      }
  GrUnusedGenReq = 15;
  GrModifyOpenParms = 16;

  (*
   * Status Indication opcodes
   *)
  SiRingStatus = 1;
  SiAdapterCheck = 2;
  SiStartReset = 3;
  SiInterruptStatus = 4;
  SiEndReset = 5;

  (*
   * Error codes
   *)
  NDIS_ERR_SUCCESS = $0000;
  NDIS_ERR_WAIT_FOR_RELEASE = $0001;
  NDIS_ERR_REQUEST_QUEUED = $0002;
  NDIS_ERR_FRAME_NOT_RECOGNIZED = $0003;
  NDIS_ERR_FRAME_REJECTED = $0004;
  NDIS_ERR_FORWARD_FRAME = $0005;
  NDIS_ERR_OUT_OF_RESOURCE = $0006;
  NDIS_ERR_INVALID_PARAMETER = $0007;
  NDIS_ERR_INVALID_FUNCTION = $0008;
  NDIS_ERR_NOT_SUPPORTED = $0009;
  NDIS_ERR_HARDWARE_ERROR = $000A;
  NDIS_ERR_TRANSMIT_ERROR = $000B;
  NDIS_ERR_NO_SUCH_DESTINATION = $000C;
  NDIS_ERR_ALREADY_STARTED = $0020;
  NDIS_ERR_INCOMPLETE_BINDING = $0021;
  NDIS_ERR_DRIVER_NOT_INITIALIZED = $0022;
  NDIS_ERR_HARDWARE_NOT_FOUND = $0023;
  NDIS_ERR_HARDWARE_FAILURE = $0024;
  NDIS_ERR_CONFIGURATION_FAILURE = $0025;
  NDIS_ERR_INTERRUPT_CONFLICT = $0026;
  NDIS_ERR_INCOMPATIBLE_MAC = $0027;
  NDIS_ERR_INITIALIZATION_FAILED = $0028;
  NDIS_ERR_GENERAL_FAILURE = $00FF;

  (*
   * Module function flags (for CommChar.CcBindFnc)
   *)
  UPPERBIND = 1;
  LOWERBIND = 2;
  DYNAMICBIND = 4;

  (*
   * Protocol level at upper boundary (for CommChar.CcUPLevel)
   *)
  UL_MAC = 1;

  (*
   * Type of interface at upper boundary (for CommChar.CcUIType)
   *)
  UI_MAC = 1;

  (*
   * Versions
   *)
  NDIS_VERSION_MAJOR = 2;
  NDIS_VERSION_MINOR = 0;

  (*
   * MAC service flags (for MACSpecChar.MscService)
   *)
  SV_BROADCAST = $00001;    { broadcast supported }
  SV_MULTICAST = $00002;    { multicast supported }
  SV_GROUPADDR = $00004;    { function or group addressing }
  SV_PROMISCUOUS = $00008;  { promiscuous mode }
  SV_SOFTWARE = $00010;     { software settable station address }
  SV_CURSTAT = $00020;      { statistics are always current }
  SV_INITDIAG = $00040;     { initiate diagnostic supported }
  SV_LOOPBACK = $00080;     { loopback mode supported }
  SV_RXCHAININD = $00100;   { 0= receive lookahead indication }
  SV_SRCROUTE = $00200;     { IBM source routing }
  SV_RESET = $00400;        { reset mac supported }
  SV_OPENCLOSE = $00800;    { open/close adapter supported }
  SV_INTERRUPT = $01000;    { asynchronous indication complete }
  SV_SRBRIDGE = $02000;     { source routing bridge supported }
  SV_GDTADDR = $04000;      { GDT virtual address supported }
  SV_MULTIXFER = $08000;    { Multiple TransferDatas permitted (version 2.0.1) }
  SV_FRAME_SIZE_0 = $10000; { MAC sets FrameSize = 0 in ReceiveLookahead (version 2.0.1) }

  (*
   * Error flags (not a bit mask) of MACSpecStat.MssStatus
   *)
  ST_MISSING = $0000;
  ST_DIAG_ERR = $0001;
  ST_CONFIG_ERROR = $0002;
  ST_FAULT = $0003;
  ST_SOFT_FAULT = $0004;

  (*
   * Status flags (bit mask) of MACSpecStat.MssStatus
   *)
  ST_OK = $0007;
  ST_MAC_IS_BOUND = $0008;
  ST_MAC_IS_OPEN = $0010;
  ST_DIAGNOSTICS = $0020;   { version 2.0.1 }

  (*
   * Bit mask of MACSpecStat.MssFilter
   *)
  FM_DIRECTED = $0001;
  FM_BROADCAST = $0002;
  FM_PROMISCUOUS = $0004;
  FM_SRC_ROUTING = $0008;

  (*
   * MACSpecStat: unmantained value.
   *)
  NOT_MAINTAINED = -1;

  (*
   * Misc
   *)
  MIN_LOOKAHEAD_DEFAULT = 64;   { minimum lookahead }
  INDICATION_INIT = $ff;        { initializaton value for Indicate advice,
                                  argument of PldRcvLkAhead and PldRcvChain }

  (*
   * Data structures for TransmitChain (Tx), TransferData (TD), and
   * ReceiveLookahed (Rx).
   *)

type
  PTxDataBlock = ^TxDataBlock;
  TxDataBlock = record
    TxPtrType: uchar;     { 0 => Physical pointer, 1 => GDT pointer  }
    TxRsvdByte: uchar;    { Reserved, must be zero.     }
    TxDataLen: ushort;    { Data block length in bytes.  }
    TxDataPtr: LPBUF;     { Far pointer to data block.   }
  end;

  PTDDataBlock = ^TDDataBlock;
  TDDataBlock = record
    TDPtrType: uchar;     { 0 => Physical pointer, 1 => GDT pointer   }
    TDRsvdByte: uchar;    { Reserved, must be zero.     }
    TDDataLen: ushort;    { Data block length in bytes.  }
    TDDataPtr: LPBUF;     { Far pointer to data block.   }
  end;

const
  MAX_TX_DATABLK = 8;
  MAX_IMMED_LEN = 64;

type
  PTxBufDesc = ^TxBufDesc;
  TxBufDesc = record
    TxImmedLen: ushort;   { Byte count of immediate data (max = MAX_IMMED_LEN) }
    TxImmedPtr: LPBUF;    { Virtual address of Immediate data }
    TxDataCount: ushort;  { Number of Data Blocks (max = MAX_TX_DATABLK) }
    TxDataBlk: array[0..0] of TxDataBlock;  { dynamic, TxDataCount elems }
  end;

const
  MAX_TD_DATABLK = 8;

type
  PTDBufDesc = ^TDBufDesc;
  TDBufDesc = record
    TDDataCount: ushort;  { Number of Data Blocks (max = MAX_TD_DATABLK) }
    TDDataBlk: array[0..0] of TDDataBlock; { dynamic, TDDataCount elems }
  end;

  PRxDataBlock = ^RxDataBlock;
  RxDataBlock = record
    RxDataLen: ushort;    { Length of the Data Block  }
    RxDataPtr: LPBUF;     { Far Pointer to Data Block }
  end;

const
  MAX_RX_DATABLK = 8;

type
  PRxBufDesc = ^RxBufDesc;
  RxBufDesc = record
    RxDataCount: ushort;  { Number of Data Blocks (max = MAX_RX_DATABLK) }
    RxDataBlk: array[0..0] of RxDataBlock; { dynamic, RxDataCount elems }
  end;

  (*
   * Protocol Table structures
   *)

type

  (*
   * Forwards
   *)
  PCommChar = ^CommChar;
  PMACSpecChar = ^MACSpecChar;
  PMCastAddr = ^MCastAddr;
  PMCastBuf = ^MCastBuf;
  PMACSpecStat = ^MACSpecStat;
  PMAC8023Stat = ^MAC8023Stat;
  PMACUprDisp = ^MACUprDisp;
  PProtLwrDisp = ^ProtLwrDisp;

  (*
   * System Request Function
   *)
  SysReqFunc = function(
    ProtCCTab: PCommChar;
    var MacCCTab: PCommChar;
    Param3,
    Opcode,
    MacDs: ushort
  ): Integer;

  (*
   * common characteristics table
   *)
  CommChar = record
    CcSize: ushort;       { Table size ($38-$40)  }
    CcNdisMjr: uchar;     { NDIS major version }
    CcNdisMnr: uchar;     { NDIS minor version }
    CcRsv0: ushort;       { reserved  }
    CcModMjr: uchar;      { Module Major version number  }
    CcModMnr: uchar;      { Module Minor version number  }
    CcBindFnc: ulong;     { Binding support (UPPERBIND, etc.) }
    CcName: array[0..(NAME_LEN)-1] of Char;  { Module name  }
    CcUPLevel: uchar;     { Upper protocol level  }
    CcUIType: uchar;      { Upper interface type  }
    CcLPLevel: uchar;     { Lower protocol level  }
    CcLIType: uchar;      { Lower interface type  }
    CcModuleID: ushort;   { Module ID (supplied by PM)  }
    CcDataSeg: ushort;    { Module Data Segment  }
    CcSysReq: SysReqFunc; { System request function (ofs $24) }
    CcSCp: PMACSpecChar;  { specific characteristics  }
    CcSSp: PMACSpecStat;  { specific status }
    CcUDp: PMACUprDisp;   { upper dispatch table  }
    CcLDp: PProtLwrDisp;  { lower dispatch table (ofs $34) }
    CcRsv1: Pointer;      { reserved  }
    CcRsv2: Pointer;      { reserved  }
  end;

  (*
   * MAC Service Specific characteristics table
   *)
  MACSpecChar = record
    MscSize: ushort;        { Table size }
    MscType: array[0..(NAME_LEN)-1] of Char; { MAC type name }
    MscStnAdrSz: ushort;    { Station address length  }
    MscPermStnAdr: array[0..(ADDR_LEN)-1] of uchar; { Permanent station address  }
    MscCurrStnAdr: array[0..(ADDR_LEN)-1] of uchar; { Current station address  }
    MscCurrFncAdr: ulong;   { Current functional address  }
    MscMCp: PMCastBuf;      { Address of multicast buffer }
    MscLinkSpd: ulong;      { Link speed (bits/sec)     }
    MscService: ulong;      { Services supported flags  }
    MscMaxFrame: ushort;    { Maximum frame size  }
    MscTBufCap: ulong;      { Transmit buffer capacity }
    MscTBlkSz: ushort;      { Transmit buf alloc block size }
    MscRBufCap: ulong;      { Receive buffer capacity  }
    MscRBlkSz: ushort;      { Receive buf alloc block size  }
    MscVenCode: array[0..2] of uchar; { Vendor code           }
    MscVenAdapter: uchar;   { Vendor adapter code   }
    MscVenAdaptDesc: PChar; { Ptr to vendor adapter desc }
    MscInterrupt: ushort;   { Interrupt level used  }
    MscTxQDepth: ushort;    { Transmit Queue Depth  }
    MscMaxNumDataBlks: ushort;  { Maximum number of data blocks    }
  end;

  (*
   * multicast address structure is ADDR_LEN bytes ulong
   *)
  MCastAddr = record
    mAddr: array[0..(ADDR_LEN)-1] of uchar;
  end;

  (*
   * the multicast address buffer manages NUM_MCADDRS multicast address
   * structures.
   *)
  MCastBuf = record
    McbMax: ushort;    { max # of multicast addresses  }
    McbCnt: ushort;    { curr# of multicast addresses  }
    McbAddrs: array[0..(NUM_MCADDRS)-1] of MCastAddr;
  end;

  (*
   * MAC service-specific status table
   *)
  MACSpecStat = record
    MssSize: ushort;    { Table size                         }
    MssDiagDT: ulong;   { Last diagnostic Date/Time          }
    MssStatus: ulong;   { MAC status - bit mask              }
    MssFilter: ushort;  { Current packet filter              }
    MssM8Sp: PMAC8023Stat; { pointer to Media specific status   }
    MssClearDT: ulong;  { Last clear stats Date/Time         }
    MssFR: ulong;       { Frames received: total             }
    MssRFCRC: ulong;    { Receive fail: CRC error            }
    MssFRByt: ulong;    { Frames received: total bytes       }
    MssRFLack: ulong;   { Receive fail: lack of buffers      }
    MssFRMC: ulong;     { Frames received: multicast         }
    MssFRBC: ulong;     { Frames received: broadcast         }
    MssRFErr: ulong;    { rcv fail: errors in general        }
    MssRFMax: ulong;    { rcv fail: exceeds max size         }
    MssRFMin: ulong;    { rcv fail: less than min size       }
    MssFRMCByt: ulong;  { Frames rcvd: multicast bytes       }
    MssFRBCByt: ulong;  { Frames rcvd: broadcast bytes       }
    MssRFHW: ulong;     { rcv fail: hardware error           }
    MssFS: ulong;       { Frames sent: total                 }
    MssFSByt: ulong;    { Frames sent: total bytes           }
    MssFSMC: ulong;     { Frames sent: multicast             }
    MssFSBC: ulong;     { Frames sent: broadcast             }
    MssFSBCByt: ulong;  { Frames sent: broadcast bytes       }
    MssFSMCByt: ulong;  { Frames sent: multicast bytes       }
    MssSFTime: ulong;   { Send fail: time-out                }
    MssSFHW: ulong;     { Send fail: hardware error          }
  end;

  (*
   * 802.3 status table
   *)
  MAC8023Stat = record
    M83sSize: ushort;       { Table size                      }
    M83sVer: ushort;        { Version                         }
    M83sRFAln: ulong;       { Receive fail: Alignment error   }
    M83sRMask: ulong;       { Receive fail bit mask (M83Sb_R*) }
    M83sRFOvrn: ulong;      { Receive fail: Overrun           }
    M83sFSCols: ulong;      { Frames sent: after collisions   }
    M83sFSDfr: ulong;       { Frames sent: after deferring    }
    M83sSFColMx: ulong;     { Frames not sent: Max collisions }
    M83sTotCol: ulong;      { Total collision during tran attempts  }
    M83sTotLCol: ulong;     { Total late collisions           }
    M83sFSCol1: ulong;      { Frames sent: after 1 collision  }
    M83sFSColM: ulong;      { Frames sent: multpl collisions  }
    M83sFSHrtB: ulong;      { Frames sent: CD heart beat      }
    M83sJabber: ulong;      { Jabber errors                   }
    M83sLostCS: ulong;      { Lost carrier sense during tran  }
    M83sTMask: ulong;       { Transmit fail bit mask (M83Sb_T*) }
    M83snumunder: ulong;    { V3.00.10 Number of underruns    }
    M83sRingUtil: ushort;   { V3.00.10 Ring Utilization Measure  }
  end;

  (*
   * MAC upper dispatch table
   *)
  MACUprDisp = record
    MudCCp: PCommChar;   { Back pointer to CC table  }

    MudGenReq: function(
      ProtID,
      ReqHandle,
      Param1: ushort;
      Param2: Pointer;
      Opcode,
      MacDs: ushort
    ): ushort;

    MudXmitChain: function(
      ProtID,
      ReqHandle: ushort;
      const BufDesc: TxBufDesc;
      MacDs: ushort
    ): ushort;

    MudXferData: function(
      var BytesCopied: ushort;
      FrameOfs: ushort;
      const BufDesc: TDBufDesc;
      MacDs: ushort
    ): ushort;

    MudRcvRelease: function(
      ReqHandle,
      MacDs: ushort
    ): ushort;

    MudIndOn: function(MacDs: ushort): ushort;
    MudIndOff: function(MacDs: ushort): ushort;
  end;

  (*
   * protocol lower dispatch table
   *)
  ProtLwrDisp = record
    PldCCp: PCommChar;   { Back pointer to CC table  }
    PldIFF: ulong;       { Interface flags           }

    { Protocol stack entry points.  }

    PldReqConfirm: function(
      ProtID,
      MacId,
      ReqHandle,
      Request,    { Original request opcode }
      ProtDs: ushort
    ): ushort;

    PldXmitConfirm: function(
      ProtID,
      MacId,
      ReqHandle,
      Status,
      ProtDs: ushort
    ): ushort;

    PldRcvLkAhead: function(
      MacId,
      FrameSize,
      BytesAvail: ushort;
      const Buffer;
      var Indicate: Byte;
      ProtDs: ushort
    ): ushort;

    PldIndComplete: function(
      MacId,
      ProtDs: ushort
    ): ushort;

    PldRcvChain: function(
      MacId,
      FrameSize,
      ReqHandle: ushort;
      const BufDesc: RxBufDesc;
      var Indicate: Byte;
      ProtDs: ushort
    ): ushort;

    PldStatInd: function(
      MacId,
      Param: ushort;
      var Indicate: Byte;
      OpCode, { see Status Indication opcodes }
      ProtDs: ushort
    ): ushort;
  end;

  (*
   * Data structures for the "Module Configuration" structure parsed from
   * the PROTOCOL.INI file. see NDIS spec for details.
   *
   * Ndis.pas: note that we provide handy accessors (GetModule*()) for this stuff.
   * See below.
   *)

  PParam = ^Param;
  Param = record
    ParamType: ushort;  { 0 => 31 bit signed integer, 1 => string }
    ParamLen: ushort;   { String length (including null) or 4.    }
    (*
     * the parameter immediately follows this structure, it can be any
     * length or type and follows the union structure.
     *)
    ParamVal: record
      case Longint of
        0: (Num: Longint);
        1: (Str: array[0..0] of Char);
      end;
  end;

  PKeywordEntry = ^KeywordEntry;
  KeywordEntry = record
    NextKeywordEntry: PKeywordEntry;  { Forward pointer  }
    PrevKeywordEntry: PKeywordEntry;  { Back Pointer     }
    KeyWord: array[0..(NAME_LEN)-1] of Char; { Keyword on left side of "="    }
    NumParams: ushort;                { Number of parameters on r. side of "=" }
    Params: array[0..0] of Param;     { Actual size depends on NumParams }
  end;

  PModCfg = ^ModCfg;
  ModCfg = record
    NextModCfg: PModCfg;    { Module config images are in a }
    PrevModCfg: PModCfg;    { double-linked list. }
    ModName: array[0..(NAME_LEN)-1] of Char;  { Bracketed Module Name.   }
    { Head of Keyword list, always one or more entries per module.  }
    KE: array[0..0] of KeywordEntry;
  end;

  PProIni = ^ProIni;
  ProIni = record
    MC: array[0..0] of ModCfg;    { Head of Module config list. }
  end;


  (*
   * Protocol Manager
   *)

const
  { opcodes }
  PmGetInfo = 1;
  PmRegisterModule = 2;
  PmBindAndStart = 3;
  PmGetLinkage = 4;

  { version }
  PROTMAN_VERSION_MAJOR = 2;
  PROTMAN_VERSION_MINOR = 0;

type
  { Protocol Manager IOCTL request block }
  ProtmanReqBlk = record
    Opcode: ushort;
    Status: ushort;
    Pointer1: Pointer;
    Pointer2: Pointer;
    Word1: ushort;
  end;

(*
 * Gets the param with the specified name from the given module config.
 *)
function GetModuleParam(Cfg: PModCfg; Name: PChar): PParam;

(*
 * Gets the value of the param with the specified name from the given module config.
 *)
function GetModuleParamStr(Cfg: PModCfg; Name: PChar; Default: PChar): PChar;

(*
 * Gets the value of the param with the specified name from the given module config.
 *)
function GetModuleParamLong(Cfg: PModCfg; Name: PChar; Default: ulong): ulong;

(*
 * Finds the section of the driver with the specified DriverName.
 *
 * Cfg must be the root of all configurations as returned by ProtmanGetInfo.
 *)
function FindModuleConfig(Cfg: PModCfg; DriverName: PChar): PModCfg;

(*
 * Gets all module configurations from PROTMAN.
 *
 * Handle must be a DOS file handle of the PROTMAN$ device.
 *)
function ProtmanGetInfo(Handle: Word): PModCfg;

(*
 * Registers the specified driver characteristics with PROTMAN using the
 * given DOS file handle of the PROTMAN$ device.
 *)
function ProtmanRegisterModule(Handle: Word; const Characteristics: CommChar): Boolean;

implementation

uses
  Bits, Strings, DosLib;

(*
 *
 *)
function GetModuleParam(Cfg: PModCfg; Name: PChar): PParam;
var
  Kw: PKeywordEntry;
begin
  Kw := @Cfg^.KE[0];
  while Kw <> nil do
  begin
    if StrIComp(Kw^.Keyword, Name) = 0 then
    begin
      GetModuleParam := @Kw^.Params[0];
      exit;
    end;
    Kw := Kw^.NextKeywordEntry;
  end;
  GetModuleParam := nil;
end;

(*
 *
 *)
function GetModuleParamStr(Cfg: PModCfg; Name: PChar; Default: PChar): PChar;
var
  Param: PParam;
begin
  Param := GetModuleParam(Cfg, Name);
  if (Param <> nil) and (Param^.ParamType = 1) then
    GetModuleParamStr := Param^.ParamVal.Str
  else
    GetModuleParamStr := Default;
end;

(*
 *
 *)
function GetModuleParamLong(Cfg: PModCfg; Name: PChar; Default: ulong): ulong;
var
  Param: PParam;
begin
  Param := GetModuleParam(Cfg, Name);
  if (Param <> nil) and (Param^.ParamType = 0) then
    GetModuleParamLong := Param^.ParamVal.Num
  else
    GetModuleParamLong := Default;
end;

(*
 *
 *)
function FindModuleConfig(Cfg: PModCfg; DriverName: PChar): PModCfg;
var
  S: PChar;
begin
  while Cfg <> nil do
  begin
    S := GetModuleParamStr(Cfg, 'DRIVERNAME', nil);
    if (S <> nil) and (StrIComp(S, DriverName) = 0) then
      break;
    Cfg := Cfg^.NextModCfg;
  end;
  FindModuleConfig := Cfg;
end;

(*
 *
 *)
function ProtmanGetInfo(Handle: Word): PModCfg;
var
  Req: ProtmanReqBlk;
begin
  ProtmanGetInfo := nil;
  ZeroMem(Req, SizeOf(Req));
  Req.Opcode := PmGetInfo;
  if (DosIoctlRead(Handle, Req, SizeOf(Req)) = 0) or
     (Req.Status <> 0) then exit;
  ProtmanGetInfo := Req.Pointer1;
end;

(*
 *
 *)
function ProtmanRegisterModule(Handle: Word; const Characteristics: CommChar): Boolean;
var
  Req: ProtmanReqBlk;
begin
  ZeroMem(Req, SizeOf(Req));
  Req.Opcode := PmRegisterModule;
  Req.Pointer1 := @Characteristics;
  ProtmanRegisterModule :=
    (DosIoctlRead(Handle, Req, SizeOf(Req)) > 0) and (Req.Status = 0);
end;

end.
