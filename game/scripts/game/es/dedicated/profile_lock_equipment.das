require ecs
require app
require game.events.events_active_matter


[es(tag=server, on_event=CmdSendPlayerProfile)]
def profile_lock_equipment_heartbeat_init(evt : Event;
                                          profile_lock_equipment__heartbeatTime : float;
                                          var profile_lock_equipment__nextHeartbeatAt : float&)
  profile_lock_equipment__nextHeartbeatAt = get_sync_time() + profile_lock_equipment__heartbeatTime


[es(tag=server, no_order)]
def profile_lock_equipment_heartbeat_update(act : UpdateStageInfoAct;
                                            eid : EntityId;
                                            player__isRentedEquipment, player__isFinishedRaid : bool;
                                            profile_lock_equipment__heartbeatTime : float;
                                            var profile_lock_equipment__nextHeartbeatAt : float&)
  let timeIsCome = profile_lock_equipment__nextHeartbeatAt > 0.0 && act.curTime >= profile_lock_equipment__nextHeartbeatAt
  if !player__isRentedEquipment && !player__isFinishedRaid && timeIsCome
    sendEvent(eid, EventLockEquipmentHeartbeat())
    profile_lock_equipment__nextHeartbeatAt = act.curTime + profile_lock_equipment__heartbeatTime
