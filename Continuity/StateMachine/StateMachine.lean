set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "It was such an easy thing, death. He saw that now: It just
      happened. You screwed up by a fraction and there it was,
      something chill and odorless, ballooning out from the four
      stupid corners of the room, your mother's Barrytown living
      room.

      Shit, he thought, Two-a-Day'll laugh his ass off, first time
      out and I pull a wilson.

      Because that was the thing about it — one wrong state, one
      bad event, and the machine was done. You couldn't unwind it.
      The transition had fired. The next state was the next state,
      and there was no going back to the init."

                                                                     — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.StateMachine.StateMachine

/-
  Verified State Machine DSL.

  Determinism: transition is a function, not a relation.
  Safety: invalid (state, event) pairs are compile errors.
  Composition: product, sum, sequential combinators with proofs.

  The action types are protocol-level intents (`sendServerHello`,
  `sendStderrLast`). The mapping from intents to `io_uring` submissions
  is a separate concern at the event loop boundary.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                      // core
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                               // combinators
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive Either (α β : Type) where
  | left : α → Either α β
  | right : β → Either α β
  deriving Repr, DecidableEq

-- product: run two machines in parallel on tagged events
def Machine.product {S₁ S₂ E₁ E₂ A₁ A₂ : Type}
    (m₁ : Machine S₁ E₁ A₁) (m₂ : Machine S₂ E₂ A₂)
    : Machine (S₁ × S₂) (Either E₁ E₂) (Either A₁ A₂) where

  initial := (m₁.initial, m₂.initial)

  transition := fun (s₁, s₂) e =>
    match e with
    | .left e₁ =>
      let t := m₁.transition s₁ e₁
      { next := (t.next, s₂), actions := t.actions.map .left }
    | .right e₂ =>
      let t := m₂.transition s₂ e₂
      { next := (s₁, t.next), actions := t.actions.map .right }

  isTerminal := fun (s₁, s₂) => m₁.isTerminal s₁ && m₂.isTerminal s₂

-- sum: choose between two machines based on initial event
inductive SumState (S₁ S₂ : Type) where
  | uninit
  | inLeft : S₁ → SumState S₁ S₂
  | inRight : S₂ → SumState S₁ S₂
  deriving Repr

def Machine.sum {S₁ S₂ E₁ E₂ A₁ A₂ : Type}
    (m₁ : Machine S₁ E₁ A₁) (m₂ : Machine S₂ E₂ A₂)
    : Machine (SumState S₁ S₂) (Either E₁ E₂) (Either A₁ A₂) where

  initial := .uninit

  transition := fun s e =>
    match s, e with
    | .uninit, .left e₁ =>
      let t := m₁.transition m₁.initial e₁
      { next := .inLeft t.next, actions := t.actions.map .left }

    | .uninit, .right e₂ =>
      let t := m₂.transition m₂.initial e₂
      { next := .inRight t.next, actions := t.actions.map .right }

    | .inLeft s₁, .left e₁ =>
      let t := m₁.transition s₁ e₁
      { next := .inLeft t.next, actions := t.actions.map .left }

    | .inRight s₂, .right e₂ =>
      let t := m₂.transition s₂ e₂
      { next := .inRight t.next, actions := t.actions.map .right }

    | .inLeft s₁, .right _ => { next := .inLeft s₁, actions := [] }
    | .inRight s₂, .left _ => { next := .inRight s₂, actions := [] }

  isTerminal := fun s =>
    match s with
    | .uninit => false
    | .inLeft s₁ => m₁.isTerminal s₁
    | .inRight s₂ => m₂.isTerminal s₂

-- sequential: run `m₁` until terminal, handoff to `m₂`
inductive SeqState (S₁ S₂ : Type) where
  | phase1 : S₁ → SeqState S₁ S₂
  | phase2 : S₂ → SeqState S₁ S₂
  deriving Repr

inductive SeqEvent (E₁ E₂ : Type) where
  | ev1 : E₁ → SeqEvent E₁ E₂
  | handoff : SeqEvent E₁ E₂
  | ev2 : E₂ → SeqEvent E₁ E₂
  deriving Repr

def Machine.sequential {S₁ S₂ E₁ E₂ A₁ A₂ : Type}
    (m₁ : Machine S₁ E₁ A₁) (m₂ : Machine S₂ E₂ A₂)
    : Machine (SeqState S₁ S₂) (SeqEvent E₁ E₂) (Either A₁ A₂) where

  initial := .phase1 m₁.initial

  transition := fun s e =>
    match s, e with
    | .phase1 s₁, .ev1 e₁ =>
      let t := m₁.transition s₁ e₁
      { next := .phase1 t.next, actions := t.actions.map .left }

    | .phase1 s₁, .handoff =>
      if m₁.isTerminal s₁ then { next := .phase2 m₂.initial, actions := [] }
      else { next := .phase1 s₁, actions := [] }

    | .phase1 s₁, .ev2 _ => { next := .phase1 s₁, actions := [] }

    | .phase2 s₂, .ev2 e₂ =>
      let t := m₂.transition s₂ e₂
      { next := .phase2 t.next, actions := t.actions.map .right }

    | .phase2 s₂, _ => { next := .phase2 s₂, actions := [] }

  isTerminal := fun s =>
    match s with
    | .phase1 _ => false
    | .phase2 s₂ => m₂.isTerminal s₂

-- `MapActions`: transform actions without changing state or events
def Machine.mapActions {S E A A' : Type} (m : Machine S E A) (f : A → A') : Machine S E A' where
  initial := m.initial

  transition := fun s e =>
    let t := m.transition s e
    { next := t.next, actions := t.actions.map f }

  isTerminal := m.isTerminal

-- `ExtendState`: attach metadata that doesn't affect transitions
def Machine.extendState {S E A X : Type} (m : Machine S E A) (init : X) : Machine (S × X) E A where
  initial := (m.initial, init)

  transition := fun (s, x) e =>
    let t := m.transition s e
    { next := (t.next, x), actions := t.actions }

  isTerminal := fun (s, _) => m.isTerminal s

-- `WithState`: modify extended state based on transitions
def Machine.withState {S E A X : Type} (m : Machine S E A) (init : X) (update : S → E → X → X)
    : Machine (S × X) E A where
  initial := (m.initial, init)

  transition := fun (s, x) e =>
    let t := m.transition s e
    { next := (t.next, update s e x), actions := t.actions }

  isTerminal := fun (s, _) => m.isTerminal s

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                      // combinator // proofs
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

theorem product_left_preserves_right {S₁ S₂ E₁ E₂ A₁ A₂ : Type}
    (m₁ : Machine S₁ E₁ A₁) (m₂ : Machine S₂ E₂ A₂)
    (s₁ : S₁) (s₂ : S₂) (e₁ : E₁) :
    ((m₁.product m₂).transition (s₁, s₂) (.left e₁)).next =
    ((m₁.transition s₁ e₁).next, s₂) := by
  simp [Machine.product]

theorem product_right_preserves_left {S₁ S₂ E₁ E₂ A₁ A₂ : Type}
    (m₁ : Machine S₁ E₁ A₁) (m₂ : Machine S₂ E₂ A₂)
    (s₁ : S₁) (s₂ : S₂) (e₂ : E₂) :
    ((m₁.product m₂).transition (s₁, s₂) (.right e₂)).next =
    (s₁, (m₂.transition s₂ e₂).next) := by
  simp [Machine.product]

theorem sequential_handoff_requires_terminal {S₁ S₂ E₁ E₂ A₁ A₂ : Type}
    (m₁ : Machine S₁ E₁ A₁) (m₂ : Machine S₂ E₂ A₂) (s₁ : S₁) :
    ((m₁.sequential m₂).transition (.phase1 s₁) .handoff).next = .phase2 m₂.initial →
    m₁.isTerminal s₁ = true := by
  simp [Machine.sequential]
  intro h; by_cases ht : m₁.isTerminal s₁
  · exact ht
  · simp [ht] at h

theorem mapActions_preserves_next {S E A A' : Type}
    (m : Machine S E A) (f : A → A') (s : S) (e : E) :
    ((m.mapActions f).transition s e).next = (m.transition s e).next := by
  simp [Machine.mapActions]

-- TODO[b7r6]: !! the commented `NixDaemon`/`REAPI` protocol state
-- machines below represent a handshake layer that conflates protocol
-- versioning with operation dispatch. extract the pure combinator
-- kernel above and reify the protocol machines in a downstream module
-- that composes these combinators with concrete `ServerEvent`/`Action`
-- types. the current mix makes `StateMachine` impossible to test in
-- isolation !!

end Continuity.StateMachine.StateMachine
