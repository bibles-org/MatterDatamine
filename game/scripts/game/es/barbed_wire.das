require ecs
require PhysMat
require HumanPhys
require DngHuman
require AnimV20
require DngDm
require CollRes
require Dacoll
require game.events.events_active_matter
require game.events.events
require game.es.damage_systems.damage_model_common


[es(tag=server, on_appear)]
def barbwire_mat_damage_init(evt : Event; barbwire_damage__matName : string; var barbwire_damage__matId : int&)
  barbwire_damage__matId = get_material_id(barbwire_damage__matName)

[es(tag=server, no_order)]
def barbwire_mat_damage(info : CmdPostPhysUpdate;
                        eid : EntityId;
                        transform : float3x4;
                        human_net_phys : HumanActor;
                        collres : CollisionResource;
                        animchar : AnimcharBaseComponent;
                        barbwire_damage__matId : int;
                        barbwire_damage__damagePerSecond : float;
                        human_damage_model__parts : Object)
  assume phys = human_net_phys.phys
  assume previousState = phys.previousState
  assume currentState = phys.currentState
  var hasBarbwireContact = false
  var barbContactPos : float3
  human_phys_state_get_torso_contacts(currentState) <| $(contacts : array<CollisionContactDataMin>#)
    for c in contacts
      if c.matId == barbwire_damage__matId
        hasBarbwireContact = true
        barbContactPos = c.wpos
        break

  if hasBarbwireContact
    let isChangingPos = abs(currentState.heightCurVel) > 1.0
    let isRotating = length_sq(currentState.targetGunSpd) > 1.0
    let isMoving = length_sq(currentState.velocity) > 0.01
    let isChangingWeapon = currentState.weapEquipState.curState != HUWeaponEquipState.EES_EQUIPED
    let isChangingLean = abs(currentState.leanPosition - previousState.leanPosition) > 0.1
    if isRotating || isChangingPos || isMoving || isChangingWeapon || isChangingLean
      let damage = info.dt * barbwire_damage__damagePerSecond
      var bestNodeId = -1
      var bestDstSq = FLT_MAX
      var tmpTm : float3x4
      for_each_part_in_damage_model(human_damage_model__parts) <| $(bodypart : BodyPartV2)
        if bodypart.barbwireImpact && length(bodypart.nodeIds) > 0
          collres_get_collision_node_tm(collres, bodypart.nodeIds[0], transform, animchar.nodeTree, tmpTm)
          let dstSq = distance_sq(tmpTm[3], barbContactPos)
          if dstSq < bestDstSq
            bestDstSq = dstSq
            bestNodeId = bodypart.nodeIds[0]
        return true
      if bestNodeId != -1
        human_damage_model_damage_entity(eid, eid, damage, bestNodeId, DamageType.DM_BARBWIRE)