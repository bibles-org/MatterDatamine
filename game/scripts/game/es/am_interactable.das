require ecs
require ecs.common
require ecs.safe
require app
require net
require math.base
require game.events.events
require game.events.events_game
require game.es.grav_zones_common
require game.es.trace_common
require game.utils.team
require game.utils.hero
require game.es.inventory_drop_common
require game.events.events_active_matter
require DagorRandom
require DagorSystem
require DagorMath
require Grid
require Dacoll
require DagorDebug3D
require game.es.am_interactable_common
require game.events.sound_net_events
require sound_utils.modules.sound_utils_events
require game.utils.sound_utils
require level

def start_interaction(user, interactable : EntityId;
                      sync_create : bool;
                      interactable__invoiceTemplateList : StringList;
                      var interactable__invoiceList : EidList;
                      var interactable__heroEid : EntityId&;
                      var human_use_object__currentInteractable : EntityId&)
  human_use_object__currentInteractable = interactable
  interactable__heroEid = user
  for action, i in interactable__invoiceTemplateList, iter_range(interactable__invoiceTemplateList)
    var actionEid : EntityId
    if sync_create
      actionEid = createEntitySync(string(action)) <| $(init)
        set(init, "interactable_invoice__parentInteractableEid", interactable)
        set(init, "interactable_invoice__hero", user)
        set(init, "interactable_invoice__idx", i)
    else
      actionEid = createEntity(string(action)) <| $(init)
        set(init, "interactable_invoice__parentInteractableEid", interactable)
        set(init, "interactable_invoice__hero", user)
        set(init, "interactable_invoice__idx", i)
    push(interactable__invoiceList, actionEid)


[es(tag=gameClient, REQUIRE=hero, track=human_use_object__currentInteractable)]
def mark_current_interactable(evt : Event; human_use_object__currentInteractable : EntityId)
  if human_use_object__currentInteractable != INVALID_ENTITY_ID
    addSubTemplate(human_use_object__currentInteractable, "active_interactable")
  else
    query() <| $ [es(REQUIRE=activeInteractable)] (eid : EntityId)
      removeSubTemplate(eid, "active_interactable")


[es(tag=server)]
def start_interaction_on_interactable_used(cmd : CmdUse;
                                           eid : EntityId;
                                           interactable__invoiceTemplateList : StringList;
                                           interactable__immediate_single_action_use : Tag const?;
                                           var interactable__blockThisInteraction : bool&;
                                           var interactable__heroEid : EntityId&;
                                           var interactable__invoiceList : EidList)
  if interactable__blockThisInteraction
    interactable__blockThisInteraction = false
    return
  query(cmd.requesterEid) <| $ [es] (var human_use_object__currentInteractable : EntityId&)
    if interactable__heroEid == INVALID_ENTITY_ID && human_use_object__currentInteractable == INVALID_ENTITY_ID
      let immediateUse = interactable__immediate_single_action_use != null && length(interactable__invoiceTemplateList) == 1
      start_interaction(cmd.requesterEid, eid,
                        immediateUse,
                        interactable__invoiceTemplateList,
                        interactable__invoiceList,
                        interactable__heroEid,
                        human_use_object__currentInteractable)
      if immediateUse
        handle_request_interaction_action(interactable__invoiceList[0])

    elif interactable__heroEid == cmd.requesterEid
      end_interaction(interactable__invoiceList,
                      interactable__heroEid,
                      human_use_object__currentInteractable)


[es(tag=server)]
def on_request_interaction_end(evt : RequestEndInteraction; var human_use_object__currentInteractable : EntityId&)
  if evt.currentInteractable != human_use_object__currentInteractable
    return //data out of date
  query(human_use_object__currentInteractable) <| $ [es] (var interactable__invoiceList : EidList;
                                                          var interactable__heroEid : EntityId&)
    end_interaction(interactable__invoiceList,
                    interactable__heroEid,
                    human_use_object__currentInteractable)


def handle_request_interaction_action(action_eid : EntityId)
  query(action_eid) <| $ [es] (interactable_invoice__parentInteractableEid : EntityId;
                               interactable_invoice__show : bool;
                               interactable_invoice__available : bool;
                               interactable_invoice__invoiceTemplateList : StringList const?)
    if interactable_invoice__show && interactable_invoice__available
      sendEventImmediate(action_eid, CmdExecInteractionAction())
    // here we allowing to execute chain invoice actions
    // interaction will be ended after last invoice in chain
    if interactable_invoice__invoiceTemplateList != null
      return
    query(interactable_invoice__parentInteractableEid) <| $ [es] (var interactable__invoiceList : EidList;
                                                                  var interactable__heroEid : EntityId&)
      query(interactable__heroEid) <| $ [es] (var human_use_object__currentInteractable : EntityId&)
        end_interaction(interactable__invoiceList,
                        interactable__heroEid,
                        human_use_object__currentInteractable)


[es(tag=server, no_order)]
def track_user_is_close_to_interactible(act : UpdateStageInfoAct;
                                        transform aka user_transform : float3x4;
                                        var human_use_object__currentInteractable : EntityId&;
                                        human_use_object__thresholdDist : float = 12.f)
  query(human_use_object__currentInteractable) <| $ [es] (transform aka object_transform : float3x4;
                                                          var interactable__invoiceList : EidList;
                                                          var interactable__heroEid : EntityId&)
    if distance_sq(user_transform[3], object_transform[3]) > square(human_use_object__thresholdDist)
      end_interaction(interactable__invoiceList,
                      interactable__heroEid,
                      human_use_object__currentInteractable)


[es(tag=server, track=(isAlive, isDowned))]
def end_interaction_on_downed_or_dead(evt : Event; isAlive : bool; isDowned : bool; var human_use_object__currentInteractable : EntityId&)
  if isDowned || !isAlive
    query(human_use_object__currentInteractable) <| $ [es] (var interactable__invoiceList : EidList;
                                                            var interactable__heroEid : EntityId&)
      end_interaction(interactable__invoiceList,
                      interactable__heroEid,
                      human_use_object__currentInteractable)


[es(tag=server, on_appear, REQUIRE=state__interruptInteractable)]
def end_interaction_on_state_change(evt : Event; game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var human_use_object__currentInteractable : EntityId&)
    query(human_use_object__currentInteractable) <| $ [es] (var interactable__invoiceList : EidList;
                                                            var interactable__heroEid : EntityId&)
      end_interaction(interactable__invoiceList,
                      interactable__heroEid,
                      human_use_object__currentInteractable)


[es(tag=server, on_disappear)]
def end_interaction_on_user_disappear(evt : Event; var human_use_object__currentInteractable : EntityId&)
  query(human_use_object__currentInteractable) <| $ [es] (var interactable__invoiceList : EidList;
                                                          var interactable__heroEid : EntityId&)
    end_interaction(interactable__invoiceList,
                    interactable__heroEid,
                    human_use_object__currentInteractable)


[es(tag=server, on_disappear)]
def end_interaction_on_object_disappear(evt : Event;
                                        var interactable__invoiceList : EidList;
                                        var interactable__heroEid : EntityId&)
  query(interactable__heroEid) <| $ [es] (var human_use_object__currentInteractable : EntityId&)
    end_interaction(interactable__invoiceList,
                    interactable__heroEid,
                    human_use_object__currentInteractable)


[es(tag=gameClient, REQUIRE=watchedByPlr, no_order)]
def query_nearby_interactables(act : UpdateStageInfoAct;
                               transform : float3x4;
                               interactables__queryInterval : float;
                               interactables__queryRadius : float;
                               var interactables__pingged : Array;
                               var interactables__nearby : EidList;
                               var interactables__nextQueryAt : float&)
  if act.curTime > interactables__nextQueryAt
    interactables__nextQueryAt = act.curTime + interactables__queryInterval

    let bounding = BSphere3(transform[3], interactables__queryRadius)
    gather_entities_in_grid(ecs_hash("interactable"), bounding, GridEntCheck.POS) <| $(interactableList)
      clear(interactables__nearby)
      for ieid in interactableList
        query(ieid) <| $ [es(REQUIRE=clientUsable)] (use_object__enabled = true)
          if use_object__enabled
            interactables__nearby |> push(ieid)

    for i in iter_range(interactables__pingged)
      let reverseIdx = length(interactables__pingged) - i - 1
      var obj = getRW_ecs_object(interactables__pingged[reverseIdx])
      let deleteAt = obj?.deleteAt ?? 0.0
      if deleteAt < act.curTime
        erase(interactables__pingged, reverseIdx)


[es(tag=gameClient, REQUIRE=interactable__heroEid)]
def add_pingged_interactable(evt : EventTeamItemHint; eid : EntityId)
  query() <| $ [es(REQUIRE=watchedByPlr)] (interactables__pingDuration : float; var interactables__pingged : Array)
    var isAlreadyPingged = false
    for it in interactables__pingged
      var obj = getRW_ecs_object(it)
      let pinggedEid = obj?.eid ?? INVALID_ENTITY_ID
      if pinggedEid == eid
        isAlreadyPingged = true
        *getRW_float(obj, "deleteAt") = get_sync_time() + interactables__pingDuration
        break
    if !isAlreadyPingged
      using() <| $(var obj : Object)
        set(obj, "eid", eid)
        set(obj, "deleteAt", get_sync_time() + interactables__pingDuration)
        push(interactables__pingged, obj)


[es(tag=server, on_appear)]
def init_interactable_invoice_with_duration(evt : Event;
                                            interactable_invoice__duration : float;
                                            var interactable_invoice__completesAt : float&)
  interactable_invoice__completesAt = get_sync_time() + interactable_invoice__duration


[es(tag=server, no_order)]
def process_interactable_invoice_with_duration(act : UpdateStageInfoAct;
                                               eid : EntityId;
                                               interactable_invoice__activateOnCompletion : bool;
                                               var interactable_invoice__completesAt : float&;
                                               var interactable_invoice__available : bool&)
  if interactable_invoice__completesAt > 0.0 && act.curTime >= interactable_invoice__completesAt
    interactable_invoice__available = true
    interactable_invoice__completesAt = 0.0
    if interactable_invoice__activateOnCompletion
      handle_request_interaction_action(eid)


[es(tag=gameClient, on_appear)]
def track_watched_invoices(evt : Event; eid, interactable_invoice__hero : EntityId)
  if has(interactable_invoice__hero, "watchedByPlr")
    addSubTemplate(eid, "watched_invoice")


[es(tag=gameClient, on_appear, REQUIRE=(watchedByPlr, human_use_object__selectedObject))]
def switch_watched_invoices_on_watch_target_on(evt : Event; eid aka hero_eid : EntityId)
  query() <| $ [es] (interactable_invoice__hero : EntityId; eid aka invoice_eid : EntityId; watched_invoice : Tag const?)
    if interactable_invoice__hero == hero_eid && watched_invoice == null
      addSubTemplate(invoice_eid, "watched_invoice")


[es(tag=gameClient, on_disappear, REQUIRE=(watchedByPlr, human_use_object__selectedObject))]
def switch_watched_invoices_on_watch_target_off(evt : Event; eid aka hero_eid : EntityId)
  query() <| $ [es] (interactable_invoice__hero : EntityId; eid aka invoice_eid : EntityId; watched_invoice : Tag const?)
    if interactable_invoice__hero == hero_eid && watched_invoice != null
      removeSubTemplate(invoice_eid, "watched_invoice")


[es(tag=gameClient, REQUIRE=hero, track=(human_use_object__selectedObject, human_use_object__currentInteractable))]
def interrupt_interaction(evt : Event; eid : EntityId; human_use_object__selectedObject, human_use_object__currentInteractable : EntityId)
  if human_use_object__currentInteractable != INVALID_ENTITY_ID && human_use_object__currentInteractable != human_use_object__selectedObject
    if has(human_use_object__currentInteractable, "interactable__uninterruptible")
      return
    if human_use_object__selectedObject != INVALID_ENTITY_ID && has(human_use_object__currentInteractable, "interactable__ignoreOtherInteractables")
      return
    send_net_event(eid, RequestEndInteraction(currentInteractable = human_use_object__currentInteractable))


[es(tag=server, on_appear)]
def invoice_creates_user_game_effect(evt : Event;
                                     interactable_invoice__hero : EntityId;
                                     interactable_invoice__userEffect : string;
                                     var interactable_invoice__userEffectEid : EntityId&)
  interactable_invoice__userEffectEid = createEntity(interactable_invoice__userEffect) <| $(init)
    init |> set("game_effect__attachedTo", interactable_invoice__hero)


[es(tag=server, on_disappear)]
def invoice_destroys_user_game_effect(evt : Event; interactable_invoice__userEffectEid : EntityId)
  destroyEntity(interactable_invoice__userEffectEid)


[es(tag=server, on_appear)]
def start_use_interactable_invoice(evt : Event;
                                   interactable_invoice__parentInteractableEid : EntityId;
                                   interactable_invoice__onStartSoundPath : string)
  query(interactable_invoice__parentInteractableEid) <| $ [es] (transform : float3x4)
    broadcast_net_sound(interactable_invoice__parentInteractableEid, interactable_invoice__onStartSoundPath, transform[3])


[es(tag=server)]
def start_chain_invoice(evt : CmdExecInteractionAction;
                        interactable_invoice__hero : EntityId;
                        interactable_invoice__invoiceTemplateList : StringList)
  query(interactable_invoice__hero) <| $ [es] (var human_use_object__currentInteractable : EntityId&)
    query(human_use_object__currentInteractable) <| $ [es] (var interactable__invoiceList : EidList;
                                                            var interactable__heroEid : EntityId&;
                                                            interactable__immediate_single_action_use : Tag const?)
      let immediateUse = interactable__immediate_single_action_use != null && length(interactable_invoice__invoiceTemplateList) == 1
      start_interaction(interactable_invoice__hero,
                        human_use_object__currentInteractable,
                        immediateUse,
                        interactable_invoice__invoiceTemplateList,
                        interactable__invoiceList,
                        interactable__heroEid,
                        human_use_object__currentInteractable)


def drop_interactable(eid : EntityId;
                      ri_extra_handle : uint64;
                      var transform : float3x4;
                      grav_dir : float3 = float3())
  let down = grav_dir == float3() ? get_grav_dir(transform[3]) : grav_dir

  var t = 50.0
  var pmid = -1
  var norm : float3
  var riDesc = RendInstDesc()
  let tracePos = transform[3] - down * 1e-1
  if traceray_normalized_exclude_ri(ri_extra_handle, tracePos, down, t, pmid, norm, ETF_ALL, riDesc, -1)
    let traceHitPos = tracePos + down * (t - 1e-3)
    transform[3] = traceHitPos
  else
    logerr("failed to align to the ground {eid} <{getEntityTemplateName(eid)}")


[es(tag=server)]
def drop_lootable_rendinsts_on_rendinst_destroyed(evt : EventRendinstDestroyed)
  if !is_level_loaded()
    return

  let upDir = -get_grav_dir(evt.riTm[3], true)
  let destrRendinstDot = dot(evt.riTm[3], upDir)

  var bbox = evt.riBBox
  bbox |> bbox3_inflate(0.16) // Magic margin number from ri_collision_check_margin
  bbox = evt.riTm * bbox
  for_each_entity_in_grid(ecs_hash("interactable"), bbox, GridEntCheck.BOUNDING) <| $(item_eid : EntityId)
    query(item_eid) <| $ [es(REQUIRE=iteractable__dropOnRiDestroy)] (ri_extra : RiExtraComponent;
                                                                     var transform aka interactable_transform : float3x4)
      if evt.riexHandle == ri_extra.handle
        return

      let overDestroyedRendinst = destrRendinstDot < dot(interactable_transform[3], upDir)
      if overDestroyedRendinst
        drop_interactable(item_eid, ri_extra.handle, interactable_transform, -upDir)