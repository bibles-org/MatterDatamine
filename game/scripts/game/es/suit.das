require ecs
require ecs.safe
require DagorRandom
require game.es.ecs_common
require game.events.events_active_matter
require game.es.player_profile_common
require game.events.player_events
require game.events.inventory_events
require game.es.item_equip_common
require DagorSystem
require HumanPhys


// suit_attachable_item shouldn't be attached to hero itself, only suit_attachable_animchar entity should be attached on equip
[es(on_appear, after=slot_attach_on_load_es, REQUIRE=suit_attachable_item__animcharTemplates)]
def reset_suit_attachable_slot_id_on_load(evt : Event;
                                          var slot_attach__slotId : int&)
  slot_attach__slotId = -1


def update_suit_attachable_animchar(controller_eid : EntityId;
                                    slot_name : string)
  query(controller_eid) <| $ [es] (attachable_suit_controller__attachedAnimcharTemplates : Object;
                                   var attachable_suit_controller__attachedAnimcharEids : Object;
                                   var attachable_suit_controller__suitAnimcharEid : EntityId&)
    var currentAnimcharId = attachable_suit_controller__attachedAnimcharEids[slot_name] ?? INVALID_ENTITY_ID
    if currentAnimcharId != INVALID_ENTITY_ID
      destroyEntity(currentAnimcharId)
      attachable_suit_controller__attachedAnimcharEids |> set(slot_name, INVALID_ENTITY_ID)
      currentAnimcharId = INVALID_ENTITY_ID

    let animcharTemplate = attachable_suit_controller__attachedAnimcharTemplates[slot_name] ?? ""
    if animcharTemplate != ""
      let animcharEid = createEntity(animcharTemplate) <| $ [es] (var init : ComponentsInitializer)
        init |> set("slot_attach__attachedTo", controller_eid)
      attachable_suit_controller__attachedAnimcharEids |> set(slot_name, animcharEid)
      currentAnimcharId = animcharEid

    if slot_name == "top"
      broadcastEvent(EventSuitChanged(oldSuitEid = attachable_suit_controller__suitAnimcharEid, newSuitEid = currentAnimcharId))
      attachable_suit_controller__suitAnimcharEid = currentAnimcharId


[es(tag=server, on_appear)]
def attachable_suit_controller_appear(evt : Event;
                                      eid aka controller_eid : EntityId;
                                      attachable_suit_controller__attachedAnimcharTemplates : Object)
  for attachedAnimcharTemplateData in attachable_suit_controller__attachedAnimcharTemplates
    update_suit_attachable_animchar(controller_eid, attachedAnimcharTemplateData.key)


def private change_attachable_suit_animchar(controller_eid : EntityId; template_name, slot_name : string)
  query(controller_eid) <| $ [es] (var attachable_suit_controller__attachedAnimcharTemplates : Object&)
    attachable_suit_controller__attachedAnimcharTemplates |> set(slot_name, template_name)
  update_suit_attachable_animchar(controller_eid, slot_name)


[es(tag=server, on_disappear)]
def attachable_suit_controller_disappear(evt : Event;
                                         attachable_suit_controller__attachedAnimcharEids : Object)
  for attachedAnimcharEidData in attachable_suit_controller__attachedAnimcharEids
    destroyEntity(attachedAnimcharEidData.value ?? INVALID_ENTITY_ID)


[es(tag=server, track=human_equipment__slots)]
def attachable_suit_track_human_equipment_slots_suit_changed(evt : Event;
                                                             human_equipment__slots : Object;
                                                             attachable_suit_controller__suitType : int;
                                                             possessedByPlr : EntityId)
  let suitEid = human_equipment__slots["chronogene_primary_1"] ?? INVALID_ENTITY_ID
  query(suitEid) <| $ [es] (suit__suitType : int)
    if attachable_suit_controller__suitType != suit__suitType
      broadcastEventImmediate(CmdRecreatePossessedRequest(playerEid = possessedByPlr))


// human_equipment__slots skips initial replication, so need to be filled on client and on server separately
[es(on_appear, REQUIRE=integratedSuit)]
def register_builting_suit_in_equipment(evt : Event; eid : EntityId; var human_equipment__slots : Object)
  var slotObjectEid = getRW_Eid(human_equipment__slots["chronogene_primary_1"])
  if slotObjectEid != null
    *slotObjectEid = eid


[es(tag=server, on_appear, REQUIRE=suit_attachable_item_in_equipment)]
def suit_attachable_sex_based_item_in_equipment_appear(evt : Event;
                                                       suit_attachable_item__suitTypeBasedAnimcharTemplates : StringList;
                                                       slot_attach__slotName : string;
                                                       slot_attach__attachedTo : EntityId;
                                                       var suit_attachable_item_in_equipment__attachedTo : EntityId&)
  let animcharTemplatesCount = length(suit_attachable_item__suitTypeBasedAnimcharTemplates)
  if animcharTemplatesCount == 0
    return

  query(slot_attach__attachedTo) <| $ [es] (attachable_suit_controller__suitType : int)
    if attachable_suit_controller__suitType >= animcharTemplatesCount
      logerr("{get_entity_info(slot_attach__attachedTo)}: invalid suit type {attachable_suit_controller__suitType}! Max suit type is {animcharTemplatesCount - 1}!")
      return

    suit_attachable_item_in_equipment__attachedTo = slot_attach__attachedTo

    assume animcharTemplate = suit_attachable_item__suitTypeBasedAnimcharTemplates[attachable_suit_controller__suitType]
    change_attachable_suit_animchar(slot_attach__attachedTo, string(animcharTemplate), slot_attach__slotName)


[es(tag=server, on_appear, REQUIRE=suit_attachable_item_in_equipment)]
def suit_attachable_item_in_equipment_appear(evt : Event;
                                             suit_attachable_item__animcharTemplates : Object;
                                             slot_attach__attachedTo : EntityId;
                                             var suit_attachable_item_in_equipment__attachedTo : EntityId&)
  suit_attachable_item_in_equipment__attachedTo = slot_attach__attachedTo
  for templ in suit_attachable_item__animcharTemplates
    var templName = templ.value ?? ""
    if empty(templName)
      let templatesList = get_ecs_StringList(templ.value)
      if templatesList != null && length(*templatesList) > 0
        let idx = rnd_int(0, length(*templatesList) - 1)
        templName := (*templatesList)[idx]

    change_attachable_suit_animchar(slot_attach__attachedTo, templName, templ.key)


[es(tag=server, on_disappear, REQUIRE=suit_attachable_item_in_equipment)]
def suit_attachable_item_in_equipment_disappear(evt : Event;
                                                slot_attach__slotName : string;
                                                suit_attachable_item_in_equipment__attachedTo : EntityId)
  change_attachable_suit_animchar(suit_attachable_item_in_equipment__attachedTo, "", slot_attach__slotName)



[es]
def suit_attachable_item_holster_attached_animchars_on_equip(evt : EquipmentApplyEffects;
                                                             suit_attachable_item__holsterAttachedAnimchars : StringList)
  assume holsterAttachedAnimchars = suit_attachable_item__holsterAttachedAnimchars
  query(evt.actorEid) <| $ [es] (var attachable_suit_controller__holsterAttachedAnimchars : StringList)
    if length(attachable_suit_controller__holsterAttachedAnimchars) < length(holsterAttachedAnimchars)
      attachable_suit_controller__holsterAttachedAnimchars |> resize(length(holsterAttachedAnimchars))
    for weaponSlot, holsterAnimchar in iter_range(holsterAttachedAnimchars), holsterAttachedAnimchars
      if holsterAnimchar != "" && attachable_suit_controller__holsterAttachedAnimchars[weaponSlot] != holsterAnimchar
        attachable_suit_controller__holsterAttachedAnimchars[weaponSlot] := holsterAnimchar
        sendEvent(evt.actorEid, EventReattachWeapon(slot = weaponSlot))


[es]
def suit_attachable_item_holster_attached_animchars_on_unequip(evt : EquipmentRevertEffects;
                                                               suit_attachable_item__holsterAttachedAnimchars : StringList)
  assume holsterAttachedAnimchars = suit_attachable_item__holsterAttachedAnimchars
  query(evt.actorEid) <| $ [es] (var attachable_suit_controller__holsterAttachedAnimchars : StringList)
    if length(attachable_suit_controller__holsterAttachedAnimchars) < length(holsterAttachedAnimchars)
      attachable_suit_controller__holsterAttachedAnimchars |> resize(length(holsterAttachedAnimchars))
    for weaponSlot, holsterAnimchar in iter_range(holsterAttachedAnimchars), holsterAttachedAnimchars
      if holsterAnimchar != ""
        attachable_suit_controller__holsterAttachedAnimchars[weaponSlot] := ""
        sendEvent(evt.actorEid, EventReattachWeapon(slot = weaponSlot))


[es(on_appear, REQUIRE=deadEntity)]
def attachable_suit_controller_append_template_on_death(evt : Event;
                                                        eid : EntityId;
                                                        attachable_suit_controller__appendOnDeath : string)
  addSubTemplate(eid, attachable_suit_controller__appendOnDeath)



def attachable_suit_decorator_update(attachable_suit_decorator_eid : EntityId)
  query(attachable_suit_decorator_eid) <| $ [es(REQUIRE=attachable_suit_decorator)] (attachable_suit_controller__suitAnimcharEid : EntityId;
                                                                                     animchar_dynmodel_nodes_hider__forceShownNodes aka decorator_animchar_dynmodel_nodes_hider__forceShownNodes : StringList;
                                                                                     animchar_dynmodel_nodes_hider__hiddenNodes aka decorator_animchar_dynmodel_nodes_hider__hiddenNodes : StringList)
    query(attachable_suit_controller__suitAnimcharEid) <| $ [es] (var animchar_dynmodel_nodes_hider__forceShownNodes aka suit_animchar_dynmodel_nodes_hider__forceShownNodes : StringList;
                                                                  var animchar_dynmodel_nodes_hider__hiddenNodes aka suit_animchar_dynmodel_nodes_hider__hiddenNodes : StringList)
      suit_animchar_dynmodel_nodes_hider__forceShownNodes := decorator_animchar_dynmodel_nodes_hider__forceShownNodes
      suit_animchar_dynmodel_nodes_hider__hiddenNodes := decorator_animchar_dynmodel_nodes_hider__hiddenNodes


[es(tag=server, on_appear,
  REQUIRE=(attachable_suit_decorator, animchar_dynmodel_nodes_hider__forceShownNodes,
    animchar_dynmodel_nodes_hider__hiddenNodes, attachable_suit_controller__suitAnimcharEid),
  track=(animchar_dynmodel_nodes_hider__forceShownNodes,
    animchar_dynmodel_nodes_hider__hiddenNodes, attachable_suit_controller__suitAnimcharEid))]
def attachable_suit_decorator_track(evt : Event;
                                    eid aka attachable_suit_decorator_eid : EntityId)
  attachable_suit_decorator_update(attachable_suit_decorator_eid)


[es(tag=server, on_appear, REQUIRE=suit_militant_attachable_animchar)]
def attachable_suit_decorator_process_suit_appear(evt : Event;
                                                  slot_attach__attachedTo : EntityId)
  attachable_suit_decorator_update(slot_attach__attachedTo)




