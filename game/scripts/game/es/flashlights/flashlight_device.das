require ecs
require AnimV20
require game.es.ecs_common
require ecs.safe
require math.base
require GeomNodeTree
require game.events.events_game
require game.es.flashlights.flashlight_common
require PhysMat
require DagorMath
require DagorSystem


def get_flashlight_device_actor(flashlight_device_attached_to : EntityId)
  var res = flashlight_device_attached_to
  if flashlight_device_attached_to |> has("equipment_item")
    query(flashlight_device_attached_to) <| $ [es] (slot_attach__attachedTo = INVALID_ENTITY_ID)
      res = slot_attach__attachedTo
  return res


def attach_flashlight_to_parent(actor_eid : EntityId; node_name : string; var node_id : int&)
  query(actor_eid) <| $ [es] (animchar : AnimcharBaseComponent)
    node_id = *animchar.nodeTree |> geomtree_findNodeIndex(node_name)
    if node_id < 0
      logerr("{get_entity_info(actor_eid)}: Invalid flashlight nodeName: {node_name}")


[es(on_appear)]
def init_attached_flashlight_controller(evt : Event;
                                        slot_attach__attachedTo : EntityId;
                                        attached_flashlight_controller__nodeName : string;
                                        var attached_flashlight_controller__nodeId : int&)
  let actorEid = get_flashlight_device_actor(slot_attach__attachedTo)
  attach_flashlight_to_parent(actorEid, attached_flashlight_controller__nodeName, attached_flashlight_controller__nodeId)


[es(on_disappear, on_appear, track=slot_attach__attachedTo, REQUIRE=equipment_item)]
def reattach_flashlight_controller(evt : Event;
                                   slot_attach__attachedTo : EntityId;
                                   equipment_mods__curModInSlots : Object)
  for item in equipment_mods__curModInSlots
    let itemEid = item.value ?? INVALID_ENTITY_ID
    query(itemEid) <| $ [es] (attached_flashlight_controller__nodeName : string;
                              var attached_flashlight_controller__nodeId : int&)
      attach_flashlight_to_parent(slot_attach__attachedTo, attached_flashlight_controller__nodeName, attached_flashlight_controller__nodeId)


[es(tag=server, on_appear)]
def init_attached_flashlight_controller_server(evt : Event;
                                               eid : EntityId;
                                               slot_attach__attachedTo : EntityId;
                                               attached_flashlight_controller__templateName : string;
                                               var attached_flashlight_controller__entityEid : EntityId&)
  attached_flashlight_controller__entityEid = createEntity(attached_flashlight_controller__templateName) <| $(init)
    init |> set("attached_flashlight__actorEid", get_flashlight_device_actor(slot_attach__attachedTo))
    init |> set("slot_attach__attachedTo", slot_attach__attachedTo)
    init |> set("attached_flashlight__controllerEid", eid)


[es(track=slot_attach__attachedTo, REQUIRE=equipment_item)]
def update_attached_flashlight_controller(evt : Event;
                                          slot_attach__attachedTo : EntityId;
                                          attached_flashlight_controller__entityEid : EntityId;
                                          attached_flashlight_controller__nodeName : string;
                                          var attached_flashlight_controller__nodeId : int&)
  query(attached_flashlight_controller__entityEid) <| $ [es] (var attached_flashlight__actorEid : EntityId&;
                                                              var attached_flashlight__isOn : bool&)
    let actorEid = get_flashlight_device_actor(slot_attach__attachedTo)
    attached_flashlight__actorEid = slot_attach__attachedTo
    if attached_flashlight__actorEid == INVALID_ENTITY_ID
      attached_flashlight__isOn = false
    attach_flashlight_to_parent(actorEid, attached_flashlight_controller__nodeName, attached_flashlight_controller__nodeId)


[es(tag=server, on_disappear, REQUIRE=slot_attach__attachedTo)]
def clear_attached_flashlight_controller_server(evt : Event;
                                                var attached_flashlight_controller__entityEid : EntityId&)
  destroyEntity(attached_flashlight_controller__entityEid)
  attached_flashlight_controller__entityEid = INVALID_ENTITY_ID


[es(on_appear)]
def attached_flashlight_appear(evt : Event;
                               attached_flashlight__extraRotation : float3;
                               var attached_flashlight__extraRotationQuat : float4&)
  var q : quat
  assume yaw = deg_to_rad(90.0 + attached_flashlight__extraRotation.y)
  assume pitch = deg_to_rad(attached_flashlight__extraRotation.z)
  assume roll = deg_to_rad(attached_flashlight__extraRotation.x)
  euler_to_quat(yaw, pitch, roll, q)
  attached_flashlight__extraRotationQuat = float4(q)


[es]
def use_flashlight_server(evt : CmdUseFlashlight;
                          attaches_list : EidList;
                          human_weap__currentGunEid : EntityId)
  let someFlashlightDisabled = find_flashlight(attaches_list, human_weap__currentGunEid) <| $ [es, unused_argument(flashlight_eid)] (flashlight_eid : EntityId;
                                                                                                                                     var is_on : bool&)
    if is_on
      is_on = false
      return true
    return false

  if !someFlashlightDisabled
    // Enable the first one
    find_flashlight(attaches_list, human_weap__currentGunEid) <| $ [es, unused_argument(flashlight_eid)] (flashlight_eid : EntityId;
                                                                                                          var is_on : bool&)
      is_on = true
      return true


[es(on_appear)]
def init_flashlight_ray_material(evt : Event;
                                 attached_flashlight__lightRayMaterial : string;
                                 var attached_flashlight__lightRayMaterialId : int&)
  attached_flashlight__lightRayMaterialId = get_material_id(attached_flashlight__lightRayMaterial)


def update_flashlight_device_slot(flashlight_device_eid : EntityId)
  query(flashlight_device_eid) <| $ [es] (flashlight_device__slotNameWithHelmet : string;
                                          flashlight_device__slotNameWithHelmetId : int;
                                          flashlight_device__slotNameWithoutHelmet : string;
                                          flashlight_device__slotNameWithoutHelmetId : int;
                                          slot_attach__attachedTo : EntityId;
                                          var slot_attach__slotName : das_string;
                                          var slot_attach__slotId : int&)
    query(slot_attach__attachedTo) <| $ [es] (human_equipment__slots : Object)
      let isHelmetEquipped = !!(human_equipment__slots.helmet ?? INVALID_ENTITY_ID)
      if isHelmetEquipped && slot_attach__slotId != flashlight_device__slotNameWithHelmetId
        slot_attach__slotName := flashlight_device__slotNameWithHelmet
        slot_attach__slotId = flashlight_device__slotNameWithHelmetId
      elif !isHelmetEquipped && slot_attach__slotId != flashlight_device__slotNameWithoutHelmetId
        slot_attach__slotName := flashlight_device__slotNameWithoutHelmet
        slot_attach__slotId = flashlight_device__slotNameWithoutHelmetId



[es(on_appear)]
def flashlight_device_init(evt : Event;
                           eid aka flashlight_eid : EntityId;
                           flashlight_device__slotNameWithHelmet : string;
                           flashlight_device__slotNameWithoutHelmet : string;
                           var flashlight_device__slotNameWithHelmetId : int&;
                           var flashlight_device__slotNameWithoutHelmetId : int&)
  if flashlight_device__slotNameWithHelmetId < 0 || flashlight_device__slotNameWithoutHelmetId < 0
    flashlight_device__slotNameWithHelmetId = animchar_addSlotId(flashlight_device__slotNameWithHelmet)
    flashlight_device__slotNameWithoutHelmetId = animchar_addSlotId(flashlight_device__slotNameWithoutHelmet)
    update_flashlight_device_slot(flashlight_eid)


[es(track=human_equipment__slots, on_appear, REQUIRE=(am_militant, human_equipment__slots))]
def human_equipment_slots_track_helmet_for_flashlight_device(evt : Event;
                                                             attaches_list : EidList)
  for attach_eid in attaches_list
    if has(attach_eid, "flashlight_device__slotNameWithHelmet")
      update_flashlight_device_slot(attach_eid)