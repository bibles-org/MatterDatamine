options no_aot
options no_unused_function_arguments = false
require ecs
require ecs.ecs_template
require game.es.net_console_macro
require game.events.events
require DngHuman
require DagorSystem
require game.es.grav_zones_common
require HeightmapQueryManager
require gpuReadbackQuery
require math.color
require DagorConsole
require DagorDebug3D

// consts
//----------------------------------------------------------------------
let debug_color = E3DCOLOR(0xFFFF00FF)
let debug_sphere_rad = 0.1

// single point check
//----------------------------------------------------------------------
[ecs_template(tag=dev)]
struct debug_hmap_query_single
  debug_hmap_query__idx : int
  debug_hmap_query__pos : float3
  debug_hmap_query__normal : float3

[ecs_template(tag=dev)]
struct debug_hmap_query
  debug_hmap_query__single_active : bool

[console_cmd(name="hmap_query_debug.enable_single_query_grav")]
def debug_switch_single_query_on_off()
  let exists = find_query() <| $ [es] (var debug_hmap_query__single_active : bool&)
    debug_hmap_query__single_active = !debug_hmap_query__single_active
    return true

  if !exists
    createEntity("debug_hmap_query") <| $(init)
      init |> set("debug_hmap_query__single_active", true)


[console_cmd(name="hmap_query_debug.query_single_grav")]
def debug_add_single_query()
  var active = true
  let exists = find_query() <| $ [es] (debug_hmap_query__single_active : bool)
    active = debug_hmap_query__single_active
    return true
  if !exists
    createEntity("debug_hmap_query") <| $(init)
      init |> set("debug_hmap_query__single_active", true)

  if (!active)
    return

  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if !camera__active
      return false

    let pos = transform[3]

    let gravDir = get_grav_dir(pos)
    let idx = heightmap_query_start(pos, gravDir)
    createEntity("debug_hmap_query_single") <| $(init)
      init |> set("debug_hmap_query__idx", idx)
      init |> set("debug_hmap_query__pos", float3(pos.x, pos.y, pos.z))
      init |> set("debug_hmap_query__normal", float3(0, 1, 0))
    return true

[es(tag=render, tag=dev, no_order)]
def debug_update_single_queries(info : UpdateStageInfoRenderDebug;
                                camera__active : bool)
  var active = false
  query() <| $ [es] (debug_hmap_query__single_active : bool)
    active = debug_hmap_query__single_active

  if !camera__active || !active
    return

  query() <| $ [es] (var debug_hmap_query__idx : int&;
                     var debug_hmap_query__pos : float3&;
                     var debug_hmap_query__normal : float3&)
    if debug_hmap_query__idx < 0
      let qpos = debug_hmap_query__pos
      debug_hmap_query__idx = heightmap_query_start(qpos, get_grav_dir(qpos))
    else
      var hmqr = HeightmapQueryResultWrapper()
      let qRes = heightmap_query_value(debug_hmap_query__idx, hmqr)
      if is_gpu_readback_query_successful(qRes)
        debug_hmap_query__pos = debug_hmap_query__pos + hmqr.normal * hmqr.hitDistWithOffsetDeform
        debug_hmap_query__normal = hmqr.normal

[es(tag=render, tag=dev, after=debug_update_single_queries)]
def draw_debug_hmap_single_queries(info : UpdateStageInfoRenderDebug;
                                   debug_hmap_query__pos : float3&;
                                   debug_hmap_query__idx : int;
                                   debug_hmap_query__normal : float3&)
  var active = false
  query() <| $ [es] (debug_hmap_query__single_active : bool)
    active = debug_hmap_query__single_active

  if (debug_hmap_query__idx < 0) || !active
    return
  begin_draw_cached_debug_lines(true, false, false)
  draw_debug_arrow_buffered(debug_hmap_query__pos, debug_hmap_query__pos + debug_hmap_query__normal, debug_color, 1)
  draw_debug_sphere_buffered(debug_hmap_query__pos, debug_sphere_rad, debug_color, 1)
  end_draw_cached_debug_lines()

// multiple point auto check - by camera pos
//----------------------------------------------------------------------
[ecs_template(tag=dev)]
struct debug_hmap_query_list
  debug_hmap_query_list__active : bool
  debug_hmap_query_list__idx : IntList
  debug_hmap_query_list__pos : Point3List
  debug_hmap_query_list__cached_pos : Point3List
  debug_hmap_query_list__spacing : float
  debug_hmap_query_list__auto_query_row_nr : int
  debug_hmap_query_list__auto_query_half_row_nr : int

[console_cmd(name="hmap_query_debug.test_auto_query_grav")]
def debug_debug_add_query2(spacing = 0.5; auto_query_row_nr = 20)
  var exists = false
  query() <| $ [es] (var debug_hmap_query_list__active : bool&;
                     var debug_hmap_query_list__spacing : float&;
                     var debug_hmap_query_list__auto_query_row_nr : int&;
                     var debug_hmap_query_list__auto_query_half_row_nr : int&)
    exists = true
    debug_hmap_query_list__active = !debug_hmap_query_list__active
    debug_hmap_query_list__spacing = spacing
    debug_hmap_query_list__auto_query_row_nr = auto_query_row_nr
    debug_hmap_query_list__auto_query_half_row_nr = auto_query_row_nr / 2

  if !exists
    query() <| $ [es] (camera__active : bool)
      if !camera__active
        return

      createEntity("debug_hmap_query_list") <| $(init)
        init |> set("debug_hmap_query_list__active", true)
        init |> set("debug_hmap_query_list__spacing", spacing)
        init |> set("debug_hmap_query_list__auto_query_row_nr", auto_query_row_nr)
        init |> set("debug_hmap_query_list__auto_query_half_row_nr", auto_query_row_nr / 2)

[es(tag=render, tag=dev, no_order)]
def hmap_query_list__update_pos(info : UpdateStageInfoRenderDebug;
                                debug_hmap_query_list__active : bool;
                                var debug_hmap_query_list__idx : IntList&;
                                var debug_hmap_query_list__pos : Point3List&;
                                var debug_hmap_query_list__cached_pos : Point3List&;
                                debug_hmap_query_list__spacing : float&;
                                debug_hmap_query_list__auto_query_row_nr : int&;
                                debug_hmap_query_list__auto_query_half_row_nr : int&)
  if !debug_hmap_query_list__active
    return

  query() <| $ [es] (camera__active : bool; transform : float3x4)
    if !camera__active
      return

    let x = transform[0].xyz
    let z = transform[2].xyz
    let pos = transform[3].xyz

    var initIdx = false
    if debug_hmap_query_list__idx.length() == 0
      initIdx = true

    // updating positions
    if debug_hmap_query_list__active
      if initIdx
        debug_hmap_query_list__pos.clear()
        debug_hmap_query_list__idx.clear()
        var currPos = pos
        for i in 0..debug_hmap_query_list__auto_query_row_nr
          for j in 0..debug_hmap_query_list__auto_query_row_nr
            currPos = pos + x * float(i - debug_hmap_query_list__auto_query_half_row_nr) * debug_hmap_query_list__spacing + z * float(j - debug_hmap_query_list__auto_query_half_row_nr) * debug_hmap_query_list__spacing
            debug_hmap_query_list__pos |> push(currPos)
            debug_hmap_query_list__cached_pos |> push(currPos)
            debug_hmap_query_list__idx |> push(heightmap_query_start(currPos, get_grav_dir(currPos)))
      else
        var currPos = pos
        for i in 0..debug_hmap_query_list__auto_query_row_nr
          for j in 0..debug_hmap_query_list__auto_query_row_nr
            currPos = pos + x * float(i - debug_hmap_query_list__auto_query_half_row_nr) * debug_hmap_query_list__spacing + z * float(j - debug_hmap_query_list__auto_query_half_row_nr) * debug_hmap_query_list__spacing
            debug_hmap_query_list__pos[(i) * debug_hmap_query_list__auto_query_row_nr + j] = currPos

    // updating heights
    for i in 0..debug_hmap_query_list__idx.length()
      if debug_hmap_query_list__idx[i] < 0
        let qpos = debug_hmap_query_list__pos[i]
        debug_hmap_query_list__idx[i] = heightmap_query_start(qpos, get_grav_dir(qpos))
      else
        var hmqr = HeightmapQueryResultWrapper()
        let qRes = heightmap_query_value(debug_hmap_query_list__idx[i], hmqr)
        if is_gpu_readback_query_successful(qRes)
          debug_hmap_query_list__cached_pos[i] = debug_hmap_query_list__pos[i] + hmqr.normal * hmqr.hitDistWithOffsetDeform
          debug_hmap_query_list__idx[i] = -1
        elif is_gpu_readback_query_failed(qRes)
          debug_hmap_query_list__idx[i] = -1

[es(tag=render, tag=dev, no_order)]
def hmap_query_list__draw(info : UpdateStageInfoRenderDebug;
                          debug_hmap_query_list__active : bool;
                          debug_hmap_query_list__pos : Point3List&;
                          debug_hmap_query_list__cached_pos : Point3List&)
  if !debug_hmap_query_list__active
    return

  for i in 0..debug_hmap_query_list__cached_pos.length()
    draw_debug_arrow_buffered(debug_hmap_query_list__pos[i], debug_hmap_query_list__cached_pos[i], debug_color, 1)

  end_draw_cached_debug_lines()