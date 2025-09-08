options no_aot
require ecs
require ecs.extra_set
require level
require Dacoll
require CollRes
require strings
require RendInst
require inventory
require math.base
require DagorConsole
require DagorDebug3D
require DngHuman
require game.utils.hero
require debug.logerr_once
require daslib/strings_boost


def get_collres_slice_mean_and_dispersion(collres : CollisionResource; min_height, max_height : float) : float2
  var mean = 0.0
  var meanSq = 0.0
  var disp = 0.0
  var pointsSize = 0
  let nodeCount = collres_get_nodesCount(collres)
  for nodeIdx in range(nodeCount)
    let node = collres |> collres_get_node(nodeIdx)
    if node.nodeType != CollisionResourceNodeType.COLLISION_NODE_TYPE_MESH
      continue
    get_collnode_geom(node) <| $(indices; vertices)
      var indexNo = 0
      while indexNo < length(indices)
        let vertIdx = int(indices[indexNo])
        let height = vertices[vertIdx].y
        if height < min_height || height > max_height
          continue
        ++pointsSize
        let point = vertices[vertIdx].xz
        let distSq = length_sq(point)
        mean += sqrt(distSq)
        meanSq += distSq
        indexNo += 3

  mean = safediv(mean, float(pointsSize))
  disp = safediv(meanSq, float(pointsSize)) - mean * mean
  return float2(mean, disp)


// when no min_coll_rad (min_coll_height) is provided, uses hero's collider radius (height)
// incl_substr -- allowed covers must include all substrings from this list
// excl_substr -- allowed covers mustn't include any substrings from this list
// all covers that don't pass substring check neither are stored in dynamic_ri_covers__allowed nor in dynamic_ri_covers__banned
[console_cmd(name="ri_covers.find_covers", hint="result will be stored in clipboard")]
def find_ri_covers(max_relative_disp : float = 0.01;
                   min_coll_rad : float = -1.f;
                   min_coll_height : float = -1.f;
                   incl_substr : string = "tree_";
                   excl_substr : string = "bush_,_double,_triple")
  let exist = find_query() <| $ [es(REQUIRE=debug_dynamic_ri_covers__allowed)] (eid : EntityId)
    destroyEntity(eid)
    return true

  if exist
    console_print("covers highlight was turned off, rerun command to get new results\n")
    return

  let searchBox = BBox3(float3(-1000.f, -100.f, -1000.f),
                        float3(1000.f, 100.f, 1000.f))
  let includeList <- split_by_chars(incl_substr, ",")
  let excludeList <- split_by_chars(excl_substr, ",")
  var allowed_covers : table<string>
  var banned_covers : table<string>
  var minCollRad = min_coll_rad
  var minCollresHeight = min_coll_height
  if minCollRad <= 0.f || minCollresHeight <= 0.f
    console_print("min_coll_rad and (or) min_coll_height weren't provided -> they are set to phys.collRad and phys.standingHeight\n")
    query(get_controlled_hero()) <| $ [es] (human_net_phys : HumanActor)
      assume phys = human_net_phys.phys
      minCollRad = minCollRad > 0.f ? minCollRad : phys.collRad
      minCollresHeight = minCollresHeight > 0.f ? minCollresHeight : phys.standingHeight
  console_print("find_covers(max_relative_disp={max_relative_disp},
    min_coll_rad={minCollRad}, min_coll_height{minCollresHeight}, incl_substr='{incl_substr}', excl_substr='{excl_substr}')\n")

  let oldNumCallbacks = setMaxNumRiCollisionCb(500000u)
  rendinst_foreachInBox(searchBox, int(GatherRiTypeFlags.RiGenAndExtra)) <| $ [unused_argument(tm, is_tm)] (desc : RendInstDesc; tm : float3x4; is_tm : bool)
    let coverName = getRIGenResName(desc)

    let collres = getRiGenCollisionResource(desc)
    if collres == null
      print("find_covers: {coverName} excluded. Reason: Missing collres.")
      return

    if banned_covers |> key_exists(coverName) || allowed_covers |> key_exists(coverName)
      return

    for substr in includeList
      if find(coverName, substr) == -1
        banned_covers |> insert(coverName)
        print("find_covers: {coverName} excluded. Reason: Doesn't have substring '{substr}' from incl_substr.")
        return

    for substr in excludeList
      if find(coverName, substr) != -1
        banned_covers |> insert(coverName)
        print("find_covers: {coverName} excluded. Reason: Has substring '{substr}' from excl_substr.")
        return

    let collresBMax = collres.boundingBox.boxMax
    let collresBMin = collres.boundingBox.boxMin
    let sliceInfo = get_collres_slice_mean_and_dispersion(*collres, minCollresHeight * 0.25, minCollresHeight)
    let relativeDisp = safediv(sliceInfo.y, square(sliceInfo.x)) // = dispersion / mean_radius^2
    let collresHeight = collresBMax.y - collresBMin.y
    if sliceInfo.x < minCollRad || relativeDisp > max_relative_disp || collresHeight < minCollresHeight
      banned_covers |> insert(coverName)
      let excludeReasons = build_string() <| $(var s)
        if sliceInfo.x < minCollRad
          s |> write(" Too thin (mean collision radius = {sliceInfo.x}; minimal mean collision radius = {minCollRad}).")
        if relativeDisp > max_relative_disp
          s |> write(" Too wide dispersion (dispersion = {relativeDisp}; maximal dispersion = {max_relative_disp}).")
        if collresHeight < minCollresHeight
          s |> write(" Too short (height = {collresHeight}; minimal height = {minCollresHeight}).")
      print("find_covers: {coverName} excluded. Reason:{excludeReasons}")
    else
      allowed_covers |> insert(coverName)
      print("find_covers: {coverName} included.")
  setMaxNumRiCollisionCb(oldNumCallbacks)

  createEntity("debug_dynamic_ri_covers") <| $(var init : ComponentsInitializer)
    var allowed_covers_list, banned_covers_list : array<uint>

    for cover in keys(allowed_covers)
      allowed_covers_list |> push(ecs_hash(cover))
    for cover in keys(banned_covers)
      banned_covers_list |> push(ecs_hash(cover))
    set(init, "debug_dynamic_ri_covers__allowed", allowed_covers_list)

  let str = build_string() <| $(var s)
    s |> write("\"dynamic_ri_covers__allowed:list<u32>\"\{\n")
    for cover in keys(allowed_covers)
      s |> write("\"cover:u32\" \{ value:i={ecs_hash(cover)}; \} // {cover}\n")
    s |> write("\}\n")

  set_clipboard_ansi_text(str)


[es(tag=(dev, render), no_order)]
def draw_ri_covers(info : UpdateStageInfoRenderDebug;
                   debug_dynamic_ri_covers__allowed : UInt32List)
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if !camera__active
      return false

    var allowed : table<uint>
    for cover in debug_dynamic_ri_covers__allowed
      allowed |> insert(cover)

    let xPos = transform[3].x
    let zPos = transform[3].z
    let radius = 200.
    let searchBox = BBox3(float3(xPos - radius, -300., zPos - radius),
                          float3(xPos + radius, 300., zPos + radius))
    let allowedColor = E3DCOLOR(0xFF00FF00)
    let bannedColor = E3DCOLOR(0xFFFF0000)
    begin_draw_cached_debug_lines(true, false, false)
    rendinst_foreachInBox(searchBox, int(GatherRiTypeFlags.RiGenAndExtra)) <| $ [unused_argument(is_tm)] (desc : RendInstDesc; tm : float3x4; is_tm : bool)
      let coverName = ecs_hash(getRIGenResName(desc))

      if allowed |> key_exists(coverName)
        draw_cached_debug_sphere(tm[3], 1.0, allowedColor, 4)
      else
        draw_cached_debug_sphere(tm[3], 1.0, bannedColor, 4)
    end_draw_cached_debug_lines()
    return true
