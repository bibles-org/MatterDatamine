require ecs
require ecs.safe
require ecs.common
require net
require app
require level
require game.events.events
require math
require math.base
require math.random
require DagorMath
require RendInst
require game.events.events_game
require GridCollision
require Grid
require DngDm
require danetlibs.swarm.main.swarm_events
require game.es.bees_swarm_common
require game.es.level_common
require game.es.damage_systems.damage_model_common
require game.events.events_active_matter
require game.utils.net_utils
require game.es.pain_common


[es(tag=server, on_event=(EventSomeSwarmBoidBorn, EventSomeSwarmBoidDied))]
def flying_swarm_change_dmg_value(evt : Event;
                                  swarm_cluster__serverCount : int;
                                  swarm_cluster__maxCount : int;
                                  swarm_cluster__maxDamage : float;
                                  var swarm_cluster__damage : float&)
  swarm_cluster__damage = swarm_cluster__maxDamage * float(swarm_cluster__serverCount) / float(swarm_cluster__maxCount)


[es(tag=render, track=aggressive_swarm__aggressionLevel, after=swarm_cluster_decrease_aggression_level_by_time)]
def bees_swarm_change_color_by_aggression(evt : Event;
                                          aggressive_swarm__aggressionLevel : float;
                                          aggressive_swarm__changeColorParams : Array;
                                          var swarm__metatex_material_params : Array&)
  for item in aggressive_swarm__changeColorParams
    let itemObj = item |> get_ecs_object()
    if itemObj != null
      let metateMetarialIdx = (*itemObj).metatexMaterialIdx ?? -1
      if metateMetarialIdx < 0 || metateMetarialIdx > length(swarm__metatex_material_params)
        continue
      var bodyObj = swarm__metatex_material_params[metateMetarialIdx] |> getRW_ecs_object()
      if bodyObj == null
        continue
      let floatValuesRngsObject = (*itemObj).metatexMaterialFloatRngs ?as Object
      if floatValuesRngsObject != null
        for floatRng in *floatValuesRngsObject
          var floatRngObj = *bodyObj |> getRW_float(floatRng.key)
          let floatRngValue = floatRng.value |> get_Point2()
          if floatRngObj != null && floatRngValue != null
            *floatRngObj = lerp((*floatRngValue).x, (*floatRngValue).y, aggressive_swarm__aggressionLevel)
      let float4ValuesRngsObject = (*itemObj).metatexMaterialFloat4Rngs ?as Object
      if float4ValuesRngsObject != null
        for float4Rng in *float4ValuesRngsObject
          var float4RngObj = *bodyObj |> getRW_Point4(float4Rng.key)
          let float4RngValueObj = float4Rng.value as Object
          if float4RngValueObj == null
            continue
          let passiveValue = (*float4RngValueObj).passive ?as float4
          let aggressiveValue = (*float4RngValueObj).aggressive ?as float4
          if passiveValue != null && aggressiveValue != null
            *float4RngObj = lerp(*passiveValue, *aggressiveValue, float4(aggressive_swarm__aggressionLevel))


[es(tag=server, on_appear, REQUIRE=game_effect__poisonAffect, track=game_effect__destroyAt)]
def show_poison_effect(evt : Event; game_effect__timeToDestroy : float; game_effect__destroyAt : float; game_effect__attachedTo : EntityId)
  send_net_event(game_effect__attachedTo, CmdShowPoisonEffect(begin = game_effect__destroyAt - game_effect__timeToDestroy, end = game_effect__destroyAt), possessed_and_spectated(game_effect__attachedTo))


[es(tag=server, no_order)]
def bees_swarm_guards_attack_humans_in_area(act : UpdateStageInfoAct;
                                            eid : EntityId;
                                            transform : float3x4;
                                            swarm_cluster__damage : float;
                                            swarm_cluster__attackRadius : float;
                                            var swarm_cluster__damageAt : float&;
                                            swarm_cluster__poisonAttack = false;
                                            swarm_cluster__attackProbability = 1.0;
                                            swarm_cluster__attackAddTrauma = .0;
                                            swarm_cluster__attakMaxTrauma = .0;
                                            swarm_cluster__damagePeriod = float2(1, 1);
                                            swarm__hitTargets : Array const?;
                                            swarm__damageZoneType = int(DamageZoneType.SPHERE))
  if swarm_cluster__damageAt > act.curTime
    return

  swarm_cluster__damageAt = act.curTime
  var maxAntistreak = 2.0 / swarm_cluster__attackProbability + 1.0
  while maxAntistreak-- > 0.0
    swarm_cluster__damageAt += rnd_float(swarm_cluster__damagePeriod)
    if swarm_cluster__attackProbability < gfrnd()
      break

  let swarmClusterPos = transform[3]
  var targets : array<EntityId>
  let radiusSq = square(swarm_cluster__attackRadius)
  let searchBoxSize = float3(swarm_cluster__attackRadius, swarm_cluster__attackRadius * 2.0, swarm_cluster__attackRadius)
  let searchBox = BBox3(swarmClusterPos - searchBoxSize, swarmClusterPos + searchBoxSize)
  for_each_entity_in_grid(ecs_hash("humans"), searchBox, GridEntCheck.POS) <| $(itEid : EntityId)
    query(itEid) <| $ [es(REQUIRE=human, REQUIRE_NOT=deadEntity)] (eid : EntityId; transform : float3x4)
      var delta = transform[3] - swarmClusterPos
      if swarm__damageZoneType == int(DamageZoneType.CYLINDER)
        delta.y = 0.0
      if length_sq(delta) > radiusSq
        return
      if !level_common::is_pos_indoor(transform[3], 5.0)
        if swarm__hitTargets != null
          var isTargetVisible = false
          for target in *swarm__hitTargets
            let targetObj = target as Object
            let targetEid = targetObj?.eid ?? INVALID_ENTITY_ID
            if targetEid == itEid
              isTargetVisible = targetObj?.visible ?? false
              break
          if !isTargetVisible
            return
        targets |> push(eid)

  if length(targets) > 0
    for target in targets
      if swarm_cluster__poisonAttack
        let isAffected = find_query() <| $ [es(REQUIRE=game_effect__poisonAffect)] (game_effect__attachedTo : EntityId;
                                                                                    game_effect__timeToDestroy : float;
                                                                                    var game_effect__destroyAt : float&)
          if game_effect__attachedTo == target
            game_effect__destroyAt = get_sync_time() + game_effect__timeToDestroy
            return true
          return false
        if !isAffected
          var affect_template = "poison_affect"
          if !has_pain_immunity(target)
            affect_template = add_sub_template_name(affect_template, "poison_visual_affect")
          createEntity(affect_template) <| $(var initList)
            initList |> set("game_effect__ownerEid", eid)
            initList |> set("game_effect__attachedTo", target)
            initList |> set("game_effect__damageTargetDeltaHp", swarm_cluster__damage)
            initList |> set("game_effect__damageType", int(DamageType.DM_GAS))
        send_net_event(target, EventBeesLeftStain(value = 0.1), possessed_and_spectated(target))
      else
        query(target) <| $ [es] (human_damage_model__parts : Object)
          let randomIdx = rnd_int(0, length(human_damage_model__parts) - 1)
          var i = 0
          for_each_part_in_damage_model(human_damage_model__parts) <| $(bodypart : BodyPartV2)
            if i++ != randomIdx
              return true
            if length(bodypart.nodeIds) > 0
              human_damage_model_damage_entity(target, eid, swarm_cluster__damage, bodypart.nodeIds[0], DamageType.DM_MELEE)
            return false

        if swarm_cluster__attackAddTrauma > 0.0 && !has_pain_immunity(target)
          send_net_event(target, CmdCauseTrauma(addTrauma = swarm_cluster__attackAddTrauma, maxTrauma = swarm_cluster__attakMaxTrauma),
              possessed_and_spectated(target))


[es(on_appear, REQUIRE=painkillerEffect)]
def stop_visual_poison_by_painkiller(evt : Event;
                                     game_effect__attachedTo aka painkiller__game_effect__attachedTo : EntityId)
  find_query() <| $ [es(REQUIRE=game_effect__poisonAffect)] (game_effect__attachedTo aka poison__game_effect__attachedTo : EntityId;
                                                             eid : EntityId)
    if painkiller__game_effect__attachedTo == poison__game_effect__attachedTo
      removeSubTemplate(eid, "poison_visual_affect")
      return true
    return false


[es(on_disappear, REQUIRE=painkillerEffect)]
def add_visual_poison_on_painkiller_end(evt : Event;
                                        game_effect__attachedTo aka painkiller__game_effect__attachedTo : EntityId)
  find_query() <| $ [es(REQUIRE=game_effect__poisonAffect)] (game_effect__attachedTo aka poison__game_effect__attachedTo : EntityId;
                                                             eid : EntityId)
    if painkiller__game_effect__attachedTo == poison__game_effect__attachedTo
      addSubTemplate(eid, "poison_visual_affect")
      return true
    return false


[es(tag=gameClient, on_appear)]
def init_min_compensation_speed_for_swarm(evt : Event;
                                          swarm_cluster__maxSpeed : float;
                                          loc_snapshots__compensationSpeedMult = float2(0.4, 1.4);             //min, max
                                          var loc_snapshots__compensationSpeed : float2&)
  loc_snapshots__compensationSpeed = loc_snapshots__compensationSpeedMult * swarm_cluster__maxSpeed