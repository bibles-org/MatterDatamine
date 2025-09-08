require ecs
require ecs.safe
require app
require player
require DagorSystem


[es(tag=gameClient, on_appear)]
def spawn_sequence_game_effect_game_client_affects_init(evt : Event;
                                                        game_effect__attachedTo : EntityId;
                                                        spawn_sequence_game_effect__gameClientAffects : Array)
  query(game_effect__attachedTo) <| $ [es] (createdByPlr : EntityId)
    let localPlayerEid = get_local_player_eid()
    let isLocalPlayerHero = createdByPlr == localPlayerEid

    for gameClientAffectData in spawn_sequence_game_effect__gameClientAffects
      let gameClientAffectObj = gameClientAffectData as Object
      let affectTemplateName = isLocalPlayerHero ? gameClientAffectObj?.fps ?? "" : gameClientAffectObj?.tps ?? ""
      let affectTime = gameClientAffectObj?.time ?? 0.0
      if affectTemplateName != "" && affectTime > 0.0
        createEntity(affectTemplateName) <| $(var init : ComponentsInitializer)
          init |> set("game_effect__attachedTo", game_effect__attachedTo)
          init |> set("game_effect__clientDestroyAt", get_sync_time() + affectTime)