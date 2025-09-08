require ecs
require fx
require app
require game.events.events_active_matter
require game.events.events
require DagorMath
require DngActor
require DngPhysObj


[cpp_event(unicast)]
struct RecreateEffectEvent {}


[es(tag=render, REQUIRE=effect)]
def fx_pre_teleport(evt : EntityWillBeTeleported;
                    eid : EntityId;
                    effect__recreateAfterTeleportIn : float;
                    var effect : TheEffect)
  effect |> effect_reset()

  createEntity("recreate_entity_effect_in") <| $(var init : ComponentsInitializer)
    init |> set("recreate_entity_effect_in__eid", eid)
    init |> set("recreate_entity_effect_in__time", get_sync_time() + effect__recreateAfterTeleportIn)


[es(tag=render, no_order)]
def recreate_entity_effect_in(act : UpdateStageInfoAct;
                              eid : EntityId;
                              recreate_entity_effect_in__eid : EntityId;
                              recreate_entity_effect_in__time : float)
  if get_sync_time() >= recreate_entity_effect_in__time
    sendEventImmediate(recreate_entity_effect_in__eid, RecreateEffectEvent())
    destroyEntity(eid)