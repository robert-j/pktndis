(*
 * SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 2026 https://github.com/robert-j
 *
 * Tiny Heap Manager for constrained environments
 *
 * Fixed-size pool allocator with a constant block size of 1514, the size of
 * an ethernet frame.
 *
 * The heap is divided into equal-sized blocks at init time. Alloc and Free
 * are O(1) via a free-block stack. Each block carries a 2-byte size header
 * so that TinySize returns the requested size, not the block size.
 *
 * All returned 32 bit pointers share a common segment => The 16 bit offset
 * is sufficient to identify or obtain a full pointer from it:
 * Ptr(TinySeg, Offset)
 *
 * The NDIS driver takes advantage of this.
 *
 * GitHub: the original implementation is in assembler, well field-tested,
 * based on Borland RTL source code that cannot be released under an
 * OSS license.
 *)

unit TinyHeap;

interface

{ Initializes the heap manager.
  Buf must be paragraph-aligned (see Bits.AlignPtr). }
procedure InitTinyHeap(Buf: Pointer; Size: Word);

{ Returns nil if no memory available. }
function TinyAlloc(Size: Word): Pointer;

{ Returns the size of the heap block P is pointing to. }
function TinySize(P: Pointer): Word;

{ Frees a memory block }
procedure TinyFree(P: Pointer);

{ Returns the one and only segment of the heap manager. }
function TinySeg: Word;

{ Like System.MaxAvail }
function TinyAvail: Word;

implementation

uses
  Bits;

(*
 * Pool layout:
 *
 *   The heap is divided into fixed-size slots. Each slot is
 *   SizeOf(Word) + BlockSize bytes, accessed via PSlot:
 *
 *     [Size: Word] [payload: BlockSize bytes]
 *
 *   Allocated: Size = requested size. Returned pointer = @Slot^.FreeOfs.
 *   Free:      FreeOfs = offset of next free slot (or EndOfList).
 *              Size is unused.
 *
 *   FreeHead is the offset of the first free slot, forming a
 *   singly-linked stack for O(1) alloc/free.
 *)

type
  PSlot = ^TSlot;
  TSlot = record
    Size: Word;
    FreeOfs: Word;
  end;

const
  BlockSize = 1514;
  EndOfList = $FFFF;

var
  HeapSeg:   Word;
  FreeHead:  Word;      { offset of first free slot, EndOfList = none }
  SlotSize:  Word;      { SizeOf(Word) + BlockSize }
  FreeCount: Word;      { number of free slots }

(*
 *
 *)
procedure InitTinyHeap(Buf: Pointer; Size: Word);
var
  Ofs, Next: Word;
  Count: Word;
  I: Integer;
begin
  HeapSeg := PtrRec(Buf).Seg;
  SlotSize := SizeOf(Word) + BlockSize;
  Count := Size div SlotSize;
  FreeCount := Count;

  if Count = 0 then
  begin
    FreeHead := EndOfList;
    exit;
  end;

  { build free list: chain all slots together }
  Ofs := PtrRec(Buf).Ofs;
  FreeHead := Ofs;

  for I := 0 to Count - 2 do
  begin
    Next := Ofs + SlotSize;
    PSlot(Ptr(HeapSeg, Ofs))^.FreeOfs := Next;
    Ofs := Next;
  end;

  { last slot terminates the list }
  PSlot(Ptr(HeapSeg, Ofs))^.FreeOfs := EndOfList;
end;

(*
 * O(1) pool allocation.
 *)
function TinyAlloc(Size: Word): Pointer;
var
  Slot: PSlot;
begin
  TinyAlloc := nil;

  if FreeHead = EndOfList then exit;
  if Size > BlockSize then exit;

  Slot := Ptr(HeapSeg, FreeHead);

  { pop from free stack }
  FreeHead := Slot^.FreeOfs;
  Dec(FreeCount);

  { store requested size in header, return pointer to payload }
  Slot^.Size := Size;
  TinyAlloc := @Slot^.FreeOfs;
end;

(*
 *
 *)
function TinySize(P: Pointer): Word;
var
  Slot: PSlot absolute P;
begin
  TinySize := 0;
  if P = nil then exit;
  Dec(PWord(Slot));
  TinySize := Slot^.Size;
end;

(*
 * O(1) pool free.
 *)
procedure TinyFree(P: Pointer);
var
  Slot: PSlot absolute P;
begin
  if P = nil then exit;

  Dec(PWord(Slot));

  { double-free guard: size is 0 if already freed }
  if Slot^.Size = 0 then exit;
  Slot^.Size := 0;

  { push onto free stack }
  Slot^.FreeOfs := FreeHead;
  FreeHead := PtrRec(Slot).Ofs;
  Inc(FreeCount);
end;

(*
 *
 *)
function TinySeg: Word; assembler;
asm
  mov   ax, HeapSeg
end;

(*
 *
 *)
function TinyAvail: Word;
begin
  TinyAvail := FreeCount * SlotSize;
end;

end.
