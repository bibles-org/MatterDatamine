require ecs
require ecs.safe
require app
require DngNet
require game.utils.net_utils
require active_matter.game.es.binoculars_common
require game.events.events
require game.events.events_active_matter
require game.es.inventory_common
require game.es.status_tip_common
require game.es.interrupt_item_use_common
require game.es.human_inventory_postponed_usage_common
require HumanPhys
require DngHuman
require PhysVars
require Dacoll


let private PREFIX = "BINOCULARS"


enum CanUseBinocularsResponse
  Approved
  Declined
  UnarmedUsage
  BlockedByDelay
  NightVisionInUse


def create_tip_for_use_binoculars_decline_reason(item : EntityId;
                                                 reason : int;
                                                 declined_from_server : bool = false)
  debug_use_item_decline_reason(item, "{reason}", PREFIX, declined_from_server)
  if declined_from_server
    return

  if reason == int(CanUseBinocularsResponse.NightVisionInUse)
    create_status_tip("status_tip_night_vision_interferes_with_binoculars_use")


def update_phys_vars_progress(var phys_vars : PhysVars;
                              human_anim__threephaseActionProgressVarId : int;
                              using_progress : float;
                              binoculars_controller__attachedAnimcharEid : EntityId)
  phys_vars |> setVar(human_anim__threephaseActionProgressVarId, using_progress)
  query(binoculars_controller__attachedAnimcharEid) <| $ [es] (var phys_vars aka binoculars_phys_vars : PhysVars;
                                                               human_anim__threephaseActionProgressVarId aka binoculars_human_anim__threephaseActionProgressVarId : int)
    binoculars_phys_vars |> setVar(binoculars_human_anim__threephaseActionProgressVarId, using_progress)


def is_active_use_state(state : int)
  return state != BinocularsUseState.NONE && state != BinocularsUseState.FINISHED


def is_watching_active(binoculars_controller__watchingState : int)
  return (binoculars_controller__watchingState >= int(BinocularsWatchingState.IN_FADEIN) &&
          binoculars_controller__watchingState <= int(BinocularsWatchingState.IDLE))


def start_binoculars_watching(var binoculars_controller__watchingState : int&)
  if is_watching_active(binoculars_controller__watchingState)
    return

  binoculars_controller__watchingState = int(BinocularsWatchingState.IN_FADEIN)


def stop_binoculars_watching(var binoculars_controller__watchingState : int&)
  if !is_watching_active(binoculars_controller__watchingState)
    return

  binoculars_controller__watchingState = int(BinocularsWatchingState.OUT_FADEIN)


def check_binoculars_can_be_used(attaches_list : EidList;
                                 item__unarmedUsage : bool;
                                 cur_time : float;
                                 binoculars_item__useRequestBlockedUntil : float)
  if !item__unarmedUsage
    return CanUseBinocularsResponse.UnarmedUsage
  if cur_time < binoculars_item__useRequestBlockedUntil
    return CanUseBinocularsResponse.BlockedByDelay

  var nvdFound = false
  var nvdIsOn = false
  for attach in attaches_list
    query(attach) <| $ [es] (equipment_mods__curModInSlots : Object)
      for modInSlotData in equipment_mods__curModInSlots
        let modEid = modInSlotData.value ?? INVALID_ENTITY_ID
        query(modEid) <| $ [es] (night_vision_device__isOn : bool)
          nvdFound = true
          nvdIsOn = night_vision_device__isOn
        if nvdFound
          return
    if nvdFound
      break
  if nvdIsOn
    return CanUseBinocularsResponse.NightVisionInUse
  return CanUseBinocularsResponse.Approved


def binoculars_use(human_eid : EntityId;
                   item_eid : EntityId;
                   start_time : float;
                   binoculars_item__useRequestBlockDelay : float;
                   server : bool;
                   var human_net_phys : HumanActor&;
                   var binoculars_controller__useRequest : bool&;
                   var binoculars_controller__useState : int&;
                   var binoculars_item__useRequestBlockedUntil : float&)
  inventory_item_prepare_using(human_eid, item_eid, human_eid, start_time, -1.0, -1.0, -1.0, true)
  human_net_phys.phys.currentState |> human_phys_state_set_stoppedSprint(true)

  // Right now client just checking for ability to use binoculars. In Future client should use binoculars by himself and send to server time at which using has been started.
  if server
    binoculars_item__useRequestBlockedUntil = get_sync_time() + binoculars_item__useRequestBlockDelay
    binoculars_controller__useRequest = true
    binoculars_controller__useState = int(BinocularsUseState.DOWN_IDLE)
  else
    send_net_event(human_eid, RequestUseBinoculars(itemEid = item_eid))
  sendEvent(item_eid, EventOnItemStartUse(userEid = human_eid, targetEid = human_eid))


[es(REQUIRE=binoculars_item)]
def try_use_binoculars(evt : TryUseItem;
                       eid aka item_eid : EntityId;
                       item__unarmedUsage : bool;
                       var binoculars_item__useRequestBlockedUntil : float&;
                       binoculars_item__useRequestBlockDelay : float = 1.0)
  query(evt.userEid) <| $ [es] (human_weap__currentGunEid : EntityId;
                                human_anim__vehicleSelected : EntityId;
                                attaches_list : EidList;
                                isAlive : bool;
                                isDowned : bool;
                                isInVehicle : bool;
                                human_net_phys__isInAir : bool;
                                human_inventory__canUseItems : bool;
                                human_inventory__canHeal : bool;
                                human_inventory__canLoadCharges : bool;
                                human_weap_anim__reloadAtTime : float;
                                var human_net_phys : HumanActor&;
                                var human_inventory__entityToUse : EntityId&;
                                var binoculars_controller__useRequest : bool&;
                                var binoculars_controller__useState : int&;
                                var human_inventory_postponed_usage__state : int&)
    if human_inventory_postponed_usage__state == int(PostponedUsageState.WaitForSwapToUnarmed) && human_inventory__entityToUse == item_eid
      human_inventory__entityToUse = INVALID_ENTITY_ID
      return

    var canUseItem = check_human_can_use_item(isAlive, human_inventory__canUseItems, human_inventory__entityToUse)
    if canUseItem != CanUseItemResponse.Approved
      if canUseItem == CanUseItemResponse.OtherItemInUse
        sendEvent(evt.userEid, EventInterruptItemUse())
      create_tip_for_use_item_decline_reason(item_eid, int(canUseItem), PREFIX)
      return

    let curTime = get_sync_time()
    canUseItem = check_item_can_be_used(evt.userEid, item_eid, human_weap__currentGunEid, human_anim__vehicleSelected, human_net_phys,
                                        curTime, curTime, human_weap_anim__reloadAtTime, isDowned, human_net_phys__isInAir, isInVehicle,
                                        human_inventory__canHeal, human_inventory__canLoadCharges)
    if canUseItem != CanUseItemResponse.Approved
      create_tip_for_use_item_decline_reason(item_eid, int(canUseItem), PREFIX)
      return

    let canUseBinoculars = check_binoculars_can_be_used(attaches_list, item__unarmedUsage, curTime, binoculars_item__useRequestBlockedUntil)
    if canUseBinoculars != CanUseBinocularsResponse.Approved
      create_tip_for_use_binoculars_decline_reason(item_eid, int(canUseBinoculars))
      return

    if try_postponed_usage_on_unurmed_usage_item(evt.userEid, human_net_phys, human_inventory_postponed_usage__state)
      human_inventory__entityToUse = item_eid
      return

    binoculars_use(evt.userEid, item_eid, curTime, binoculars_item__useRequestBlockDelay, is_server(), human_net_phys, binoculars_controller__useRequest, binoculars_controller__useState, binoculars_item__useRequestBlockedUntil)


[es(tag=server)]
def try_use_binoculars_server(evt : RequestUseBinoculars;
                              eid aka human_eid : EntityId;
                              human_weap__currentGunEid : EntityId;
                              human_anim__vehicleSelected : EntityId;
                              human_inventory__entityToUse : EntityId;
                              attaches_list : EidList;
                              isAlive : bool;
                              isDowned : bool;
                              isInVehicle : bool;
                              human_net_phys__isInAir : bool;
                              human_inventory__canUseItems : bool;
                              human_inventory__canHeal : bool;
                              human_inventory__canLoadCharges : bool;
                              human_weap_anim__reloadAtTime : float;
                              var human_net_phys : HumanActor&;
                              var binoculars_controller__useRequest : bool&;
                              var binoculars_controller__useState : int&)
  var canUseItem = check_human_can_use_item(isAlive, human_inventory__canUseItems, human_inventory__entityToUse)
  if canUseItem != CanUseItemResponse.Approved
    if canUseItem == CanUseItemResponse.OtherItemInUse
      sendEvent(eid, EventInterruptItemUse())
    send_net_event(human_eid, ResponseFailureUseBinoculars(itemEid = evt.itemEid, reason = int(canUseItem)), target_entity_conn(human_eid))
    return

  let curTime = get_sync_time()
  canUseItem = check_item_can_be_used(human_eid, evt.itemEid, human_weap__currentGunEid, human_anim__vehicleSelected, human_net_phys,
                                      curTime, curTime, human_weap_anim__reloadAtTime, isDowned, human_net_phys__isInAir, isInVehicle,
                                      human_inventory__canHeal, human_inventory__canLoadCharges)
  if canUseItem != CanUseItemResponse.Approved
    send_net_event(human_eid, ResponseFailureUseBinoculars(itemEid = evt.itemEid, reason = int(canUseItem)), target_entity_conn(human_eid))
    return

  query(evt.itemEid) <| $ [es] (item__unarmedUsage : bool;
                                var binoculars_item__useRequestBlockedUntil : float&;
                                binoculars_item__useRequestBlockDelay : float = 1.0)
    let canUseBinoculars = check_binoculars_can_be_used(attaches_list, item__unarmedUsage, curTime, binoculars_item__useRequestBlockedUntil)
    if canUseBinoculars != CanUseBinocularsResponse.Approved
      send_net_event(human_eid, ResponseFailureUseBinoculars(itemEid = evt.itemEid, reason = int(CanUseItemResponse.End) + int(canUseBinoculars)), target_entity_conn(human_eid))
      return

    binoculars_use(human_eid, evt.itemEid, curTime, binoculars_item__useRequestBlockDelay, true, human_net_phys, binoculars_controller__useRequest, binoculars_controller__useState, binoculars_item__useRequestBlockedUntil)


[es(tag=netClient, REQUIRE=hero)]
def binoculars_on_use_failure(evt : ResponseFailureUseBinoculars;
                              eid aka human_eid : EntityId)
  inventory_item_reset_using(human_eid)
  let lastCanUseItemResponseCode = int(CanUseItemResponse.End)
  if lastCanUseItemResponseCode <= evt.reason
    create_tip_for_use_binoculars_decline_reason(evt.itemEid, evt.reason - lastCanUseItemResponseCode, true)
  else
    create_tip_for_use_item_decline_reason(evt.itemEid, evt.reason, PREFIX, true)


[es(tag=server, track=binoculars_controller__useRequest)]
def binoculars_controller_track_use_request(evt : Event;
                                            binoculars_controller__useRequest : bool;
                                            var binoculars_controller__watchingState : int&;
                                            var binoculars_controller__useState : int&)
  if !binoculars_controller__useRequest
    if binoculars_controller__watchingState != BinocularsWatchingState.NONE
      stop_binoculars_watching(binoculars_controller__watchingState)
    else
      stop_binoculars_use(binoculars_controller__useState)


[es(tag=server, track=binoculars_controller__watchingBlocked)]
def binoculars_controller_track_watchingBlocked(evt : Event;
                                                binoculars_controller__watchingBlocked : bool;
                                                binoculars_controller__watchingBlockDelay : float = 0.75;
                                                var binoculars_controller__watchingState : int&;
                                                var binoculars_controller__watchingBlockedUntil : float&)
  if binoculars_controller__watchingBlocked
    stop_binoculars_watching(binoculars_controller__watchingState)
    binoculars_controller__watchingBlockedUntil = get_sync_time() + binoculars_controller__watchingBlockDelay


[es(tag=server, REQUIRE=binoculars_item)]
def binoculars_use_interrupted(evt : EventItemUseInterrupted)
  query(evt.userEid) <| $ [es] (var binoculars_controller__useState : int&)
    assume state = binoculars_controller__useState
    if !is_active_use_state(state) || state == BinocularsUseState.INTERRUPTION
      return
    state = int(BinocularsUseState.INTERRUPTION)


[es(track=binoculars_controller__useState)]
def binoculars_controller_track_use_state(evt : Event;
                                          eid aka actor_eid : EntityId;
                                          binoculars_controller__useProgressWatchingStart : float;
                                          binoculars_controller__useProgressOutStart : float;
                                          binoculars_controller__useProgressDownIdleStart : float;
                                          binoculars_controller__useProgressEnd : float;
                                          binoculars_controller__useState : int;
                                          human_anim__threephaseActionProgressVarId : int;
                                          binoculars_controller__attachedAnimcharEid : EntityId;
                                          var binoculars_controller__useProgress : float&;
                                          var phys_vars : PhysVars)
  assume progressWatchingStart = binoculars_controller__useProgressWatchingStart
  assume progressOutStart = binoculars_controller__useProgressOutStart
  assume progressDownIdleStart = binoculars_controller__useProgressDownIdleStart
  assume progressEnd = binoculars_controller__useProgressEnd
  assume usingProgress = binoculars_controller__useProgress

  if binoculars_controller__useState == BinocularsUseState.NONE
    usingProgress = 0.0
  elif binoculars_controller__useState == BinocularsUseState.IN
    if usingProgress >= binoculars_controller__useProgressWatchingStart
      usingProgress = 0.0
  elif binoculars_controller__useState == BinocularsUseState.WATCHING
    usingProgress = (progressWatchingStart + progressOutStart) * 0.5
  elif binoculars_controller__useState == BinocularsUseState.OUT
    if usingProgress >= binoculars_controller__useProgressWatchingStart
      usingProgress = progressOutStart
    else
      // In -> Out transition
      let inProgress = usingProgress / binoculars_controller__useProgressWatchingStart
      let outProgress = 1.0 - inProgress
      let outLen = progressEnd - binoculars_controller__useProgressOutStart
      usingProgress = binoculars_controller__useProgressOutStart + outLen * outProgress
  elif binoculars_controller__useState == BinocularsUseState.DOWN_IDLE
    usingProgress = (progressDownIdleStart + progressEnd) * 0.5
  elif (binoculars_controller__useState == BinocularsUseState.FINISHED ||
       binoculars_controller__useState == BinocularsUseState.INTERRUPTION)
    usingProgress = progressEnd

    // Ensure binoculars item usage is finished
    sendEvent(actor_eid, EventInterruptItemUse())

  update_phys_vars_progress(phys_vars, human_anim__threephaseActionProgressVarId, usingProgress, binoculars_controller__attachedAnimcharEid)


[es(tag=server, track=binoculars_controller__useState, after=binoculars_controller_track_use_state)]
def binoculars_controller_track_use_state_server(evt : Event;
                                                 eid aka actor_eid : EntityId;
                                                 binoculars_controller__useAffectTemplate : string;
                                                 human_inventory__entityToUse : EntityId;
                                                 var binoculars_controller__useState : int&;
                                                 var binoculars_controller__useAffectEid : EntityId&;
                                                 var binoculars_controller__attachedAnimcharEid : EntityId&;
                                                 var binoculars_controller__useRequest : bool&)
  // Common affect
  let commonAffectRequired = is_active_use_state(binoculars_controller__useState)
  if commonAffectRequired && binoculars_controller__useAffectEid == INVALID_ENTITY_ID
    query(human_inventory__entityToUse) <| $ [es] (binoculars_item__attachedAnimcharTemplate : string;
                                                   animchar__res aka binoculars_animchar__res : string)
      binoculars_controller__useAffectEid = createEntity(binoculars_controller__useAffectTemplate) <| $(var init : ComponentsInitializer)
        init |> set("game_effect__attachedTo", actor_eid)

      var attachedAnimcharTemplate = binoculars_item__attachedAnimcharTemplate
      attachedAnimcharTemplate = add_sub_template_name(attachedAnimcharTemplate, "slot_attach_show_after_appear")
      binoculars_controller__attachedAnimcharEid = createEntity(attachedAnimcharTemplate) <| $(var init : ComponentsInitializer)
        init |> set("slot_attach__attachedTo", actor_eid)
        init |> set("animchar__res", binoculars_animchar__res)
        init |> set("slot_attach_show_after_appear__time", 0.05) // Small delay to correctly morph equip animation
  elif !commonAffectRequired && binoculars_controller__useAffectEid != INVALID_ENTITY_ID
    destroyEntity(binoculars_controller__useAffectEid)
    binoculars_controller__useAffectEid = INVALID_ENTITY_ID

    destroyEntity(binoculars_controller__attachedAnimcharEid)
    binoculars_controller__attachedAnimcharEid = INVALID_ENTITY_ID

    binoculars_controller__useRequest = false


  if binoculars_controller__useState == BinocularsUseState.INTERRUPTION
    binoculars_controller__useState = int(BinocularsUseState.FINISHED)
  elif binoculars_controller__useState == BinocularsUseState.FINISHED || binoculars_controller__useState == BinocularsUseState.NONE
    query(human_inventory__entityToUse) <| $ [es(REQUIRE=binoculars_item)] ()
      sendEvent(actor_eid, EventInterruptItemUse())


[es(track=binoculars_controller__watchingState)]
def binoculars_controller_track_watching_state(evt : Event;
                                               binoculars_controller__watchingState : int;
                                               binoculars_controller__watchingFadeInIdleOutTime : float3;
                                               var binoculars_controller__watchingNextStateAt : float&;
                                               var binoculars_controller__useState : int&)
  assume state = binoculars_controller__watchingState
  assume watchingFadeInIdleOutTime = binoculars_controller__watchingFadeInIdleOutTime

  binoculars_controller__watchingNextStateAt = -1.0

  if state == BinocularsWatchingState.IN_FADEIN || state == BinocularsWatchingState.OUT_FADEIN
    binoculars_controller__watchingNextStateAt = get_sync_time() + watchingFadeInIdleOutTime.x
  elif state == BinocularsWatchingState.IN_FADE || state == BinocularsWatchingState.OUT_FADE
    binoculars_controller__watchingNextStateAt = get_sync_time() + watchingFadeInIdleOutTime.y
  elif state == BinocularsWatchingState.IN_FADEOUT || state == BinocularsWatchingState.OUT_FADEOUT
    binoculars_controller__watchingNextStateAt = get_sync_time() + watchingFadeInIdleOutTime.z

  if state == BinocularsWatchingState.OUT_FADEOUT
    stop_binoculars_use(binoculars_controller__useState)


[es(tag=server, track=binoculars_controller__watchingState, after=binoculars_controller_track_watching_state)]
def binoculars_controller_track_watching_state_server(evt : Event;
                                                      eid aka actor_eid : EntityId;
                                                      binoculars_controller__watchingState : int;
                                                      human_inventory__entityToUse : EntityId;
                                                      var binoculars_controller__binocularsAffectEid : EntityId&)
  assume state = binoculars_controller__watchingState
  let binocularsAffectRequired = (state >= int(BinocularsWatchingState.IN_FADE) && state <= int(BinocularsWatchingState.OUT_FADEIN))


  if binocularsAffectRequired && binoculars_controller__binocularsAffectEid == INVALID_ENTITY_ID
    query(human_inventory__entityToUse) <| $ [es] (binoculars_item__binocularsAffectTemplate : string)
      if binoculars_item__binocularsAffectTemplate != ""
        binoculars_controller__binocularsAffectEid = createEntity(binoculars_item__binocularsAffectTemplate) <| $(var init : ComponentsInitializer)
          init |> set("game_effect__attachedTo", actor_eid)
  elif !binocularsAffectRequired && binoculars_controller__binocularsAffectEid != INVALID_ENTITY_ID
    destroyEntity(binoculars_controller__binocularsAffectEid)
    binoculars_controller__binocularsAffectEid = INVALID_ENTITY_ID


[es(no_order)]
def binoculars_controller_update(act : UpdateStageInfoAct;
                                 binoculars_controller__useInReverseMult : float = 1.25;
                                 binoculars_controller__useInOutSpeed : float2;
                                 binoculars_controller__useProgressWatchingStart : float;
                                 binoculars_controller__useProgressOutStart : float;
                                 binoculars_controller__useProgressDownIdleStart : float;
                                 binoculars_controller__useProgressEnd : float;
                                 binoculars_controller__useProgressToStartWatchingSM : float;
                                 binoculars_controller__useRequest : bool;
                                 binoculars_controller__watchingRequest : bool;
                                 binoculars_controller__watchingBlocked : bool;
                                 human_anim__threephaseActionProgressVarId : int;
                                 binoculars_controller__attachedAnimcharEid : EntityId;
                                 binoculars_controller__watchingNextStateAt : float;
                                 binoculars_controller__watchingBlockedUntil : float;
                                 var binoculars_controller__useProgress : float&;
                                 var binoculars_controller__useState : int&;
                                 var binoculars_controller__watchingState : int&;
                                 var phys_vars : PhysVars)
  assume state = binoculars_controller__useState
  assume usingProgress = binoculars_controller__useProgress
  assume usingInReverseMult = binoculars_controller__useInReverseMult
  assume usingInOutSpeed = binoculars_controller__useInOutSpeed
  assume usingProgressWatchingStart = binoculars_controller__useProgressWatchingStart
  assume useProgressWatchingEnd = binoculars_controller__useProgressOutStart
  assume useProgressDownIdleStart = binoculars_controller__useProgressDownIdleStart
  assume usingProgressEnd = binoculars_controller__useProgressEnd
  assume useProgressToStartWatchingSM = binoculars_controller__useProgressToStartWatchingSM


  if is_active_use_state(state)
    if state == BinocularsUseState.IN
      if usingProgress >= useProgressWatchingEnd
        // Out -> In transition
        let outLen = usingProgressEnd - useProgressWatchingEnd
        var outProgress = usingProgress - useProgressWatchingEnd
        outProgress = outProgress / outLen
        let inProgress = 1.0 - outProgress
        usingProgress = usingProgressWatchingStart * inProgress

      let usingInSpeed = usingInOutSpeed.x
      usingProgress += act.dt * usingInSpeed
      if usingProgress >= usingProgressWatchingStart
        usingProgress = usingProgressWatchingStart
        state = int(BinocularsUseState.WATCHING)

    elif state == BinocularsUseState.IN_REVERSE
      let speed = usingInOutSpeed.x * binoculars_controller__useInReverseMult
      usingProgress -= act.dt * speed
      if usingProgress <= 0.0
        usingProgress = 0.0
        state = int(BinocularsUseState.NONE)
    elif state == BinocularsUseState.WATCHING
      if is_watching_active(binoculars_controller__watchingState)
        if !binoculars_controller__watchingRequest || binoculars_controller__watchingBlocked
          stop_binoculars_watching(binoculars_controller__watchingState)
      elif !binoculars_controller__useRequest
        stop_binoculars_use(binoculars_controller__useState)
    elif state == BinocularsUseState.OUT
      let usingOutSpeed = usingInOutSpeed.y
      usingProgress += act.dt * usingOutSpeed
      if usingProgress >= useProgressDownIdleStart
        usingProgress = useProgressDownIdleStart

        if binoculars_controller__useRequest
          state = int(BinocularsUseState.DOWN_IDLE)
        else
          state = int(BinocularsUseState.FINISHED)
    elif state == BinocularsUseState.DOWN_IDLE
      if !binoculars_controller__useRequest
        state = int(BinocularsUseState.FINISHED)
      else
        if binoculars_controller__watchingRequest && !binoculars_controller__watchingBlocked

          if act.curTime > binoculars_controller__watchingBlockedUntil
            state = int(BinocularsUseState.IN)


    update_phys_vars_progress(phys_vars, human_anim__threephaseActionProgressVarId, usingProgress, binoculars_controller__attachedAnimcharEid)


    let isWatchingRequired = ((usingProgress >= useProgressToStartWatchingSM && usingProgress < useProgressWatchingEnd) &&
                              binoculars_controller__useRequest)
    let isWatchingActive = is_watching_active(binoculars_controller__watchingState)
    if isWatchingRequired && (binoculars_controller__watchingState == BinocularsWatchingState.NONE)
      start_binoculars_watching(binoculars_controller__watchingState)
    elif !isWatchingRequired && isWatchingActive
      stop_binoculars_watching(binoculars_controller__watchingState)

  elif binoculars_controller__watchingState != BinocularsWatchingState.NONE
    stop_binoculars_watching(binoculars_controller__watchingState)

  if binoculars_controller__watchingNextStateAt > 0.0 && act.curTime >= binoculars_controller__watchingNextStateAt
    if binoculars_controller__watchingState == BinocularsWatchingState.OUT_FADEOUT
      binoculars_controller__watchingState = int(BinocularsWatchingState.NONE)
    else
      binoculars_controller__watchingState++


[es(tag=server, REQUIRE=binoculars_use_game_effect, no_order)]
def binoculars_use_game_effect_update(act : UpdateStageInfoAct;
                                      game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (human_net_phys : HumanActor;
                                            human_inventory__entityToUse : EntityId;
                                            binoculars_controller__useState : int;
                                            transform aka human_transform : float3x4;
                                            human__aimTm : float3x4;
                                            binoculars_controller__watchingObstacleBlockTraceDistMinMax : float2 = float2(1.0, 1.2);
                                            binoculars_controller__watchingObstacleBlockTraceRadius : float = 0.33;
                                            var binoculars_controller__useRequest : bool&;
                                            var binoculars_controller__watchingBlocked : bool&)
    if !is_active_use_state(binoculars_controller__useState)
      return

    assume currentState = human_net_phys.phys.currentState
    assume weapEquipState = currentState.weapEquipState
    assume blockTraceDistMinMax = binoculars_controller__watchingObstacleBlockTraceDistMinMax
    assume blockTraceRadius = binoculars_controller__watchingObstacleBlockTraceRadius


    let p0 = human__aimTm[3]
    let p1 = p0 + human_transform[0] * (binoculars_controller__watchingBlocked ? blockTraceDistMinMax.y : blockTraceDistMinMax.x)

    var queryOut = ShapeQueryOutput()
    let SPHERE_CAST_MASK = int(PhysLayer.EPL_STATIC)
    binoculars_controller__watchingBlocked = sphere_cast_ex(p0, p1, blockTraceRadius, queryOut, -1, null, SPHERE_CAST_MASK)

    var ignoreShootInputInterrupt = false
    if binoculars_controller__useState != int(BinocularsUseState.DOWN_IDLE)
      query(human_inventory__entityToUse) <| $ [es] (binoculars_item__ignoreShootInputInterrupt : Tag const?)
        ignoreShootInputInterrupt = (binoculars_item__ignoreShootInputInterrupt != null)

    var stopUsing = false

    let isWeaponSwitchRequested = (weapEquipState.curSlot != weapEquipState.nextSlot && weapEquipState.nextSlot != HUWeaponSlots.EWS_UNARMED)

    assume ct = human_net_phys.phys.appliedCT
    if ((ct |> is_control_bit_set(HumanPhysControlType.HCT_SHOOT) && !ignoreShootInputInterrupt) ||
       ct |> is_control_bit_set(HumanPhysControlType.HCT_ZOOM_VIEW) ||
       ct |> is_control_bit_set(HumanPhysControlType.HCT_MELEE) ||
       ct |> is_control_bit_set(HumanPhysControlType.HCT_SPRINT) ||
       ct |> is_control_bit_set(HumanPhysControlType.HCT_CRAWL) ||
       isWeaponSwitchRequested)
      stopUsing = true

    if stopUsing
      binoculars_controller__useRequest = false