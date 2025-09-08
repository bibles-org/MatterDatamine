require ecs
require game.events.events_active_matter
require DngPhysObj
require math.base
require DagorMath


// fx fire for airdrop and assistant phrase
[es(tag=gameClient, REQUIRE=airdrop, on_appear)]
def create_fire_fx_airdrop_on_appear(evt : Event;
                                     airdrop__assistantScript : string;
                                     airdrop__initialPosition : float3;
                                     airdrop__fireFxTemplate : string;
                                     var airdrop__fireFxEid : EntityId&)
  query() <| $[es] (watchedByPlr : EntityId)
    sendEvent(watchedByPlr, CmdStartAssistantSpeak(scriptName = airdrop__assistantScript, skipBeepSound = true))
  airdrop__fireFxEid = createEntity(airdrop__fireFxTemplate) <| $(init)
    var init_transform = IDENT_TM
    init_transform[3] = airdrop__initialPosition
    init |> set("transform", init_transform)


[es(tag=render, REQUIRE=airdrop, no_order)]
def update_position_fire_fx_airdrop(info : ParallelUpdateFrameDelayed;
                                    airdrop__initialPosition : float3;
                                    phys_obj_net_phys : PhysObjActor;
                                    first_contact_listener__hadContact : bool;
                                    airdrop__groundingFxTemplate : string;
                                    var airdrop__fireFxEid : EntityId&)
  if first_contact_listener__hadContact
    if airdrop__fireFxEid != INVALID_ENTITY_ID
      destroyEntity(airdrop__fireFxEid)
      airdrop__fireFxEid = INVALID_ENTITY_ID
      createEntity(airdrop__groundingFxTemplate) <| $(init)
        var init_transform = IDENT_TM
        init_transform[3] = float3(phys_obj_net_phys.phys.currentState.location.P)
        init |> set("transform", init_transform)
  else
    query(airdrop__fireFxEid) <| $[es] (var transform aka fx_transform : float3x4&)
      let forward = normalize(phys_obj_net_phys.phys.currentState.velocity)
      var up = float3(0.0, 1.0, 0.0)
      let right = cross(forward, up)
      up = cross(forward, right)
      var newTransform = IDENT_TM
      newTransform[0] = forward
      newTransform[1] = up
      newTransform[2] = right
      newTransform[3] = float3(phys_obj_net_phys.phys.currentState.location.P)
      if newTransform[3] == float3()
        newTransform[3] = airdrop__initialPosition
      fx_transform = newTransform


// fx smoke on ground for airdrop
[es(tag=render, REQUIRE=airdrop, no_order)]
def update_signal_smoke_fx_airdrop(info : ParallelUpdateFrameDelayed;
                                   transform aka airdrop_transform : float3x4;
                                   airdrop__smokeOnGroundTemplate : string;
                                   airdrop__smokeOnGroundDestoyAt : float;
                                   var airdrop__smokeFxEid : EntityId&)
  if info.curTime < airdrop__smokeOnGroundDestoyAt
    if airdrop__smokeFxEid == INVALID_ENTITY_ID
      airdrop__smokeFxEid = createEntity(airdrop__smokeOnGroundTemplate) <| $(init)
        var init_transform = IDENT_TM
        init_transform[3] = airdrop_transform[3]
        init |> set("transform", init_transform)
    else
      query(airdrop__smokeFxEid) <| $[es] (var transform aka smoke_transform : float3x4&)
        smoke_transform[3] = airdrop_transform[3]
  elif info.curTime > airdrop__smokeOnGroundDestoyAt && airdrop__smokeFxEid != INVALID_ENTITY_ID
    destroyEntity(airdrop__smokeFxEid)
    airdrop__smokeFxEid = INVALID_ENTITY_ID
