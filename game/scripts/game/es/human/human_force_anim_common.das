module human_force_anim_common shared
require ecs
require AnimV20

let
  upperHash = ecs_hash("upper")
  lowerHash = ecs_hash("lower")


def send_change_anim_lower_state_event_safe(eid : EntityId; state_id : int)
  if isLoadingEntity(eid)
    return
  send_change_anim_state_event(eid, "lower", lowerHash, state_id)


def send_change_anim_upper_state_event_safe(eid : EntityId; state_id : int)
  if isLoadingEntity(eid)
    return
  send_change_anim_state_event(eid, "upper", upperHash, state_id)


def send_change_anim_state_event_safe(eid : EntityId; state_id : int)
  if isLoadingEntity(eid)
    return
  send_change_anim_state_event(eid, "lower", lowerHash, state_id)
  send_change_anim_state_event(eid, "upper", upperHash, state_id)
