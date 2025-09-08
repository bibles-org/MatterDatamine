require ecs
require math.base
require DagorMath
require DagorSystem
require Dacoll


[es(tag=gameClient, on_appear)]
def particle_border_effect_appear(evt : Event;
                                  particle_border_effect__drawerEid : EntityId)
  query(particle_border_effect__drawerEid) <| $ [es] (var particle_border_drawer__dirty : bool&)
    particle_border_drawer__dirty = true


[es(tag=gameClient, track=particle_border_drawer__effectColorMult)]
def particle_border_drawer_effect_color_mult_track(evt : Event;
                                                   particle_border_drawer__effectColorMult : E3DCOLOR;
                                                   particle_border_drawer__effectEids : EidList)
  for effectEid in particle_border_drawer__effectEids
    query(effectEid) <| $ [es] (var effect__colorMult : E3DCOLOR&)
      effect__colorMult = particle_border_drawer__effectColorMult


def update_circle_border_drawer_effects_transform(transform aka drawer_transform : float3x4;
                                                  particle_circle_border_drawer__radius : float;
                                                  var particle_border_drawer__effectEids : EidList)

  if length(particle_border_drawer__effectEids) == 0
    return

  let deltaAngle = TWOPI / float(length(particle_border_drawer__effectEids))
  let bisector = particle_circle_border_drawer__radius * cos(deltaAngle  * 0.5)
  let baseLen = 2.0 * particle_circle_border_drawer__radius * sin(deltaAngle  * 0.5)

  for effectIdx, effectEid in iter_range(particle_border_drawer__effectEids), particle_border_drawer__effectEids
    query(effectEid) <| $ [es] (var transform aka effect_transform : float3x4)
      let angle = deltaAngle * float(effectIdx)
      var s, c : float
      sincos(angle, s, c)

      var q : quat
      euler_to_quat(angle, 0.0, 0.0, q)
      make_tm(q, float3(s * bisector, 0.0, c * bisector), effect_transform)

      effect_transform = effect_transform * scale_tm(baseLen)
      effect_transform[3] += drawer_transform[3]

      let tracePos = effect_transform[3] + float3(0.0, particle_circle_border_drawer__radius, 0.0)
      let traceDir = float3(0, -1, 0)
      var norm : float3
      var d = particle_circle_border_drawer__radius * 2.0
      if traceray_normalized(tracePos, traceDir, d, norm)
        let surfaceOffset = 0.0285
        let p = tracePos + traceDir * d + norm * surfaceOffset
        effect_transform[3].y = p.y


def update_circle_border_drawer_effects_count(particle_border_effect__drawerEid : EntityId;
                                              count : int;
                                              particle_border_drawer__effectName : string;
                                              particle_border_drawer__effectColorMult : E3DCOLOR;
                                              var particle_border_drawer__effectEids : EidList)
  while length(particle_border_drawer__effectEids) < count
    let effectEid = createEntity("particle_border_effect") <| $(init)
      var tm = IDENT_TM
      tm[3] = float3(0.0, -4096.0, 0.0)
      init |> set("particle_border_effect__drawerEid", particle_border_effect__drawerEid)
      init |> set("transform", tm)
      init |> set("effect__name", particle_border_drawer__effectName)
      init |> set("effect__colorMult", particle_border_drawer__effectColorMult)

    particle_border_drawer__effectEids |> push(effectEid)

  while length(particle_border_drawer__effectEids) > count
    destroyEntity(particle_border_drawer__effectEids[length(particle_border_drawer__effectEids) - 1])
    particle_border_drawer__effectEids |> pop()


[es(tag=gameClient, on_appear)]
def particle_circle_border_drawer_appear(evt : Event;
                                         eid : EntityId;
                                         particle_border_drawer__effectName : string;
                                         particle_border_drawer__effectColorMult : E3DCOLOR;
                                         particle_border_drawer__segmentsCount : int;
                                         var particle_border_drawer__effectEids : EidList)
  update_circle_border_drawer_effects_count(eid,
                                            particle_border_drawer__segmentsCount,
                                            particle_border_drawer__effectName,
                                            particle_border_drawer__effectColorMult,
                                            particle_border_drawer__effectEids)


[es(tag=gameClient, on_disappear)]
def particle_circle_border_drawer_disappear(evt : Event;
                                            var particle_border_drawer__effectEids : EidList)
  for effectEid in particle_border_drawer__effectEids
    destroyEntity(effectEid)
  particle_border_drawer__effectEids |> clear()


[es(tag=gameClient, track=(transform, particle_circle_border_drawer__radius),
  REQUIRE=(transform, particle_circle_border_drawer__radius))]
def particle_circle_border_drawer_track(evt : Event;
                                        var particle_border_drawer__dirty : bool&)
  particle_border_drawer__dirty = true


[es(tag=gameClient, track=(particle_border_drawer__dirty))]
def particle_circle_border_drawer_dirty(evt : Event;
                                        transform : float3x4;
                                        particle_circle_border_drawer__radius : float;
                                        var particle_border_drawer__dirty : bool&;
                                        var particle_border_drawer__effectEids : EidList)
  if !particle_border_drawer__dirty
    return
  update_circle_border_drawer_effects_transform(transform,
                                                particle_circle_border_drawer__radius,
                                                particle_border_drawer__effectEids)
  particle_border_drawer__dirty = false