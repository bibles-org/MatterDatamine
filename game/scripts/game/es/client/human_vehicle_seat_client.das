require ecs
require DngHuman
require game.events.events_active_matter
require game.es.human.human_vehicle_seat_common


[es(tag=gameClient, before=before_animchar_update_sync, after=(human_weap_update_es, human_locomotion_es, after_net_phys_sync))]
def human_vehicle_seats_non_shooter_pre_animchar_client(info : ParallelUpdateFrameDelayed;
                                                        isInVehicle : bool;
                                                        human_anim__vehicleSelected : EntityId;
                                                        human_weap__blockAiming : bool = false;
                                                        human_net_phys : HumanActor const?;
                                                        vehicle__localSeatTm : float3x4&;
                                                        var transform : float3x4&)
  if !isInVehicle
    return

  update_transform_from_local_seat_tm(/*is_shooter*/false, human_anim__vehicleSelected, human_weap__blockAiming,
                                      human_net_phys, vehicle__localSeatTm, transform)
