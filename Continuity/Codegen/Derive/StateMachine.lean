import Continuity.Codegen.AST.Cpp.Ast
import Continuity.Codegen.AST.Cpp.Render

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Turner was watching the Hitachi's projection of the AI's
      construct: a vast, tridimensional, translucent graphic of
      data flow and process precedence. The thing that surprised
      him most was not the scale — he'd expected that — but the
      way the graph *moved*, each transition firing, each state
      advancing, a clockwork of intent so precise it bordered on
      the obscene. It was, he understood, a state machine. Not
      a metaphor. A literal, mechanical description of a mind
      that had been compiled into protocol. The codegen bridge
      was the part he'd come to see: the extrusion of those
      states, events, and actions from the verified kernel in
      Lean down into the C++ substrate where the IO loop lived.
      One wrong bridge, one dropped transition, and the whole
      edifice would fission into garbage. But get it right — get
      every state, every event, every combinator proven — and
      the machine would speak fluently in both worlds."

                                                                     — Count Zero

     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.Derive.StateMachine

open Continuity.Codegen.AST.Cpp

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                  // transition // table // model
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure FlatTransition where
  source : String
  event : String
  target : String
  actions : List String
  deriving Repr, Inhabited

structure FlatMachine where
  name : String
  states : List String
  events : List String
  actions : List String
  initialState : String
  terminalStates : List String
  transitions : List FlatTransition
  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                     // enum // class // emission
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def emitEnumClass (name : String) (values : List String) (underlying : Option CType) : String :=
  let underlying' := underlying.getD (CType.intType false 32)
  renderDecl (CDecl.enumClass name underlying' (values.map fun v => (v, Option.none))) 0

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                      // step // function // body
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def emitStepBody (m : FlatMachine) : String :=
  let emitBranch (t : FlatTransition) : String :=
    let cond := "s == " ++ m.name ++ "_state::" ++ t.source
                ++ " && e == " ++ m.name ++ "_event::" ++ t.event
    let actionList : String :=
      if t.actions.isEmpty then "{}"
      else "{"
           ++ String.intercalate ", " (t.actions.map fun a => m.name ++ "_action::" ++ a)
           ++ "}"
    let targetState := m.name ++ "_state::" ++ t.target
    "  if (" ++ cond ++ ")\n    return {" ++ targetState ++ ", " ++ actionList ++ "};"

  let branches := String.intercalate "\n\n" (m.transitions.map emitBranch)

  let fallthrough :=
    if branches.isEmpty then ""
    else "\n\n  return {s, {}};"

  branches ++ fallthrough

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                      // done // function // body
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def emitDoneBody (m : FlatMachine) : String :=
  if m.terminalStates.isEmpty then
    "  return false;"
  else
    let conds := m.terminalStates.map fun ts =>
      "s == " ++ m.name ++ "_state::" ++ ts
    let expr := String.intercalate " || " conds
    "  return " ++ expr ++ ";"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                   // initial // function // body
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def emitInitialBody (m : FlatMachine) : String :=
  "  return " ++ m.name ++ "_state::" ++ m.initialState ++ ";"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // struct // emission
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def emitMachineStruct (m : FlatMachine) : String :=
  let stateTypeName := m.name ++ "_state_type"
  let stateEnumName := m.name ++ "_state"
  let eventEnumName := m.name ++ "_event"
  let actionEnumName := m.name ++ "_action"

  let usingLine := "  using state_type = " ++ stateTypeName ++ ";"

  let stateEnum := emitEnumClass stateEnumName m.states (CType.u8)

  let eventEnum := emitEnumClass eventEnumName m.events (CType.u8)

  let actionEnum := emitEnumClass actionEnumName m.actions (CType.u8)

  let initialFn : String :=
    "[[nodiscard]] static constexpr auto initial() -> state_type {" ++ "\n"
    ++ emitInitialBody m ++ "\n"
    ++ "  }"

  let stepFn : String :=
    "static auto step(state_type s, event const& e) -> step_result<state_type> {" ++ "\n"
    ++ emitStepBody m ++ "\n"
    ++ "  }"

  let doneFn : String :=
    "[[nodiscard]] static auto done(state_type s) -> bool {" ++ "\n"
    ++ emitDoneBody m ++ "\n"
    ++ "  }"

  let nl := "\n"
  let body := String.intercalate (nl ++ nl) [
    "struct " ++ m.name ++ " {",
    usingLine,
    "",
    stateEnum,
    "",
    eventEnum,
    "",
    actionEnum,
    "",
    "  " ++ initialFn,
    "",
    "  " ++ stepFn,
    "",
    "  " ++ doneFn,
    "};"
  ]

  body ++ nl ++ "static_assert(machine<" ++ m.name ++ ">);"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                           // combinator // wrapper // emission
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def unlines (xs : List String) : String :=
  String.intercalate "\n" xs

private def emitComposeAdapter (machineName : String) : String :=
  let commentLine := "// compose adapter: " ++ machineName ++ " -> abstract_machine<event, operation>"
  let assertLine := "static_assert(abstract_machine<" ++ machineName ++ "_abstract>);"
  unlines [
    commentLine,
    "struct " ++ machineName ++ "_abstract {",
    "  using input_type = event;",
    "  using output_type = operation;",
    "  using state_type = " ++ machineName ++ "_state_type;",
    "",
    "  " ++ machineName ++ " m;",
    "",
    "  auto initial() -> state_type { return m.initial(); }",
    "",
    "  auto step(state_type s, event const& e) -> abstract_step_result<state_type, operation> {",
    "    auto result = m.step(s, e);",
    "    return {result.state, std::move(result.operations)};",
    "  }",
    "",
    "  auto done(state_type s) -> bool { return m.done(s); }",
    "};",
    assertLine
  ]

private def emitIdentityWrapper (machineName : String) : String :=
  let assertLine := "static_assert(abstract_machine<" ++ machineName ++ "_identity<" ++ machineName ++ ">>);"
  unlines [
    "// identity wrapper: " ++ machineName ++ " as abstract_machine<event, event>",
    "template <typename M>",
    "  requires machine<M>",
    "struct " ++ machineName ++ "_identity {",
    "  using input_type = event;",
    "  using output_type = event;",
    "  using state_type = typename M::state_type;",
    "",
    "  M m;",
    "",
    "  auto initial() -> state_type { return m.initial(); }",
    "",
    "  auto step(state_type s, event const& e)",
    "      -> abstract_step_result<state_type, event> {",
    "    return {s, {e}};",
    "  }",
    "",
    "  auto done(state_type s) -> bool { return m.done(s); }",
    "};",
    assertLine
  ]

private def emitFilterWrapper (machineName : String) : String :=
  unlines [
    "// filter wrapper: " ++ machineName ++ " with event predicate",
    "template <typename Predicate>",
    "struct " ++ machineName ++ "_filter {",
    "  using input_type = event;",
    "  using output_type = step_result<" ++ machineName ++ "_state_type>;",
    "  using state_type = " ++ machineName ++ "_state_type;",
    "",
    "  Predicate predicate;",
    "  " ++ machineName ++ " m;",
    "",
    "  auto initial() -> state_type { return m.initial(); }",
    "",
    "  auto step(state_type s, event const& e)",
    "      -> abstract_step_result<state_type, step_result<state_type>> {",
    "    if (predicate(e)) {",
    "      auto result = m.step(s, e);",
    "      auto out_state = result.state;",
    "      return {out_state, {std::move(result)}};",
    "    }",
    "    return {s, {}};",
    "  }",
    "",
    "  auto done(state_type s) -> bool { return m.done(s); }",
    "};"
  ]

private def emitAccumulateWrapper (machineName : String) : String :=
  unlines [
    "// accumulate wrapper: fold state over " ++ machineName ++ " transitions",
    "template <typename AccumState, typename FoldFn>",
    "struct " ++ machineName ++ "_accumulate {",
    "  using input_type = event;",
    "  using output_type = AccumState;",
    "  using state_type = std::pair<" ++ machineName ++ "_state_type, AccumState>;",
    "",
    "  FoldFn fold_fn;",
    "  AccumState accum_init;",
    "  " ++ machineName ++ " m;",
    "",
    "  auto initial() -> state_type { return {m.initial(), accum_init}; }",
    "",
    "  auto step(state_type s, event const& e)",
    "      -> abstract_step_result<state_type, AccumState> {",
    "    auto result = m.step(s.first, e);",
    "    auto new_accum = fold_fn(s.second, result);",
    "    return {{result.state, new_accum}, {new_accum}};",
    "  }",
    "",
    "  auto done(state_type s) -> bool { return m.done(s.first); }",
    "};"
  ]

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                // convenience
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def emitMachineConcept (name : String) (states events actions : List String)
    (transitions : List FlatTransition) : String :=
  let m : FlatMachine := {
    name := name
    states := states
    events := events
    actions := actions
    initialState := states.head?.getD "invalid"
    terminalStates := []
    transitions := transitions
  }
  emitMachineStruct m

def emitCombinatorWrappers (machineName : String) : String :=
  String.intercalate "\n" [
    "// ═══════════════════════════════════════════════════════════════════════════════",
    "// ABSTRACT MACHINE COMBINATOR WRAPPERS for " ++ machineName,
    "// ═══════════════════════════════════════════════════════════════════════════════",
    "",
    emitComposeAdapter machineName,
    "",
    emitIdentityWrapper machineName,
    "",
    emitFilterWrapper machineName,
    "",
    emitAccumulateWrapper machineName
  ]

def emitAbstractCombinators (machineName : String) : String :=
  emitCombinatorWrappers machineName

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                   // header // file // assembly
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def emitIncludes : String :=
  "#pragma once\n\n"
  ++ "#include <utility>\n"
  ++ "#include <vector>\n\n"

private def emitGeneratedNotice (machName : String) : String :=
  "// ═══════════════════════════════════════════════════════════════════════════════\n"
  ++ "// GENERATED BY CONTINUITY — DO NOT EDIT\n"
  ++ "// Source: Continuity.StateMachine.StateMachine → Continuity.Codegen.Derive.StateMachine\n"
  ++ "// Machine: " ++ machName ++ "\n"
  ++ "// ═══════════════════════════════════════════════════════════════════════════════\n\n"

def emitMachineHeader (m : FlatMachine) : String :=
  let namespaceOpen : String := "namespace evring {"
  let namespaceClose : String := "} // namespace evring"

  let machineStruct := emitMachineStruct m
  let combinators := emitCombinatorWrappers m.name

  let nl := "\n"
  String.intercalate nl [
    emitIncludes,
    emitGeneratedNotice m.name,
    namespaceOpen,
    "",
    machineStruct,
    "",
    combinators,
    "",
    namespaceClose
  ]

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                     // toggle // machine // test
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def toggleMachineStates : List String := ["off", "on"]
def toggleMachineEvents : List String := ["flip"]
def toggleMachineActions : List String := ["none", "log_flip"]

def toggleMachineTransitions : List FlatTransition := [
  { source := "off", event := "flip", target := "on", actions := ["log_flip"] },
  { source := "on",  event := "flip", target := "off", actions := ["log_flip"] }
]

def toggleMachine : FlatMachine := {
  name := "toggle_machine"
  states := toggleMachineStates
  events := toggleMachineEvents
  actions := toggleMachineActions
  initialState := "off"
  terminalStates := []
  transitions := toggleMachineTransitions
}

def emitToggleMachineHeader : String :=
  emitMachineHeader toggleMachine

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                          // derivation // roster
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def deriveCppStateMachines : List (String × String) := [
  ("state_machine/toggle_machine.h", emitToggleMachineHeader)
]

def cppStateMachineFiles : List (String × String) := deriveCppStateMachines

end Continuity.Codegen.Derive.StateMachine
