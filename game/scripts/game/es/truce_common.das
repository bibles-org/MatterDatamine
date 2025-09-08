module truce_common shared

require app
require ecs
require DagorSystem


let TRUCE_UNASSIGNED = -1
let TRUCE_MAX = 63 // 64 bits, so 0-63 are valid truce ids

let TRUCE_ZONE = 0


def make_truce_mask(truce_id : int)
  return uint64(1) << uint64(truce_id)


def has_truce(truce_controller__masks : UInt64List;
              actor_truce_id : int;
              target_truce_id : int)
  if actor_truce_id == target_truce_id && actor_truce_id != TRUCE_UNASSIGNED
    return true

  if actor_truce_id == TRUCE_UNASSIGNED || target_truce_id == TRUCE_UNASSIGNED
    return false

  if actor_truce_id >= length(truce_controller__masks)
    return false

  let truceBMask = make_truce_mask(target_truce_id)
  return (truce_controller__masks[actor_truce_id] & truceBMask) != 0ul


def change_truce(actor_truce_id : int;
                 target_truce_id : int;
                 value : bool;
                 mutual : bool = true)
  if actor_truce_id == TRUCE_UNASSIGNED || target_truce_id == TRUCE_UNASSIGNED
    logerr("Failed to conclude truce: one of the truce ids is unassigned! actor_truce_id={actor_truce_id} target_truce_id={target_truce_id}")
    return

  if actor_truce_id > TRUCE_MAX || target_truce_id > TRUCE_MAX
    logerr("Failed to conclude truce: one of the truce ids is out of range! actor_truce_id={actor_truce_id} target_truce_id={target_truce_id}")
    return

  if actor_truce_id == target_truce_id
    return

  find_query() <| $ [es] (var truce_controller__masks : UInt64List)
    let maxTruceId = max(actor_truce_id, target_truce_id)

    if int(maxTruceId) >= length(truce_controller__masks)
      truce_controller__masks |> resize(int(maxTruceId) + 1)

    let newActorTruceMask = (value ? (truce_controller__masks[int(actor_truce_id)] | make_truce_mask(target_truce_id))
                                   : (truce_controller__masks[int(actor_truce_id)] & ~make_truce_mask(target_truce_id)))
    if newActorTruceMask != truce_controller__masks[int(actor_truce_id)]
      truce_controller__masks[int(actor_truce_id)] = newActorTruceMask
      print("[TRUCE CHANGED] actor={actor_truce_id} target={target_truce_id} value={value}")


    if mutual
      let newTargetTruceMask = (value ? (truce_controller__masks[int(target_truce_id)] | make_truce_mask(actor_truce_id))
                                      : (truce_controller__masks[int(target_truce_id)] & ~make_truce_mask(actor_truce_id)))

      if newTargetTruceMask != truce_controller__masks[int(target_truce_id)]
        truce_controller__masks[int(target_truce_id)] = newTargetTruceMask
        print("[TRUCE CHANGED][MUTUAL] actor={target_truce_id} target={actor_truce_id} value={value}")

    return true


def conclude_truce(actor_truce_id : int;
                   target_truce_id : int;
                   mutual : bool = true)
  change_truce(actor_truce_id, target_truce_id, true, mutual)


def break_truce(actor_truce_id : int;
                target_truce_id : int;
                mutual : bool = true)
  change_truce(actor_truce_id, target_truce_id, false, mutual)


def generate_truce_id()
  var truceId = TRUCE_UNASSIGNED

  find_query() <| $ [es] (var truce_controller__truceCounter : int&)
    truceId = truce_controller__truceCounter++
    return true

  return truceId