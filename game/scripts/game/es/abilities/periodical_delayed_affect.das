require ecs
require app
require Grid
require game.events.events_active_matter
require math.base
require DagorMath
require game.utils.team


[es(tag=server, on_appear)]
def delayed_affect_appear(evt : Event; game_effect__applyDelay : float; var game_effect__applyUpdateAt : float&)
  game_effect__applyUpdateAt = get_sync_time() + game_effect__applyDelay


[es(tag=gameClient, on_appear)]
def delayed_affect_appear_client(evt : Event; game_effect__clientApplyDelay : float; var game_effect__clientApplyUpdateAt : float&)
  game_effect__clientApplyUpdateAt = get_sync_time() + game_effect__clientApplyDelay


[es(tag=server, on_appear, REQUIRE_NOT=(game_effect__applyUpdateAt, game_effect__clientApplyUpdateAt, game_effect__customAffectUpdate))]
def periodical_affect_appear(evt : Event; eid, game_effect__attachedTo : EntityId)
  sendEvent(eid, ApplyGameAffect(targetEid = game_effect__attachedTo))


[es(tag=server, after=delayed_affect_appear, REQUIRE_NOT=game_effect__customAffectUpdate)]
def periodical_affect_update(act : UpdateStageInfoAct;
                             eid, game_effect__attachedTo : EntityId;
                             game_effect__applyUpdateInterval : float = 0.0;
                             var game_effect__applyUpdateAt : float&)
  if act.curTime < game_effect__applyUpdateAt
    return
  game_effect__applyUpdateAt = act.curTime + game_effect__applyUpdateInterval
  if game_effect__applyUpdateInterval <= 0f
    game_effect__applyUpdateAt = FLT_MAX

  sendEvent(eid, ApplyGameAffect(targetEid = game_effect__attachedTo))


[es(tag=gameClient, after=delayed_affect_appear_client, REQUIRE_NOT=game_effect__customAffectUpdate)]
def periodical_affect_update_client(act : UpdateStageInfoAct;
                                    eid, game_effect__attachedTo : EntityId;
                                    game_effect__clientApplyUpdateInterval : float = 0.0;
                                    var game_effect__clientApplyUpdateAt : float&)
  if act.curTime < game_effect__clientApplyUpdateAt
    return

  game_effect__clientApplyUpdateAt = act.curTime + game_effect__clientApplyUpdateInterval
  if game_effect__clientApplyUpdateInterval <= 0f
    game_effect__clientApplyUpdateAt = FLT_MAX

  sendEvent(eid, ApplyGameAffect(targetEid = game_effect__attachedTo))


// distance check

def apply_affect_for_nearest(pos : float3; eid : EntityId; sphere_zone__radius : float; owner_eid : EntityId const?)
  var offenderTeam = TEAM_UNASSIGNED
  var personalEnemies : EidList const?
  query(owner_eid ?? eid) <| $ [es] (team : int;
                                     personal_enemies__enemies : EidList const?)
    offenderTeam = team
    personalEnemies = personal_enemies__enemies
  let sphere = BSphere3(pos, sphere_zone__radius)
  for_each_entity_in_grid(fixed_array(ecs_hash("humans"), ecs_hash("interactable")), sphere, GridEntCheck.BOUNDING) <| $(item_eid : EntityId)
    query(item_eid) <| $ [es] (team : int)
      if team != offenderTeam || is_personal_enemy(personalEnemies, item_eid)  // is_teams_friendly doesn't works here, because offender can be with unassigned team
        sendEvent(eid, ApplyGameAffect(targetEid = item_eid))


[es(tag=server, on_appear, after=affects_follow_owner, REQUIRE_NOT=game_effect__applyUpdateAt,
    REQUIRE=(game_effect__distanceLimit, game_effect__customAffectUpdate))]
def periodical_affect_with_distance_appear(evt : Event; eid : EntityId;
                                           transform : float3x4;
                                           game_effect__ownerEid : EntityId const?;
                                           sphere_zone__radius : float)
  apply_affect_for_nearest(transform[3], eid, sphere_zone__radius, game_effect__ownerEid)


[es(tag=server, after=delayed_affect_appear, REQUIRE=(game_effect__distanceLimit, game_effect__customAffectUpdate))]
def periodical_affect_with_radius_update(act : UpdateStageInfoAct; eid : EntityId;
                                         transform : float3x4;
                                         game_effect__applyUpdateInterval : float = 0.0;
                                         sphere_zone__radius : float;
                                         game_effect__ownerEid : EntityId const?;
                                         var game_effect__applyUpdateAt : float&)
  if act.curTime < game_effect__applyUpdateAt
    return
  game_effect__applyUpdateAt = act.curTime + game_effect__applyUpdateInterval
  if game_effect__applyUpdateInterval <= 0f
    game_effect__applyUpdateAt = FLT_MAX

  apply_affect_for_nearest(transform[3], eid, sphere_zone__radius, game_effect__ownerEid)
