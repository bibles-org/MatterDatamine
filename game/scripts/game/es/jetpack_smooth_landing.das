require ecs
require Dacoll
require DagorMath
require GamePhys
require game.events.events

[es(before=human_jetpack_es)]
def jetpack_smooth_landing(evt : CmdPostPhysUpdate;
                           transform : float3x4;
                           isInVehicle : bool;
                           human_net_phys__velocity : float3;
                           human_jetpack__flightMode : bool;
                           human_use_object__lockJetpackUse : bool = false;
                           human_jetpack__enabled : bool;
                           human_jetpack__enableSmoothLanding : bool = true;
                           human_jetpack__eid : EntityId;
                           human_coll_damage__minDmgSpd : float)
  if human_use_object__lockJetpackUse || isInVehicle || !human_jetpack__enabled || !human_jetpack__enableSmoothLanding
    return

  query(human_jetpack__eid) <| $ [es] (jetpack__vertAccel : float;
                                       jetpack__fuel : float;
                                       var jetpack__smoothLanding : bool&)
    let isMoveDown = human_net_phys__velocity.y < -4.0
    if !isMoveDown
      jetpack__smoothLanding = false
      return

    let pos = transform[3] + float3(0, 8, 0)
    let endPos = pos + human_net_phys__velocity
    var height = 300.

    tracedown_normalized(endPos, height, ETF_DEFAULT)

    let vertAccel = gravity() - jetpack__vertAccel
    let curSpeed = -human_net_phys__velocity.y

    let time = (human_coll_damage__minDmgSpd - curSpeed) / vertAccel
    let heightForDamage = curSpeed * time + vertAccel * 0.5 * time * time

    if (jetpack__fuel > 0.0 || human_jetpack__flightMode) && height <= heightForDamage
      jetpack__smoothLanding = true
