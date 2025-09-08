require ecs
require AnimV20
require DagorMath
require DagorSystem
require GeomNodeTree
require ecs.common
require game.es.slot_attach_common
require game.events.events_active_matter


[es(on_appear, REQUIRE=(slot_attach, attachedToParent), parallel_for=16)]
def force_slot_attach_on_appear(evt : Event;
                                eid : EntityId;
                                slot_attach__slotId : int;
                                slot_attach__attachedTo : EntityId;
                                var animchar : AnimcharBaseComponent;
                                disableUpdate : Tag const?;
                                var animchar_node_wtm : AnimcharNodesMat44?;
                                var animchar_render__root_pos : vec4f?;
                                animchar__visible : bool = true;
                                slot_attach__calcAnim : bool = true)
  slot_attach_init_tms_impl(0.f, eid, slot_attach__slotId, slot_attach__attachedTo, animchar, disableUpdate,
                            animchar_node_wtm, animchar_render__root_pos, animchar__visible, slot_attach__calcAnim, true)


[es(on_appear, track=(animchar__visible, animchar__updatable), REQUIRE=animchar__visible, parallel_for=16)]
def force_slot_attach_on_parent_change_state(evt : Event;
                                             attaches_list : EidList;
                                             animchar__updatable : bool = true)
  if !animchar__updatable
    return

  for attachmentEid in attaches_list
    query(attachmentEid) <| $ [es] (slot_attach__slotId : int;
                                    slot_attach__attachedTo : EntityId;
                                    var animchar : AnimcharBaseComponent;
                                    disableUpdate : Tag const?;
                                    var animchar_node_wtm : AnimcharNodesMat44?;
                                    var animchar_render__root_pos : vec4f?;
                                    animchar__visible : bool;
                                    slot_attach__calcAnim : bool = true)
      slot_attach_init_tms_impl(0.f, attachmentEid, slot_attach__slotId, slot_attach__attachedTo, animchar, disableUpdate,
                                animchar_node_wtm, animchar_render__root_pos, animchar__visible, slot_attach__calcAnim, true)


[es(after=visual_offset_updater_es, before=start_async_phys_sim_es)] // Note: start_async_phys_sim_es shall be started after all p-for ESes
def slot_attach_init_tms_es(info : ParallelUpdateFrameDelayed)
  broadcastEventImmediate(SlotAttachUpdateEvent(dt = info.dt))

  query() <| $ [es] (eid : EntityId;
                     slot_attach__slotId : int;
                     slot_attach__attachedTo : EntityId;
                     var transform : float3x4)
    if eid != INVALID_ENTITY_ID
      return
    if slot_attach__slotId < 0 || !slot_attach__attachedTo
      return
    query(slot_attach__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent;
                                              animchar__actOnDemand : Tag const?;
                                              animchar__updatable : bool = true)
      if !animchar__updatable && animchar__actOnDemand != null
        return
      var tmpTm : mat44f
      if animchar_initAttachmentTmAndNodeWtm(animchar, slot_attach__slotId, tmpTm)
        let wtmOfs = *animchar.nodeTree |> geomtree_getWtmOfs()
        transform = float3x4(tmpTm)
        transform[3] += wtmOfs
      else
        show_bad_slot_error(eid, slot_attach__slotId, slot_attach__attachedTo)


[es(REQUIRE_NOT=(slot_attach__secondaryUpdate, sleeping_animchar_update_toggle, slot_attach__toSkeletonAttach),
    REQUIRE=slot_attach, parallel_for=16)]
def slot_attach_first_priority_update_es(info : SlotAttachUpdateEvent;
                                         eid : EntityId;
                                         slot_attach__slotId : int;
                                         slot_attach__attachedTo : EntityId;
                                         var animchar : AnimcharBaseComponent;
                                         disableUpdate : Tag const?;
                                         var animchar_node_wtm : AnimcharNodesMat44?;
                                         var animchar_render__root_pos : vec4f?;
                                         animchar__visible : bool = true;
                                         slot_attach__calcAnim : bool = true;
                                         force_animchar_act : bool = false)
  slot_attach_init_tms_impl(info.dt, eid, slot_attach__slotId, slot_attach__attachedTo, animchar, disableUpdate,
                            animchar_node_wtm, animchar_render__root_pos, animchar__visible, slot_attach__calcAnim, false /*force_update*/, force_animchar_act)


[es(after=slot_attach_first_priority_update_es,
    REQUIRE_NOT=(sleeping_animchar_update_toggle, slot_attach__toSkeletonAttach),
    REQUIRE=(slot_attach, slot_attach__secondaryUpdate), parallel_for=16)]
def slot_attach_secondary_priority_update_es(info : SlotAttachUpdateEvent;
                                             eid : EntityId;
                                             slot_attach__slotId : int;
                                             slot_attach__attachedTo : EntityId;
                                             var animchar : AnimcharBaseComponent;
                                             disableUpdate : Tag const?;
                                             var animchar_node_wtm : AnimcharNodesMat44?;
                                             var animchar_render__root_pos : vec4f?;
                                             animchar__visible : bool = true;
                                             slot_attach__calcAnim : bool = true;
                                             force_animchar_act : bool = false)
  slot_attach_init_tms_impl(info.dt, eid, slot_attach__slotId, slot_attach__attachedTo, animchar, disableUpdate,
                            animchar_node_wtm, animchar_render__root_pos, animchar__visible, slot_attach__calcAnim, false /*force_update*/, force_animchar_act)


def remove_from_eid_list(attach_eid : EntityId; var list : EidList&)
  let it = list |> find_index(attach_eid)
  if it >= 0
    list |> erase(it)

[es(on_appear)]
def slot_attach_on_load_es(evt : Event;
                           slot_attach__slotName : string;
                           var slot_attach__slotId : int&)
  if slot_attach__slotId < 0
    slot_attach__slotId = animchar_addSlotId(slot_attach__slotName)

def attach_to_parent_impl(eid : EntityId; slot_attach__attachedTo : EntityId; slot_attach__inAttachedList : EntityId) : bool
  var result = false
  query(slot_attach__attachedTo) <| $ [es] (var attaches_list : EidList&)
    result = true
    if slot_attach__inAttachedList != slot_attach__attachedTo
      var prevAttachedList = getRW_ecs_EidList(slot_attach__inAttachedList, "attaches_list")
      if prevAttachedList != null
        remove_from_eid_list(eid, *prevAttachedList)

    if attaches_list |> find_index(eid) < 0
      attaches_list |> push(eid)
    if slot_attach__inAttachedList != slot_attach__attachedTo
      setOptional(eid, "slot_attach__inAttachedList", slot_attach__attachedTo)
    if !has(eid, "attachedToParent")
      addSubTemplate(eid, "attached_to_parent")
  return result

[es(tag=gameClient, on_event=CmdInitSlotAttach)]
def slot_attach_init_es(evt : Event;
                        eid : EntityId;
                        slot_attach__attachedTo : EntityId;
                        slot_attach__inAttachedList : EntityId)
  if !attach_to_parent_impl(eid, slot_attach__attachedTo, slot_attach__inAttachedList)
    logerr("Could not slot attach <{getEntityTemplateName(eid)}> to <{getEntityTemplateName(slot_attach__attachedTo)}>")

[es(tag=gameClient, no_order, REQUIRE_NOT=attachedToParent)]
def attach_to_parent_es(info : UpdateStageInfoAct;
                        eid : EntityId;
                        slot_attach__attachedTo : EntityId;
                        slot_attach__inAttachedList : EntityId)
  attach_to_parent_impl(eid, slot_attach__attachedTo, slot_attach__inAttachedList)

[es(on_appear)]
def attach_to_parent_on_create_es(evt : Event;
                                  eid : EntityId;
                                  slot_attach__attachedTo : EntityId;
                                  slot_attach__inAttachedList : EntityId)
  attach_to_parent_impl(eid, slot_attach__attachedTo, slot_attach__inAttachedList)

[es(REQUIRE=attaches_list, on_event=EventEntityCreated)]
def attach_on_parent_create_es(evt : Event;
                               eid aka attached_to_eid : EntityId)
  query() <| $ [es] (eid aka attach_eid : EntityId; slot_attach__attachedTo : EntityId; slot_attach__inAttachedList : EntityId)
    if attached_to_eid == slot_attach__attachedTo
      attach_to_parent_impl(attach_eid, slot_attach__attachedTo, slot_attach__inAttachedList)

[es(REQUIRE=slot_attach__attachedTo, on_event=EventEntityDestroyed)]
def detach_from_parent_es(evt : Event;
                          eid : EntityId;
                          var slot_attach__inAttachedList : EntityId&)
  var attaches_list = getRW_ecs_EidList(slot_attach__inAttachedList, "attaches_list")
  if attaches_list != null
    remove_from_eid_list(eid, *attaches_list)
  slot_attach__inAttachedList = INVALID_ENTITY_ID

[es(REQUIRE=slot_attach__attachedTo, on_event=EventComponentsDisappear)]
def slot_attached_to_disappear_es(evt : Event;
                                  eid : EntityId;
                                  slot_attach__inAttachedList : EntityId)
  var prevAttachedList = getRW_ecs_EidList(slot_attach__inAttachedList, "attaches_list")
  if prevAttachedList != null
    remove_from_eid_list(eid, *prevAttachedList)
    removeSubTemplate(eid, "attached_to_parent")

[es(track=slot_attach__attachedTo)]
def track_attach_es(evt : Event;
                    eid : EntityId;
                    slot_attach__inAttachedList : EntityId;
                    slot_attach__attachedTo : EntityId)
  var prevAttachedList = getRW_ecs_EidList(slot_attach__inAttachedList, "attaches_list")
  if prevAttachedList != null
    remove_from_eid_list(eid, *prevAttachedList)
    removeSubTemplate(eid, "attached_to_parent")
  attach_to_parent_impl(eid, slot_attach__attachedTo, slot_attach__inAttachedList)

[es(on_event=CmdSlotDetach)]
def detach_anim_es(evt : Event; var slot_attach__attachedTo : EntityId&; var slot_attach__slotId : int&)
  slot_attach__attachedTo = INVALID_ENTITY_ID
  slot_attach__slotId = -1
