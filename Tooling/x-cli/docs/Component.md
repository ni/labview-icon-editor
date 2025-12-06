# Component View (selected internals)

```mermaid
graph TD
  subgraph XCli
    CP[CommandParser]
    H1[EchoCommand]
    H2[ReverseCommand]
    H3[UpperCommand]
    SE[SimulationEngine]
    LG[InvocationLogger]
    IG[IsolationGuard]
    CL[ConfigLoader]
  end
  CP --> H1
  CP --> H2
  CP --> H3
  H1 --> SE
  H2 --> SE
  H3 --> SE
  SE --> LG
  IG -. guards .- H1
  IG -. guards .- SE
```

Testing seams

Commands unit‑tested (happy/negative paths); SimulationEngine boundary tests.

Logger JSON shape verified; IsolationGuard policy tests ensure no side‑effects.
