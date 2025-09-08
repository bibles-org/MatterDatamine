require ecs
require ecs.safe
require AnimV20
require math.base
require game.es.inventory_drop_common
require game.es.ecs_common
require GeomNodeTree
require DagorSystem


[es(on_disappear, tag=server)]
def cleanup_equipment_on_destroy_es(evt : Event; human_equipment__slots : Object)
  for it in human_equipment__slots
    let itemEid = get_Eid(it.value) ?? INVALID_ENTITY_ID
    destroyEntity(itemEid)


[es(on_disappear, tag=server)]
def cleanup_intentory_on_destroy_es(evt : Event; itemContainer : EidList)
  for itemEid in itemContainer
    destroyEntity(itemEid)


[es(on_disappear, tag=server)]
def destroy_attached_weapon_mods_on_ground(evt : Event; var gun_mods__curModInSlots : Object&)
  for gunModInSlot in gun_mods__curModInSlots
    let gunModEid = get_Eid(gunModInSlot.value) ?? INVALID_ENTITY_ID
    destroyEntity(gunModEid)
  gun_mods__curModInSlots |> clear()


def get_equipment_holder_pos(eid : EntityId)
  var pos : float3

  query(eid) <| $ [es] (slot_attach__slotId : int;
                        slot_attach__attachedTo : EntityId)
    query(slot_attach__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent)
      if slot_attach__slotId >= 0
        pos = *animchar.nodeTree |> geomtree_getNodeWpos(slot_attach__slotId)

  return pos


[es(on_disappear, tag=server, before=unequip_equipment_on_destroy)]
def destroy_attached_equipment_mods_on_ground(evt : Event;
                                              eid : EntityId;
                                              item__hp : float = 1.0;
                                              slot_attach__slotId : int const?;
                                              slot_attach__attachedTo : EntityId const?;
                                              var equipment_mods__curModInSlots : Object&)
  if length(equipment_mods__curModInSlots) > 0
    var tm = IDENT_TM
    tm[3] = get_equipment_holder_pos(eid)

    for equipmentModInSlot in equipment_mods__curModInSlots
      let equipmentModEid = get_Eid(equipmentModInSlot.value) ?? INVALID_ENTITY_ID

      query(equipmentModEid) <| $ [es] (item__dropOnGroundIfParentDestroyed : Tag const?;
                                        item__humanOwnerEid : EntityId = INVALID_ENTITY_ID)
        if item__dropOnGroundIfParentDestroyed != null && item__hp <= 0.0
          if tm[3] != float3()
            validate_gameplay_position(tm[3]) <| $()
              return <- "equipmentModEid={get_entity_info(equipmentModEid)}
eid={get_entity_info(equipmentModEid)}
item__humanOwnerEid={item__humanOwnerEid}
slot_attach__slotId={slot_attach__slotId}
slot_attach__attachedTo={slot_attach__attachedTo}"
            drop_item_phys(equipmentModEid, tm)
          elif item__humanOwnerEid != INVALID_ENTITY_ID
            drop_item(equipmentModEid, item__humanOwnerEid)
          else
            logerr("Failed to drop item on ground on parent destruction! equipmentModEid={get_entity_info(equipmentModEid)}
eid={get_entity_info(equipmentModEid)}
item__humanOwnerEid={item__humanOwnerEid}
slot_attach__slotId={slot_attach__slotId}
slot_attach__attachedTo={slot_attach__attachedTo}")
            destroyEntity(equipmentModEid)
        else
          destroyEntity(equipmentModEid)
    equipment_mods__curModInSlots |> clear()