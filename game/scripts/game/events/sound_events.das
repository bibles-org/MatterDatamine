module sound_events shared
require ecs

[cpp_event(unicast)]
struct CmdSoundMeleeIrq
  irq : string

[event(unicast)]
struct CmdStartTinnitusSfx
  pos : float3
  power : float

[event(unicast)]
struct CmdSoundGenIrqSim
  irq : string
