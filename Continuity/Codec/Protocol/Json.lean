import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Scanner

set_option autoImplicit false

namespace Continuity.Codec.Protocol.Json

open Continuity.Codec.Core.Box

inductive Value where
  | null
  | bool (b : Bool)
  | number (n : Int)
  | str (s : String)
  | array (elems : List Value)
  | object (fields : List (String × Value))
  deriving Repr

def Value.isNull : Value → Bool | .null => true | _ => false
def Value.asBool : Value → Option Bool | .bool b => some b | _ => none
def Value.asString : Value → Option String | .str s => some s | _ => none
def Value.asArray : Value → Option (List Value) | .array a => some a | _ => none
def Value.asObject : Value → Option (List (String × Value)) | .object o => some o | _ => none

def Value.field (v : Value) (name : String) : Option Value :=
  match v with
  | .object fields => fields.find? (fun (k, _) => k == name) |>.map Prod.snd
  | _ => none

def isWhitespace (c : UInt8) : Bool := c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D
def isDigit (c : UInt8) : Bool := c >= 0x30 && c <= 0x39

-- Parse JSON using position-based scanning (partial for mutual recursion)
partial def parseValue (bs : Bytes) (pos : Nat) : Option (Value × Nat) :=
  let pos := skipWS bs pos
  if h : pos < bs.size then
    let c := bs[pos]
    if c == 0x6E then guard (pos + 4 ≤ bs.size) *> some (.null, pos + 4)
    else if c == 0x74 then guard (pos + 4 ≤ bs.size) *> some (.bool true, pos + 4)
    else if c == 0x66 then guard (pos + 5 ≤ bs.size) *> some (.bool false, pos + 5)
    else if c == 0x22 then parseStr bs (pos + 1) |>.map fun (s, e) => (.str s, e)
    else if c == 0x5B then parseArr bs (pos + 1)   |>.map fun (a, e) => (.array a, e)
    else if c == 0x7B then parseObj bs (pos + 1)   |>.map fun (o, e) => (.object o, e)
    else if c == 0x2D || isDigit c then parseNum bs pos
    else none
  else none
where
  skipWS (bs : Bytes) (p : Nat) : Nat :=
    if h : p < bs.size then (if isWhitespace bs[p] then skipWS bs (p + 1) else p) else p
  parseStr (bs : Bytes) (p : Nat) : Option (String × Nat) :=
    if h : p < bs.size then
      if bs[p] == 0x22 then some (String.fromUTF8? (bs.extract (p - (p - p)) p) |>.getD "", p + 1)
      else if bs[p] == 0x5C then parseStr bs (p + 2)
      else parseStr bs (p + 1)
    else none
  parseNum (bs : Bytes) (start : Nat) : Option (Value × Nat) :=
    let rec scan (p : Nat) : Nat :=
      if h : p < bs.size then
        let c := bs[p]
        if isDigit c || c == 0x2D || c == 0x2B || c == 0x2E || c == 0x65 || c == 0x45
        then scan (p + 1) else p
      else p
    let e := scan start
    if e > start then some (.number ((String.fromUTF8? (bs.extract start e) |>.getD "").toInt?.getD 0), e)
    else none
  parseArr (bs : Bytes) (p : Nat) : Option (List Value × Nat) :=
    let p := skipWS bs p
    if h : p < bs.size then
      if bs[p] == 0x5D then some ([], p + 1)
      else match parseValue bs p with
        | none => none
        | some (v, p) =>
          let p := skipWS bs p
          if h2 : p < bs.size then
            if bs[p] == 0x2C then parseArr bs (p + 1) |>.map fun (vs, e) => (v :: vs, e)
            else if bs[p] == 0x5D then some ([v], p + 1)
            else none
          else none
    else none
  parseObj (bs : Bytes) (p : Nat) : Option (List (String × Value) × Nat) :=
    let p := skipWS bs p
    if h : p < bs.size then
      if bs[p] == 0x7D then some ([], p + 1)
      else if bs[p] == 0x22 then
        match parseStr bs (p + 1) with
        | none => none
        | some (key, p) =>
          let p := skipWS bs p
          if h2 : p < bs.size then
            if bs[p] == 0x3A then
              match parseValue bs (p + 1) with
              | none => none
              | some (v, p) =>
                let p := skipWS bs p
                if h3 : p < bs.size then
                  if bs[p] == 0x2C then parseObj bs (p + 1) |>.map fun (fs, e) => ((key, v) :: fs, e)
                  else if bs[p] == 0x7D then some ([(key, v)], p + 1)
                  else none
                else none
            else none
          else none
      else none
    else none

def parse (bs : Bytes) : Option Value := parseValue bs 0 |>.map Prod.fst

end Continuity.Codec.Protocol.Json
