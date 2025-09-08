require ecs
require DngNet
require game.events.events
require HumanPhys
require DngHuman
require RendInst
require DagorMath
require CollRes
require game.es.door_operations_common


[es(tag=gameClient, after=hero_human_use_door_object_es, REQUIRE=hero)]
def push_door_es(info : UpdateStageInfoAct;
                 eid : EntityId;
                 isAlive : bool;
                 human_use_object__selectedObject : EntityId;
                 human_net_phys : HumanActor;
                 collres : CollisionResource;
                 transform : float3x4;
                 human_push_door__minAngleDot : float = 0.525;
                 human_push_door__extrapolatePosTime : float = 0.2)
  if !isAlive
    return

  let humanEid = eid
  let humanTm := transform

  var humanBox = BBox3(collres.vFullBBox)
  let velLocal = rotate(inverse(humanTm), human_net_phys.phys.currentState.velocity)
  let fwdOffset = float3(0.5, 0.0, 0.0)
  let predictedPos = humanBox.center + velLocal * max(info.dt, human_push_door__extrapolatePosTime) + fwdOffset
  humanBox |> bbox3_add(predictedPos)

  ecs::query(human_use_object__selectedObject) <| $ [es(REQUIRE=isDoor,
                                                        REQUIRE_NOT=unpushable_door)] (eid : EntityId;
                                                                                       door_operations__openedAngle : float;
                                                                                       door_operations__closedAngle : float;
                                                                                       door_operations__state : int;
                                                                                       door_operations__omniRotate : bool = false;
                                                                                       ri_extra : RiExtraComponent;
                                                                                       transform : float3x4)
    let isSprinting = (int(human_net_phys.phys.currentState.states) & int(StateFlag.ST_SPRINT)) != 0
    let riType = handle_to_ri_type(ri_extra.handle)
    let slowMoving = human_net_phys.phys.currentState.moveState == HUMoveState.EMS_RUN || \
                     human_net_phys.phys.currentState.moveState == HUMoveState.EMS_WALK

    // We use rotating_rendinst_simple_phys to open ajar doors using physics very nicely. It uses physics impulses to do so.
    // Immortal ri extras don't send collision impulses so we need this hack to handle such doors.
    // Ideally we should send those impulses but it is much more difficult to do without breaking anything than this.
    let canOpenDoor = isSprinting || (riex_isImmortal(riType) && door_operations__state == int(DoorState.AJAR) && slowMoving)
    if door_operations__state == int(DoorState.OPENED) || !canOpenDoor
      return
    let doorDir = transform[2]
    let openerDir = humanTm[0]
    let angleDot = dot(doorDir, openerDir)
    if abs(angleDot) < human_push_door__minAngleDot
      return
    if !door_operations__omniRotate && angleDot * (door_operations__openedAngle - door_operations__closedAngle) > 0.0
      return
    let doorCollres = get_ri_gen_extra_collres(int(riType))
    if doorCollres == null
      return

    let doorBox = BBox3(doorCollres.vFullBBox)
    if check_bbox3_intersection(humanBox, humanTm, doorBox, transform)
      sendEvent(humanEid, HumanUseObjectRequest(objectEid = eid))
