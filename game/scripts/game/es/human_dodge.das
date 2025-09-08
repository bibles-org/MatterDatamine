require ecs
require net
require Dacoll
require HumanPhys
require DngHuman
require CollisionTraces
require game.events.events_active_matter
require game.events.events
require app
require DagorMath
require DagorMathUtils
require DagorDataBlock
require CollRes

let DEFAULT_SPHERE_CAST_MASK = int(PhysLayer.EPL_ALL) & ~(int(PhysLayer.EPL_CHARACTER) | int(PhysLayer.EPL_KINEMATIC) | int(PhysLayer.EPL_DEBRIS))

[es(on_appear)]
def human_dodge_init_collision_object(evt : Event;
                                      human_dodge__checkCollisionObjSize : float3;
                                      var human_dodge_checkCollisionsObj : CollisionObject)
  using() <| $(var coll_props : DataBlock)
    datablock_add_block(coll_props, "box") <| $(box)
      add(box, "width", human_dodge__checkCollisionObjSize)
    human_dodge_checkCollisionsObj = add_dynamic_collision(coll_props)


[es(on_disappear)]
def human_dodge_free_collision_object(evt : Event;
                                      var human_dodge_checkCollisionsObj : CollisionObject)
  destroy_dynamic_collision(human_dodge_checkCollisionsObj)


[es(REQUIRE_NOT=(deadEntity, disableUpdate))]
def human_input_dodge(info : CmdPostPhysUpdate;
                      human_net_phys__isInAir : bool;
                      human_dodge__dodgeSpd, human_dodge__dodgeSpdMulti : float;
                      human_dodge_checkCollisionsObj : CollisionObject;
                      human_dodge__checkCollisionObjSize : float3;
                      human_dodge__checkCollisionObjBoundingRad : float;
                      human_dodge__speedReduceCoefDistanceDivider, human_dodge__freeFlyspeedReduceCoef : float;
                      var human_net_phys : HumanActor&)
  assume phys = human_net_phys.phys
  if human_net_phys__isInAir
    return

  let dodgeState = phys.appliedCT.dodgeState
  if dodgeState == DodgeState.No
    return
  human_control_state_set_dodge_state(phys.producedCT, DodgeState.No)
  var direction = float3(0.0, 0.0, 0.0)
  let orientationQuat = phys.previousState.location.O.quat
  let position = float3(phys.previousState.location.P)

  if dodgeState == DodgeState.Left
    let left = float3(0.0, 0.0, 1.0)
    direction = orientationQuat * left
  elif dodgeState == DodgeState.Right
    let right = float3(0.0, 0.0, -1.0)
    direction = orientationQuat * right
  elif dodgeState == DodgeState.Back
    let back = float3(-1.0, 0.0, 0.0)
    direction = orientationQuat * back

  var tm : float3x4
  tm[0] = direction
  tm[1] = -phys.currentState.gravDirection
  tm[2] = cross(tm[0], tm[1])
  tm[3] = position + direction * human_dodge__checkCollisionObjSize.x * 0.5f + -phys.currentState.gravDirection * phys.standingHeight * 0.6f

  var minReducingCoef = 1.0

  test_collision_world_ex(human_dodge_checkCollisionsObj, tm, human_dodge__checkCollisionObjBoundingRad) <| $(contacts : array<CollisionContactData>#)
    for contact in contacts
      let contactWPos = basis_aware_xVz(contact.wpos, position, phys.currentState.vertDirection)
      let coef = distance(position, contactWPos) / human_dodge__speedReduceCoefDistanceDivider
      minReducingCoef = min(minReducingCoef, coef)

  // trace finish height
  for i in range(3)
    let from = position + direction * float(i + 1) + -phys.currentState.gravDirection * 0.1f
    let to = from + phys.currentState.gravDirection * 0.2f
    var outDown = ShapeQueryOutput()
    if !sphere_cast_ex(from, to, phys.walkRad, outDown,
                      phys.rayMatId, phys.torsoCollision,
                      phys |> human_phys_getTraceHandle(), DEFAULT_SPHERE_CAST_MASK)
      minReducingCoef = minReducingCoef * human_dodge__freeFlyspeedReduceCoef
      break

  let spd = human_dodge__dodgeSpd * minReducingCoef * human_dodge__dodgeSpdMulti
  phys.currentState.velocity += direction * spd
