options no_aot
require ecs
require ecs.safe
require ecs.ecs_template
require math.base
require game.utils.hero
require game.es.protected_am_core_common
require DagorConsole
require DagorSystem
require DagorDebug3D


[ecs_template]
struct protected_am_core_debug_draw
  protected_am_core__debugDraw : bool = false


[console_cmd(name="am.protected_am_core_debug_draw")]
def protected_am_core_debug_draw_cmd(draw : bool = true)
  let tmpl = "protected_am_core_debug_draw"
  addSubTemplate(get_controlled_hero(), tmpl) <| $(var init)
    set(init, "protected_am_core__debugDraw", draw)


[es(tag=render, tag=dev, no_order)]
def protected_am_core_debug_es(act : UpdateStageInfoAct;
                               protected_am_core__debugDraw : bool)
  if !protected_am_core__debugDraw
    return

  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false

    query() <| $ [es] (transform aka core_transform : float3x4;
                       protected_am_core__originPos : float3;
                       protected_am_core__patrolRadius : float;
                       protected_am_core__patrolPath : Point3List;
                       protected_am_core__patrolPathPointIndex : int;
                       protected_am_core__patrolHeight : float;
                       protected_am_core__patrolPathMode : int)
      if distance_sq(camera_transform[3], core_transform[3]) > square(100.0)
        return

      draw_debug_sphere_buffered(protected_am_core__originPos, 0.2, E3DCOLOR(0xFF15FF00), 12, 1)
      draw_debug_sphere_buffered(protected_am_core__originPos, protected_am_core__patrolRadius, E3DCOLOR(0xFF00FFF2), 12, 1)
      let posOffset = float3(0.0, protected_am_core__patrolHeight, 0.0)
      if length(protected_am_core__patrolPath) > 0
        let posColorDefault = E3DCOLOR(0xFF919191)
        let posColorCurrent = E3DCOLOR(0xFFFF00EA)

        let startPos = protected_am_core__patrolPath[0] + posOffset
        let endPos = protected_am_core__patrolPath[length(protected_am_core__patrolPath) - 1] + posOffset

        let startPosColor = (protected_am_core__patrolPathPointIndex == 0) ? posColorCurrent : posColorDefault
        draw_debug_sphere_buffered(startPos, 0.05, startPosColor, 12, 1)

        for i in range(1, length(protected_am_core__patrolPath))
          let pos0 = protected_am_core__patrolPath[i - 1] + posOffset
          let pos1 = protected_am_core__patrolPath[i] + posOffset
          let posColor = (protected_am_core__patrolPathPointIndex == i) ? posColorCurrent : posColorDefault
          draw_debug_sphere_buffered(pos1, 0.1, posColor, 12, 1)
          draw_debug_line_buffered(pos0, pos1, E3DCOLOR(0xFFFFFFFF), 1)

        if protected_am_core__patrolPathMode == int(ProtectedAmCorePatrolPathMode.LOOP)
          draw_debug_line_buffered(endPos, startPos, E3DCOLOR(0xFFFFFFFF), 1)

    return true