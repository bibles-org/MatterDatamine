options no_aot
require ecs
require ecs.ecs_template
require game.utils.hero
require math.base
require math.ang
require game.es.door_operations_common
require DagorConsole
require DagorDebug3D
require daslib/enum_trait


[ecs_template]
struct door_debug_draw
  door__debugDraw : bool = false


[console_cmd(name="door.debug_draw")]
def debug_door_cmd(door__debugDraw : bool = true)
  let tmpl = "door_debug_draw"
  addSubTemplate(get_controlled_hero(), tmpl) <| $(var init)
    set(init, "door__debugDraw", door__debugDraw)


[es(tag=render, tag=dev, no_order)]
def door_debug_draw(evt : UpdateStageInfoRenderDebug;
                    door__debugDraw : bool)
  if !door__debugDraw
    return

  begin_draw_cached_debug_lines(false, false, false)
  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false


    query() <| $ [es] (initialTransform aka door_initialTransform : float3x4;
                       rendinst_axis_rotation__axis : float3;
                       door_operations__serverTargetAngle : float;
                       rendinst_axis_rotation__targetAngle : float;
                       rendinst_axis_rotation__curAngle : float;
                       door_operations__reqState : int;
                       door_operations__state : int)
      if distance_sq(camera_transform[3], door_initialTransform[3]) > square(5.0)
        return

      var rotTm : float3x4
      make_tm(rendinst_axis_rotation__axis, deg_to_rad(door_operations__serverTargetAngle), rotTm)
      let serverTargetVector = rotate(rotTm, door_initialTransform[0])

      let serverTargetVectorStartPoint = door_initialTransform[3] + door_initialTransform[1]
      let serverTargetVectorEndPoint = door_initialTransform[3] + door_initialTransform[1] + serverTargetVector
      draw_cached_debug_line(
        serverTargetVectorStartPoint,
        serverTargetVectorEndPoint,
        E3DCOLOR(0xFFFF0000))


      make_tm(rendinst_axis_rotation__axis, deg_to_rad(rendinst_axis_rotation__targetAngle), rotTm)
      let targetVector = rotate(rotTm, door_initialTransform[0])

      let targetVectorStartPoint = door_initialTransform[3] + door_initialTransform[1] * 1.05
      let targetVectorEndPoint = door_initialTransform[3] + door_initialTransform[1] * 1.05 + targetVector
      draw_cached_debug_line(
        targetVectorStartPoint,
        targetVectorEndPoint,
        E3DCOLOR(0xFF00FF00))


      make_tm(rendinst_axis_rotation__axis, deg_to_rad(rendinst_axis_rotation__curAngle), rotTm)
      let curVector = rotate(rotTm, door_initialTransform[0])

      let curVectorStartPoint = door_initialTransform[3] + door_initialTransform[1] * 1.1
      let curVectorEndPoint = door_initialTransform[3] + door_initialTransform[1] * 1.1 + curVector
      draw_cached_debug_line(
        curVectorStartPoint,
        curVectorEndPoint,
        E3DCOLOR(0xFF0000FF))

      let reqState = typeinfo enum_names(type<DoorState>)[door_operations__reqState]
      let state = typeinfo enum_names(type<DoorState>)[door_operations__state]
      let markPos = door_initialTransform[3] + door_initialTransform[1] * 1.2
      add_debug_text_mark(markPos, "reqState: {reqState} state: {state}", -1, 0.0,
                          door_operations__reqState == 0 ? E3DCOLOR(0xFFFF0000) :
                          (door_operations__reqState == 1 ? E3DCOLOR(0xFF00FF00) : E3DCOLOR(0xFFFFFF00)))

    return true
  end_draw_cached_debug_lines()