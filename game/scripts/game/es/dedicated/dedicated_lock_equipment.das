require ecs
require DngNet
require matching
require game.es.message_queue_common
require game.events.events_active_matter


struct LockEquipmentAction
  session_id : string
  is_rented_equipment : bool


[es(tag=server, after=server_parse_signed_token, on_event=CmdSendPlayerProfile)]
def lock_equipment_request(evt : Event; userid : uint64; player__isRentedEquipment : bool)
  var lockEquipment = false
  find_query() <| $ [es] (game_mode__lockEquipment : bool)
    lockEquipment = game_mode__lockEquipment
    return true
  if !lockEquipment || !has_network()
    return

  let data <- LockEquipmentAction(
    session_id = string(get_session_id()),
    is_rented_equipment = player__isRentedEquipment
  )
  sendToProfileServer("lock_equipment", userid, data)


[es(tag=server, REQUIRE=profile_lock_equipment__nextHeartbeatAt)]
def lock_equipment_heartbeat_request(evt : EventLockEquipmentHeartbeat; userid : uint64)
  var lockEquipment = false
  find_query() <| $ [es] (game_mode__lockEquipment : bool)
    lockEquipment = game_mode__lockEquipment
    return true
  if lockEquipment && has_network() && userid != INVALID_USER_ID

    let data <- LockEquipmentAction(
      session_id = string(get_session_id())
    )
    sendToProfileServer("lock_equipment", userid, data)
