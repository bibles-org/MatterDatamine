require ecs
require ecs.common
require app
require dm
require DngDm
require game.events.events
require game.events.vehicle_events
require DmFire
require AnimV20
require CollRes

def is_part_on_fire(fire_damage : FireDamageComponent; part_id : int)
  for fire in fire_damage.data
    if fire.partNo == part_id
      return true
  return false

def is_fire_effect(effects : int)
  return (effects & (1 << int(DamageEffectType.DM_EFFECT_FIRE))) != 0

def process_fire_damage_effect(eid : EntityId;
                               offender : EntityId;
                               part_id : int;
                               effects : int;
                               transform : float3x4;
                               animchar : AnimcharBaseComponent;
                               damage_model : DamageModel;
                               collres : CollisionResource;
                               fire_damage__fireParamsPreset : string;
                               var fire_damage : FireDamageComponent&;
                               var fire_damage__isBurn : bool&)
  if is_fire_effect(effects) && !is_part_on_fire(fire_damage, part_id)
    let collNodeId = damage_model.dmData |> get_collision_node_id(part_id)
    let collisionNode = collres |> collres_get_node(collNodeId)
    var nodeTm : float3x4
    collres |> collres_get_collision_node_tm(collNodeId, transform, animchar.nodeTree, nodeTm)

    using() <| $(var desc : StartBurnDesc#)
      desc.offender = offender
      desc.partId = part_id
      desc.fireParamsId = get_fire_params_id(fire_damage__fireParamsPreset)
      if desc.fireParamsId < 0
        desc.fireParamsId = 0
      startburndesc_setNodeId(desc, collisiondata_getGeomNodeIdByCollNode(damage_model.collisionData, collNodeId))
      desc.initiatorId = uint(-1)
      desc.atTime = double(get_sync_time())
      desc.offset = inverse(transform) * nodeTm * collisionNode.boundingSphere.c
      dm_calcRadius(desc, collisionNode.boundingSphere, collisionNode.boundingSphere.r)

      fire_component_startBurn(fire_damage, eid, desc)

      if !has(eid, "non_burnable")
        fire_damage__isBurn = true

[es(tag=server)]
def damage_effects_fire_on_part_damage(evt : EventOnPartDamageEffects;
                                       eid : EntityId;
                                       transform : float3x4;
                                       animchar : AnimcharBaseComponent;
                                       damage_model : DamageModel;
                                       collres : CollisionResource;
                                       fire_damage__fireParamsPreset : string = "";
                                       var fire_damage : FireDamageComponent&;
                                       var fire_damage__isBurn : bool&)
  process_fire_damage_effect(eid, evt.offender, evt.partId, evt.effects,
                             transform, animchar, damage_model, collres, fire_damage__fireParamsPreset, fire_damage, fire_damage__isBurn)

[es(tag=server)]
def damage_effects_fire_on_part_kill(evt : EventOnPartKillEffects;
                                     eid : EntityId;
                                     transform : float3x4;
                                     animchar : AnimcharBaseComponent;
                                     damage_model : DamageModel;
                                     collres : CollisionResource;
                                     fire_damage__fireParamsPreset : string = "";
                                     var fire_damage : FireDamageComponent&;
                                     var fire_damage__isBurn : bool&)
  process_fire_damage_effect(eid, evt.offender, evt.partId, evt.effects,
                             transform, animchar, damage_model, collres, fire_damage__fireParamsPreset, fire_damage, fire_damage__isBurn)

def is_cut_effect(effects : int)
  return (effects & (1 << int(DamageEffectType.DM_EFFECT_CUT))) != 0

def process_cut_damage_effect(eid : EntityId;
                              offender : EntityId;
                              part_id : int;
                              effects : int;
                              damage_model : DamageModel)
  assume partState = get_damage_part_props(damage_model.dmData, part_id).state
  if is_cut_effect(effects) && partState != DamagePartState.DP_STATE_CUT
    sendEvent(eid, EventCutPart(offender = offender, partNo = part_id))

[es(tag=server)]
def damage_effects_cut_on_part_damage(evt : EventOnPartDamageEffects;
                                      eid : EntityId;
                                      damage_model : DamageModel)
  process_cut_damage_effect(eid, evt.offender, evt.partId, evt.effects, damage_model)

[es(tag=server)]
def damage_effects_cut_on_part_kill(evt : EventOnPartKillEffects;
                                    eid : EntityId;
                                    damage_model : DamageModel)
  process_cut_damage_effect(eid, evt.offender, evt.partId, evt.effects, damage_model)
