options no_aot
require net
require ecs
require ecs.ecs_template
require ECSGlobalTags
require math.base
require DagorConsole
require DagorSystem
require Dacoll
require ecs.templates_common
require strings
require daslib/strings_boost
require danetlibs.console_commands.main.console_common
require game.es.server_debug_common
require game.es.grav_zones_common
require game.es.net_console_macro

def get_look_tm(at = 100.0)
  var camTm := IDENT_TM
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if camera__active
      camTm := transform
    return camera__active

  let traceDir : float3 = camTm[2]
  var t = at
  var norm : float3
  traceray_normalized(camTm[3], traceDir, t, norm, ETF_ALL)
  var resTm = IDENT_TM
  resTm[3] = camTm[3] + traceDir * (t - 0.1)
  let grav = get_grav_dir(resTm[3])
  resTm[1] = -grav
  let tmp = cross(-grav, camTm[2])
  resTm[0] = normalize(cross(tmp, -grav))
  resTm[2] = normalize(cross(resTm[0], -grav))

  return resTm


[console_cmd(name="ecs.create_entity_at")]
def console_create_entity_at(templ : string; x, y, z, v1x, v1y, v1z, v2x, v2y, v2z, v3x, v3y, v3z : float = .0)
  var tm := IDENT_TM
  if x == .0 && y == .0 && z == .0
    tm = get_look_tm()
  else
    tm[0] = float3(v1x, v1y, v1z)
    tm[1] = float3(v2x, v2y, v2z)
    tm[2] = float3(v3x, v3y, v3z)
    tm[3] = float3(x, y, z)
  if is_server()
    createEntity(templ) <| $(init)
      init |> set("transform", tm)
  else
    exec_server_cmd("ecs.create_entity_at {templ} {tm[3].x} {tm[3].y} {tm[3].z} {tm[0].x} {tm[0].y} {tm[0].z} {tm[1].x} {tm[1].y} {tm[1].z} {tm[2].x} {tm[2].y} {tm[2].z}")


[net_console_cmd(name="ecs.print_entity_info")]
def console_print_entity_info(eid : int)
  let parsedEid = EntityId(uint(eid))
  print("Entity <{parsedEid}>({getEntityTemplateName(parsedEid)})")