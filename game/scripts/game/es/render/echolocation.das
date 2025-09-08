require ecs
require ecs.common
require ecs.ecs_template
require math.easing
require math.base
require DagorDebug3D
require DagorMath
require DagorSystem
require Dacoll
require DngWeapon
require DngUI
require game.es.human_weap_common


def draw_echolocation_hit(pos : float3;
                          norm : float3;
                          halfSize : float;
                          color : E3DCOLOR)
  let normUp = perpendicular(norm)
  let normRight = cross(norm, normUp)
  let up = normUp * (halfSize)
  let right = normRight * (halfSize)
  draw_debug_rect_buffered(
    pos - up - right,
    pos + up - right,
    pos - up + right,
    color,
    1)


[es(on_appear, REQUIRE=darkness_anomaly__staleBreathAvailableTime)]
def darkness_anomaly_echolocation_enable(evt : Event;
                                         game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var echolocation__enabled : bool&)
    echolocation__enabled = true


[es(on_disappear, REQUIRE=darkness_anomaly__staleBreathAvailableTime)]
def darkness_anomaly_echolocation_disable(evt : Event;
                                          game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var echolocation__enabled : bool&)
    echolocation__enabled = false
    query() <| $ [es] (eid : EntityId;
                       echolocation__attachedTo : EntityId)
      if echolocation__attachedTo == game_effect__attachedTo
        destroyEntity(eid)


[es(no_order, tag=render, REQUIRE=hero)]
def echolocation(info : UpdateStageInfoAct;
                 eid : EntityId;
                 echolocation__enabled : bool;
                 echolocation__time : float;
                 var echolocation__generateAt : float&)
  if !echolocation__enabled
    return

  if info.curTime >= echolocation__generateAt
    echolocation__generateAt = info.curTime + echolocation__time
    var shootTm : float3x4
    if human_weap_get_aim_tm(eid, info.curTime, shootTm)
      createEntitySync("echolocation_source") <| $(init)
        init |> set("echolocation__attachedTo", eid)
        init |> set("transform", shootTm)


def do_echolocation_trace(x : int;
                          y : int;
                          tm : float3x4;
                          dist : float;
                          cell_size : float;
                          hit_time : float)
  let tracePos = tm[3] + float(y) * tm[1] * cell_size + float(x) * tm[2] * cell_size
  let traceDir = tm[0]
  var norm : float3

  var d = dist
  if traceray_normalized(tracePos, traceDir, d, norm)
    let surfaceOffset = 0.0285
    let p = tracePos + traceDir * d + norm * surfaceOffset
    draw_debug_line_buffered(tracePos, p, E3DCOLOR(0x19DDDDDD), 3)
    createEntity("echolocation_hit") <| $(init)
      init |> set("echolocation_hit__pos", p)
      init |> set("echolocation_hit__norm", norm)
      init |> set("echolocation_hit__time", hit_time)
      init |> set("echolocation_hit__timer", hit_time)


[es(on_appear)]
def echolocation_source_init(evt : Event;
                             echolocation__gridRadius : int;
                             echolocation__gridTicksPerStep : int;
                             var echolocation__curTick : int&)
  echolocation__curTick = echolocation__gridRadius * echolocation__gridTicksPerStep


[es(tag=render, after=echolocation)]
def echolocation_source_update(info : UpdateStageInfoAct;
                               eid : EntityId;
                               transform : float3x4;
                               echolocation__timePerTick : float;
                               echolocation__distance : float;
                               echolocation__hitTime : float;
                               echolocation__gridRadius : int;
                               echolocation__gridTicksPerStep : int;
                               echolocation__gridCellSize : float;
                               var echolocation__nextTickAt : float&;
                               var echolocation__curTick : int&)
  if info.curTime >= echolocation__nextTickAt
    echolocation__nextTickAt = info.curTime + echolocation__timePerTick
    let curTick = echolocation__curTick--

    let ticksPerStep = echolocation__gridTicksPerStep

    let tickType = curTick % ticksPerStep
    let step = (((echolocation__gridRadius * ticksPerStep + 1 - curTick) / ticksPerStep) - 1)
    if tickType == 0
      for x in range(-step, step + 1)
        do_echolocation_trace(x, -step, transform, echolocation__distance,
                              echolocation__gridCellSize, echolocation__hitTime)
    elif tickType == 1
      for y in range(-step + 1, step)
        do_echolocation_trace(-step, y, transform, echolocation__distance,
                              echolocation__gridCellSize, echolocation__hitTime)
    elif tickType == 2
      for x in range(-step, step + 1)
        do_echolocation_trace(x, step, transform, echolocation__distance,
                              echolocation__gridCellSize, echolocation__hitTime)
    elif tickType == 3
      for y in range(-step + 1, step)
        do_echolocation_trace(step, y, transform, echolocation__distance,
                              echolocation__gridCellSize, echolocation__hitTime)

    if echolocation__curTick == 0
      destroyEntity(eid)


[es(tag=render, before=echolocation)]
def echolocation_hit_update(info : UpdateStageInfoAct;
                            eid : EntityId;
                            echolocation_hit__pos : float3;
                            echolocation_hit__norm : float3;
                            echolocation_hit__time : float;
                            echolocation_hit__amplitudePhase : float;
                            var echolocation_hit__timer : float&)
  echolocation_hit__timer -= info.dt
  if echolocation_hit__timer > 0.0
    let progress = 1.0 - echolocation_hit__timer / echolocation_hit__time
    let alpha = smoothstep(progress < echolocation_hit__amplitudePhase ? 0.0 : 1.0,
                           echolocation_hit__amplitudePhase, progress)
    let halfSize = 0.003
    let color = E3DCOLOR(uint4(235u, 235u, 235u, uint(alpha * 255.0)))
    draw_echolocation_hit(echolocation_hit__pos, echolocation_hit__norm, halfSize, color)
    draw_echolocation_hit(echolocation_hit__pos, echolocation_hit__norm, halfSize * 0.5, color)
  else
    destroyEntity(eid)