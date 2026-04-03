(*
 * SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 2020-2026 https://github.com/robert-j
 *
 * Static, 4 elements, tiny queue implementation for constrained environments.
 *)

unit TinyQue;

interface

const
  QueueSize = 4;  { must be a power of two }

type
  TTinyQueue = object
  private
    FElems: array[0..QueueSize - 1] of Word;
    FHead:  Word;
    FCount: Word;
  public
    procedure Init;
    { Returns false when queue full }
    function Enqueue(Elem: Word): Boolean;
    { Undefined when IsEmpty = true }
    function Deqeue: Word;
    { Whether the queue is empty }
    function IsEmpty: Boolean;
  end;

implementation

procedure TTinyQueue.Init;
begin
  FHead := 0;
  FCount := 0;
end;

function TTinyQueue.Enqueue(Elem: Word): Boolean;
begin
  if FCount >= QueueSize then
  begin
    Enqueue := false;
    exit;
  end;
  FElems[(FHead + FCount) and (QueueSize - 1)] := Elem;
  Inc(FCount);
  Enqueue := true;
end;

function TTinyQueue.Deqeue: Word;
begin
  Deqeue := FElems[FHead];
  Dec(FCount);
  FHead := (FHead + 1) and (QueueSize - 1);
end;

function TTinyQueue.IsEmpty: Boolean;
begin
  IsEmpty := FCount = 0;
end;

end.
