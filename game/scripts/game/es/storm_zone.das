require ecs


[es(tag=server, on_appear, track=inStormZone)]
def storm_zone_affects_update(evt : Event; eid : EntityId;
                              transform : float3x4;
                              var storm_zone__affectEids : EidList&;
                              storm_zone__affectTemplates : StringList;
                              inStormZone : bool)
  if inStormZone
    storm_zone__affectEids |> resize(length(storm_zone__affectTemplates))
    for affectEid, affectTemplate in storm_zone__affectEids, storm_zone__affectTemplates
      if !affectEid
        affectEid = createEntity(string(affectTemplate)) <| $(ini)
          ini |> set("game_effect__attachedTo", eid)
          ini |> set("transform", transform)
  else
    for affectEid in storm_zone__affectEids
      affectEid |> destroyEntity()
    storm_zone__affectEids |> clear()


[es(tag=server, on_disappear)]
def storm_zone_affects_destroy(evt : Event; storm_zone__affectEids : EidList)
  for affectEid in storm_zone__affectEids
    affectEid |> destroyEntity()


[es(tag=server, on_appear, track=(inStormZone, isAlive))]
def storm_zone_alive_affects_update(evt : Event; eid : EntityId;
                                    transform : float3x4;
                                    isAlive : bool;
                                    var storm_zone__aliveAffectEids : EidList&;
                                    storm_zone__aliveAffectTemplates : StringList;
                                    inStormZone : bool)
  if inStormZone && isAlive
    storm_zone__aliveAffectEids |> resize(length(storm_zone__aliveAffectTemplates))
    for affectEid, affectTemplate in storm_zone__aliveAffectEids, storm_zone__aliveAffectTemplates
      if !affectEid
        affectEid = createEntity(string(affectTemplate)) <| $(ini)
          ini |> set("game_effect__attachedTo", eid)
          ini |> set("transform", transform)
  else
    for affectEid in storm_zone__aliveAffectEids
      affectEid |> destroyEntity()
    storm_zone__aliveAffectEids |> clear()


[es(tag=server, on_disappear)]
def storm_zone_alive_affects_destroy(evt : Event; storm_zone__aliveAffectEids : EidList)
  for affectEid in storm_zone__aliveAffectEids
    affectEid |> destroyEntity()
