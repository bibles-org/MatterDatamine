require ecs
require AnimV20
require PhysVars
require DngHuman
require math.base
require DagorSystem
require GeomNodeTree
require DagorMathUtils
require game.events.events_active_matter


[es(on_appear)]
def mothman_init_vars(evt : Event;
                      var mothman_anim__moveAngleHorizontalVarId : int&;
                      var mothman_anim__moveAngleVerticalVarId : int&;
                      var mothman_anim__moveSpeedVarId : int&;
                      var phys_vars : PhysVars&)
  mothman_anim__moveAngleHorizontalVarId = registerVar(phys_vars, "move_angle_horizontal", 0.f)
  mothman_anim__moveAngleVerticalVarId = registerVar(phys_vars, "move_angle_vertical", 0.f)
  mothman_anim__moveSpeedVarId = registerVar(phys_vars, "move_speed", 0.f)

[es(REQUIRE_NOT=animchar__actOnDemand, before=human_anim_es)]
def mothman_anim_es(info : ParallelUpdateFrameDelayed;
                    mothman_anim__moveAngleHorizontalVarId : int;
                    mothman_anim__moveAngleVerticalVarId : int;
                    mothman_anim__moveSpeedVarId : int;
                    mothman_anim__maxNormalSpeed : float = 5.0;
                    mothman_anim__velocityViscosity : float = 0.1;
                    human_net_phys : HumanActor;
                    transform : float3x4;
                    var mothman_anim__prevVelocity : float3&;
                    var phys_vars : PhysVars&)
  assume phys = human_net_phys.phys

  let interpK = get_phys_interpk_clamped(phys, info.curTime)
  let velocity = lerp(phys.previousState.velocity, phys.currentState.velocity, float3(interpK))

  let animVelocity = approach(mothman_anim__prevVelocity, velocity, info.dt, mothman_anim__velocityViscosity)

  let animVelocityDotVertNorm = dot(animVelocity, human_net_phys.phys.currentState.vertDirection)
  let animHorzVelocity = animVelocity - animVelocityDotVertNorm * human_net_phys.phys.currentState.vertDirection

  let moveSpeedVar = (length(animHorzVelocity) / mothman_anim__maxNormalSpeed)
  phys_vars |> setVar(mothman_anim__moveSpeedVarId, moveSpeedVar) // values from 0..1 are for normal speed blending, 1..2 for fast movement mode

  mothman_anim__prevVelocity = animVelocity

  let velocityDir = normalize(animVelocity)
  let up = normalize(transform[1]) // used for asin inside basis_aware_dir_to_angles so let's be sure it is normalized (might not be during spawn animations)
  let forward = normalize(transform[0])
  let newAngle = basis_aware_dir_to_angles(velocityDir, up, forward)

  phys_vars |> setVar(mothman_anim__moveAngleHorizontalVarId, newAngle.x * RAD_TO_DEG)
  phys_vars |> setVar(mothman_anim__moveAngleVerticalVarId, newAngle.y * RAD_TO_DEG)


[es(on_appear)]
def mothman_float_anim_init_es(evt : Event;
                               eid : EntityId;
                               animchar : AnimcharBaseComponent;
                               mothman_anim__floatNodeName : string = "Root_2";
                               var mothman_anim__floatNodeId : int&)
  mothman_anim__floatNodeId = geomtree_findNodeIndex(*animchar.nodeTree, mothman_anim__floatNodeName)
  if mothman_anim__floatNodeId < 0
    logerr("mothman_anim__floatNodeName '{mothman_anim__floatNodeName}' not found in ({eid})<{getEntityTemplateName(eid)}>")
    return


[es(REQUIRE_NOT=animchar__actOnDemand, after=animchar_es)]
def mothman_float_anim_es(info : ParallelUpdateFrameDelayed;
                          mothman_anim__floatNodeId : int;
                          mothman_anim__floatSpeed : float = 0.08;
                          mothman_anim__floatMagnitude : float = 0.15;
                          var mothman_anim__floatTimer : float&;
                          var animchar : AnimcharBaseComponent&;
                          var animchar_node_wtm : AnimcharNodesMat44&;
                          var animchar_render__root_pos : vec4f&)
  if mothman_anim__floatNodeId < 0
    return

  mothman_anim__floatTimer += info.dt * mothman_anim__floatSpeed
  if mothman_anim__floatTimer > 1.0
    mothman_anim__floatTimer -= 1.0

  let t = mothman_anim__floatTimer * PI * 2.0
  let offset = float3(sin(t + PI / 2.0), pow(sin(t), 3.0), sin(2.0 * t)) * mothman_anim__floatMagnitude

  geomtree_getNodeTm(*animchar.nodeTree, mothman_anim__floatNodeId).col3 += float4(offset.x, offset.y, offset.z, 0.0f)
  geomtree_invalidateWtm(*animchar.nodeTree)
  animchar_recalc_wtm(animchar)
  animchar_copy_nodes(animchar, animchar_node_wtm, animchar_render__root_pos)

[es(on_appear)]
def mothman_attack_animation_init(evt : Event;
                                  animchar : AnimcharBaseComponent;
                                  monstrified_mothman_attack__paramName : string;
                                  var monstrified_mothman_attack__paramId : int&)
  monstrified_mothman_attack__paramId = *animchar.animGraph |> anim_graph_getParamId(monstrified_mothman_attack__paramName, int(PT_ScalarParam))


[es(on_appear)]
def mothman_gathering_animation_init(evt : Event;
                                     animchar : AnimcharBaseComponent;
                                     monstrified_mothman_gathering__paramName : string;
                                     var monstrified_mothman_gathering__paramId : int&)
  monstrified_mothman_gathering__paramId = *animchar.animGraph |> anim_graph_getParamId(monstrified_mothman_gathering__paramName, int(PT_ScalarParam))


[es(REQUIRE_NOT=animchar__actOnDemand, before=human_anim_es)]
def mothman_attack_anim_update(upd : ParallelUpdateFrameDelayed;
                               monstrified_mothman_attack__floatingObjectAttractionProgress : float;
                               monstrified_mothman_attack__shootAnimTime : float;
                               monstrified_mothman_attack__paramId : int;
                               monstrified_mothman_attack__shotAt : float;
                               monstrified_mothman_attack__holdObjectAtParamValue : float;
                               var animchar : AnimcharBaseComponent&)
  assume breakpointTime = monstrified_mothman_attack__holdObjectAtParamValue
  let endThrowAnimAt = monstrified_mothman_attack__shotAt + monstrified_mothman_attack__shootAnimTime
  if upd.curTime < endThrowAnimAt
    let progress = 1.0 - clamp((endThrowAnimAt - upd.curTime) / monstrified_mothman_attack__shootAnimTime, 0.0, 1.0)
    let attackParam = breakpointTime + progress * (1.0 - breakpointTime)
    *animchar.animState |> anim_state_holder_setParam(monstrified_mothman_attack__paramId, attackParam)
  else
    *animchar.animState |> anim_state_holder_setParam(monstrified_mothman_attack__paramId, monstrified_mothman_attack__floatingObjectAttractionProgress * breakpointTime)


[es(REQUIRE_NOT=animchar__actOnDemand, before=human_anim_es)]
def mothman_gathering_anim_update(upd : ParallelUpdateFrameDelayed;
                                  monstrified_mothman_gathering__paramId : int;
                                  monstrified_mothman_gathering__nextGatherAt : float;
                                  monstrified_mothman_gathering__oneItemGatherTime : float;
                                  var animchar : AnimcharBaseComponent&)
  var desiredVal = 0.0
  if monstrified_mothman_gathering__nextGatherAt >= 0.0 && upd.curTime <= monstrified_mothman_gathering__nextGatherAt
    let progress = 1.0 - (monstrified_mothman_gathering__nextGatherAt - upd.curTime) / monstrified_mothman_gathering__oneItemGatherTime
    desiredVal = progress

  let paramValue = anim_state_holder_getParam(*animchar.animState, monstrified_mothman_gathering__paramId)
  let newVal = approach(paramValue, desiredVal, upd.dt, 0.3)
  *animchar.animState |> anim_state_holder_setParam(monstrified_mothman_gathering__paramId, newVal)
