require ecs
require ecs.safe
require game.events.events_active_matter


// human_weap__blockAiming is not replicated so it has to run on all soldiers, not just hero
[es(tag=gameClient, no_order)]
def human_weap_block_aim_es(info : ParallelUpdateFrameDelayed;
                            var human_weap__blockAiming : bool&;
                            isInVehicle : bool = false;
                            isPassenger : bool = false;
                            human_net_phys__isUnderwater : bool = false;
                            human_weap__currentGunEid : EntityId;
                            human_unarmed__active : bool = false;
                            human_weap__blockAimingFromEffect : bool = false)
  if isInVehicle
    human_weap__blockAiming = !isPassenger || has(human_weap__currentGunEid, "gun__disableAimInVehicle") || human_net_phys__isUnderwater
  else
    human_weap__blockAiming = human_unarmed__active

  if human_weap__blockAimingFromEffect
    human_weap__blockAiming = true
