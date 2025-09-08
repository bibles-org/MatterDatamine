require ecs
require app
require ecs.common
require math.random
require game.events.events_active_matter
require game.es.ecs_common
require game.es.truce_common
require game.utils.team
require level
require BehNodes


[es(tag=server, on_appear, on_event=EventLevelLoaded)]
def impostor_controller_on_appear(evt : Event;
                                  impostor_controller__initDelay : float;
                                  var impostor_controller__initAt : float&)
  if !is_level_loaded()
    return

  impostor_controller__initAt = get_sync_time() + impostor_controller__initDelay


def convert_some_guards_to_impostors(impostor_controller__guardImpostorsCount : int2;
                                     impostor_controller__guardDisclosureTime : float2)

  var guards : array<tuple<eid : EntityId; pos : float3>>
  query() <| $ [es(REQUIRE=am_area_guard, REQUIRE_NOT=deadEntity)] (eid aka guard_eid : EntityId;
                                                                    transform : float3x4)
    guards |> emplace((guard_eid, transform[3]))

  let guardsCount = length(guards)
  if guardsCount == 0
    return

  let impostorsCount = min(rnd_int(impostor_controller__guardImpostorsCount), guardsCount)

  guards |> shuffle()

  for i in range(impostorsCount)
    print("[IMPOSTOR] Convert guard <{get_entity_info(guards[i].eid)}> to impostor.")
    addSubTemplate(guards[i].eid, "bot_impostor") <| $(var init : ComponentsInitializer)
      init |> set("bot_impostor__disclosureAt", get_sync_time() + rnd_float(impostor_controller__guardDisclosureTime))


[es(tag=server, no_order)]
def impostor_controller_update(act : ParallelUpdateFrameDelayed;
                               impostor_controller__initAt : float;
                               impostor_controller__guardImpostorsCount : int2;
                               impostor_controller__guardDisclosureTime : float2;
                               var impostor_controller__inited : bool&)
  if !impostor_controller__inited
    if is_level_loaded() && act.curTime >= impostor_controller__initAt
      impostor_controller__inited = true

      let haveImpostorArtifacts = find_query() <| $ [es(REQUIRE=monster_impostor_artifact_item)] ()
        return true

      if haveImpostorArtifacts
        convert_some_guards_to_impostors(impostor_controller__guardImpostorsCount,
                                        impostor_controller__guardDisclosureTime)


[es(tag=server, no_order)]
def impostor_disclosure_by_timer(act : UpdateStageInfoAct;
                                 eid : EntityId;
                                 bot_impostor__disclosureAt : float;
                                 bot_impostor__behNode : string;
                                 var team : int&;
                                 var truce_id : int&;
                                 var beh_tree__node : das_string;
                                 var beh_tree : BehaviourTree;
                                 var beh_tree__latencyLoadRequire : bool&)
  if act.curTime >= bot_impostor__disclosureAt
    print("[IMPOSTOR] Impostor <{get_entity_info(eid)}> disclosed himself on timer.")

    removeSubTemplate(eid, "bot_impostor")

    beh_tree__node := bot_impostor__behNode
    beh_tree_reset(beh_tree)
    beh_tree__latencyLoadRequire = true

    team = create_new_bot_team(INVALID_ENTITY_ID, -1)

    truce_id = generate_truce_id()
    conclude_truce(truce_id, TRUCE_ZONE, true)

