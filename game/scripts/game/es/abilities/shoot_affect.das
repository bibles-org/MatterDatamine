require ecs
require app
require net
require DngDm
require game.es.concussion_common
require game.events.events_game
require game.events.events_active_matter
require math.base
require GeomNodeTree
require Gun
require DaWeapons
require DaWeaponProps
require DagorMath
require DagorSystem
require DagorRandom
require DagorDebug3D
require AnimV20
require CapsuleApproximation


def create_cmd_net_shot(launch_desc : LaunchDesc#)
  return <- CmdNetShot(
    shellId = launch_desc.shellId.shellId,
    damageId = launch_desc.shellId.damageId,
    ballisticsId = launch_desc.shellId.ballisticsId,
    gunPropsId = launch_desc.gunPropsId,
    atTime = launch_desc.atTime,
    initialLifeTime = launch_desc.initialLifeTime,
    tm := launch_desc.tm,
    vel = launch_desc.vel,
    firingMode = launch_desc.firingMode,
    bombBayHeight = launch_desc.bombBayHeight)


[es(tag=server)]
def do_shoot_affect(evt : ApplyGameAffect;
                    game_effect__shootShellIndex : int)
  query(evt.targetEid) <| $ [es] (walker_agent__targetEid : EntityId;
                                  animchar : AnimcharBaseComponent;
                                  unit__shootNodeId : int;
                                  gun__propsId : int;
                                  gun__shell_prop_ids : GunShellPropIds;
                                  var gun : Gun)
    var shootTm = IDENT_TM
    geomtree_getNodeWtmScalar(*animchar.nodeTree, unit__shootNodeId, shootTm)
    query(walker_agent__targetEid) <| $ [es] (@shared_comp capsule_approximation : CapsuleApproximation;
                                              animchar aka target_animchar : AnimcharBaseComponent)
      let index = grnd() % length(capsule_approximation.capsuleDatas)
      assume data = capsule_approximation.capsuleDatas[index]
      var targetTm : float3x4
      geomtree_getNodeWtmScalar(*target_animchar.nodeTree, int(data.nodeIndex), targetTm)
      let targetPos = targetTm[3] + (data.a + data.b) * gfrnd()

      assume curShellId = gun__shell_prop_ids[game_effect__shootShellIndex]
      shell_start_get_props(int(curShellId.shellId)) <| $(startProps : ShellStartProps)
        let dir = normalize(targetPos - shootTm[3])
        let vel = dir * startProps.speed * (1.0 + gfrnd() * startProps.speedDispersion)
        using() <| $(var launchDesc : LaunchDesc#)
          launchDesc.shellId = curShellId
          launchDesc.gunPropsId = int16(gun__propsId)
          launchDesc.atTime = get_sync_time()
          launchDesc.initialLifeTime = 0.0
          launchDesc.tm = shootTm
          launchDesc.vel = vel
          launchDesc.firingMode = 0u
          launchDesc.bombBayHeight = 0.0

          gun |> gun_launch(launchDesc, evt.targetEid, evt.targetEid)
          sendEvent(evt.targetEid, create_cmd_net_shot(launchDesc))


[es(tag=server, on_appear)]
def init_unit_shoot_node(evt : Event;
                         eid : EntityId;
                         animchar : AnimcharBaseComponent;
                         unit__shootNodeName : string;
                         var unit__shootNodeId : int&)
  unit__shootNodeId = *animchar.nodeTree |> geomtree_findNodeIndex(unit__shootNodeName)
  if unit__shootNodeId == -1
    logerr("{eid} <{getEntityTemplateName(eid)}>: does not have '{unit__shootNodeName}' animchar node. Failed to assign unit__shootNodeId")