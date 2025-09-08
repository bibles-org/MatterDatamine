require ecs
require HumanPhys
require DngHuman
require game.events.events_active_matter


[es(before=before_net_phys_sync)]
def human_phys_set_gun_offset_es(info : ParallelUpdateFrameDelayed;
                                 human_weap__currentGunEid : EntityId;
                                 var human_net_phys : HumanActor)
  human_net_phys.phys.gunOffset = float3(0.0)
  query(human_weap__currentGunEid) <| $ [es] (gun_aim_offset__gunOffsets : Point3List;
                                              gun_dynamic_position__offset : float3 = float3(0.0))
    let standState = int(human_net_phys.phys.currentState.standState)
    var gunOffset : float3
    if standState < length(gun_aim_offset__gunOffsets)
      gunOffset = gun_aim_offset__gunOffsets[standState]
    let aimOffset = float3(gunOffset.z, gunOffset.y, -gunOffset.x)
    human_net_phys.phys.gunOffset = gun_dynamic_position__offset + aimOffset
