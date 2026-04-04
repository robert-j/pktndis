# PKTNDIS

An NDIS 2.0 MAC driver for DOS that bridges a Packet Driver interface
to NDIS. This allows NDIS-based protocol stacks (such as Microsoft LAN
Manager, Windows for Workgroups, or MS TCP/IP) to operate over emulators
and environments that only provide a Packet Driver interface — most
notably `dosemu2`.

This is a retro-computing project. The code is written and built entirely
in DOS using period-correct tools — Borland Pascal 7, Borland MAKE, and
a real-mode debugger. The only concession to modernity is a
[comfortable editor](https://github.com/robert-j/retropas).

## Download

Pre-built binaries are available on the
[Releases](../../releases) page. No build tools are required to use them.

## Installation

Copy `pktndis.dos` and `oemsetup.inf` from the release archive to a
directory accessible from DOS. In the LAN Manager or WfW Setup program,
select "Unlisted or Updated Network Adapter" and point it to that
directory.

### PROTOCOL.INI Parameters

```ini
; section name may differ in your installation
[pktndis]
DriverName=PKTNDIS$     ; mandatory, must be PKTNDIS$
interrupt=0             ; auto-detect Packet Driver interrupt (default)
interrupt=0x61          ; use a specific interrupt number
hide=1                  ; hide the Packet Driver interface (default)
hide=0                  ; don't hide the Packet Driver interface
```

The `hide` option makes the underlying Packet Driver invisible, forcing
dual-stack software to use the NDIS interface.

## Building from Source

Source code is provided for reference. The release binaries are built
from a larger codebase that provides an optimized runtime, a more
efficient buffer allocator, and a smaller memory footprint. That
codebase cannot be open-sourced due to Borland's RTL license terms, so
official binaries are available on the Releases page.

### Requirements

- Borland Pascal 7.01 (untested with earlier versions)

### Build

Edit `src/makefile` and set `BPROOT` to your Borland Pascal installation
directory. Then:

```shell
cd src
make
```

The output (`pktndis.exe`) is placed in `src/build/`. Rename it to
`pktndis.dos` for use as an NDIS driver.

### Distribution build

```shell
cd src
make dist
```

Performs a build and places the driver and all necessary files, like
end-user [documentation](etc/readme.md), in `src/dist`.

## Project Structure

```text
src/
  pktndis.pas   Main program and DOS driver entry point
  driver.pas    NDIS MAC driver implementation
  ndis.pas      NDIS 2.0 interface (Pascal translation of IBM DDK headers)
  pktdrv.pas    Packet Driver interface
  tinyheap.pas  Fixed-size pool allocator for network buffers
  tinyque.pas   Static queue for interrupt-context packet handling
  utils.pas     Minimal console/debug I/O routines
  bits.pas      Low-level types and memory primitives
  doslib.pas    DOS system call interface
  makefile      Borland MAKE makefile
  bpc.cfg       Compiler configuration
etc/
  oemsetup.inf  NDIS driver installation file
bin/
  xdate.exe     Build tool: timestamp generator (DOS binary)
```

## How It Works

PKTNDIS locates an existing Packet Driver on a software interrupt,
registers itself as an NDIS MAC driver, and translates between the two
interfaces:

- **Receive path, sync**: Packet Driver receive upcalls are queued and
  delivered to NDIS protocol drivers via `ReceiveLookahead` and
  `TransferData`.
- **Receive path, async**: Packet Driver receive upcalls are delivered
  via `ReceiveChain`.
- **Transmit path**: NDIS `TransmitChain` calls are forwarded to the
  Packet Driver's `SendPkt`.

The driver operates entirely in real mode. The release binaries require
a 386 or above. The reference source can be built for 8086.

## See Also

[DIS_PKT](https://github.com/robert-j/dispkt) — the reverse: an NDIS
to Packet Driver shim for DOS.

## License

[MIT](LICENSE)
