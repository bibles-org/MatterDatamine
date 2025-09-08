options no_aot
require ecs
require ecs.safe
require ecs.ecs_template
require math.base
require strings
require game.utils.hero
require DagorConsole
require DagorDebug3D
require DagorSystem


[ecs_template]
struct mothman_debug
  mothman_debug__debugDraw : bool = false


[console_cmd(name="mothman.debug_draw")]
def mothman_debug_draw_cmd(draw : bool = true)
  let tmpl = "mothman_debug"
  addSubTemplate(get_controlled_hero(), tmpl) <| $(var init)
    set(init, "mothman_debug__debugDraw", draw)


[es(tag=render, tag=dev, no_order)]
def diving_mothman_debug_es(act : UpdateStageInfoAct;
                            mothman_debug__debugDraw : bool;
                            mothman_diving_grab_ability__potentialTargetSphereOffset : float3;
                            mothman_diving_grab_ability__potentialTargetSphereRadius : float;
                            mothman_diving_grab_ability__potentialTargetEid : EntityId;
                            transform : float3x4)
  if !mothman_debug__debugDraw
    return

  let offsetWS = rotate(transform, mothman_diving_grab_ability__potentialTargetSphereOffset)
  let spherePos = transform[3] + offsetWS

  let hasTarget = mothman_diving_grab_ability__potentialTargetEid != INVALID_ENTITY_ID
  draw_debug_sphere_buffered(spherePos, mothman_diving_grab_ability__potentialTargetSphereRadius,
                             hasTarget ? E3DCOLOR(0xFFFF0000) : E3DCOLOR(0xFF00FF00), 12, 1)

  query(mothman_diving_grab_ability__potentialTargetEid) <| $ [es] (transform aka target_transform : float3x4)
    let markPos = target_transform[3] + float3(0.0, 1.0, 0.0)
    add_debug_text_mark(markPos, "TARGET", -1, 0.0, E3DCOLOR(0xFFFF0000))


