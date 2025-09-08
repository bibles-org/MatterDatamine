require ecs
require ecs.soa_template
require game.es.ecs_common
require game.utils.team
require game.events.events_active_matter
require danetlibs.dm.dm_events
require DngDm
require CollisionTraces
require GridCollision


[soa_template]
struct InvisibleManTargetData
  personal_enemies__candidates__eid : EntityId
  personal_enemies__candidates__damageDealt : float


[soa_def]
def find_index_in_personal_enemies_candidates(personal_enemies__candidates : InvisibleManTargetData_SOA;
                                              target_eid : EntityId)
  for idx, id in range(length(personal_enemies__candidates)), personal_enemies__candidates
    if id.personal_enemies__candidates__eid == target_eid
      return idx
  return -1


def is_same_kind(first_eid : EntityId;
                 second_eid : EntityId)
  var result = false
  query(first_eid) <| $ [es] (agent_dangers__tag aka first_agent_dangers__tag : das_string const?)
    query(second_eid) <| $ [es] (agent_dangers__tag aka second_agent_dangers__tag : das_string const?)
      if first_agent_dangers__tag != null && second_agent_dangers__tag != null
        result = (*first_agent_dangers__tag == *second_agent_dangers__tag)

  return result


[soa_def]
def process_friendly_team_personal_enemy_damage(actor_eid : EntityId;
                                                target_eid : EntityId;
                                                damage : float;
                                                damage_type : int;
                                                damage_pos : float3;
                                                damage_dir : float3;
                                                personal_enemies__damageToMakeEnemy : float;
                                                personal_enemies__damageToMakeEnemySameKind : float;
                                                var personal_enemies__enemies : EidList;
                                                var personal_enemies__candidates : InvisibleManTargetData_SOA)
  if is_personal_enemy(personal_enemies__enemies, target_eid)
    // Already an enemy
    return

  let isSameKind = is_same_kind(actor_eid, target_eid)
  if (isSameKind && damage_type == int(DamageType.DM_MELEE) &&
      !is_personal_enemy(target_eid, actor_eid) && is_actor_teams_friendly(actor_eid, target_eid))
    if was_targeting_enemies(damage_pos, damage_dir, target_eid)
      // We don't hold a grudge against our relatives who accidentally hit us in melee combat
      return

  var candidateIdx = personal_enemies__candidates |> find_index_in_personal_enemies_candidates(target_eid)
  if candidateIdx < 0
    candidateIdx = length(personal_enemies__candidates)
    personal_enemies__candidates |> push() <| InvisibleManTargetData(
        personal_enemies__candidates__eid = target_eid,
        personal_enemies__candidates__damageDealt = damage
      )
  else
    personal_enemies__candidates[candidateIdx].personal_enemies__candidates__damageDealt += damage

  let damageToMakeEnemy = isSameKind ? personal_enemies__damageToMakeEnemySameKind : personal_enemies__damageToMakeEnemy

  if damageToMakeEnemy >= 0.0
    if personal_enemies__candidates[candidateIdx].personal_enemies__candidates__damageDealt >= damageToMakeEnemy
      personal_enemies__enemies |> push(target_eid)
      personal_enemies__candidates |> erase(candidateIdx)


def was_targeting_enemies(pos, dir : float3; offender_eid : EntityId)
  var res = false
  query(offender_eid) <| $ [es] (team : int)
    using() <| $(var intersections : IntersectedEntities)
      let from = pos - dir
      let len = 2.0
      var t1 = len; var t2 = len; var t3 = len
      //draw_debug_arrow_buffered(from, from + dir * len, ACWHITE, 500)

      trace_entities_in_grid(ecs_hash("humans"), from, dir, t1, INVALID_ENTITY_ID, intersections, SortIntersections.NO)
      if has_enemies(intersections, team)
        res = true
        return
      clear(intersections)

      trace_entities_in_grid(ecs_hash("creatures"), from, dir, t2, INVALID_ENTITY_ID, intersections, SortIntersections.NO)
      if has_enemies(intersections, team)
        res = true
        return
      clear(intersections)

      trace_entities_in_grid(ecs_hash("vehicles"), from, dir, t3, INVALID_ENTITY_ID, intersections, SortIntersections.NO)
      if length(intersections) > 0
        res = true
        return
  return res


def has_enemies(intersections, offender_team)
  var res = false
  for it in intersections
    query(it.eid) <| $ [es] (team : int)
      if !is_teams_friendly(team, offender_team)
        res = true
    if res
      return res
  return res


[soa_es, es(tag=server)]
def human_ai_add_personal_enemy_on_take_damage(evt : CmdApplyDamage;
                                               eid aka human_eid : EntityId;
                                               team aka human_team : int;
                                               personal_enemies__damageToMakeEnemy : float;
                                               personal_enemies__damageToMakeEnemySameKind : float;
                                               var personal_enemies__enemies : EidList;
                                               var personal_enemies__candidates : InvisibleManTargetData_SOA)
  query(evt.offender) <| $ [es(REQUIRE=ai_target)] (team aka target_team : int)
    if is_teams_friendly(human_team, target_team)
      process_friendly_team_personal_enemy_damage(human_eid, evt.offender, evt.deltaHp, evt.damageType, evt.hitPos, evt.hitDir,
                                                  personal_enemies__damageToMakeEnemy, personal_enemies__damageToMakeEnemySameKind,
                                                  personal_enemies__enemies, personal_enemies__candidates)