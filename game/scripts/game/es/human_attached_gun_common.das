module human_attached_gun_common shared
require ecs
require game.utils.team
require Gun
require game.events.events_game
require game.es.interactable_common
require HumanPhys
require DngActor
require DngHuman
require DngNet
require EffectorData
require AnimV20
require GeomNodeTree
require DagorMath


def reset_attached_gun(gun_eid : EntityId)
  query(gun_eid) <| $ [es] (dependsOnBuildingEid : EntityId = INVALID_ENTITY_ID;
                            var mounted_gun : MountedGun;
                            var gun : Gun;
                            var gun__owner : EntityId&;
                            var animchar__updatable : bool&;
                            var interactable : bool&;
                            var mounted_gun__active : bool&;
                            var team : int?)
    gun.appliedControls.shoot = false

    gun__owner = INVALID_ENTITY_ID

    animchar__updatable = false
    interactable = true

    mounted_gun__active = false
    mounted_gun.wishShoot = false
    mounted_gun.locked = false
    if team != null
      *team = TEAM_UNASSIGNED
    query(dependsOnBuildingEid) <| $ [es] (var team : int&)
      team = TEAM_UNASSIGNED


def detach_from_gun(eid : EntityId;
                    var human_attached_gun__attachedGunEid : EntityId&)
  reset_attached_gun(human_attached_gun__attachedGunEid)
  human_attached_gun__attachedGunEid = INVALID_ENTITY_ID
  query(eid) <| $ [es] (var human_net_phys : HumanActor;
                        var animchar_effectors__effectorsState : Object;
                        var human_attached_gun__lhandNodeIdx : int&;
                        var human_attached_gun__rhandNodeIdx : int&)

    var rightHandEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, "r.hand")
    if rightHandEffector != null
      rightHandEffector.weight = 0.0
    var leftHandEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, "l.hand")
    if leftHandEffector != null
      leftHandEffector.weight = 0.0

    human_attached_gun__lhandNodeIdx = -1
    human_attached_gun__rhandNodeIdx = -1

    if is_server()
      human_net_phys.phys.currentState.weapEquipState.progress = 0.0
      human_net_phys.phys.currentState.weapEquipState.curState = HUWeaponEquipState.EES_EQUIPING
      send_net_event(eid, HumanDetachFromGunResponse())

    sendEventImmediate(eid, HumanDetachFromGunComplete())

    human_net_phys.phys.currentState |> human_phys_state_set_isAttached(false)


def gun_needs_detach(gun_eid : EntityId; human_pos : float3)
  var res = false
  query(gun_eid) <| $ [es] (transform : float3x4;
                            animchar : AnimcharBaseComponent;
                            gun_autodetach__threshold : float3;
                            gun_autodetach__nodeId : int = -1)
    var gunTm = transform
    if gun_autodetach__nodeId >= 0
      geomtree_getNodeWtmScalar(*animchar.nodeTree, gun_autodetach__nodeId, gunTm)
    let humanToGunDir = gunTm[3] - human_pos
    let forwardDist = abs(dot(humanToGunDir, gunTm[2]))
    let upDist = dot(humanToGunDir, float3(0.0, 1.0, 0.0))
    let sideDist = abs(dot(humanToGunDir, gunTm[0]))
    if ((upDist < 0.0) || (forwardDist > gun_autodetach__threshold.z) ||
        (upDist > gun_autodetach__threshold.y) || (sideDist > gun_autodetach__threshold.x))
      res = true
  return res


def find_gun_to_attach(human_eid : EntityId; radius : float = 2.0; ignore_checks : bool = false)
  var gunEid = find_interactable(ecs_hash("interactable"), human_eid, radius, ignore_checks) <| $(eid : EntityId)
    return has(eid, "stationary_gun")
  if gunEid != INVALID_ENTITY_ID
    query(human_eid) <| $ [es] (human_net_phys : HumanActor)
      if gun_needs_detach(gunEid, float3(human_net_phys.phys.currentState.location.P))
        gunEid = INVALID_ENTITY_ID
  return gunEid
