require ecs
require DngHuman
require math
require game.events.events_active_matter


[es(before=human_phys_es)]
def human_in_spawn_speed_es(ecs : ParallelUpdateFrameDelayed; var human_net_phys : HumanActor; in_spawn : bool)
  if !in_spawn
    return
  // TODO: move to entity_mods and apply with proper multiplier (setup in entity)
  human_net_phys.phys.currentState.moveSpeedMult = min(human_net_phys.phys.currentState.moveSpeedMult * 1.5, 1e+10)