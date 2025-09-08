require app
require ecs
require ecs.safe
require math.random
require game.events.events
require game.events.events_active_matter
require game.es.grav_zones_common
require DagorMath
require DagorRandom
require PhysMat
require CollRes
require Dacoll
require CollisionTraces


[es(tag=server, before=drop_loot_on_ri_destruction)]
def hive_body_destruction(evt : EventOnRendinstDestruction;
                          eid aka hive_eid : EntityId;
                          transform aka hive_transform : float3x4;
                          hive_body__templates : Array;
                          hive_body__spawnOffset : float3;
                          hive_body__spawnChance : float;
                          hive_honeycomb__templates : Array;
                          hive_honeycomb__spawnOffset : float3;
                          hive_honeycomb__spawnChance : float;
                          var hive_body__destructionTriggered : bool&)
  if hive_body__destructionTriggered
    return

  hive_body__destructionTriggered = true

  let baseTm = get_grav_tm(hive_transform[3])

  // Body
  if gfrnd() < hive_body__spawnChance

    var totalWeight = 0.0
    for data in hive_body__templates
      totalWeight += (data as Object)?.weight ?? 0.0

    if totalWeight > 0.0
      let rnd = gfrnd() * totalWeight

      var weight = 0.0
      for data in hive_body__templates
        let templateObj = data as Object
        weight += templateObj?.weight ?? 0.0
        if weight >= rnd

          var bodyTm = baseTm
          bodyTm[3] += rotate(hive_transform, hive_body__spawnOffset)

          createEntity(templateObj?["template"] ?? "") <| $(var init : ComponentsInitializer)
            init |> set("transform", bodyTm)

          break

  // Honeycombs
  if gfrnd() < hive_honeycomb__spawnChance
    for data in hive_honeycomb__templates
      let templateObj = data as Object
      let spawnCount = rnd_int(templateObj?.number ?? int2(0, 0))

      for _ in range(spawnCount)

        var honeycombTm = build_grav_tm(hive_transform[3], hive_transform[1])
        honeycombTm[3] += rotate(hive_transform, hive_honeycomb__spawnOffset)
        honeycombTm[3] += rnd_dir3() * rnd_float(0.0, 0.33)

        createEntity(templateObj?["template"] ?? "") <| $(var init : ComponentsInitializer)
          init |> set("transform", honeycombTm)

  broadcastEvent(EventBeehiveDestruction(beehiveEid = hive_eid))


[es(tag=gameClient)]
def hive_client_destruction_effect_client(evt : CmdReplaceRiExtraRes;
                                          transform aka hive_transform : float3x4;
                                          ri_extra__riAfterDestruction : string;
                                          hive_client_destruction__effectTemplate : string;
                                          hive_client_destruction__effectOffset : float3;
                                          hive_client_destruction__fallingEffectMarkTemplate : string;
                                          hive_client_destruction__fallingSoundTemplate : string)
  if evt.riExtra == ri_extra__riAfterDestruction

    var effectTm = get_grav_tm(hive_transform[3])
    effectTm[3] += rotate(hive_transform, hive_client_destruction__effectOffset)

    createEntity(hive_client_destruction__effectTemplate) <| $(var init : ComponentsInitializer)
      init |> set("transform", effectTm)

    createEntity(hive_client_destruction__fallingEffectMarkTemplate) <| $(var init : ComponentsInitializer)
      let fallingEffectMarkTm = build_grav_tm(effectTm[3], effectTm[1])
      init |> set("transform", fallingEffectMarkTm)

    createEntity(hive_client_destruction__fallingSoundTemplate) <| $(var init : ComponentsInitializer)
      init |> set("transform", effectTm)


[es(tag=gameClient, no_order)]
def hive_wasp_slime_falling_mark(act : UpdateStageInfoAct;
                                 eid : EntityId;
                                 hive_wasp_slime_falling_mark__speed : float;
                                 hive_wasp_slime_falling_mark__updateInterval : float;
                                 hive_wasp_slime_falling_mark__collisionEffectTemplate : string;
                                 hive_wasp_slime_falling_mark__maxDistance : float;
                                 var hive_wasp_slime_falling_mark__travelledDistance : float&;
                                 var hive_wasp_slime_falling_mark__updateTime : float&;
                                 var transform : float3x4)
  hive_wasp_slime_falling_mark__updateTime += act.dt
  if hive_wasp_slime_falling_mark__updateTime < hive_wasp_slime_falling_mark__updateInterval
    return

  let prevPos = transform[3]
  let delta = hive_wasp_slime_falling_mark__speed * hive_wasp_slime_falling_mark__updateTime

  var t = delta
  var norm : float3
  var matId = PHYSMAT_INVALID
  var riDesc = RendInstDesc()
  if traceray_normalized(prevPos, transform[1], t, matId, norm, ETF_ALL, riDesc, -1)
    let traceHitPos = prevPos + transform[1] * (t - 1e-3)
    hive_wasp_slime_falling_mark__travelledDistance += (delta - t)
    if hive_wasp_slime_falling_mark__travelledDistance <= hive_wasp_slime_falling_mark__maxDistance
      transform[3] = traceHitPos

      createEntity(hive_wasp_slime_falling_mark__collisionEffectTemplate) <| $(var init : ComponentsInitializer)
        init |> set("transform", build_grav_tm(transform[3], transform[1]))

    destroyEntity(eid)
  else
    hive_wasp_slime_falling_mark__travelledDistance += delta
    transform[3] += transform[1] * delta

    if hive_wasp_slime_falling_mark__travelledDistance > hive_wasp_slime_falling_mark__maxDistance
      destroyEntity(eid)

  hive_wasp_slime_falling_mark__updateTime = 0.0