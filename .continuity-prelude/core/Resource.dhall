let Resource : Type = < Pure | Network | Auth : Text | Sandbox : Text | Filesystem : Text >

in  let Resources : Type = List Resource

in  let pure = [] : List Resource

in  let network = [ Resource.Network ]

in  let auth = λ(provider : Text) → [ Resource.Auth provider ]

in  let combine = λ(r : Resources) → λ(s : Resources) → r # s

in  { Resource = Resource
, Resources = Resources
, pure = pure
, network = network
, auth = auth
, combine = combine
}
