options no_aot = true
require ecs
require app
require walkerai
require math
require math.base
require DagorMath
require DngWalkerai
require DagorRandom
require DagorDebug3D
require DagorConsole
require strings
require ecs.ecs_template
require game.es.ai.ai_danger_common
require game.es.ai.walker_common
require game.es.ecs_common

// usage:
// incomment needed [init]
// active_matter-aot-win64-c-dev.exe -aot "d:\dagor2\active_matter\prog\scripts\game\es\ai\ai_danger_debug.das" D:\dummy.cpp -- --verbose --config d:/dagor2/active_matter/prog/aot_config.blk


// to_log(LOG_DEBUG, to log without new lines

def print_values(limit = 100; step = 10; hr = true; blk)
  let origin : float2
  let shootDir = float2(1, 0)
  var x = -limit
  if hr
    to_log(LOG_DEBUG, " y\\x ")
    while x <= limit
      to_log(LOG_DEBUG, fmt(":4d", x))
      to_log(LOG_DEBUG, x == 0 ? "  " : " ")
      x += step
      if x == 0
        to_log(LOG_DEBUG, " ")
    to_log(LOG_DEBUG, "\n\n")

  var y = -limit
  while y <= limit
    x = -limit
    if hr
      to_log(LOG_DEBUG, fmt(":4d", y))
      to_log(LOG_DEBUG, " ")
    while x <= limit
      let pos = float2(x, y)
      invoke(blk, origin, pos, shootDir)
      if hr && x == 0
        to_log(LOG_DEBUG, " ")
      x += step
      if hr && x == 0
        to_log(LOG_DEBUG, " ")
    to_log(LOG_DEBUG, "\n")
    if hr && y == 0
      to_log(LOG_DEBUG, "\n")
    y += step
    if hr && y == 0
      to_log(LOG_DEBUG, "\n")


def print_alertness_with_params(stance : int)
  let agent_dangers__frustumAngle = 45f
  let frustumMinCos = cos(deg_to_rad(agent_dangers__frustumAngle))
  print_values(100, 10, true) <| $(origin, pos, shootDir : float2)
    let dist = length(pos - origin)
    let frustumCos = dot(normalize(pos - origin), shootDir)
    let inFrustum = frustumCos >= frustumMinCos
    let agent_dangers__maxDangerDist = 90.0
    let alertness = calc_target_alertness(dist, inFrustum, frustumCos, stance, /*is_downed*/false, agent_dangers__maxDangerDist)
    to_log(LOG_DEBUG, fmt(":.2f", alertness))
    to_log(LOG_DEBUG, " ")

// [init]
def print_alertness()
  to_log(LOG_DEBUG, "Stance stand\n")
  print_alertness_with_params(STANCE_STAND)
  to_log(LOG_DEBUG, "Stance crouch\n")
  print_alertness_with_params(STANCE_CROUCH)
  to_log(LOG_DEBUG, "Stance crawl\n")
  print_alertness_with_params(STANCE_CRAWL)
  to_log(LOG_DEBUG, " ")

// [init]
def print_traceable_ratio()
  print_danger_or_traceable_ratio(false)

// [init]
def print_danger()
  print_danger_or_traceable_ratio(true)

def print_danger_or_traceable_ratio(printDanger = true)
  let agent_dangers__frustumAngle = 45f
  let frustumMinCos = cos(deg_to_rad(agent_dangers__frustumAngle))
  let atTime = 1000f
  let agent_dangers__maxDangerDist = 90f

  print_values(100, 10, true) <| $(origin, pos, shootDir : float2)
    let dist = length(pos - origin)
    let frustumCos = dot(normalize(pos - origin), shootDir)
    let inFrustum = frustumCos >= frustumMinCos
    let alertness = calc_target_alertness(dist, inFrustum, frustumCos, STANCE_STAND, /*is_downed*/false, agent_dangers__maxDangerDist)
    using() <| $(var danger : Danger#)
      danger.distance = dist
      danger.alertness = alertness
      danger.inFrustumTime = inFrustum ? atTime - 1f : -1f
      danger.lastBulletNearbyTime = -1f //atTime - 0.1f
      danger.lastTraceTime = atTime - 100f
      using() <| $(var target : Target#)
        target.lastShootTimer = atTime //1000f
        let isAi = false
        var dangerMeter = calc_danger(atTime, agent_dangers__maxDangerDist, danger, target, /*noise*/0.25, isAi)
        if (dangerMeter < 0.73)
          dangerMeter = 0.0
        to_log(LOG_DEBUG, fmt(":.2f", printDanger ? dangerMeter : calc_traceable_ratio(atTime, dangerMeter, danger)))
        to_log(LOG_DEBUG, " ")


[ecs_template]
struct ai_danger_debug_draw
  ai_danger__debugDrawDist : float = 50.0


[console_cmd(name="ai_danger.debug_draw")]
def ai_danger_debug_draw_cmd(dist = 50.)
  let tmpl = "ai_danger_debug_draw"
  let exists = find_query() <| $ [es] (eid : EntityId; var ai_danger__debugDrawDist : float&)
    if ai_danger__debugDrawDist == dist
      destroyEntity(eid)
    else
      ai_danger__debugDrawDist = dist
    return true

  if !exists
    createEntity(tmpl) <| $(init)
      init |> set("ai_danger__debugDrawDist", dist)


[es(tag=render, tag=dev, no_order)]
def ai_danger_debug_es(evt : UpdateStageInfoRenderDebug;
                       ai_danger__debugDrawDist : float)

  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false

    let debugDrawDistSq = square(ai_danger__debugDrawDist)
    query() <| $ [es] (agent_dangers : AgentDangers;
                       transform aka agent_transform : float3x4)
      let distSq = distance_sq(camera_transform[3], agent_transform[3])
      if distSq > debugDrawDistSq
        return

      for i in iter_range(agent_dangers.dangers)
        assume danger = agent_dangers.dangers[i]
        query(danger.eid) <| $ [es] (transform aka danger_transform : float3x4)
          let color = danger.traceable ? E3DCOLOR(0xFF00FF00) : E3DCOLOR(0xFFFF0000)

          let midPoint = (agent_transform[3] + danger_transform[3]) * 0.5
          draw_debug_line_buffered(agent_transform[3], danger_transform[3], color, 1)

          var j = 0
          add_debug_text_mark(midPoint, "<{danger.eid}>", -1, float(j++), color)
          add_debug_text_mark(midPoint, "traceable: {danger.traceable ? "yes" : "no"}", -1, float(j++), color)
          add_debug_text_mark(midPoint, "inFrustumTime: {fmt(":.2f", danger.inFrustumTime)}", -1, float(j++), color)
          add_debug_text_mark(midPoint, "alertness: {fmt(":.2f", danger.alertness)}", -1, float(j++), color)
          add_debug_text_mark(midPoint, "dangerMeter: {fmt(":.2f", danger.dangerMeter)}", -1, float(j++), color)
          add_debug_text_mark(midPoint, "noiseMeter: {fmt(":.2f", danger.noiseMeter)}", -1, float(j++), color)

          let timeFromLastTrace = get_sync_time() - danger.lastTraceTime
          add_debug_text_mark(midPoint, "timeFromLastTrace: {fmt(":.2f", timeFromLastTrace)} s.", -1, float(j++), color)

    return true