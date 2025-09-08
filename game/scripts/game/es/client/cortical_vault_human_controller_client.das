require ecs
require ecs.safe
require app
require math.base
require math
require DagorMath
require AnimV20
require GeomNodeTree
require DagorInput
require DngNet
require game.events.events
require game.events.events_active_matter
require game.es.cortical_vault_human_controller_common


def get_hacking_cortical_vault_client_timeout()
  return 3.0


def get_channeling_start_position(animchar : AnimcharBaseComponent;
                                  hacking_cortical_vault_client__channelingNodeId : int)
  return geomtree_getNodeWpos(*animchar.nodeTree, hacking_cortical_vault_client__channelingNodeId)


[es(tag=gameClient, no_order)]
def draw_human_hacking_cortical_vault_effect(update : ParallelUpdateFrameDelayed;
                                             human_hacking_cortical_vault_effect__pointEid : EntityId;
                                             human_hacking_cortical_vault_effect__flySpeed : float;
                                             human_hacking_cortical_vault_effect__requiredDistanceToTarget : float;
                                             human_hacking_cortical_vault_effect__target : EntityId;
                                             human_hacking_cortical_vault_effect__owner : EntityId)
  query(human_hacking_cortical_vault_effect__owner) <| $ [es] (animchar : AnimcharBaseComponent;
                                                               hacking_cortical_vault_client__channelingNodeId : int)
    query(human_hacking_cortical_vault_effect__pointEid) <| $ [es] (var transform aka point_transform : float3x4&)
      query(human_hacking_cortical_vault_effect__target) <| $ [es] (transform aka target_transform : float3x4&)
        let dir = target_transform[3] - point_transform[3]
        let len = length(dir)
        if len > human_hacking_cortical_vault_effect__requiredDistanceToTarget
          let speed = human_hacking_cortical_vault_effect__flySpeed * update.dt
          let move = dir * safediv(speed, len)
          point_transform[3] += move
        else
          point_transform[3] = get_channeling_start_position(animchar, hacking_cortical_vault_client__channelingNodeId)


[es(tag=gameClient, on_disappear)]
def cleanup_human_hacking_cortical_vault_effect_point(evt : Event; human_hacking_cortical_vault_effect__pointEid : EntityId)
  destroyEntity(human_hacking_cortical_vault_effect__pointEid)


[es(tag=gameClient, on_appear)]
def init_human_hacking_cortical_vault_effect_point(evt : Event;
                                                   human_hacking_cortical_vault_effect__owner : EntityId;
                                                   var human_hacking_cortical_vault_effect__pointEid : EntityId&)
  query(human_hacking_cortical_vault_effect__owner) <| $ [es] (animchar : AnimcharBaseComponent;
                                                               hacking_cortical_vault_client__channelingNodeId : int)
    human_hacking_cortical_vault_effect__pointEid = createEntity("human_hacking_cortical_vault_effect_point") <| $(init)
      var tm = IDENT_TM
      tm[3] = get_channeling_start_position(animchar, hacking_cortical_vault_client__channelingNodeId)
      init |> set("transform", tm)


def update_militant_ragdoll_phys_obj_alt_use(actor_eid : EntityId;
                                             militant_ragdoll_phys_obj_eid : EntityId)
  query(militant_ragdoll_phys_obj_eid) <| $ [es(REQUIRE=militant_ragdoll_phys_obj)] (var item__setCustomUseAltPrompt : das_string)
    item__setCustomUseAltPrompt := ""
    let useOption = calculate_militant_ragdoll_phys_obj_use_option(actor_eid, militant_ragdoll_phys_obj_eid)

    if useOption == CorticalVaultHumanControllerUseOption.HACK_CORTICAL_VAULT
      item__setCustomUseAltPrompt := "hint/hack_cortical_vault"
    elif useOption == CorticalVaultHumanControllerUseOption.GATHER_AM
      item__setCustomUseAltPrompt := "items/active_matter_pile/pickup"


[es(tag=gameClient, track=(human_use_object__selectedObject, cortical_vault_human_controller__hackingProcessEid),
  REQUIRE=(watchedByPlr, cortical_vault_human_controller__hackingProcessEid))]
def hero_track_cortical_vault_human_controller_selected(evt : Event;
                                                        eid aka actor_eid : EntityId;
                                                        human_use_object__selectedObject : EntityId)
  update_militant_ragdoll_phys_obj_alt_use(actor_eid, human_use_object__selectedObject)


[es(tag=gameClient, REQUIRE=active_matter_pile_provider, on_appear, on_disappear)]
def update_militant_ragdoll_phys_obj_alt_use_on_active_matter_pile_provider_state_changed(evt : Event;
                                                                                          eid aka ragdoll_eid : EntityId)
  query() <| $ [es(REQUIRE=watchedByPlr)] (eid aka actor_eid : EntityId)
    update_militant_ragdoll_phys_obj_alt_use(actor_eid, ragdoll_eid)


[es(tag=gameClient, REQUIRE=militant_ragdoll_phys_obj)]
def update_militant_ragdoll_phys_obj_alt_use_on_exhausted(evt : EventActiveMatterPileProviderExhausted;
                                                          active_matter_pile_provider__amSourceEid : EntityId;
                                                          eid aka ragdoll_eid : EntityId)
  query(active_matter_pile_provider__amSourceEid) <| $ [es] (var am_storage__value : int&)
    am_storage__value = 0
  query() <| $ [es(REQUIRE=watchedByPlr)] (eid aka actor_eid : EntityId)
    update_militant_ragdoll_phys_obj_alt_use(actor_eid, ragdoll_eid)


[es(tag=gameClient)]
def cortical_vault_hacked_client(evt : EventAmStorageHacked)
  query(evt.ragdollPhysObjEid) <| $ [es] (var am_storage__hacked : bool&)
    am_storage__hacked = true

    query(evt.hackerActorEid) <| $ [es(REQUIRE=watchedByPlr)] ()
      sendEvent(
        evt.hackerActorEid,
        CmdHeroLogExEventLocal(event = "", key = "hint/you_hacked_cortical_vault"))

  query() <| $ [es(REQUIRE=watchedByPlr)] (eid aka actor_eid : EntityId)
    if evt.hackerActorEid != actor_eid
      sendEvent(
        actor_eid,
        CmdHeroLogExEventLocal(event = "", key = "hint/hacked_cortical_vault_detected"))


[es(tag=input, REQUIRE=hacking_cortical_vault_client)]
def client_sustain_hacking_cortical_vault_process(act : UpdateStageUpdateInput;
                                                  eid : EntityId;
                                                  human_input__use : int;
                                                  hacking_cortical_vault_client__timeoutAt : float;
                                                  cortical_vault_human_controller__hackingProcessEid : EntityId;
                                                  cortical_vault_human_controller__clientTemplate : string;
                                                  var hacking_cortical_vault_client__removed : bool&)
  if hacking_cortical_vault_client__removed
    return

  let isTimeout = (act.curTime > hacking_cortical_vault_client__timeoutAt &&
                  cortical_vault_human_controller__hackingProcessEid == INVALID_ENTITY_ID)

  let handle = uint16(human_input__use)
  let btnPressed = is_action_active(handle) && get_digital_action_state(handle).bState
  if !btnPressed || isTimeout
    removeSubTemplate(eid, cortical_vault_human_controller__clientTemplate)
    send_net_event(eid, CmdHumanStopHackingCorticalVaultRequest())
    hacking_cortical_vault_client__removed = true
    return


[es(tag=gameClient, on_appear)]
def hacking_cortical_vault_client_appear(evt : Event;
                                         eid aka actor_eid : EntityId;
                                         hacking_cortical_vault_client__channelingNodeName : string;
                                         animchar : AnimcharBaseComponent;
                                         hacking_cortical_vault_client__ragdollPhysObjEid : EntityId;
                                         var hacking_cortical_vault_client__animEffect : EntityId&;
                                         var hacking_cortical_vault_client__visualEffect : EntityId&;
                                         var hacking_cortical_vault_client__channelingNodeId : int&)
  hacking_cortical_vault_client__channelingNodeId = geomtree_findNodeIndex(*animchar.nodeTree,
                                                                           hacking_cortical_vault_client__channelingNodeName)

  hacking_cortical_vault_client__animEffect = createEntity("hacking_cortical_vault_militant_effect") <| $(init)
    init |> set("game_effect__attachedTo", actor_eid)

  hacking_cortical_vault_client__visualEffect = createEntity("human_hacking_cortical_vault_effect") <| $(init)
    init |> set("human_hacking_cortical_vault_effect__target", hacking_cortical_vault_client__ragdollPhysObjEid)
    init |> set("human_hacking_cortical_vault_effect__owner", actor_eid)


[es(tag=gameClient, on_disappear)]
def hacking_cortical_vault_client_disappear(evt : Event;
                                            var hacking_cortical_vault_client__animEffect : EntityId&;
                                            var hacking_cortical_vault_client__visualEffect : EntityId&)
  destroyEntity(hacking_cortical_vault_client__animEffect)
  hacking_cortical_vault_client__animEffect = INVALID_ENTITY_ID
  destroyEntity(hacking_cortical_vault_client__visualEffect)
  hacking_cortical_vault_client__visualEffect = INVALID_ENTITY_ID


[es(tag=(gameClient, server))]
def cortical_vault_human_controller_use_client_server(evt : CmdUseAlt;
                                                      eid aka militant_ragdoll_phys_obj_eid : EntityId)
  let useOption = calculate_militant_ragdoll_phys_obj_use_option(evt.requesterEid, militant_ragdoll_phys_obj_eid)

  if useOption == CorticalVaultHumanControllerUseOption.HACK_CORTICAL_VAULT
    query(evt.requesterEid) <| $ [es(REQUIRE_NOT=hacking_cortical_vault_client)] (cortical_vault_human_controller__clientTemplate : string)
      addSubTemplate(evt.requesterEid, cortical_vault_human_controller__clientTemplate) <| $(init)
        init |> set("hacking_cortical_vault_client__ragdollPhysObjEid", militant_ragdoll_phys_obj_eid)
        init |> set("hacking_cortical_vault_client__timeoutAt", get_sync_time() + get_hacking_cortical_vault_client_timeout())


[es(tag=netClient, REQUIRE_NOT=hacking_cortical_vault_client)]
def cortical_vault_human_controller_use_net_client(evt : HumanUseAltObjectRequest;
                                                   eid aka actor_eid : EntityId;
                                                   cortical_vault_human_controller__clientTemplate : string)
  let useOption = calculate_militant_ragdoll_phys_obj_use_option(actor_eid, evt.objectEid)

  if useOption == CorticalVaultHumanControllerUseOption.HACK_CORTICAL_VAULT
    addSubTemplate(actor_eid, cortical_vault_human_controller__clientTemplate) <| $(init)
      init |> set("hacking_cortical_vault_client__ragdollPhysObjEid", evt.objectEid)
      init |> set("hacking_cortical_vault_client__timeoutAt", get_sync_time() + get_hacking_cortical_vault_client_timeout())


[es(tag=gameClient, track=cortical_vault_human_controller__hackingProcessEid, REQUIRE=hacking_cortical_vault_client)]
def track_cortical_vault_human_controller_hacking_process(evt : Event;
                                                          eid aka actor_eid : EntityId;
                                                          cortical_vault_human_controller__hackingProcessEid : EntityId;
                                                          cortical_vault_human_controller__clientTemplate : string;
                                                          var hacking_cortical_vault_client__removed : bool&)
  if cortical_vault_human_controller__hackingProcessEid == INVALID_ENTITY_ID
    removeSubTemplate(actor_eid, cortical_vault_human_controller__clientTemplate)
    hacking_cortical_vault_client__removed = true


[es(tag=gameClient, on_appear)]
def init_human_revive_cortical_vault_effect(evt : Event;
                                            human_revive_cortical_vault_effect__owner : EntityId;
                                            human_revive_cortical_vault_effect__target : EntityId;
                                            var human_revive_cortical_vault_effect__eid : EntityId&)
  query(human_revive_cortical_vault_effect__owner) <| $ [es] (animchar : AnimcharBaseComponent;
                                                              nexus_militant__channelingNodeId : int)
    human_revive_cortical_vault_effect__eid = createEntity("human_revive_cortical_vault_effect_linear") <| $(init)
      var tmpTm : mat44f
      var wtmOfs : float3
      query(human_revive_cortical_vault_effect__target) <| $ [es] (slot_attach__slotId : int)
        if animchar_initAttachmentTmAndNodeWtm(animchar, slot_attach__slotId, tmpTm)
          wtmOfs = *animchar.nodeTree |> geomtree_getWtmOfs()
      var tm = IDENT_TM
      let position = get_channeling_start_position(animchar, nexus_militant__channelingNodeId)
      let goal = tmpTm.col3.xyz + wtmOfs
      let dir = goal - position
      let q = dir_to_quat(dir)
      make_tm(q, position, tm)
      init |> set("transform", tm)


[es(tag=gameClient, no_order)]
def draw_human_revive_cortical_vault_effect(update : ParallelUpdateFrameDelayed;
                                            human_revive_cortical_vault_effect__eid : EntityId;
                                            human_revive_cortical_vault_effect__owner : EntityId;
                                            human_revive_cortical_vault_effect__target : EntityId)
  query(human_revive_cortical_vault_effect__owner) <| $ [es] (animchar : AnimcharBaseComponent;
                                                              nexus_militant__channelingNodeId : int)
    query(human_revive_cortical_vault_effect__eid) <| $ [es] (var transform : float3x4&)
      var tmpTm : mat44f
      var wtmOfs : float3
      query(human_revive_cortical_vault_effect__target) <| $ [es] (slot_attach__slotId : int)
        if animchar_initAttachmentTmAndNodeWtm(animchar, slot_attach__slotId, tmpTm)
          wtmOfs = *animchar.nodeTree |> geomtree_getWtmOfs()
      var tm = IDENT_TM
      let position = get_channeling_start_position(animchar, nexus_militant__channelingNodeId)
      let goal = tmpTm.col3.xyz + wtmOfs
      let dir = goal - position
      let q = dir_to_quat(dir)
      make_tm(q, position, tm)
      transform = tm


[es(tag=gameClient, on_disappear)]
def destroy_human_revive_cortical_vault_effect(evt : Event;
                                               human_revive_cortical_vault_effect__eid : EntityId)
  destroyEntity(human_revive_cortical_vault_effect__eid)
