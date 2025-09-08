require ecs
require ecs.safe
require ecs.common
require game.events.inventory_events
require game.events.events_active_matter


[es(on_appear, REQUIRE=item_in_equipment)]
def item_in_equipment_appear(evt : Event;
                             equipment_mods__curModInSlots : Object const?;
                             var animchar__updatable : bool&)
  if equipment_mods__curModInSlots != null
    animchar__updatable = true


[es(on_appear, REQUIRE_NOT=(item_in_equipment, item_in_world))]
def equipment_in_inventory_appear(evt : Event;
                                  equipment_mods__curModInSlots : Object)
  for modInSlot in equipment_mods__curModInSlots
    query(modInSlot.value ?? INVALID_ENTITY_ID) <| $ [es] (var slot_attach__visible : bool&)
      slot_attach__visible = false


[es(on_appear, REQUIRE=item_in_world)]
def equipment_in_world_appear(evt : Event;
                              equipment_mods__curModInSlots : Object;
                              var animchar__updatable : bool&)
  for modInSlot in equipment_mods__curModInSlots
    query(modInSlot.value ?? INVALID_ENTITY_ID) <| $ [es] (var slot_attach__visible : bool&)
      slot_attach__visible = true
      animchar__updatable = true


[es(on_appear, REQUIRE=slot_attach_fps_hidable_equipment, track=slot_attach__visible, track=slot_attach__attachedTo,
  after=animchar_attachable_visibility_es)]
def slot_attach_fps_hidable_equipment_appear(evt : Event;
                                             slot_attach__attachedTo : EntityId;
                                             var slot_attach__visible : bool&;
                                             var animchar_render__enabled : bool&)
  slot_attach__visible = slot_attach__attachedTo != INVALID_ENTITY_ID && !(slot_attach__attachedTo |> has("watchedByPlr"))
  animchar_render__enabled = slot_attach__visible


[es(on_disappear, REQUIRE=(item__invisible, slot_attach_fps_hidable_equipment), after=unhide_animchar)]
def slot_attach_fps_hidable_equipment_appear_after_unhide_animchar(evt : Event;
                                                                   slot_attach__attachedTo : EntityId;
                                                                   var slot_attach__visible : bool&;
                                                                   var animchar_render__enabled : bool&)
  slot_attach__visible = slot_attach__attachedTo != INVALID_ENTITY_ID && !(slot_attach__attachedTo |> has("watchedByPlr"))
  animchar_render__enabled = slot_attach__visible


[es(on_appear, REQUIRE=watchedByPlr)]
def slot_attach_fps_hidable_equipment_owner_appear(evt : Event;
                                                   attaches_list : EidList)
  let isReplayTpsCam = find_query() <| $ [es(REQUIRE=replayCamera)] (camera__active, isTpsView : bool)
    return camera__active && isTpsView
  if !isReplayTpsCam
    for attach in attaches_list
      query(attach) <| $ [es(REQUIRE=slot_attach_fps_hidable_equipment)] (var slot_attach__visible : bool&)
        slot_attach__visible = false


[es(on_disappear, REQUIRE=watchedByPlr)]
def slot_attach_fps_hidable_equipment_owner_disappear(evt : Event;
                                                      attaches_list : EidList)
  for attach in attaches_list
    query(attach) <| $ [es(REQUIRE=slot_attach_fps_hidable_equipment)] (var slot_attach__visible : bool&)
      slot_attach__visible = true


[es(on_disappear, track=camera__active)]
def slot_attach_fps_hidable_equipment_owner_camera_track(evt : Event;
                                                         camera__active : bool;
                                                         camera__target = INVALID_ENTITY_ID)
  if camera__active
    query() <| $ [es(REQUIRE=hero)] (eid : EntityId; attaches_list : EidList)
      for attach in attaches_list
        query(attach) <| $ [es(REQUIRE=slot_attach_fps_hidable_equipment)] (var slot_attach__visible : bool&)
          slot_attach__visible = camera__target != eid


[es(REQUIRE=watchedByPlr)]
def update_slot_attach_fps_hidable_equipment_visability_on_unequip(evt : EventOnEquipmentUnequipped)
  query(evt.equipmentEid) <| $ [es(REQUIRE=slot_attach_fps_hidable_equipment)] (var animchar_render__enabled : bool&)
    animchar_render__enabled = true