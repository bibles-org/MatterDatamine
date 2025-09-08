require ecs
require game.events.events_game
require game.es.action_common


[es(tag=gameClient, on_appear, track=isAlive)]
def lifetime_affects_client_init(evt : Event; eid : EntityId;
                                 transform : float3x4;
                                 isAlive : bool;
                                 var lifetime_affects_client__affectEids : EidList&;
                                 lifetime_affects_client__affectTemplates : StringList)
  if isAlive
    lifetime_affects_client__affectEids |> resize(length(lifetime_affects_client__affectTemplates))
    for affectEid, affectTemplate in lifetime_affects_client__affectEids, lifetime_affects_client__affectTemplates
      if !affectEid
        affectEid = createEntity(string(affectTemplate)) <| $(ini)
          ini |> set("game_effect__attachedTo", eid)
          ini |> set("transform", transform)
  else
    for affectEid in lifetime_affects_client__affectEids
      affectEid |> destroyEntity()
    lifetime_affects_client__affectEids |> clear()


[es(tag=gameClient, on_disappear)]
def lifetime_affects_client_destroy(evt : Event; lifetime_affects_client__affectEids : EidList)
  for affectEid in lifetime_affects_client__affectEids
    affectEid |> destroyEntity()


[es(tag=server, on_appear, track=isAlive)]
def lifetime_affects_server_init(evt : Event; eid : EntityId;
                                 transform : float3x4;
                                 isAlive : bool;
                                 var lifetime_affects_server__affectEids : EidList&;
                                 lifetime_affects_server__affectTemplates : StringList)
  if isAlive
    lifetime_affects_server__affectEids |> resize(length(lifetime_affects_server__affectTemplates))
    for affectEid, affectTemplate in lifetime_affects_server__affectEids, lifetime_affects_server__affectTemplates
      if !affectEid
        affectEid = createEntity(string(affectTemplate)) <| $(ini)
          ini |> set("game_effect__attachedTo", eid)
          ini |> set("transform", transform)
  else
    for affectEid in lifetime_affects_server__affectEids
      affectEid |> destroyEntity()
    lifetime_affects_server__affectEids |> clear()


[es(tag=server, on_disappear)]
def lifetime_affects_server_destroy(evt : Event; lifetime_affects_server__affectEids : EidList)
  for affectEid in lifetime_affects_server__affectEids
    affectEid |> destroyEntity()