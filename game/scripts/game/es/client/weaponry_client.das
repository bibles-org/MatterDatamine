require ecs
require game.events.events_game
require DngWeaponRender
require DaWeapons
require game.events.events_active_matter


[es(tag=render, no_order)]
def gun_flash_fx_check_destruction_time(info : ParallelUpdateFrameDelayed; eid : EntityId; var gun_flash_fx__timeToDestroy : float&)
  gun_flash_fx__timeToDestroy -= info.dt
  if gun_flash_fx__timeToDestroy <= 0.
    destroyEntity(eid)