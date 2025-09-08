require app
require DagorMath
require debug.logerr_once
require ecs
require math.base
require math.easing


def getFog(data; n) : bool
  let words = n / 32
  let bits = n % 32
  if words < length(data)
    return (data[words] & (1 << bits)) != 0
  return false


// value is true to set fog, false to clear fog, returns true if the value was changed
def setFog(var data &; n; value) : bool
  let words = n / 32
  let bits = n % 32
  if words < length(data)
    if value
      if (data[words] & (1 << bits)) == 0
        data[words] |= (1 << bits)
        return true
    else
      if (data[words] & (1 << bits)) != 0
        data[words] &= ~(1 << bits)
        return true
  return false


[es(tag=gameClient, no_order)]
def clear_fog_of_war_es(info : UpdateStageInfoAct;
                        transform : float3x4;
                        fog_of_war_clearer__radius : float;
                        watchedByPlr : EntityId const?;
                        fog_of_war_reveal_effect : Tag const?)
  if watchedByPlr == null && fog_of_war_reveal_effect == null
    return
  query() <| $ [es] (eid : EntityId;
                     tiled_map__tilesPath : string;
                     fog_of_war__leftTop : float2;
                     fog_of_war__rightBottom : float2;
                     fog_of_war__resolution : float;
                     fog_of_war__enabled : bool;
                     var fog_of_war__data : IntList&;
                     var fog_of_war__dataGen : int&;
                     var fog_of_war__score : int&;
                     var fog_of_war__thresholdScore : int&;
                     fog_of_war__thresholdMultiplier : float;
                     var fog_of_war__revealed : bool&)
    if !fog_of_war__enabled
      return

    if fog_of_war__resolution <= 0.0
      logerr_once("fog_of_war__resolution in {tiled_map__tilesPath} should be positive, got: {fog_of_war__resolution}")
      return
    let cols = int((fog_of_war__rightBottom.x - fog_of_war__leftTop.x) / fog_of_war__resolution)
    let rows = int((fog_of_war__rightBottom.y - fog_of_war__leftTop.y) / fog_of_war__resolution)

    // if hero spawned before the zone is loaded then cols and rows will be 0, it would be fixed with
    // appear of the zone, don't logerr here.
    if cols == 0 || rows == 0
      return
    let center = (fog_of_war__rightBottom + fog_of_war__leftTop) / 2.0
    let zoneRadiusSq = square((fog_of_war__rightBottom.x - fog_of_war__leftTop.x) / 2.0)

    let dx = (fog_of_war__rightBottom.x - fog_of_war__leftTop.x) / float(cols)
    let dy = (fog_of_war__rightBottom.y - fog_of_war__leftTop.y) / float(rows)

    // init clear threshold score
    if fog_of_war__thresholdScore <= 0
      fog_of_war__score = 0
      fog_of_war__thresholdScore = 0
      for i in range(0, rows)
        for j in range(0, cols)
          let n = i * cols + j
          let cellPos = fog_of_war__leftTop + float2(float(j) * dx, float(i) * dy) + float2(dx / 2.0, dy / 2.0)
          if distance_sq(center, cellPos) <= zoneRadiusSq
            fog_of_war__thresholdScore += 1
            fog_of_war__score += getFog(fog_of_war__data, n) ? 0 : 1
      fog_of_war__thresholdScore = floori(float(fog_of_war__thresholdScore) * fog_of_war__thresholdMultiplier)

    let revealEid = getSingletonEntity("fog_of_war_reveal_effect")
    if revealEid == INVALID_ENTITY_ID && fog_of_war__score >= fog_of_war__thresholdScore && fog_of_war__revealed == false
      fog_of_war__revealed = true
      createEntity("fog_of_war_reveal_effect") <| $(var init)
        var tm = IDENT_TM
        tm[3] = float3(center.x, 0.0, center.y)
        init |> set("transform", tm)
        init |> set("game_effect__attachedTo", eid)
        init |> set("fog_of_war_reveal_effect__max_radius", (fog_of_war__rightBottom.x - fog_of_war__leftTop.x) / 2.0)

    let rx = ceili(fog_of_war_clearer__radius / dx)
    let ry = ceili(fog_of_war_clearer__radius / dy)

    let x = transform[3][0]
    let y = transform[3][2]

    let xi = int((x - fog_of_war__leftTop.x) / dx)
    let yi = int((y - fog_of_war__leftTop.y) / dy)

    let clearRadiusSq = square(fog_of_war_clearer__radius)

    for i in range(-rx, rx + 1)
      for j in range(-ry, ry + 1)
        let xn = clamp(xi + i, 0, cols - 1)
        let yn = clamp(yi + j, 0, rows - 1)

        let cellPos = fog_of_war__leftTop + float2(float(xn) * dx, float(yn) * dy) + float2(dx / 2.0, dy / 2.0)
        let dist_sq = distance_sq(cellPos, float2(x, y))
        if dist_sq < clearRadiusSq
          let n = yn * cols + xn

          if distance_sq(center, cellPos) <= zoneRadiusSq
            let changed = setFog(fog_of_war__data, n, false)
            if changed
              fog_of_war__dataGen += 1
              fog_of_war__score += 1
          else
            setFog(fog_of_war__data, n, true)


[es(tag=gameClient, before=clear_fog_of_war_es)]
def reveal_fog_of_war_es(info : UpdateStageInfoAct;
                         fog_of_war_reveal_effect__max_radius : float;
                         game_effect__timeToDestroy : float;
                         game_effect__clientDestroyAt : float;
                         var fog_of_war_clearer__radius : float&)
  fog_of_war_clearer__radius = inOutSine(cvt(get_sync_time(),
                                game_effect__clientDestroyAt - game_effect__timeToDestroy,
                                game_effect__clientDestroyAt,
                                0.0,
                                1.0)) * fog_of_war_reveal_effect__max_radius
