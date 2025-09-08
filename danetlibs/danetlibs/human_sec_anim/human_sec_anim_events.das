module human_sec_anim_events shared
require ecs

[cpp_event(unicast, with_scheme)]
struct CmdStartSecAnim
  startTime : float

[cpp_event(unicast, with_scheme)]
struct CmdStopSecAnim
  immediately : bool
