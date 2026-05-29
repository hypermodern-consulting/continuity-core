# State Machine

## Core

A state machine is a transition function with terminal state detection:

```lean
structure Machine (S E A : Type) where
  initial : S
  transition : S → E → Transition S A
  isTerminal : S → Bool
```

Determinism is free: `transition` is a function, not a relation. Every
(state, event) pair has exactly one outcome by construction.

## Combinators

| Combinator | What it does |
|-----------|-------------|
| `product` | Run two machines in parallel on tagged events |
| `sum` | Choose between two machines based on first event |
| `sequential` | Run m₁ until terminal, then handoff to m₂ |
| `mapActions` | Transform actions without changing states |
| `extendState` | Attach metadata that doesn't affect transitions |
| `withState` | Modify extended state based on transitions |

## Nix Daemon

The full Nix daemon protocol is modeled as a composed machine:

```lean
def daemonMachine (config : HandshakeConfig) :=
  (serverHandshake config).sequential (daemonOps config.serverVersion)
```

Phase 1 (handshake): version negotiation, feature intersection, REAPI upgrade.
Phase 2 (operations): awaitingOp → processing → sendingStderr → sendingResult → opComplete.

The actions are protocol-level intents: `sendServerHello`, `sendFeatures`,
`sendStderrLast`. The mapping from intents to io_uring submissions is
the event loop's concern — the state machine doesn't know what a ring is.
