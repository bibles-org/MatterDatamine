require ecs
require game.events.events
require game.es.action_common
require DngHuman
require HumanPhys


[es]
def human_block_sprint_es(info : CmdPostPhysUpdate;
                          eid : EntityId;
                          var human_net_phys : HumanActor;
                          human_weap__throwMode : bool;
                          human_phys__jumpEndTime : float;
                          burning__isPuttingOut : bool;
                          human_phys__afterJumpDelay : float)
  let physTime = float(info.tick) * info.dt
  assume currentState = human_net_phys.phys.currentState
  let isBlockedByJump = physTime < human_phys__jumpEndTime + human_phys__afterJumpDelay
  let isBlockedByAction = does_action_block_sprint(eid)
  let blocked = human_weap__throwMode || isBlockedByAction || burning__isPuttingOut || isBlockedByJump
  human_phys_state_set_block_sprint(currentState, blocked)
