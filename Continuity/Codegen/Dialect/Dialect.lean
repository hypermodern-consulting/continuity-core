set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The best code is the kind you can't write wrong."

      Dialect typeclass — the abstraction layer between verified spec and
      target-language code. Each target language implements this interface.

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.Dialect

class CodegenLang (L : Type) where
  Module : Type
  Decl   : Type
  Stmt   : Type
  Expr   : Type
  renderFile : Module → String
  renderDecl : Decl → String
  renderStmt : Stmt → Nat → String
  renderExpr : Expr → String
  moduleFromDecls : List Decl → Module

end Continuity.Codegen.Dialect
