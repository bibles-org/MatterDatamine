require ecs
require math.base
require game.events.events_game


[es(tag=server)]
def unit_death_spawner(evt : EventEntityDied;
                       eid : EntityId;
                       transform : float3x4;
                       unit__deathSpawner : StringList)
  var tm = IDENT_TM
  tm[3] = transform[3]
  for entityTemplate in unit__deathSpawner
    createEntity(string(entityTemplate)) <| $(var init)
      init |> set("transform", tm)
      init |> set("ownerEid", eid)