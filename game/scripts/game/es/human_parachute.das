require ecs
require app
require net
require DngNet
require GamePhys
require math.base
require DagorMath
require DngHuman
require Dacoll
require game.events.events
require game.events.events_game
require game.es.human.human_parachute_common
require game.events.events_active_matter


[es(tag=server, on_appear)]
def human_parachute_control_effect(evt : Event;
                                   eid : EntityId;
                                   landing_effect_template : string;
                                   var landing_control_effect__eid : EntityId&)
  landing_control_effect__eid = createEntity(landing_effect_template) <| $(init)
    init |> set("human_parachute_control_effect__attachedTo", eid)


[es(tag=server, no_order)]
def can_open_parachute(evt : ParallelUpdateFrameDelayed;
                       human_parachute_control_effect__attachedTo : EntityId;
                       human_parachute__minDeployHeight : float;
                       human_parachute__minDeployVelocity : float;
                       human_parachute__autoDeployHeight : float;
                       var human_parachute__canDeploy : bool&)
  query(human_parachute_control_effect__attachedTo) <| $ [es] (human_net_phys__velocity : float3;
                                                               human_net_phys__isInAir : bool;
                                                               human_net_phys : HumanActor;
                                                               transform : float3x4)
    let upDir = -human_net_phys.phys.currentState.gravDirection
    let gravVelProj = dot(upDir, human_net_phys__velocity)
    let isAllowedDeployVelocity = gravVelProj < -human_parachute__minDeployVelocity
    let isAllowedDeployHeight = get_parachute_altitude(transform[3], -upDir, human_parachute__autoDeployHeight + 100.f) > human_parachute__minDeployHeight
    human_parachute__canDeploy = human_net_phys__isInAir && isAllowedDeployVelocity && isAllowedDeployHeight


[es(tag=server, before=human_parachute, REQUIRE_NOT=disableUpdate)]
def human_parachute_deploy(evt : CmdPostPhysUpdate;
                           human_net_phys : HumanActor;
                           human_net_phys__isInAir : bool;
                           landing_control_effect__eid : EntityId)
  let pos = float3(human_net_phys.phys.currentState.location.P)
  let gravDir = human_net_phys.phys.currentState.gravDirection
  query(landing_control_effect__eid) <| $ [es] (human_parachute__canDeploy : bool;
                                                human_parachute__autoDeployHeight : float;
                                                var human_parachute__isDeployed : bool&;
                                                var human_parachute__deployedAtTime : float&;
                                                var human_parachute__closedAtTime : float&)
    if !human_parachute__isDeployed && human_parachute__canDeploy && human_parachute__autoDeployHeight > 0.f && get_parachute_altitude(pos, gravDir, human_parachute__autoDeployHeight + 100.f) < human_parachute__autoDeployHeight
      human_parachute__isDeployed = true
      human_parachute__deployedAtTime = get_sync_time()

    if !human_net_phys__isInAir && human_parachute__isDeployed
      human_parachute__isDeployed = false
      human_parachute__closedAtTime = get_sync_time()


[es(tag=server, track=human_parachute__isDeployed, after=(human_parachute_weapons_use, human_parachute_freefall))]
def human_parachute_control_effect_delete_on_land(evt : Event;
                                                  eid : EntityId;
                                                  human_parachute_control_effect__attachedTo : EntityId;
                                                  human_parachute__isDeployed : bool)
  if !human_parachute__isDeployed
    query(human_parachute_control_effect__attachedTo) <| $ [es] (var landing_control_effect__eid : EntityId&)
      landing_control_effect__eid = INVALID_ENTITY_ID
    destroyEntity(eid)


[es(tag=server, on_event=EventEntityDied)]
def human_parachute_control_effect_delete_on_death(evt : Event;
                                                   var landing_control_effect__eid : EntityId&)
  destroyEntity(landing_control_effect__eid)
  landing_control_effect__eid = INVALID_ENTITY_ID


[es(after=human_parachute_deploy, REQUIRE_NOT=disableUpdate)]
def human_parachute(evt : CmdPostPhysUpdate;
                    landing_control_effect__eid : EntityId;
                    var human_net_phys : HumanActor)
  query(landing_control_effect__eid) <| $ [es] (human_parachute__maxFallSpeed : float;
                                                human_parachute__deployTime : float;
                                                human_parachute__deployedAtTime : float;
                                                human_parachute__isDeployed : bool)
    if !human_parachute__isDeployed
      return
    let dt = evt.dt
    assume curState = human_net_phys.phys.currentState
    let upDir = -human_net_phys.phys.currentState.gravDirection
    let gravVelProj = dot(upDir, curState.velocity)
    if gravVelProj < 0.0
      let currentVelocity = length(curState.velocity)
      let wantedVelocityRatio = cvt(get_sync_time(), human_parachute__deployedAtTime, human_parachute__deployedAtTime + human_parachute__deployTime,
                                    0.0, 1.0)
      let wantedVelocity = currentVelocity + (human_parachute__maxFallSpeed - currentVelocity) * square(wantedVelocityRatio)
      // g = k*V^2 where V is desired max speed
      let k = safediv(gravity(), square(wantedVelocity))
      let ungravitatedVelocity = curState.velocity + upDir * gravity() * dt
      curState.velocity -= k * normalize(ungravitatedVelocity) * length_sq(ungravitatedVelocity) * dt


[es(tag=server, track=human_parachute__isDeployed, before=human_parachute_control_effect_delete_on_land)]
def human_parachute_freefall(evt : Event;
                             human_parachute_control_effect__attachedTo : EntityId;
                             human_parachute__isDeployed : bool)
  query(human_parachute_control_effect__attachedTo) <| $ [es] (var human_freefall__canFreefall : bool&)
    if human_parachute__isDeployed
      human_freefall__canFreefall = false
      sendEventImmediate(human_parachute_control_effect__attachedTo, CmdHumanEndFreefall())
    else
      human_freefall__canFreefall = true


[es(tag=server, track=human_parachute__isDeployed, before=human_parachute_control_effect_delete_on_land)]
def human_parachute_weapons_use(evt : Event;
                                human_parachute_control_effect__attachedTo : EntityId;
                                human_parachute__hideWeaponAffectTemplate : string;
                                var human_parachute__hideWeaponAffectEid : EntityId&;
                                human_parachute__isDeployed : bool)
  if human_parachute__isDeployed
    if human_parachute__hideWeaponAffectEid == INVALID_ENTITY_ID
      human_parachute__hideWeaponAffectEid = createEntity(human_parachute__hideWeaponAffectTemplate) <| $(init)
        init |> set("game_effect__attachedTo", human_parachute_control_effect__attachedTo)
  else
    destroyEntity(human_parachute__hideWeaponAffectEid)
    human_parachute__hideWeaponAffectEid = INVALID_ENTITY_ID
