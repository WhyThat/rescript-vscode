let a = 12

let b = [1, 2, 3, a]

let c = <div />

let s = React.string

module M = {
  @react.component
  let make = (~x) => React.string(x)
}

let d = <M x="abc" />

module J = {
  @react.component
  export make = (~children: React.element) => React.null
}

let z = <J> {React.string("")} {React.string("")} </J>
