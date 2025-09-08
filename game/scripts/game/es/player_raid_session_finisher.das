require app
require ecs
require DngDm
require game.events.events
require game.events.events_active_matter


enum PlayerRaidSessionFinisherState
  NOT_FINISHING = -1
  ZONE_COLLAPSED_TO_FINAL_EXTRACTION = 0
  ZONE_COMPLETELY_COLLAPSED = 1
  EVERYONE_DIES = 2
  DEDICATED_SHUTDOWN = 3


[es(tag=server, on_event=EventOnMovingZoneStopped)]
def player_raid_start_session_finisher(evt : Event; var player_raid_session_finisher__state : int&)
  if player_raid_session_finisher__state != int(PlayerRaidSessionFinisherState.NOT_FINISHING)
    return
  let isDynamicZoneMode = find_query() <| $ [es(REQUIRE=dynamic_zone_controller__state)] ()
    return true
  if isDynamicZoneMode
    return
  player_raid_session_finisher__state = int(PlayerRaidSessionFinisherState.ZONE_COLLAPSED_TO_FINAL_EXTRACTION)


[es(tag=server, no_order)]
def player_raid_session_finisher_update_next_state_timer(upd : UpdateStageInfoAct;
                                                         var player_raid_session_finisher__nextStateAt : float&;
                                                         var player_raid_session_finisher__state : int&)
  if player_raid_session_finisher__nextStateAt < 0.0 || player_raid_session_finisher__nextStateAt > get_sync_time()
    return

  player_raid_session_finisher__state += 1
  player_raid_session_finisher__nextStateAt = -1.0


[es(tag=server, track=player_raid_session_finisher__state, on_appear)]
def player_raid_session_finisher_on_state_change(evt : Event;
                                                 player_raid_session_finisher__state : int;
                                                 player_raid_session_finisher__smallZoneTime : float;
                                                 player_raid_session_finisher__zoneCollapsedCompletely : float;
                                                 player_raid_session_finisher__zompleteZoneCollapseTime : float;
                                                 player_raid_session_finisher__delayAfterEveryoneDead : float;
                                                 var player_raid_session_finisher__nextStateAt : float&)
  print("[RAID SESSION FINISHER] state: {player_raid_session_finisher__state}")
  if player_raid_session_finisher__state == int(PlayerRaidSessionFinisherState.ZONE_COLLAPSED_TO_FINAL_EXTRACTION)
    player_raid_session_finisher__nextStateAt = get_sync_time() + player_raid_session_finisher__smallZoneTime
    find_query() <| $ [es] (moving_zone__targetPos : float3;
                            sphere_zone__radius : float;
                            var moving_zone__chooseFinalExtraction : bool&;
                            var moving_zone__targetRadius : float&;
                            var moving_zone__startEndTime : float2&;
                            var moving_zone__sourceRadius : float&;
                            var moving_zone__sourcePos : float3&)
      moving_zone__chooseFinalExtraction = false
      moving_zone__sourceRadius = sphere_zone__radius
      moving_zone__sourcePos = moving_zone__targetPos
      moving_zone__targetRadius = 0.0
      moving_zone__startEndTime.x = player_raid_session_finisher__nextStateAt - player_raid_session_finisher__zompleteZoneCollapseTime
      if player_raid_session_finisher__zompleteZoneCollapseTime > player_raid_session_finisher__smallZoneTime
        error("[RAID SESSION FINISHER]: zompleteZoneCollapseTime({player_raid_session_finisher__zompleteZoneCollapseTime}) can't be greater than smallZoneTime({player_raid_session_finisher__smallZoneTime})")
        moving_zone__startEndTime.x = get_sync_time()

      moving_zone__startEndTime.y = player_raid_session_finisher__nextStateAt
      return true
  elif player_raid_session_finisher__state == int(PlayerRaidSessionFinisherState.ZONE_COMPLETELY_COLLAPSED)
    player_raid_session_finisher__nextStateAt = get_sync_time() + player_raid_session_finisher__zoneCollapsedCompletely
  elif player_raid_session_finisher__state == int(PlayerRaidSessionFinisherState.EVERYONE_DIES)
    player_raid_session_finisher__nextStateAt = get_sync_time() + player_raid_session_finisher__delayAfterEveryoneDead
    query() <| $ [es(REQUIRE=heroForPlayer)] (eid : EntityId)
      sendEvent(eid, CmdKill(damageType = uint16(int(DamageType.DM_ZONE)), deathHpDamage = 100.0))
  elif player_raid_session_finisher__state == int(PlayerRaidSessionFinisherState.DEDICATED_SHUTDOWN)
    player_raid_session_finisher__nextStateAt = -1.0
    exit_game("Raid session finished")
  return
