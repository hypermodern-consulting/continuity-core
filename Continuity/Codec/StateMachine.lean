import Continuity.Codec.Box

set_option autoImplicit false

namespace Continuity.Codec.StateMachine

/-!
  Verified State Machine DSL for protocol state machines.

  Determinism: each (state, event) pair has exactly one transition.
  Safety: only valid transitions are expressible.
  Progress: terminal states are explicitly marked.
-/

structure Transition (S A : Type) where
  next : S
  actions : List A
  deriving Repr

structure Machine (S E A : Type) where
  initial : S
  transition : S → E → Transition S A
  isTerminal : S → Bool

def Machine.step {S E A : Type} (m : Machine S E A) (s : S) (e : E) : S × List A :=
  let t := m.transition s e
  (t.next, t.actions)

def Machine.run {S E A : Type} (m : Machine S E A) (events : List E) : S × List A :=
  events.foldl (fun (s, actions) e =>
    let (s', newActions) := m.step s e
    (s', actions ++ newActions)
  ) (m.initial, [])

def Machine.validTrace {S E A : Type} (m : Machine S E A) (events : List E) : Bool :=
  m.isTerminal (m.run events).1

/-- Determinism is free: transition is a function, not a relation. -/
theorem deterministic {S E A : Type} (m : Machine S E A) (s : S) (e : E) :
    ∀ t1 t2, m.transition s e = t1 → m.transition s e = t2 → t1 = t2 := by
  intro t1 t2 h1 h2; rw [← h1, ← h2]

-- ═══════════════════════════════════════════════════════════════════════════════
-- PROTOCOL STATE MACHINE TEMPLATES
-- ═══════════════════════════════════════════════════════════════════════════════

/-- TLS-style handshake state machine template -/
inductive HandshakeState where
  | initial | clientHello | serverHello | serverParams
  | serverFinished | clientFinished | established | failed
  deriving Repr, DecidableEq

/-- Generic connection lifecycle -/
inductive ConnState where
  | disconnected | connecting | handshaking | established
  | draining | closed | failed
  deriving Repr, DecidableEq

-- ═══════════════════════════════════════════════════════════════════════════════
-- PRODUCT MACHINES
-- ═══════════════════════════════════════════════════════════════════════════════

/-- Run two machines in parallel (product composition) -/
def Machine.product {S₁ S₂ E A₁ A₂ : Type}
    (m₁ : Machine S₁ E A₁) (m₂ : Machine S₂ E A₂)
    : Machine (S₁ × S₂) E (A₁ ⊕ A₂) where
  initial := (m₁.initial, m₂.initial)
  transition := fun (s₁, s₂) e =>
    let t₁ := m₁.transition s₁ e
    let t₂ := m₂.transition s₂ e
    ⟨(t₁.next, t₂.next), t₁.actions.map Sum.inl ++ t₂.actions.map Sum.inr⟩
  isTerminal := fun (s₁, s₂) => m₁.isTerminal s₁ && m₂.isTerminal s₂

end Continuity.Codec.StateMachine
