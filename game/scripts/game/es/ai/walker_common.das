module walker_common shared

require DagorRandom
require DagorMath
require DagorMathUtils
require math.base
require pathfinder
require math.maybe_pos
require ecs
require ecs.safe
require HumanPhys

let
  STANCE_STAND = 2
  STANCE_CROUCH = 1
  STANCE_CRAWL = 0


def determinate_stance(phys_state : HumanPhysState)
  if phys_state.isCrawl
    return STANCE_CRAWL
  if phys_state.isCrouch
    return STANCE_CROUCH
  return STANCE_STAND


def check_door_is_pushable(door_eid : EntityId; from, to : float3) : int //-1 for not pushable, 0 for irrelevant, 1 for pushable
  var res = 0
  query(door_eid) <| $ [es] (transform : float3x4;
                             door_operations__openedAngle : float;
                             door_operations__openedDir : float3;
                             rendinst_axis_rotation__targetAngle : float)
    if abs(rendinst_axis_rotation__targetAngle - door_operations__openedAngle) > 5.0
      let doorEndNow = transform[3] + transform[0]
      let doorEndOpened = transform[3] + door_operations__openedDir
      var mua1, mub1, mua2, mub2 : float
      line_line_intersect(transform[3], doorEndNow, from, to, mua1, mub1)
      line_line_intersect(transform[3], doorEndOpened, from, to, mua2, mub2)

      if mub1 > .0 && mua1 > .0 //the intersection is in front of us and is not behind the door's hinge
        res = mub2 < mub1 == mua2 < .0 ? 1 : -1 //this just works, don't ask me how. If it doesn't - god help you.
      // else the door is irrelevant to us
  return res