options no_aot
require ecs
require ecs.safe
require ecs.ecs_template
require game.utils.hero
require DagorConsole
require game.es.am_core_warrior_common
require DagorDebug3DSolid


[ecs_template]
struct am_core_warrior_debug_draw
  am_core_warrior__debugDraw : bool = false


[console_cmd(name="am.core_warrior_debug_draw")]
def am_core_warrior_debug_draw_cmd(draw : bool = true)
  let tmpl = "am_core_warrior_debug_draw"
  addSubTemplate(get_controlled_hero(), tmpl) <| $(var init)
    set(init, "am_core_warrior__debugDraw", draw)


[es(tag=render, tag=dev, no_order)]
def am_core_warrior_debug_es(act : UpdateStageInfoAct;
                             am_core_warrior__debugDraw : bool)
  if !am_core_warrior__debugDraw
    return

  query() <| $ [es] (am_core_warrior__damageRadius : float;
                     am_core_warrior__normal : float3;
                     am_core_warrior__state : int;
                     transform : float3x4;
                     am_core_warrior__actAt : float;
                     am_core_warrior__chargeTime : float;
                     var am_core_warrior__lastHitAt : float&)
    if am_core_warrior__state == int(CoreWarriorState.CHARGE)
      am_core_warrior__lastHitAt = am_core_warrior__actAt
      if (act.curTime >= am_core_warrior__actAt &&
          act.curTime - act.dt < am_core_warrior__actAt)
        draw_debug_disk_buffered(transform[3], am_core_warrior__normal, am_core_warrior__damageRadius, 36, E3DCOLOR(0xbbff3300), 30)
        draw_debug_disk_buffered(transform[3], -am_core_warrior__normal, am_core_warrior__damageRadius, 36, E3DCOLOR(0xbbff3300), 30)
      let duration = am_core_warrior__chargeTime
      let timePassed = act.curTime - am_core_warrior__actAt + am_core_warrior__chargeTime
      let t = sqrt(max(0.0, timePassed / duration))
      let radius = lerp(0.0, am_core_warrior__damageRadius, t)
      draw_debug_disk_buffered(transform[3], am_core_warrior__normal, radius, 36, E3DCOLOR(0x55ffaa00), 2)
      draw_debug_disk_buffered(transform[3], -am_core_warrior__normal, radius, 36, E3DCOLOR(0x55ffaa00), 2)
