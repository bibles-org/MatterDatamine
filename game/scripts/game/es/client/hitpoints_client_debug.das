options no_aot
require ecs
require ecs.safe
require ecs.ecs_template
require math.base
require strings
require game.es.entity_mods_common
require RendInst
require DagorConsole
require DagorDebug3D
require DagorSystem
require Ballistics
require BallisticsProps
require AnimV20
require GeomNodeTree
require CapsuleApproximation
require CollRes
require DngDm
require daslib/enum_trait
require danetlibs.dm.dm_events
require game.es.hitpoints_damage_common
require game.events.events


def get_damage_type_name(index : int)
  if index < 0 || index >= typeinfo enum_length(type<DamageType>)
    return ""
  return typeinfo enum_names(type<DamageType>)[index]


def get_hp_color(hp : float;
                 max_hp : float)
  if max_hp <= 0.0
    return E3DCOLOR(0xFFFFFFFF)
  let hpProgress = hp / max_hp
  if hpProgress >= 0.66
    return E3DCOLOR(0xFF00FF00)
  elif hpProgress >= 0.33
    return E3DCOLOR(0xFFFBFF00)
  else
    return E3DCOLOR(0xFFFD0000)


[ecs_template]
struct hitpoints_debug_draw
  hitpoints__debugDrawDist : float = 0.0
  hitpoints__debugDrawDistSq : float = 0.0


[console_cmd(name="hitpoints.debug_hp")]
def hitpoints_debug_draw_cmd(dist = 50.0)
  let tmpl = "hitpoints_debug_draw"
  let distSq = square(dist)

  let exists = find_query() <| $ [es] (eid : EntityId;
                                       var hitpoints__debugDrawDist : float&;
                                       var hitpoints__debugDrawDistSq : float&)
    if hitpoints__debugDrawDist == dist
      destroyEntity(eid)
    else
      hitpoints__debugDrawDist = dist
      hitpoints__debugDrawDistSq = distSq
    return true

  if !exists
    createEntity(tmpl) <| $(init)
      init |> set("hitpoints__debugDrawDist", dist)
      init |> set("hitpoints__debugDrawDistSq", distSq)


[es(tag=(render, dev), no_order)]
def debug_draw_hitpoints_hp_es(evt : UpdateStageInfoRenderDebug;
                               hitpoints__debugDrawDistSq : float)

  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false
    query() <| $ [es] (transform aka hitpoints_transform : float3x4;
                       hitpoints__hp : float;
                       hitpoints__maxHp : float)
      let distSq = distance_sq(camera_transform[3], hitpoints_transform[3])
      if distSq > hitpoints__debugDrawDistSq
        return

      let markPos = hitpoints_transform[3] + float3(0.0, 1.0, 0.0)
      let hp = hitpoints__hp
      let maxHp = hitpoints__maxHp
      add_debug_text_mark(markPos, "hp:{fmt(":.2f", hp)}/{fmt(":.2f", maxHp)}", -1, 0.0, get_hp_color(hp, maxHp))

    query() <| $ [es] (human_damage_model__parts : Object;
                       transform aka hitpoints_transform : float3x4;
                       collres : CollisionResource;
                       animchar : AnimcharBaseComponent)
      let distSq = distance_sq(camera_transform[3], hitpoints_transform[3])
      if distSq > hitpoints__debugDrawDistSq
        return

      for partComp in human_damage_model__parts
        let part = partComp.value as Object
        let nodeIdsComp = part?.nodeIds
        if nodeIdsComp == null
          continue
        let nodeIds = (*nodeIdsComp) |> get_ecs_IntList()
        if nodeIds == null
          continue
        if length(*nodeIds) == 0
          continue

        var nodePosition : float3
        var nodesCount = 0
        for nodeIdx in *nodeIds
          if nodeIdx < 0
            continue

          var ntm : float3x4
          collres_get_collision_node_tm(collres, nodeIdx, hitpoints_transform, animchar.nodeTree, ntm)
          nodePosition += ntm[3]
          nodesCount++
        if nodesCount > 0
          nodePosition /= float(nodesCount)
        else
          nodePosition = hitpoints_transform[3]

        let hp = part?.hp ?? 0.0
        let maxHp = part?.maxHp ?? 0.0

        var i = 0
        add_debug_text_mark(nodePosition, "{partComp.key} {fmt(":.2f", hp)}/{fmt(":.2f", maxHp)}", -1, float(i++), get_hp_color(hp, maxHp))

        // Protection
        let protection = part.protection ?as FloatList
        if protection != null
          for dmType in iter_range(*protection)
            let protectionValue = (*protection)[dmType]
            if protectionValue == 0.0
              continue
            add_debug_text_mark(nodePosition, "{get_damage_type_name(dmType)} {fmt(":.1f", protectionValue * 100.0)}%", -1, float(i++), E3DCOLOR(0xAAAAAAAA))

    query() <| $ [es] (transform aka hitpoints_transform : float3x4;
                       cellular_hitpoints__damagedCells, cellular_hitpoints__maxCells : int;
                       cellular_hitpoints__currentCellHp, cellular_hitpoints__maxCellHp : float)
      let distSq = distance_sq(camera_transform[3], hitpoints_transform[3])
      if distSq > hitpoints__debugDrawDistSq
        return

      let markPos = hitpoints_transform[3] + float3(0.0, 1.0, 0.0)
      let hp = cellular_hitpoints__currentCellHp
      let maxHp = cellular_hitpoints__maxCellHp
      let cellsLeft = cellular_hitpoints__maxCells - cellular_hitpoints__damagedCells
      let cells = cellular_hitpoints__maxCells
      add_debug_text_mark(markPos, "cell hp:{fmt(":.2f", hp)}/{fmt(":.2f", maxHp)} cells:{cellsLeft}/{cells}", -1, 0.0, E3DCOLOR(0xFFFFFFFF))

    return true


[ecs_template]
struct ri_hitpoints_debug_draw
  ri_hitpoints__debugDrawDist : float = 0.0


[console_cmd(name="rendinst.debug_hp")]
def ri_hitpoints_debug_draw_cmd(dist = 5.0)
  let tmpl = "ri_hitpoints_debug_draw"

  let exists = find_query() <| $ [es] (eid : EntityId;
                                       var ri_hitpoints__debugDrawDist : float&)
    if ri_hitpoints__debugDrawDist == dist
      destroyEntity(eid)
    else
      ri_hitpoints__debugDrawDist = dist
    return true

  if !exists
    createEntity(tmpl) <| $(init)
      init |> set("ri_hitpoints__debugDrawDist", dist)


[es(tag=(render, dev), no_order)]
def debug_draw_ri_hitpoints_hp_es(evt : UpdateStageInfoRenderDebug;
                                  ri_hitpoints__debugDrawDist : float)

  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false
    let box = BBox3(transform[3] - float3(ri_hitpoints__debugDrawDist), transform[3] + float3(ri_hitpoints__debugDrawDist))
    let oldNumCallbacks = setMaxNumRiCollisionCb(500000u)
    rendinst_foreachInBox(box, int(GatherRiTypeFlags.RiExtraOnly)) <| $ [unused_argument(is_tm)] (desc : RendInstDesc; tm : float3x4; is_tm : bool)
      if !riex_isRiGenExtraValid(desc.riExtraHandle)
        return

      let initialHp = riex_getInitialHP(desc.riExtraHandle)
      if initialHp < 0.0
        return

      let hp = riex_get_hp(desc.riExtraHandle)
      add_debug_text_mark(tm[3], "hp:{fmt(":.2f", hp)}/{fmt(":.2f", initialHp)}", -1, 0.0, get_hp_color(hp, initialHp))
    setMaxNumRiCollisionCb(oldNumCallbacks)
    return true


[ecs_template]
struct hitpoints_debug_damage_draw
  hitpoints__debugDamageDrawDist : float = 0.0
  hitpoints__debugDamageDrawDistSq : float = 0.0


[ecs_template]
struct hitpoints_debug_damage
  hitpoints__debugDamageSum : float
  hitpoints__debugDamageTimer : float
  hitpoints__debugDamagePerSecond : float
  hitpoints__debugDamageEventsCount : int


[console_cmd(name="hitpoints.debug_damage")]
def hitpoints_debug_damage_draw_cmd(dist = 50.0)
  let tmpl = "hitpoints_debug_damage_draw"
  let distSq = square(dist)

  let exists = find_query() <| $ [es] (eid : EntityId;
                                       var hitpoints__debugDamageDrawDist : float&;
                                       var hitpoints__debugDamageDrawDistSq : float&)
    if hitpoints__debugDamageDrawDist == dist
      destroyEntity(eid)
    else
      hitpoints__debugDamageDrawDist = dist
      hitpoints__debugDamageDrawDistSq = distSq
    return true

  if !exists
    createEntity(tmpl) <| $(init)
      init |> set("hitpoints__debugDamageDrawDist", dist)
      init |> set("hitpoints__debugDamageDrawDistSq", distSq)


[es(tag=(render, dev), no_order)]
def debug_check_hitpoints_damage_es(evt : UpdateStageInfoAct;
                                    hitpoints__debugDamageDrawDistSq : float)

  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false
    query() <| $ [es(REQUIRE=hitpoints__hp)] (eid aka actor_eid : EntityId;
                                              transform aka hitpoints_transform : float3x4;
                                              hitpoints__debugDamageSum : float const?)
      let distSq = distance_sq(camera_transform[3], hitpoints_transform[3])
      let isDpsDebug = (hitpoints__debugDamageSum != null)
      let inDistRange = (distSq <= hitpoints__debugDamageDrawDistSq)

      if inDistRange && !isDpsDebug
        addSubTemplate(actor_eid, "hitpoints_debug_damage")
      elif !inDistRange && isDpsDebug
        removeSubTemplate(actor_eid, "hitpoints_debug_damage")

    query() <| $ [es(REQUIRE=human_damage_model__parts)] (eid aka actor_eid : EntityId;
                                                          transform aka hitpoints_transform : float3x4;
                                                          hitpoints__debugDamageSum : float const?)
      let distSq = distance_sq(camera_transform[3], hitpoints_transform[3])
      let isDpsDebug = (hitpoints__debugDamageSum != null)
      let inDistRange = (distSq <= hitpoints__debugDamageDrawDistSq)

      if inDistRange && !isDpsDebug
        addSubTemplate(actor_eid, "hitpoints_debug_damage")
      elif !inDistRange && isDpsDebug
        removeSubTemplate(actor_eid, "hitpoints_debug_damage")

    return true


[es(tag=(render, dev), no_order, REQUIRE_NOT=deadEntity)]
def debug_draw_hitpoints_damage_es(evt : UpdateStageInfoRenderDebug;
                                   hitpoints__debugDamagePerSecond : float;
                                   hitpoints__debugDamageSum : float;
                                   hitpoints__debugDamageEventsCount : int;
                                   transform aka hitpoints_transform : float3x4)
  let markPos = hitpoints_transform[3] + float3(0.0, 1.75, 0.0)

  var i = 0
  add_debug_text_mark(markPos, "DPS: {hitpoints__debugDamagePerSecond}", -1, float(i--), E3DCOLOR(0xFFFFFFFF))
  add_debug_text_mark(markPos, "Damage: {hitpoints__debugDamageSum}", -1, float(i--), E3DCOLOR(0xFFFFFFFF))
  add_debug_text_mark(markPos, "Events: {hitpoints__debugDamageEventsCount}", -1, float(i--), E3DCOLOR(0xFFFFFFFF))


[es(tag=dev, no_order)]
def debug_hitpoints_daamge_es(act : UpdateStageInfoAct;
                              var hitpoints__debugDamageSum : float&;
                              var hitpoints__debugDamageTimer : float&;
                              var hitpoints__debugDamagePerSecond : float&;
                              var hitpoints__debugDamageEventsCount : int&)
  if hitpoints__debugDamageEventsCount > 0
    hitpoints__debugDamageTimer += act.dt
    if hitpoints__debugDamageTimer >= 2.0
      hitpoints__debugDamagePerSecond = hitpoints__debugDamageSum / hitpoints__debugDamageTimer
      hitpoints__debugDamageTimer = 0.0
      hitpoints__debugDamageSum = 0.0
      hitpoints__debugDamageEventsCount = 0


def print_damage(text : string)
  console_print(text)
  visual_log(text)


[es(tag=dev, REQUIRE=hitpoints__debugDamageSum)]
def debug_hitpoints_damage_on_projectile_hit(evt : EventOnProjectileHit)
  query(evt.projectileEid) <| $ [es] (projectile_ballistics : ProjectileBallistics;
                                      projectile_ballistics_props : ProjectileProps)
    let speedSq = length_sq(projectile_ballistics.state.vel)
    let energy = projectile_ballistics_props.mass * speedSq * 0.5

    print_damage("Energy: {energy}, Speed: {sqrt(speedSq)}, Mass: {projectile_ballistics_props.mass}")


[es(tag=dev)]
def debug_hitpoints_damage_on_apply_damage(evt : CmdApplyDamage;
                                           human_damage_model__dmgMult : float = 1.0;
                                           hitpoints__dmgMult : float = 1.;
                                           collres : CollisionResource;
                                           var hitpoints__debugDamageSum : float&;
                                           var hitpoints__debugDamageEventsCount : int&;
                                           entity_mod_values : Object const?)

  let mult = min(hitpoints__dmgMult, human_damage_model__dmgMult)
  let deltaHp = calculate_modified_damage_delta(evt, mult, entity_mod_values)

  let node = collres_get_node(collres, evt.collNodeId)
  let collNodeName = node != null ? node |> collnode_get_name() : "N/A"

  print_damage("dmg={deltaHp} collNodeName={collNodeName} evt.deltaHp={evt.deltaHp} damageType={DamageType(evt.damageType)}")

  hitpoints__debugDamageSum += deltaHp
  hitpoints__debugDamageEventsCount++