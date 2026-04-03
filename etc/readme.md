# PKTNDIS

An NDIS 2.0 MAC driver for DOS that bridges a Packet Driver interface
to NDIS. This allows NDIS-based protocol stacks (such as Microsoft LAN
Manager, Windows for Workgroups, or MS TCP/IP) to operate over emulators
and environments that only provide a Packet Driver interface — most
notably `dosemu2`.

## Installation

Copy `pktndis.dos` and `oemsetup.inf` to a directory accessible from
DOS. In the LAN Manager or WfW Setup program, select "Unlisted or
Updated Network Adapter" and point it to that directory.

## Configuration

`PKTNDIS` supports the following `PROTOCOL.INI` parameters:

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

## License

[MIT](../LICENSE)
