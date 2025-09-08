require ecs
require app
require strings
require DagorMath
require game.events.events_game
require game.events.events_active_matter
require AnimV20
require GeomNodeTree


[es(tag=server, REQUIRE=game_effect__destroyWithAttachedTo)]
def cleanup_attached_affects(evt : EventAnyEntityDied; eid, game_effect__attachedTo : EntityId)
  if evt.victim == game_effect__attachedTo
    eid |> destroyEntity()


[es(tag=server, REQUIRE=game_effect__destroyWithOwner)]
def cleanup_owned_affects(evt : EventAnyEntityDied; eid, game_effect__ownerEid : EntityId)
  if evt.victim == game_effect__ownerEid
    eid |> destroyEntity()


[es(tag=server, no_order, REQUIRE=game_effect__followOwnerPos)]
def affects_follow_owner(act : UpdateStageInfoAct;
                         game_effect__ownerEid : EntityId;
                         game_effect__followTargetOffset = float3();
                         var transform aka follow_transform : float3x4&)
  query(game_effect__ownerEid) <| $ [es] (transform : float3x4&)
    follow_transform[3] = transform[3]
    follow_transform[3] += transform |> rotate(game_effect__followTargetOffset)


[es(tag=server, no_order, REQUIRE=game_effect__followAiTargetNode)]
def affects_follow_ai_target_node(act : UpdateStageInfoAct;
                                  game_effect__ownerEid : EntityId;
                                  game_effect__followTargetOffset = float3();
                                  var transform aka follow_transform : float3x4&)
  query(game_effect__ownerEid) <| $ [es] (transform : float3x4;
                                          animchar : AnimcharBaseComponent;
                                          navmesh_phys__currentLookDir : float3 const?;
                                          ai_target_node__nodeId : int)
    follow_transform[3] = *animchar.nodeTree |> geomtree_getNodeWpos(ai_target_node__nodeId)
    if navmesh_phys__currentLookDir != null
      let lookQuat = dir_to_quat(*navmesh_phys__currentLookDir)
      follow_transform[3] += lookQuat * game_effect__followTargetOffset
    else
      follow_transform[3] += transform |> rotate(game_effect__followTargetOffset)


[es(tag=server)]
def apply_extra_affect(evt : ApplyGameAffect; eid : EntityId;
                       game_effect__affectUniqueKeyName = "";
                       game_effect__applyGameEffectTemplate : string;
                       game_effect__attachedAt : float const?;
                       game_effect__ownerEid : EntityId const?)
  var create = true
  if !empty(game_effect__affectUniqueKeyName)
    find_query() <| $ [es] (game_effect__affectUniqueKey : string; game_effect__attachedTo : EntityId)
      create = evt.targetEid != game_effect__attachedTo || game_effect__affectUniqueKey != game_effect__affectUniqueKeyName
      return !create
  if !create
    return

  createEntity(game_effect__applyGameEffectTemplate) <| $(init)
    init |> set("game_effect__attachedTo", evt.targetEid)
    init |> set("game_effect__attachedAt", game_effect__attachedAt ?? get_sync_time())
    init |> set("game_effect__ownerEid", game_effect__ownerEid ?? eid)
    if !empty(game_effect__affectUniqueKeyName)
      init |> set("game_effect__affectUniqueKey", game_effect__affectUniqueKeyName)


[es(tag=gameClient)]
def apply_extra_affect_client(evt : ApplyGameAffect; eid : EntityId;
                              game_effect__affectUniqueKeyName = "";
                              game_effect__clientApplyGameEffectTemplate : string;
                              game_effect__attachedAt : float const?;
                              game_effect__ownerEid : EntityId const?)
  var create = true
  if !empty(game_effect__affectUniqueKeyName)
    find_query() <| $ [es] (game_effect__affectUniqueKey : string; game_effect__attachedTo : EntityId)
      create = evt.targetEid != game_effect__attachedTo || game_effect__affectUniqueKey != game_effect__affectUniqueKeyName
      return !create
  if !create
    return

  createEntity(game_effect__clientApplyGameEffectTemplate) <| $(init)
    init |> set("game_effect__attachedTo", evt.targetEid)
    init |> set("game_effect__attachedAt", game_effect__attachedAt ?? get_sync_time())
    init |> set("game_effect__ownerEid", game_effect__ownerEid ?? eid)
    if !empty(game_effect__affectUniqueKeyName)
      init |> set("game_effect__affectUniqueKey", game_effect__affectUniqueKeyName)


[es(tag=render, no_order)]
def client_affect_update(act : UpdateStageInfoAct; eid : EntityId;
                         game_effect__attachedTo, game_effect__ownerEid : EntityId const?;
                         game_effect__attachedAt : float const?;
                         game_effect__clientHeroAffectTemplate : string;
                         game_effect__clientHeroAffectUniqueTag : string = "";
                         var game_effect__clientHeroAffectEid : EntityId&)
  let attachTo = game_effect__attachedTo ?? eid
  if has(attachTo, "watchedByPlr")
    var create = true
    query(game_effect__clientHeroAffectEid) <| $ [es] (eid : EntityId; game_effect__attachedTo : EntityId)
      create = attachTo != game_effect__attachedTo
      if create
        eid |> destroyEntity()

    if !empty(game_effect__clientHeroAffectUniqueTag)
      let game_effect__clientHeroAffectUniqueTagHash = ecs_hash(game_effect__clientHeroAffectUniqueTag)
      find_query() <| $ [es] (eid : EntityId; game_effect__attachedTo : EntityId)
        create = attachTo != game_effect__attachedTo || !has(eid, game_effect__clientHeroAffectUniqueTag, game_effect__clientHeroAffectUniqueTagHash)
        return !create

    if create
      game_effect__clientHeroAffectEid = createEntity(game_effect__clientHeroAffectTemplate) <| $(ini)
        ini |> set("game_effect__attachedTo", attachTo)
        ini |> set("game_effect__attachedAt", game_effect__attachedAt ?? act.curTime)
        ini |> set("game_effect__ownerEid", game_effect__ownerEid ?? eid)
  elif game_effect__clientHeroAffectEid != INVALID_ENTITY_ID
    game_effect__clientHeroAffectEid |> destroyEntity()
    game_effect__clientHeroAffectEid = INVALID_ENTITY_ID


[es(tag=render, on_disappear)]
def client_affect_destroy(evt : Event; game_effect__clientHeroAffectEid : EntityId;
                          game_effect__clientHeroAffectDestroyTemplate : das_string const?)
  if game_effect__clientHeroAffectDestroyTemplate != null
    game_effect__clientHeroAffectEid |> addSubTemplate(string(*game_effect__clientHeroAffectDestroyTemplate))
  else
    game_effect__clientHeroAffectEid |> destroyEntity()