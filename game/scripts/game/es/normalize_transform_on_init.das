require ecs
require app
require math.random
require math.base
require game.es.grav_zones_common
require level
require Dacoll
require DagorSystem


[es(tag=server, on_appear, on_event=EventLevelLoaded, REQUIRE=normalize_down_on_init)]
def normalize_transform_on_init(evt : Event;
                                normalize_down_on_init__additionalHeight : float = 15.0;
                                normalize_down_on_init__height : float = 30.0;
                                var transform : float3x4)
  if !is_level_loaded()
    return

  assume additionalHeight = normalize_down_on_init__additionalHeight
  var height = normalize_down_on_init__height
  var dirUp : float3
  let down = get_grav_dir(transform[3])
  var pmat : int
  let traceFrom = transform[3] + float3(0.0, additionalHeight, 0.0)

  if traceray_normalized_lmesh(traceFrom, down, height, pmat, dirUp)
    transform[3].y += additionalHeight - height
    let magicLMeshOffset = 2.0
    height -= magicLMeshOffset // Workaround fix for the tracedown below
                               // (it returns incorrect ground intersection)
    transform = build_grav_tm(transform[3], -dirUp)

  if tracedown_normalized(traceFrom, height, dirUp, ETF_DEFAULT)
    transform[3].y += additionalHeight - height
    transform = build_grav_tm(transform[3], -dirUp)
