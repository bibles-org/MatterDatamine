require ecs
require app
require net
require AnimV20
require PhysVars
require pathfinder
require DagorSystem


[es(tag=server, on_appear)]
def changed_blink_demonstration_init(evt : Event;
                                     transform : float3x4;
                                     changed_blink_demonstration__blinkInterval : float;
                                     var changed_blink_demonstration__origin : float3&;
                                     var changed_blink_demonstration__blinkAt : float&)
  changed_blink_demonstration__origin = transform[3]
  changed_blink_demonstration__blinkAt = get_sync_time() + changed_blink_demonstration__blinkInterval


[es(tag=server, after=unmap_nphys_navmesh_components)]
def changed_blink_demonstration_update(act : UpdateStageInfoAct;
                                       changed_blink_demonstration__origin : float3;
                                       changed_blink_demonstration__offset : float3;
                                       changed_blink_demonstration__blinkInterval : float;
                                       var loc_snapshots__simulateBlinkPrevPos : float3&;
                                       var changed_blink_demonstration__blinkAt : float&;
                                       var changed_blink_demonstration__shifted : bool&;
                                       var navmesh_phys__currentPos : float3&;
                                       var navmesh_phys__currentPoly : int64&;
                                       var loc_snapshots__blink : bool&)
  if act.curTime < changed_blink_demonstration__blinkAt
    return
  changed_blink_demonstration__blinkAt = act.curTime + changed_blink_demonstration__blinkInterval

  assume origin = changed_blink_demonstration__origin
  assume offset = changed_blink_demonstration__offset
  assume shifted = changed_blink_demonstration__shifted
  let blinkPos = shifted ? origin : origin + offset

  let extents = float3(0.5)
  using(navmesh_phys__currentPos, blinkPos, extents) <| $(var req : FindRequest#)
    req.startPoly = dtPolyRef(navmesh_phys__currentPoly)
    if move_along_surface(req)
      loc_snapshots__simulateBlinkPrevPos = navmesh_phys__currentPos
      navmesh_phys__currentPos = req.end
      navmesh_phys__currentPoly = int64(req.endPoly)
      loc_snapshots__blink = true
      shifted = !shifted


[es(on_appear)]
def animation_demonstration_parametric_init(evt : Event;
                                            animation_demonstration__varName : string;
                                            animation_demonstration__paramName : string;
                                            animchar : AnimcharBaseComponent;
                                            animation_demonstration__paramValuesList : FloatList;
                                            var animation_demonstration__varId : int&;
                                            var animation_demonstration__paramId : int&;
                                            var animation_demonstration__curParamIdx : int&;
                                            var phys_vars : PhysVars)
  animation_demonstration__varId = registerVar(phys_vars, animation_demonstration__varName, 0.0)
  assume animGraph = animchar.animGraph
  let paramId = *animGraph |> anim_graph_getParamId(animation_demonstration__paramName, int(PT_ScalarParam))
  if paramId >= 0
    animation_demonstration__paramId = paramId
  if length(animation_demonstration__paramValuesList) > 0
    animation_demonstration__curParamIdx = 0


[es(no_order)]
def animation_demonstration_parametric_update(act : UpdateStageInfoAct;
                                              animation_demonstration__varId : int;
                                              animation_demonstration__animTime : float;
                                              animation_demonstration__paramId : int;
                                              animation_demonstration__paramValuesList : FloatList;
                                              var animation_demonstration__curAnimTime : float&;
                                              var animation_demonstration__curParamIdx : int&;
                                              var phys_vars : PhysVars;
                                              var animchar : AnimcharBaseComponent)
  animation_demonstration__curAnimTime += act.dt * (1.0 / animation_demonstration__animTime)
  if animation_demonstration__curAnimTime >= animation_demonstration__animTime
    animation_demonstration__curAnimTime = 0.0
    if animation_demonstration__paramId >= 0 && animation_demonstration__curParamIdx >= 0
      animation_demonstration__curParamIdx = (animation_demonstration__curParamIdx + 1) % length(animation_demonstration__paramValuesList)
      assume animState = animchar.animState
      *animState |> anim_state_holder_setParam(animation_demonstration__paramId,
        animation_demonstration__paramValuesList[animation_demonstration__curParamIdx])
  setVar(phys_vars, animation_demonstration__varId, animation_demonstration__curAnimTime)


[es(on_appear)]
def animation_demonstration_repeat_init(evt : Event;
                                        animation_demonstration__pauseTime : float;
                                        var animation_demonstration__repeatAt : float&;
                                        var animation_demonstration__pauseAt : float&)
  animation_demonstration__pauseAt = get_sync_time()
  animation_demonstration__repeatAt = animation_demonstration__pauseAt + animation_demonstration__pauseTime


[es(no_order)]
def animation_demonstration_repeat_update(act : UpdateStageInfoAct;
                                          animation_demonstration__repeatTime : float;
                                          animation_demonstration__pauseTime : float;
                                          animation_demonstration__repeatStateName : string;
                                          var animation_demonstration__repeatAt : float&;
                                          var animation_demonstration__pauseAt : float&;
                                          var anim_state__forceAnimState : das_string&)
  if animation_demonstration__pauseAt <= act.curTime
    animation_demonstration__pauseAt = act.curTime + animation_demonstration__repeatTime + animation_demonstration__pauseTime
    anim_state__forceAnimState := ""
  if animation_demonstration__repeatAt <= act.curTime
    animation_demonstration__repeatAt = act.curTime + animation_demonstration__repeatTime + animation_demonstration__pauseTime
    anim_state__forceAnimState := animation_demonstration__repeatStateName
