require ecs
require game.events.events_active_matter

[es(tag=server, after=dmgzone_es)]
def decay_zone_fire_damage_resistance(info : ParallelUpdateFrameDelayed;
                                      dmgzone_fire_resistance__decayInterval : float;
                                      var dmgzone_fire_resistance__currentTicks : int&;
                                      var dmgzone_fire_resistance__lastTickAt : float&)
  if dmgzone_fire_resistance__currentTicks <= 0 || dmgzone_fire_resistance__lastTickAt + dmgzone_fire_resistance__decayInterval > info.curTime
    return

  dmgzone_fire_resistance__lastTickAt = info.curTime
  dmgzone_fire_resistance__currentTicks -= 1