import Continuity.Codegen.Dialect.Cpp

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      cpp!{} — C++ quasiquoter with interpolation.

      Write C++ in situ:        [cpp| [[nodiscard]] uint64_t f(uint64_t x) { ... } ]

      Interpolate Lean values:  [cpp| [[nodiscard]] uint64_t f(uint64_t x) {
                                  if (x < $$(minSize)) return 0;
                                }]

      Pattern: lean-mlir's `[LV| ... ]` and `[mlir_type| ... ]` quasiquoters.

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.Dialect.Cpp

open Lean

--- ══════════════════════════════════════════════════════════════════════════════
--- Syntax categories
--- ══════════════════════════════════════════════════════════════════════════════

declare_syntax_cat cpp_type

syntax "$$(" term ")" : cpp_type
syntax "uint8_t" : cpp_type
syntax "uint16_t" : cpp_type
syntax "uint32_t" : cpp_type
syntax "uint64_t" : cpp_type
syntax "auto" : cpp_type
syntax "bool" : cpp_type
syntax "void" : cpp_type
syntax "const" cpp_type : cpp_type

syntax ident "::" ident "<" cpp_type ">" : cpp_type
syntax ident "::" ident : cpp_type
syntax ident "<" cpp_type ">" : cpp_type
syntax ident : cpp_type

declare_syntax_cat cpp_expr

syntax "$$(" term ")" : cpp_expr
syntax num : cpp_expr
syntax ident : cpp_expr
syntax cpp_expr "." ident : cpp_expr
syntax cpp_expr "." ident "(" sepBy(cpp_expr, ",") ")" : cpp_expr
syntax cpp_expr "." "index" cpp_expr : cpp_expr
syntax "static_cast" "<" cpp_type ">" "(" cpp_expr ")" : cpp_expr
syntax "(" cpp_expr ")" : cpp_expr
syntax cpp_expr "|" cpp_expr : cpp_expr
syntax cpp_expr "<<" cpp_expr : cpp_expr
syntax cpp_expr "<" cpp_expr : cpp_expr
syntax cpp_expr "==" cpp_expr : cpp_expr
syntax cpp_expr "!=" cpp_expr : cpp_expr
syntax cpp_expr "+" cpp_expr : cpp_expr
syntax cpp_expr "&&" cpp_expr : cpp_expr
syntax cpp_expr ">" cpp_expr : cpp_expr
syntax ident "(" sepBy(cpp_expr, ",") ")" : cpp_expr

declare_syntax_cat cpp_stmt

syntax "$$(" term ")" : cpp_stmt
syntax "return" cpp_expr ";" : cpp_stmt
syntax "return" ";" : cpp_stmt
syntax "if" "(" cpp_expr ")" cpp_stmt : cpp_stmt
syntax "if" "(" cpp_expr ")" cpp_stmt "else" cpp_stmt : cpp_stmt
syntax cpp_type ident "=" cpp_expr ";" : cpp_stmt
syntax cpp_expr ";" : cpp_stmt
syntax "{" (cpp_stmt)* "}" : cpp_stmt

declare_syntax_cat cpp_param
declare_syntax_cat cpp_func

syntax cpp_type ident : cpp_param

syntax "[[" ident,* "]]" cpp_type ident "(" (cpp_param)* ")" "{" (cpp_stmt)* "}" : cpp_func

--- ══════════════════════════════════════════════════════════════════════════════
--- Term wrappers (like lean-mlir's [mlir_type| ... ])
--- ══════════════════════════════════════════════════════════════════════════════

syntax "[cpp_type|" cpp_type "]" : term
syntax "[cpp_expr|" cpp_expr "]" : term
syntax "[cpp_stmt|" cpp_stmt "]" : term

--- ══════════════════════════════════════════════════════════════════════════════
--- macro_rules: expand cpp_type to CType terms
--- ══════════════════════════════════════════════════════════════════════════════

macro_rules
  | `([cpp_type| $$($t:term) ]) => return t
  | `([cpp_type| uint8_t])   => `(CType.u8)
  | `([cpp_type| uint16_t])  => `(CType.u16)
  | `([cpp_type| uint32_t])  => `(CType.u32)
  | `([cpp_type| uint64_t])  => `(CType.u64)
  | `([cpp_type| auto])      => `(CType.auto)
  | `([cpp_type| bool])      => `(CType.bool)
  | `([cpp_type| void])      => `(CType.void)

  | `([cpp_type| const $t]) => do
      let inner : Term ← `([cpp_type| $t])
      `(CType.const $inner)

  | `([cpp_type| $ns:ident :: $n:ident < $t:cpp_type >]) => do
      let tn : Term ← `([cpp_type| $t])
      let nm := ns.getId.toString ++ "::" ++ n.getId.toString
      `(CType.template $(quote nm) [$tn])

  | `([cpp_type| $ns:ident :: $n:ident]) =>
      let nm := ns.getId.toString ++ "::" ++ n.getId.toString
      `(CType.named $(quote nm))

  | `([cpp_type| $n:ident < $t:cpp_type >]) => do
      let tn : Term ← `([cpp_type| $t])
      let nm := n.getId.toString
      `(CType.template $(quote nm) [$tn])

  | `([cpp_type| $x:ident]) =>
      let nm := x.getId.toString
      `(CType.named $(quote nm))

--- ══════════════════════════════════════════════════════════════════════════════
--- macro_rules: expand cpp_expr to CExpr terms
--- ══════════════════════════════════════════════════════════════════════════════

macro_rules
  | `([cpp_expr| $$($t:term) ]) => return t
  | `([cpp_expr| $n:num]) =>
      let v : Nat := n.getNat
      `(CExpr.litInt CType.u64 $(quote v))

  | `([cpp_expr| $x:ident]) =>
      let nm := x.getId.toString
      `((CExpr.var $(quote nm) : CExpr CType.u64))

  | `([cpp_expr| $e . $f:ident]) => do
      let et : Term ← `([cpp_expr| $e])
      let fn := f.getId.toString
      `(CExpr.field $et $(quote fn) CType.u64)

  | `([cpp_expr| $e . $m:ident ($args,*)] ) => do
      let et : Term ← `([cpp_expr| $e])
      let mn := m.getId.toString
      let as : Array Term ← args.getElems.mapM (fun a => `([cpp_expr| $a]))
      `(CExpr.methodCall $et $(quote mn) [$(as),*] CType.u64)

  | `([cpp_expr| $a:cpp_expr . index $b:cpp_expr ]) => do
      let lhs : Term ← `([cpp_expr| $a])
      let rhs : Term ← `([cpp_expr| $b])
      `(CExpr.spanIndex $lhs $rhs)

  | `([cpp_expr| static_cast < $ty:cpp_type > ( $e:cpp_expr ) ]) => do
      let ct : Term ← `([cpp_type| $ty])
      let et : Term ← `([cpp_expr| $e])
      `(CExpr.cast "static_cast" $ct $et)

  | `([cpp_expr| ( $e ) ]) => `([cpp_expr| $e])

  | `([cpp_expr| $a | $b ]) => do
      let lhs : Term ← `([cpp_expr| $a])
      let rhs : Term ← `([cpp_expr| $b])
      `(CExpr.binop (a := CType.u64) (b := CType.u64) BinOp.bitOr $lhs $rhs CType.u64)

  | `([cpp_expr| $a << $b ]) => do
      let lhs : Term ← `([cpp_expr| $a])
      let rhs : Term ← `([cpp_expr| $b])
      `(CExpr.binop (a := CType.u64) (b := CType.u64) BinOp.shl $lhs $rhs CType.u64)

  | `([cpp_expr| $a < $b ]) => do
      let lhs : Term ← `([cpp_expr| $a])
      let rhs : Term ← `([cpp_expr| $b])
      `(CExpr.binop (a := CType.u64) (b := CType.u64) BinOp.lt $lhs $rhs CType.bool)

  | `([cpp_expr| $a == $b ]) => do
      let lhs : Term ← `([cpp_expr| $a])
      let rhs : Term ← `([cpp_expr| $b])
      `(CExpr.binop (a := CType.u64) (b := CType.u64) BinOp.eq $lhs $rhs CType.bool)

  | `([cpp_expr| $a != $b ]) => do
      let lhs : Term ← `([cpp_expr| $a])
      let rhs : Term ← `([cpp_expr| $b])
      `(CExpr.binop (a := CType.u64) (b := CType.u64) BinOp.ne $lhs $rhs CType.bool)

  | `([cpp_expr| $a + $b ]) => do
      let lhs : Term ← `([cpp_expr| $a])
      let rhs : Term ← `([cpp_expr| $b])
      `(CExpr.binop (a := CType.u64) (b := CType.u64) BinOp.add $lhs $rhs CType.u64)

  | `([cpp_expr| $a > $b ]) => do
      let lhs : Term ← `([cpp_expr| $a])
      let rhs : Term ← `([cpp_expr| $b])
      `(CExpr.binop (a := CType.u64) (b := CType.u64) BinOp.gt $lhs $rhs CType.bool)

  | `([cpp_expr| $a && $b ]) => do
      let lhs : Term ← `([cpp_expr| $a])
      let rhs : Term ← `([cpp_expr| $b])
      `(CExpr.binop (a := CType.u64) (b := CType.u64) BinOp.and $lhs $rhs CType.bool)

  | `([cpp_expr| $fn:ident ($args,*) ]) => do
      let nm := fn.getId.toString
      let as : Array Term ← args.getElems.mapM (fun a => `([cpp_expr| $a]))
      `(CExpr.call $(quote nm) [$(as),*] CType.u64)

--- ══════════════════════════════════════════════════════════════════════════════
--- macro_rules: expand cpp_stmt to CStmt terms
--- ══════════════════════════════════════════════════════════════════════════════

macro_rules
  | `([cpp_stmt| $$($t) ]) =>
      return t

  | `([cpp_stmt| return $e ; ]) => do
      let et : Term ← `([cpp_expr| $e])
      `(CStmt.ret $et)

  | `([cpp_stmt| return ; ]) =>
      `(CStmt.retVoid)

  | `([cpp_stmt| if ( $c ) $b ]) => do
      let ct : Term ← `([cpp_expr| $c])
      let bt : Term ← `([cpp_stmt| $b])
      `(CStmt.ifThen $ct [$bt])

  | `([cpp_stmt| if ( $c ) $t else $e ]) => do
      let ct : Term ← `([cpp_expr| $c])
      let tt : Term ← `([cpp_stmt| $t])
      let et : Term ← `([cpp_stmt| $e])
      `(CStmt.ifElse $ct [$tt] [$et])

  | `([cpp_stmt| $ty:cpp_type $name:ident = $e:cpp_expr ; ]) => do
      let pt : Term ← `([cpp_type| $ty])
      let nm := name.getId.toString
      let et : Term ← `([cpp_expr| $e])
      `(CStmt.decl $pt $(quote nm) (some ⟨$pt, $et⟩))

  | `([cpp_stmt| $e:cpp_expr ;]) => do
      let et : Term ← `([cpp_expr| $e])
      `(CStmt.expr $et)

  | `([cpp_stmt| { $ss:cpp_stmt* } ]) => do
      let sts : Array Term ← ss.mapM (fun s => `([cpp_stmt| $s]))
      `(CStmt.block [$(sts),*])

--- ══════════════════════════════════════════════════════════════════════════════
--- Entry point: [cpp| [[nodiscard]] uint64_t name(params) { body } ]
--- ══════════════════════════════════════════════════════════════════════════════

macro "[cpp|" fn:cpp_func "]" : term => do
  match fn with
  | `(cpp_func| [[ $attrs:ident,* ]] $ret:cpp_type $name:ident
        ( $params:cpp_param* )
        { $body:cpp_stmt* } ) => do
      let rt : Term ← `([cpp_type| $ret])
      let nm := name.getId.toString
      let attrStrs := attrs.getElems.map (·.getId.toString)
      let paramTms ← params.mapM (fun p =>
        match p with
        | `(cpp_param| $pty:cpp_type $pnm:ident) => do
            let pt : Term ← `([cpp_type| $pty])
            let pn := pnm.getId.toString
            `(CParam.mk $pt $(quote pn))
        | _ => Macro.throwError "bad param")
      let sts : Array Term ← body.mapM (fun s => `([cpp_stmt| $s]))
      `(CDecl.funcAttr $(quote (attrStrs.toList)) $rt $(quote nm) [$(paramTms),*] [$(sts),*])
  | _ => Macro.throwError "unsupported cpp function syntax"

/-- Interpolation test: pre-built CExpr embedded via $$(). -/
def minSize : CExpr CType.u64 := CExpr.litInt CType.u64 8

def interpFunc : CDecl :=
  [cpp| [[nodiscard]] uint64_t guard_func(uint64_t x) {
    if (x < $$(minSize))
      return 0;
    else
      return x;
  }]

end Continuity.Codegen.Dialect.Cpp
