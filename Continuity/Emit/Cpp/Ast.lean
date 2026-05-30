/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                  // continuity // emit // cpp
                                                                      ast.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  C++ AST — abstract syntax for the C++23 subset we emit.

  Four distinct syntactic categories (unlike Dhall's one, like Haskell's four):
    CType — types, including const, pointer, reference, template
    CExpr — expressions
    CStmt — statements (expressions have no semicolons; statements do)
    CDecl — top-level declarations: includes, structs, functions, namespaces

  These assemble into CFile, which is a complete .hpp or .cpp file.

  We model the subset of C++ that appears in codec codegen: structs with
  fields, pack/unpack functions using memcpy and span, size checks, offset
  arithmetic. Not a general-purpose C++ AST — no classes, no inheritance,
  no exceptions, no templates beyond std containers.
-/

namespace Continuity.Emit.Cpp


/- ════════════════════════════════════════════════════════════════════════════════
                                                             // binary operators
   ════════════════════════════════════════════════════════════════════════════════ -/

inductive BinOp where
  -- arithmetic
  | add | sub | mul | div | mod
  -- comparison
  | eq | ne | lt | le | gt | ge
  -- bitwise
  | bitAnd | bitOr | bitXor | shl | shr
  -- logical
  | and | or
  deriving Repr, DecidableEq, Inhabited

inductive UnOp where
  | neg        -- `-x`
  | logNot     -- `!x`
  | bitNot     -- `~x`
  | addrOf     -- `&x`
  | deref      -- `*x`
  | preInc     -- `++x`
  | preDec     -- `--x`
  deriving Repr, DecidableEq, Inhabited


/- ════════════════════════════════════════════════════════════════════════════════
                                                                       // types
   ════════════════════════════════════════════════════════════════════════════════ -/

inductive CType where
  /-- `void` -/
  | void
  /-- `bool` -/
  | bool
  /-- fixed-width integer: `uint8_t`, `int32_t`, etc.
      unsigned × bit width -/
  | intType (unsigned : Bool) (bits : Nat)
  /-- `float` or `double` -/
  | floatType (bits : Nat)
  /-- `size_t` -/
  | sizeT
  /-- named type: `NixString`, `ParseResult` -/
  | named (name : String)
  /-- qualified name: `std::uint8_t`, `continuity::NixString` -/
  | qualified (ns : String) (name : String)
  /-- pointer: `uint8_t*` -/
  | ptr (inner : CType)
  /-- reference: `NixString&` -/
  | ref (inner : CType)
  /-- const qualifier: `const uint8_t` -/
  | const (inner : CType)
  /-- fixed-size array: `std::array<uint8_t, 32>` -/
  | array (elem : CType) (size : Nat)
  /-- template instantiation: `std::span<const uint8_t>`, `std::vector<uint8_t>`,
      `std::optional<T>` -/
  | template (name : String) (args : List CType)
  /-- `auto` -/
  | auto
  deriving Repr, Inhabited


/- ════════════════════════════════════════════════════════════════════════════════
                                                                 // expressions
   ════════════════════════════════════════════════════════════════════════════════ -/

inductive CExpr where
  /-- integer literal: `42`, `0xFF`, `0b1010` -/
  | litInt (value : Int)
  /-- unsigned literal with suffix: `42u`, `0xFFull` -/
  | litUInt (value : Nat) (suffix : String)
  /-- string literal: `"hello"` -/
  | litStr (value : String)
  /-- bool literal: `true`, `false` -/
  | litBool (value : Bool)
  /-- initializer list: `{1, 2, 3}` -/
  | initList (elems : List CExpr)

  /-- variable reference: `buf`, `offset` -/
  | var (name : String)
  /-- qualified reference: `std::nullopt` -/
  | qual (ns : String) (name : String)
  /-- field access: `s.magic` -/
  | field (expr : CExpr) (name : String)
  /-- arrow access: `p->magic` -/
  | arrow (expr : CExpr) (name : String)
  /-- array index: `buf[i]` -/
  | index (expr : CExpr) (idx : CExpr)

  /-- function call: `memcpy(dst, src, 8)` -/
  | call (fn : String) (args : List CExpr)
  /-- method call: `buf.size()`, `out.push_back(x)` -/
  | methodCall (expr : CExpr) (method : String) (args : List CExpr)

  /-- binary operator: `x + y` -/
  | binop (op : BinOp) (lhs : CExpr) (rhs : CExpr)
  /-- unary operator: `!x`, `&s.magic` -/
  | unop (op : UnOp) (operand : CExpr)

  /-- `static_cast<T>(x)` or `reinterpret_cast<T>(x)` -/
  | cast (kind : String) (ty : CType) (expr : CExpr)
  /-- c-style cast: `(uint8_t)x` — discouraged but sometimes needed -/
  | cCast (ty : CType) (expr : CExpr)

  /-- ternary: `cond ? thenExpr : elseExpr` -/
  | ternary (cond : CExpr) (thenE : CExpr) (elseE : CExpr)
  /-- sizeof: `sizeof(T)` or `sizeof(expr)` -/
  | sizeofType (ty : CType)
  | sizeofExpr (expr : CExpr)
  /-- parenthesized: `(x + y)` -/
  | parens (inner : CExpr)

  deriving Repr, Inhabited


/- ════════════════════════════════════════════════════════════════════════════════
                                                                  // statements
   ════════════════════════════════════════════════════════════════════════════════ -/

inductive CStmt where
  /-- expression statement: `f();` -/
  | expr (e : CExpr)
  /-- variable declaration: `uint8_t x = 0;` or `auto x = f();` -/
  | decl (ty : CType) (name : String) (init : Option CExpr)
  /-- assignment: `x = y;` -/
  | assign (lhs : CExpr) (rhs : CExpr)
  /-- compound assignment: `x += y;`, `x |= z;` -/
  | assignOp (op : BinOp) (lhs : CExpr) (rhs : CExpr)
  /-- return with value: `return x;` -/
  | ret (value : CExpr)
  /-- return void: `return;` -/
  | retVoid
  /-- if / else if / else chain -/
  | ifElse (cond : CExpr) (thenBody : List CStmt)
           (elseBody : Option (List CStmt))
  /-- for loop: `for (init; cond; step) { body }` -/
  | for_ (init : CStmt) (cond : CExpr) (step : CExpr) (body : List CStmt)
  /-- range for: `for (auto& x : xs) { body }` -/
  | rangeFor (ty : CType) (name : String) (range : CExpr) (body : List CStmt)
  /-- while: `while (cond) { body }` -/
  | while_ (cond : CExpr) (body : List CStmt)
  /-- block: `{ stmts }` — bare compound statement -/
  | block (stmts : List CStmt)
  /-- break / continue -/
  | break | continue
  /-- `// comment` -/
  | comment (text : String)
  /-- blank line -/
  | blank
  deriving Repr, Inhabited


/- ════════════════════════════════════════════════════════════════════════════════
                                                                // declarations
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- struct field -/
structure CField where
  ty : CType
  name : String
  deriving Repr, Inhabited

/-- function parameter -/
structure CParam where
  ty : CType
  name : String
  deriving Repr, Inhabited

inductive CDecl where
  /-- `#pragma once` -/
  | pragmaOnce
  /-- `#include <cstdint>` -/
  | includeSystem (header : String)
  /-- `#include "foo.hpp"` -/
  | includeLocal (header : String)
  /-- forward declaration: `struct NixString;` -/
  | forwardDecl (name : String)

  /-- struct definition with fields -/
  | struct_ (name : String) (fields : List CField)
  /-- enum class: `enum class Arch : uint8_t { x86_64, aarch64 };` -/
  | enumClass (name : String) (underlying : Option CType)
              (values : List (String × Option CExpr))

  /-- function definition -/
  | func (retType : CType) (name : String)
         (params : List CParam) (body : List CStmt)
  /-- function with attributes: `[[nodiscard]] inline bool parse(...)` -/
  | funcAttr (attrs : List String) (retType : CType) (name : String)
             (params : List CParam) (body : List CStmt)

  /-- namespace block: `namespace foo { ... }` -/
  | namespace_ (name : String) (decls : List CDecl)
  /-- anonymous namespace: `namespace { ... }` -/
  | anonNamespace (decls : List CDecl)

  /-- using declaration: `using byte = uint8_t;` -/
  | using_ (alias : String) (ty : CType)
  /-- static_assert: `static_assert(sizeof(Foo) == 16);` -/
  | staticAssert (cond : CExpr) (msg : Option String)

  /-- `// comment` -/
  | comment (text : String)
  /-- blank line -/
  | blank
  /-- raw text — escape hatch. use sparingly -/
  | raw (text : String)
  deriving Repr, Inhabited


/- ════════════════════════════════════════════════════════════════════════════════
                                                                       // file
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- A complete C++ header or source file -/
structure CFile where
  /-- file-level header comment -/
  header : Option String := Option.none
  /-- include guard is always `#pragma once` for headers -/
  pragmaOnce : Bool := true
  /-- all declarations in order -/
  decls : List CDecl
  deriving Repr, Inhabited


/- ════════════════════════════════════════════════════════════════════════════════
                                                                 // combinators
   ════════════════════════════════════════════════════════════════════════════════ -/

-- ── type shortcuts ────────────────────────────────────────────────────────────

namespace CType

def u8    : CType := CType.intType true 8
def u16   : CType := CType.intType true 16
def u32   : CType := CType.intType true 32
def u64   : CType := CType.intType true 64
def i8    : CType := CType.intType false 8
def i16   : CType := CType.intType false 16
def i32   : CType := CType.intType false 32
def i64   : CType := CType.intType false 64

def constPtr (inner : CType) : CType := CType.ptr (CType.const inner)
def constRef (inner : CType) : CType := CType.ref (CType.const inner)

/-- `std::span<const uint8_t>` — the canonical input buffer type -/
def constByteSpan : CType :=
  CType.template "std::span" [CType.const CType.u8]

/-- `std::vector<uint8_t>` — the canonical output buffer type -/
def byteVec : CType :=
  CType.template "std::vector" [CType.u8]

/-- `std::optional<T>` -/
def optional (inner : CType) : CType :=
  CType.template "std::optional" [inner]

end CType

-- ── expression shortcuts ──────────────────────────────────────────────────────

namespace CExpr

/-- `memcpy(dst, src, n)` — the operation we emit most -/
def memcpy (dst : CExpr) (src : CExpr) (n : Nat) : CExpr :=
  CExpr.call "memcpy" [dst, src, CExpr.litInt n]

/-- `buf + offset` — pointer/span arithmetic -/
def addOffset (buf : String) (offset : Nat) : CExpr :=
  if offset == 0 then CExpr.var buf
  else CExpr.binop BinOp.add (CExpr.var buf) (CExpr.litInt offset)

/-- `&s.fieldName` — address of a struct field -/
def addrOfField (structVar : String) (fieldName : String) : CExpr :=
  CExpr.unop UnOp.addrOf (CExpr.field (CExpr.var structVar) fieldName)

end CExpr

-- ── statement shortcuts ───────────────────────────────────────────────────────

namespace CStmt

/-- `memcpy(dst, src, n);` as a statement -/
def memcpy (dst : CExpr) (src : CExpr) (n : Nat) : CStmt :=
  CStmt.expr (CExpr.memcpy dst src n)

/-- `if (cond) return val;` — early return guard -/
def guard (cond : CExpr) (retVal : CExpr) : CStmt :=
  CStmt.ifElse cond [CStmt.ret retVal] Option.none

/-- `if (len < minSize) return std::nullopt;` — the size check pattern -/
def sizeCheck (lenExpr : CExpr) (minSize : Nat) : CStmt :=
  CStmt.guard
    (CExpr.binop BinOp.lt lenExpr (CExpr.litInt minSize))
    (CExpr.qual "std" "nullopt")

end CStmt


end Continuity.Emit.Cpp
