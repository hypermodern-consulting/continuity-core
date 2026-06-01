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

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                // transition // table // model
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
---                                                 // enum // class // emission
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def emitEnumClass (name : String) (values : List String) (underlying : Option CType) : String :=
  let underlying' := underlying.getD (CType.intType false 32)
  renderDecl (CDecl.enumClass name underlying' (values.map fun v => (v, Option.none))) 0

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                    // step // function // body
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
---                                       // struct emission with external state type
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-
  emitMachineStructExt — like emitMachineStruct but uses `using state_type = extTy`
  instead of generating an enum class for the state.  The state type (extTy) is a
  pre-existing struct defined in the protocol header (e.g. sigil_state, zmtp_state).
-/
def emitMachineStructExt (extStateTy : String) (m : FlatMachine) : String :=
  let stateTypeName := extStateTy
  let eventEnumName := m.name ++ "_event"
  let actionEnumName := m.name ++ "_action"

  let usingLine := "  using state_type = " ++ stateTypeName ++ ";"

  let eventEnum := emitEnumClass eventEnumName m.events (CType.u8)

  let actionEnum := emitEnumClass actionEnumName m.actions (CType.u8)

  let initialFn : String :=
    "[[nodiscard]] auto initial() const -> state_type {" ++ "\n"
    ++ emitInitialBody m ++ "\n"
    ++ "  }"

  let stepFn : String :=
    "auto step(state_type s, event const& e) const -> step_result<state_type> {" ++ "\n"
    ++ emitStepBody m ++ "\n"
    ++ "  }"

  let doneFn : String :=
    "[[nodiscard]] auto done(state_type const& s) const -> bool {" ++ "\n"
    ++ emitDoneBody m ++ "\n"
    ++ "  }"

  let nl := "\n"
  let body := String.intercalate (nl ++ nl) [
    "struct " ++ m.name ++ " {",
    usingLine,
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

private def emitIncludesExt : String :=
  "#pragma once\n\n"
  ++ "#include <utility>\n"
  ++ "#include <vector>\n"
  ++ "#include \"evring/core/event.h\"\n"
  ++ "#include \"evring/machine/machine.h\"\n\n"

private def emitAlignmentNotice (machName : String) (targets : List String) : String :=
  let targetStrs := targets.map fun t => "//   " ++ t
  "// ═══════════════════════════════════════════════════════════════════════════════\n"
  ++ "// GENERATED BY CONTINUITY — DO NOT EDIT\n"
  ++ "// Source: Continuity.StateMachine.StateMachine → Continuity.Codegen.Derive.StateMachine\n"
  ++ "// Machine: " ++ machName ++ "\n"
  ++ "// Aligns with libevring-cpp:\n"
  ++ String.intercalate "\n" targetStrs ++ "\n"
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

def emitMachineHeaderExt (extStateTy : String) (targets : List String) (m : FlatMachine) : String :=
  let namespaceOpen : String := "namespace evring {"
  let namespaceClose : String := "} // namespace evring"

  let machineStruct := emitMachineStructExt extStateTy m
  let combinators := emitCombinatorWrappers m.name

  let nl := "\n"
  String.intercalate nl [
    emitIncludesExt,
    emitAlignmentNotice m.name targets,
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

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                           // sigil_machine // protocol codegen
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def sigilStates : List String := ["text", "think", "tool_call", "code_block"]
def sigilEvents : List String := ["token", "think_start", "think_end", "tool_call_start",
  "tool_call_end", "code_block_start", "code_block_end", "chunk_end", "flush", "stream_end",
  "reserved", "decode_error"]

def sigilActions : List String := ["event_ignored", "emit_chunk", "reset_state",
  "accumulate_token", "mark_stream_done", "emit_ambiguity_reset"]

def sigilTransitions : List FlatTransition := [
  { source := "text",       event := "token",              target := "text",       actions := ["accumulate_token"] },
  { source := "text",       event := "think_start",        target := "think",      actions := ["emit_chunk"] },
  { source := "text",       event := "tool_call_start",    target := "tool_call",  actions := ["emit_chunk"] },
  { source := "text",       event := "code_block_start",   target := "code_block", actions := ["emit_chunk"] },
  { source := "text",       event := "chunk_end",          target := "text",       actions := ["emit_chunk"] },
  { source := "text",       event := "flush",              target := "text",       actions := ["emit_chunk"] },
  { source := "text",       event := "stream_end",         target := "text",       actions := ["emit_chunk", "mark_stream_done"] },
  { source := "think",      event := "token",              target := "think",      actions := ["accumulate_token"] },
  { source := "think",      event := "think_end",          target := "text",       actions := ["emit_chunk"] },
  { source := "think",      event := "chunk_end",          target := "think",      actions := ["emit_chunk"] },
  { source := "think",      event := "flush",              target := "think",      actions := ["emit_chunk"] },
  { source := "think",      event := "stream_end",         target := "text",       actions := ["emit_chunk", "mark_stream_done"] },
  { source := "think",      event := "tool_call_start",    target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] },
  { source := "think",      event := "code_block_start",   target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] },
  { source := "think",      event := "think_start",        target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] },
  { source := "tool_call",  event := "token",              target := "tool_call",  actions := ["accumulate_token"] },
  { source := "tool_call",  event := "tool_call_end",      target := "text",       actions := ["emit_chunk"] },
  { source := "tool_call",  event := "chunk_end",          target := "tool_call",  actions := ["emit_chunk"] },
  { source := "tool_call",  event := "flush",              target := "tool_call",  actions := ["emit_chunk"] },
  { source := "tool_call",  event := "stream_end",         target := "text",       actions := ["emit_chunk", "mark_stream_done"] },
  { source := "tool_call",  event := "think_start",        target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] },
  { source := "tool_call",  event := "code_block_start",   target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] },
  { source := "tool_call",  event := "tool_call_start",    target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] },
  { source := "code_block", event := "token",              target := "code_block", actions := ["accumulate_token"] },
  { source := "code_block", event := "code_block_end",     target := "text",       actions := ["emit_chunk"] },
  { source := "code_block", event := "chunk_end",          target := "code_block", actions := ["emit_chunk"] },
  { source := "code_block", event := "flush",              target := "code_block", actions := ["emit_chunk"] },
  { source := "code_block", event := "stream_end",         target := "text",       actions := ["emit_chunk", "mark_stream_done"] },
  { source := "code_block", event := "think_start",        target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] },
  { source := "code_block", event := "tool_call_start",    target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] },
  { source := "code_block", event := "code_block_start",   target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] },
  { source := "text",       event := "reserved",           target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] },
  { source := "think",      event := "reserved",           target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] },
  { source := "tool_call",  event := "reserved",           target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] },
  { source := "code_block", event := "reserved",           target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] },
  { source := "text",       event := "decode_error",       target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] },
  { source := "think",      event := "decode_error",       target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] },
  { source := "tool_call",  event := "decode_error",       target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] },
  { source := "code_block", event := "decode_error",       target := "text",       actions := ["emit_ambiguity_reset", "reset_state"] }
]

def sigilMachine : FlatMachine := {
  name := "sigil_machine"
  states := sigilStates
  events := sigilEvents
  actions := sigilActions
  initialState := "text"
  terminalStates := []
  transitions := sigilTransitions
}

def emitSigilMachineHeader : String :=
  emitMachineHeaderExt "sigil_state"
    ["protocol/sigil.h  →  sigil_machine (parse_mode → mode transitions)"]
    sigilMachine

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                           // zmtp_machine // protocol codegen
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def zmtpStates : List String := ["await_greeting", "await_handshake", "ready", "failed"]
def zmtpEvents : List String := ["byte_arrived", "greeting_ok", "greeting_ambiguous",
  "handshake_ok", "handshake_incomplete", "handshake_ambiguous",
  "frame_arrived", "frame_ambiguous", "command_ready", "command_error"]

def zmtpActions : List String := ["event_ignored", "advance_phase",
  "buffer_consumed", "mark_failed", "collect_frame", "emit_operation"]

def zmtpTransitions : List FlatTransition := [
  { source := "await_greeting",  event := "byte_arrived",         target := "await_greeting",  actions := ["buffer_consumed"] },
  { source := "await_greeting",  event := "greeting_ok",          target := "await_handshake", actions := ["advance_phase", "buffer_consumed"] },
  { source := "await_greeting",  event := "greeting_ambiguous",   target := "failed",          actions := ["mark_failed"] },
  { source := "await_handshake", event := "byte_arrived",         target := "await_handshake", actions := ["buffer_consumed"] },
  { source := "await_handshake", event := "handshake_ok",         target := "await_handshake", actions := ["buffer_consumed", "collect_frame"] },
  { source := "await_handshake", event := "handshake_incomplete", target := "await_handshake", actions := [] },
  { source := "await_handshake", event := "handshake_ambiguous",  target := "failed",          actions := ["mark_failed"] },
  { source := "await_handshake", event := "command_ready",        target := "ready",           actions := ["advance_phase", "buffer_consumed"] },
  { source := "await_handshake", event := "command_error",        target := "failed",          actions := ["mark_failed"] },
  { source := "ready",           event := "byte_arrived",         target := "ready",           actions := ["buffer_consumed"] },
  { source := "ready",           event := "frame_arrived",        target := "ready",           actions := ["buffer_consumed", "collect_frame"] },
  { source := "ready",           event := "frame_ambiguous",      target := "failed",          actions := ["mark_failed"] },
  { source := "failed",          event := "byte_arrived",         target := "failed",          actions := [] },
  { source := "failed",          event := "greeting_ok",          target := "failed",          actions := [] },
  { source := "failed",          event := "greeting_ambiguous",   target := "failed",          actions := [] },
  { source := "failed",          event := "handshake_ok",         target := "failed",          actions := [] },
  { source := "failed",          event := "handshake_incomplete", target := "failed",          actions := [] },
  { source := "failed",          event := "handshake_ambiguous",  target := "failed",          actions := [] },
  { source := "failed",          event := "command_ready",        target := "failed",          actions := [] },
  { source := "failed",          event := "command_error",        target := "failed",          actions := [] },
  { source := "failed",          event := "frame_arrived",        target := "failed",          actions := [] },
  { source := "failed",          event := "frame_ambiguous",      target := "failed",          actions := [] }
]

def zmtpMachine : FlatMachine := {
  name := "zmtp_machine"
  states := zmtpStates
  events := zmtpEvents
  actions := zmtpActions
  initialState := "await_greeting"
  terminalStates := ["failed"]
  transitions := zmtpTransitions
}

def emitZmtpMachineHeader : String :=
  emitMachineHeaderExt "zmtp_state"
    ["protocol/zmtp.h  →  zmtp_machine (conn_phase → connection lifecycle)"]
    zmtpMachine

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                           // http1_machine // protocol codegen
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def http1States : List String := ["initial", "sending", "waiting_write", "receiving",
  "waiting_read", "done", "error"]
def http1Events : List String := ["send_request", "write_complete", "data_received",
  "read_complete", "parse_error", "connection_close"]

def http1Actions : List String := ["event_ignored", "enqueue_send", "enqueue_recv",
  "parse_response_chunk", "finalize_response", "mark_error"]

def http1Transitions : List FlatTransition := [
  { source := "initial",       event := "send_request",     target := "sending",       actions := ["enqueue_send"] },
  { source := "sending",       event := "write_complete",   target := "waiting_read",  actions := ["enqueue_recv"] },
  { source := "sending",       event := "parse_error",      target := "error",         actions := ["mark_error"] },
  { source := "waiting_write", event := "write_complete",   target := "waiting_read",  actions := ["enqueue_recv"] },
  { source := "waiting_write", event := "parse_error",      target := "error",         actions := ["mark_error"] },
  { source := "waiting_read",  event := "data_received",    target := "receiving",     actions := ["parse_response_chunk"] },
  { source := "waiting_read",  event := "parse_error",      target := "error",         actions := ["mark_error"] },
  { source := "waiting_read",  event := "connection_close", target := "error",         actions := ["mark_error"] },
  { source := "receiving",     event := "read_complete",    target := "done",          actions := ["finalize_response"] },
  { source := "receiving",     event := "data_received",    target := "waiting_read",  actions := ["enqueue_recv"] },
  { source := "receiving",     event := "parse_error",      target := "error",         actions := ["mark_error"] },
  { source := "receiving",     event := "connection_close", target := "done",          actions := ["finalize_response"] },
  { source := "done",          event := "send_request",     target := "done",          actions := [] },
  { source := "done",          event := "data_received",    target := "done",          actions := [] },
  { source := "error",         event := "send_request",     target := "error",         actions := [] },
  { source := "error",         event := "write_complete",   target := "error",         actions := [] },
  { source := "error",         event := "data_received",    target := "error",         actions := [] },
  { source := "error",         event := "read_complete",    target := "error",         actions := [] },
  { source := "error",         event := "parse_error",      target := "error",         actions := [] },
  { source := "error",         event := "connection_close", target := "error",         actions := [] }
]

def http1Machine : FlatMachine := {
  name := "http1_machine"
  states := http1States
  events := http1Events
  actions := http1Actions
  initialState := "initial"
  terminalStates := ["done", "error"]
  transitions := http1Transitions
}

def emitHttp1MachineHeader : String :=
  emitMachineHeader http1Machine

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                           // http2_machine // protocol codegen
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def http2States : List String := ["initial", "sending_preface", "waiting_write",
  "waiting_read", "connected", "error"]
def http2Events : List String := ["send_preface", "write_complete", "settings_received",
  "parse_error", "goaway_received"]

def http2Actions : List String := ["event_ignored", "enqueue_preface", "enqueue_recv",
  "enqueue_pending_frames", "mark_error", "advance_phase"]

def http2Transitions : List FlatTransition := [
  { source := "initial",         event := "send_preface",       target := "sending_preface", actions := ["enqueue_preface"] },
  { source := "sending_preface", event := "write_complete",     target := "waiting_read",    actions := ["enqueue_recv"] },
  { source := "sending_preface", event := "parse_error",        target := "error",           actions := ["mark_error"] },
  { source := "waiting_write",   event := "write_complete",     target := "waiting_read",    actions := ["enqueue_recv"] },
  { source := "waiting_write",   event := "parse_error",        target := "error",           actions := ["mark_error"] },
  { source := "waiting_read",    event := "settings_received",  target := "connected",       actions := ["advance_phase"] },
  { source := "waiting_read",    event := "parse_error",        target := "error",           actions := ["mark_error"] },
  { source := "connected",       event := "write_complete",     target := "connected",       actions := ["enqueue_recv"] },
  { source := "connected",       event := "settings_received",  target := "connected",       actions := [] },
  { source := "connected",       event := "goaway_received",    target := "error",           actions := ["mark_error"] },
  { source := "connected",       event := "parse_error",        target := "error",           actions := ["mark_error"] },
  { source := "error",           event := "send_preface",       target := "error",           actions := [] },
  { source := "error",           event := "write_complete",     target := "error",           actions := [] },
  { source := "error",           event := "settings_received",  target := "error",           actions := [] },
  { source := "error",           event := "parse_error",        target := "error",           actions := [] },
  { source := "error",           event := "goaway_received",    target := "error",           actions := [] }
]

def http2Machine : FlatMachine := {
  name := "http2_machine"
  states := http2States
  events := http2Events
  actions := http2Actions
  initialState := "initial"
  terminalStates := ["connected", "error"]
  transitions := http2Transitions
}

def emitHttp2MachineHeader : String :=
  emitMachineHeader http2Machine

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                          // derivation // roster
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def deriveCppStateMachines : List (String × String) := [
  ("state_machine/toggle_machine.h", emitToggleMachineHeader),
  ("state_machine/sigil_machine.h", emitSigilMachineHeader),
  ("state_machine/zmtp_machine.h", emitZmtpMachineHeader),
  ("state_machine/http1_machine.h", emitHttp1MachineHeader),
  ("state_machine/http2_machine.h", emitHttp2MachineHeader)
]

def cppStateMachineFiles : List (String × String) := deriveCppStateMachines

end Continuity.Codegen.Derive.StateMachine
