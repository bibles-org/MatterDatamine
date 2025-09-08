require ecs
require ecs.common
require ecs.safe
require CollRes
require DagorSystem
require DagorConsole
require AnimV20
require dm
require DagorRandom


[es(on_appear)]
def dm_parts_es(evt : Event;
                collres : CollisionResource&;
                var dm_parts__parts : Object&;
                var dm_parts__dmgMult : FloatList&;
                var dm_parts__type : StringList&;
                var dm_parts__bulletTransparent : BoolList&;
                var dm_parts__partsArmor : FloatList&;
                var dm_parts__partsArmorMin : FloatList?;
                var dm_parts__dotMult : FloatList?;
                var dm_parts__armorItemEids : EidList?)
  let haveSpecificParts = !empty(dm_parts__parts)
  var type_str = ""
  for nodeId in range(0, collres_get_nodesCount(collres))
    var dmgMult = 1.0f
    var dotMult = 0.0f
    var armor = 0.0f
    var armorMin = 0.0f
    let name = collres_get_node(collres, nodeId) |> collnode_get_name()
    var part = dm_parts__parts[name] ?as Object
    var bulletTransparent = haveSpecificParts
    if part != null
      dmgMult = get_float(*part, "dmgMult") ?? dmgMult
      dotMult = get_float(*part, "dotMult") ?? 0.0f
      armor = get_float(*part, "armor") ?? armor
      armorMin = get_float(*part, "armorMin") ?? armorMin
      type_str = get_string(*part, "type", "")
      var collNodeId =  (*part)["collNodeId"] ?as int
      assert(collNodeId == null || *collNodeId == nodeId)
      set(*part, "collNodeId", nodeId)
      bulletTransparent = get_bool(*part, "bulletTransparent") ?? false
    else
      dm_parts__parts |> push_to_object(name) <| $(var info : Object)
        info |> set("collNodeId", nodeId)
      type_str = ""
    push(dm_parts__dmgMult, dmgMult)
    push(dm_parts__type, type_str)
    push(dm_parts__bulletTransparent, bulletTransparent)
    push(dm_parts__partsArmor, armor)
    if dm_parts__partsArmorMin != null
      push(*dm_parts__partsArmorMin, armorMin)
    if dm_parts__dotMult != null
      push(*dm_parts__dotMult, dotMult)

  if dm_parts__armorItemEids != null
    resize(*dm_parts__armorItemEids, collres_get_nodesCount(collres))

[es(on_appear)]
def dm_parts_verefication_es(evt : Event;
                             eid : EntityId;
                             collres : CollisionResource&;
                             dm_parts__parts : Object&;
                             collres__res : string = "")
  for dmPart in dm_parts__parts
    let nodeIdx = collres_get_node_index_by_name(collres, dmPart.key)
    if nodeIdx < 0
      logerr("Entity with template '{getEntityTemplateName(eid)}' references collnode '{dmPart.key}'
              in 'dm_parts__parts' component and it is not found in collres '{collres__res}'")

def find_anim_by_name(name : string;
                      dm_parts__parts : Object&)
  let it = dm_parts__parts[name] ?as Object
  if it == null
    return -1
  let animModeName = get_string(*it, "type", "")
  return animModeName != "" ? animV20_get_enum_value_by_name(animModeName) : -1

[es(tag=render, on_appear)]
def client_dm_parts_es(evt : Event;
                       collres : CollisionResource&;
                       dm_parts__parts : Object&;
                       var dm_parts__hitPartsAnimationId : Array&)
  for nodeId in range(0, collres_get_nodesCount(collres))
    push(dm_parts__hitPartsAnimationId, find_anim_by_name(collres_get_node(collres, nodeId) |> collnode_get_name(), dm_parts__parts))

[es(tag=server, on_appear)]
def damage_model_part_state_init_es(evt : Event;
                                    damage_model : DamageModel&;
                                    var dm_state : UInt16List)
  dm_state |> resize(get_damage_part_props_count(damage_model.dmData))
  for hp in dm_state
    hp = uint16(MAX_REL_HP_FIXED)


[es(tag=server, after=damage_model_part_alive_update_es)]
def vehicle_damage_state_updater_es(info : UpdateStageInfoAct;
                                    damage_model : DamageModel&;
                                    var dm_state : UInt16List)
  for id in range(get_damage_part_props_count(damage_model.dmData))
    dm_state[id] = get_damage_part_props(damage_model.dmData, id).relHpFixed


[es(tag=server, REQUIRE=dm_events, track=dm_events)]
def damage_model_hitcamera_es_event(evt : Event;
                                    eid : EntityId;
                                    dm_events__offender : EntityId;
                                    var dm_events__xrayActivator : EntityId&;
                                    xray__activateAlways : Tag const?)
  let xrayActivator = dm_events__xrayActivator
  dm_events__xrayActivator = INVALID_ENTITY_ID
  let needShowXray = has(xrayActivator, "xrayActivator") || xray__activateAlways != null
  if (!needShowXray || (!(get_Eid(dm_events__offender, "possessedByPlr") ?? INVALID_ENTITY_ID)
      && !has(dm_events__offender, "hitcam__listener")))
    return
  // Create an entity with request of the hitcamera to deleay a sending the ShowHitCamera event
  // to moment where the isExploded and the fire_damage__isFatal will be updated to a new state.
  // This entity will be procceed only once at the UpdateStageInfoAct below and the destroyed.
  createEntity("xray_request") <| $(var init)
    init |> set("xray_request__targetEid", eid)

[es(on_appear, before=dm_phys_parts_es)]
def damage_model_disable_parts_es(evt : Event;
                                  disableDMParts : StringList&;
                                  var damage_model : DamageModel&)
  for partName in disableDMParts
    let partId = find_part_id_by_name(damage_model, string(partName))
    if partId >= 0
      set_enabled <| get_damage_part_props_for_modification(damage_model.dmData, partId) <| false

[es(tag=gameClient, track=dm_state)]
def damage_model_sync_state_es(evt : Event;
                               dm_state : UInt16List;
                               var damage_model : DamageModel&)
  if (length(dm_state) != get_damage_part_props_count(damage_model.dmData))
    logerr("length(dm_state)!= get_damage_part_props_count(damage_model.dmData) (%d != %d) {length(dm_state)} {get_damage_part_props_count(damage_model.dmData)}")
    return

  for i in range(0, length(dm_state))
    get_damage_part_props_for_modification(damage_model.dmData, i).relHpFixed = dm_state[i]
