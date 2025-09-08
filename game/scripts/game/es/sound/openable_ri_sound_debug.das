options no_aot
require ecs
require ecs.ecs_template
require math.base
require DagorConsole
require DagorDebug3D
require DagorSystem
require soundSystem


[ecs_template]
struct sound_debug_draw_openable
  soundDebugDrawOpenable : bool


[console_cmd(name="snd.debug_draw_openable")]
def sound_debug_draw_openable_console_cmd()
  var entEid : EntityId
  find_query() <| $ [es(REQUIRE=soundDebugDrawOpenable)] (eid : EntityId)
    entEid = eid
    return true
  if !entEid
    createEntity("sound_debug_draw_openable")
    sound_debug("snd.sound_debug_draw_openable=1")
  else
    destroyEntity(entEid)
    sound_debug("snd.sound_debug_draw_openable=0")


[es(tag=sound, no_order, REQUIRE=soundDebugDrawOpenable)]
def ri_extra_sound_draw_debug(evt : UpdateStageInfoRenderDebug)

  query() <| $ [es] (openable_ri_sound__path : string;
                     openable_ri__closed : string = "";
                     ri_after_loot_name : string = "";
                     transform : float3x4)
    let pos = transform[3]
    if length_sq(pos - get_listener_pos()) < square(100.)
      if length_sq(pos - get_listener_pos()) < 3. * 3.
        add_debug_text_mark(pos, "'{openable_ri_sound__path}'     '{openable_ri__closed}'   '{ri_after_loot_name}'", -1, 0., E3DCOLOR(0xffffffff))
      else
        add_debug_text_mark(pos, "'{openable_ri_sound__path}'     '{openable_ri__closed}'   '{ri_after_loot_name}'", -1, 0., E3DCOLOR(0xff000000))
