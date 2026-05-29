

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                          // continuity // statemachine
                                                                                                                           statemachine.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Verified State Machine DSL.

  Determinism: transition is a function, not a relation.
  Safety: invalid (state, event) pairs are compile errors.
  Composition: product, sum, sequential combinators with proofs.

  The action types are protocol-level intents (sendServerHello,
  sendStderrLast). The mapping from intents to io_uring submissions
  is a separate concern at the event loop boundary.
-/

namespace Continuity.StateMachine


/- ════════════════════════════════════════════════════════════════════════════════
                                                                       // core
   ════════════════════════════════════════════════════════════════════════════════ -/

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


/- ════════════════════════════════════════════════════════════════════════════════
                                                               // combinators
   ════════════════════════════════════════════════════════════════════════════════ -/

inductive Either (α β : Type) where
  | left : α → Either α β
  | right : β → Either α β
  deriving Repr, DecidableEq

/-- Product: run two machines in parallel on tagged events. -/
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

/-- Sum: choose between two machines based on initial event. -/
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

/-- Sequential: run m₁ until terminal, handoff to m₂. -/
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

/-- MapActions: transform actions without changing state or events. -/
def Machine.mapActions {S E A A' : Type} (m : Machine S E A) (f : A → A') : Machine S E A' where
  initial := m.initial
  transition := fun s e =>
    let t := m.transition s e
    { next := t.next, actions := t.actions.map f }
  isTerminal := m.isTerminal

/-- ExtendState: attach metadata that doesn't affect transitions. -/
def Machine.extendState {S E A X : Type} (m : Machine S E A) (init : X) : Machine (S × X) E A where
  initial := (m.initial, init)
  transition := fun (s, x) e =>
    let t := m.transition s e
    { next := (t.next, x), actions := t.actions }
  isTerminal := fun (s, _) => m.isTerminal s

/-- WithState: modify extended state based on transitions. -/
def Machine.withState {S E A X : Type} (m : Machine S E A) (init : X) (update : S → E → X → X)
    : Machine (S × X) E A where
  initial := (m.initial, init)
  transition := fun (s, x) e =>
    let t := m.transition s e
    { next := (t.next, update s e x), actions := t.actions }
  isTerminal := fun (s, _) => m.isTerminal s


/- ════════════════════════════════════════════════════════════════════════════════
                                                        // combinator proofs
   ════════════════════════════════════════════════════════════════════════════════ -/

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


/- ════════════════════════════════════════════════════════════════════════════════
                                                   // protocol version
   ════════════════════════════════════════════════════════════════════════════════ -/

structure ProtocolVersion where
  value : UInt64
  deriving Repr, DecidableEq

namespace ProtocolVersion
  def make (major minor : Nat) : ProtocolVersion :=
    ⟨((major.toUInt64 <<< 8) ||| minor.toUInt64)⟩
  def major (v : ProtocolVersion) : Nat := (v.value >>> 8).toNat
  def minor (v : ProtocolVersion) : Nat := (v.value &&& 0xFF).toNat
  def supports (v : ProtocolVersion) (minMinor : Nat) : Bool := v.minor >= minMinor
  def current : ProtocolVersion := make 1 38
  def minimum : ProtocolVersion := make 1 10
end ProtocolVersion

inductive Feature where
  | reapiV2 | casSha256 | streamingNar | signedNarinfo
  deriving Repr, DecidableEq, Hashable

inductive TrustLevel where
  | unknown | trusted | untrusted
  deriving Repr, DecidableEq

structure ReapiConfig where
  instanceName : String
  digestFunction : Nat
  deriving Repr, DecidableEq

structure HandshakeConfig where
  serverVersion : ProtocolVersion
  serverFeatures : List Feature
  reapiConfig : Option ReapiConfig
  daemonVersion : String
  trustLevel : TrustLevel
  deriving Repr

def HandshakeConfig.default : HandshakeConfig := {
  serverVersion := ProtocolVersion.current
  serverFeatures := [.reapiV2, .casSha256, .streamingNar]
  reapiConfig := some { instanceName := "main", digestFunction := 0 }
  daemonVersion := "nix-serve-cas 0.1.0"
  trustLevel := .trusted
}


/- ════════════════════════════════════════════════════════════════════════════════
                                                    // server handshake
   ════════════════════════════════════════════════════════════════════════════════ -/

inductive ServerState where
  | init (config : HandshakeConfig)
  | versioned (config : HandshakeConfig) (negotiated : ProtocolVersion)
  | features (config : HandshakeConfig) (negotiated : ProtocolVersion) (active : List Feature)
  | upgrading (config : HandshakeConfig) (negotiated : ProtocolVersion) (active : List Feature)
  | nixReady (version : ProtocolVersion)
  | reapiReady (config : ReapiConfig)
  | failed (reason : String)
  deriving Repr

inductive ServerEvent where
  | clientHello (clientVersion : ProtocolVersion)
  | clientLegacy
  | clientFeatures (features : List Feature)
  | clientUpgradeResponse (accept : Bool)
  deriving Repr

inductive ServerAction where
  | sendServerHello (version : ProtocolVersion)
  | sendDaemonVersion (version : String)
  | sendTrustLevel (level : TrustLevel)
  | sendFeatures (features : List Feature)
  | sendUpgradeOffer
  | sendReapiConfig (config : ReapiConfig)
  | ready
  | fail (reason : String)
  deriving Repr

def featureIntersection (a b : List Feature) : List Feature :=
  a.filter (b.contains ·)

def shouldOfferUpgrade (config : HandshakeConfig) (active : List Feature) : Bool :=
  active.contains .reapiV2 && config.reapiConfig.isSome

def serverTransition : ServerState → ServerEvent → Transition ServerState ServerAction

  | .init config, .clientHello clientVer =>
    let negotiated := if clientVer.value < config.serverVersion.value
                      then clientVer else config.serverVersion
    { next := .versioned config negotiated
    , actions := [.sendServerHello config.serverVersion] }

  | .versioned config negotiated, .clientLegacy =>
    if negotiated.supports 38 then
      let actions :=
        (if negotiated.supports 33 then [.sendDaemonVersion config.daemonVersion] else []) ++
        (if negotiated.supports 35 then [.sendTrustLevel config.trustLevel] else [])
      { next := .versioned config negotiated, actions := actions }
    else
      let actions :=
        (if negotiated.supports 33 then [.sendDaemonVersion config.daemonVersion] else []) ++
        (if negotiated.supports 35 then [.sendTrustLevel config.trustLevel] else []) ++
        [.ready]
      { next := .nixReady negotiated, actions := actions }

  | .versioned config negotiated, .clientFeatures clientFeatures =>
    let active := featureIntersection config.serverFeatures clientFeatures
    if shouldOfferUpgrade config active then
      { next := .upgrading config negotiated active
      , actions := [.sendFeatures config.serverFeatures, .sendUpgradeOffer] }
    else
      { next := .nixReady negotiated
      , actions := [.sendFeatures config.serverFeatures, .ready] }

  | .upgrading config _ _, .clientUpgradeResponse accept =>
    if accept then
      match config.reapiConfig with
      | some rc => { next := .reapiReady rc, actions := [.sendReapiConfig rc, .ready] }
      | none => { next := .failed "REAPI config missing", actions := [.fail "REAPI config missing"] }
    else
      { next := .nixReady (config.serverVersion), actions := [.ready] }

  | .nixReady _, _ =>
    { next := .failed "Already terminal", actions := [.fail "Already terminal"] }
  | .reapiReady _, _ =>
    { next := .failed "Already terminal", actions := [.fail "Already terminal"] }
  | .failed reason, _ =>
    { next := .failed reason, actions := [] }
  | _, _ =>
    { next := .failed "Invalid transition", actions := [.fail "Invalid transition"] }

def serverHandshake (config : HandshakeConfig) : Machine ServerState ServerEvent ServerAction := {
  initial := .init config
  transition := serverTransition
  isTerminal := fun s => match s with
    | .nixReady _ | .reapiReady _ | .failed _ => true
    | _ => false
}


/- ════════════════════════════════════════════════════════════════════════════════
                                                    // client handshake
   ════════════════════════════════════════════════════════════════════════════════ -/

inductive ClientState where
  | init (clientVersion : ProtocolVersion) (clientFeatures : List Feature)
  | sentHello (clientVersion : ProtocolVersion) (clientFeatures : List Feature)
  | versioned (negotiated : ProtocolVersion) (clientFeatures : List Feature)
  | awaitingUpgrade (negotiated : ProtocolVersion)
  | nixReady (version : ProtocolVersion)
  | reapiReady (config : ReapiConfig)
  | failed (reason : String)
  deriving Repr

inductive ClientEvent where
  | serverHello (version : ProtocolVersion)
  | serverDaemonVersion (version : String)
  | serverTrustLevel (level : TrustLevel)
  | serverFeatures (features : List Feature)
  | upgradeOffer
  | reapiConfig (config : ReapiConfig)
  deriving Repr

inductive ClientAction where
  | sendClientHello (version : ProtocolVersion)
  | sendLegacyFields
  | sendFeatures (features : List Feature)
  | sendUpgradeResponse (accept : Bool)
  | ready
  | fail (reason : String)
  deriving Repr

def clientTransition : ClientState → ClientEvent → Transition ClientState ClientAction

  | .sentHello clientVer clientFeatures, .serverHello serverVer =>
    let negotiated := if clientVer.value < serverVer.value then clientVer else serverVer
    { next := .versioned negotiated clientFeatures, actions := [.sendLegacyFields] }

  | .versioned negotiated features, .serverDaemonVersion _ =>
    { next := .versioned negotiated features, actions := [] }

  | .versioned negotiated features, .serverTrustLevel _ =>
    { next := .versioned negotiated features, actions := [] }

  | .versioned negotiated clientFeatures, .serverFeatures serverFeatures =>
    let active := featureIntersection clientFeatures serverFeatures
    if active.contains .reapiV2 then
      { next := .awaitingUpgrade negotiated, actions := [.sendFeatures clientFeatures] }
    else
      { next := .nixReady negotiated, actions := [.sendFeatures clientFeatures, .ready] }

  | .awaitingUpgrade negotiated, .upgradeOffer =>
    { next := .awaitingUpgrade negotiated, actions := [.sendUpgradeResponse true] }

  | .awaitingUpgrade _, .reapiConfig config =>
    { next := .reapiReady config, actions := [.ready] }

  | .nixReady _, _ => { next := .failed "Already terminal", actions := [] }
  | .reapiReady _, _ => { next := .failed "Already terminal", actions := [] }
  | .failed reason, _ => { next := .failed reason, actions := [] }
  | _, _ => { next := .failed "Invalid transition", actions := [.fail "Invalid transition"] }

def clientHandshake (clientVersion : ProtocolVersion) (features : List Feature)
    : Machine ClientState ClientEvent ClientAction := {
  initial := .init clientVersion features
  transition := clientTransition
  isTerminal := fun s => match s with
    | .nixReady _ | .reapiReady _ | .failed _ => true
    | _ => false
}


/- ════════════════════════════════════════════════════════════════════════════════
                                                    // daemon operation loop
   ════════════════════════════════════════════════════════════════════════════════ -/

inductive DaemonOpState where
  | awaitingOp (version : ProtocolVersion)
  | processing (version : ProtocolVersion) (op : String)
  | sendingStderr (version : ProtocolVersion) (op : String)
  | sendingResult (version : ProtocolVersion) (op : String)
  | opComplete (version : ProtocolVersion)
  | opFailed (version : ProtocolVersion) (reason : String)
  deriving Repr

inductive DaemonOpEvent where
  | clientOp (op : String)
  | processComplete (success : Bool)
  | stderrSent
  | stderrComplete
  | resultSent
  | clientDisconnect
  deriving Repr

inductive DaemonOpAction where
  | beginProcess (op : String)
  | sendStderrLast
  | sendResult (success : Bool)
  | sendError (reason : String)
  | ready
  deriving Repr

def daemonOpTransition : DaemonOpState → DaemonOpEvent → Transition DaemonOpState DaemonOpAction
  | .awaitingOp ver, .clientOp op =>
    { next := .processing ver op, actions := [.beginProcess op] }
  | .processing ver op, .processComplete success =>
    if success then { next := .sendingStderr ver op, actions := [] }
    else { next := .opFailed ver "Operation failed", actions := [.sendError "Operation failed"] }
  | .sendingStderr ver op, .stderrSent =>
    { next := .sendingStderr ver op, actions := [] }
  | .sendingStderr ver op, .stderrComplete =>
    { next := .sendingResult ver op, actions := [.sendStderrLast] }
  | .sendingResult ver _, .resultSent =>
    { next := .opComplete ver, actions := [.ready] }
  | .opComplete ver, .clientOp op =>
    { next := .processing ver op, actions := [.beginProcess op] }
  | _, .clientDisconnect =>
    { next := .opFailed ProtocolVersion.current "Client disconnected", actions := [] }
  | .opFailed ver reason, _ =>
    { next := .opFailed ver reason, actions := [] }
  | _, _ =>
    { next := .opFailed ProtocolVersion.current "Invalid daemon op transition"
    , actions := [.sendError "Protocol error"] }

def daemonOps (version : ProtocolVersion) : Machine DaemonOpState DaemonOpEvent DaemonOpAction := {
  initial := .awaitingOp version
  transition := daemonOpTransition
  isTerminal := fun s => match s with | .opFailed _ _ => true | _ => false
}


/- ════════════════════════════════════════════════════════════════════════════════
                                                    // composed daemon
   ════════════════════════════════════════════════════════════════════════════════ -/

abbrev DaemonEvent := SeqEvent ServerEvent DaemonOpEvent
abbrev DaemonAction := Either ServerAction DaemonOpAction

def daemonMachine (config : HandshakeConfig)
    : Machine (SeqState ServerState DaemonOpState) DaemonEvent DaemonAction :=
  (serverHandshake config).sequential (daemonOps config.serverVersion)


/- ════════════════════════════════════════════════════════════════════════════════
                                                              // proofs
   ════════════════════════════════════════════════════════════════════════════════ -/

theorem server_terminal_stays_terminal (config : HandshakeConfig)
    (s : ServerState) (e : ServerEvent) :
    (serverHandshake config).isTerminal s = true →
    (serverHandshake config).isTerminal ((serverHandshake config).transition s e).next = true := by
  intro h; simp [serverHandshake] at h ⊢
  match s with
  | .nixReady _ => simp [serverTransition]
  | .reapiReady _ => simp [serverTransition]
  | .failed _ => simp [serverTransition]
  | .init _ | .versioned _ _ | .features _ _ _ | .upgrading _ _ _ => simp at h


/- ════════════════════════════════════════════════════════════════════════════════
                                                           // test traces
   ════════════════════════════════════════════════════════════════════════════════ -/

def exampleReapiHandshake : List ServerEvent :=
  [ .clientHello ProtocolVersion.current
  , .clientFeatures [.reapiV2, .casSha256]
  , .clientUpgradeResponse true ]

def exampleDaemonTrace : List DaemonEvent :=
  [ .ev1 (.clientHello ProtocolVersion.current)
  , .ev1 (.clientFeatures [.reapiV2])
  , .ev1 (.clientUpgradeResponse true)
  , .handoff
  , .ev2 (.clientOp "isValidPath")
  , .ev2 (.processComplete true)
  , .ev2 .stderrComplete
  , .ev2 .resultSent ]

#eval
  let m := daemonMachine HandshakeConfig.default
  let (finalState, actions) := m.run exampleDaemonTrace
  (repr finalState, actions.length)

end Continuity.StateMachine
