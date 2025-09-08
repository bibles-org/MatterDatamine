require ecs
require ecs.safe
require app
require Grid
require DagorMath
require game.events.events_active_matter


[es(tag=server, on_disappear)]
def recreate_on_disappear(evt : Event;
                          eid : EntityId;
                          transform : float3x4;
                          recreate_on_disappear__delay : float;
                          if_there_no_heroes_nearby__distance : float const?)
  let templateName = getEntityTemplateName(eid)
  if templateName != ""
    if recreate_on_disappear__delay > 0.0
      var timerTemplateName = "recreate_on_disappear_timer"
      if if_there_no_heroes_nearby__distance != null
        timerTemplateName = "{timerTemplateName}+if_there_no_heroes_nearby"
      createEntity(timerTemplateName) <| $(var init : ComponentsInitializer)
        init |> set("transform", transform)
        init |> set("recreate_on_disappear_timer__template", templateName)
        init |> set("recreate_on_disappear_timer__createAt", get_sync_time() + recreate_on_disappear__delay)
        init |> set("recreate_on_disappear_timer__delay", recreate_on_disappear__delay)

        if if_there_no_heroes_nearby__distance != null
          init |> set("if_there_no_heroes_nearby__distance", *if_there_no_heroes_nearby__distance)
    else
      createEntity(templateName) <| $(var init : ComponentsInitializer)
        init |> set("recreate_on_disappear__delay", recreate_on_disappear__delay)


[es(tag=server, no_order)]
def recreate_on_disappear_timer(act : ParallelUpdateFrameDelayed;
                                eid : EntityId;
                                transform : float3x4;
                                recreate_on_disappear_timer__template : string;
                                recreate_on_disappear_timer__delay : float;
                                if_there_no_heroes_nearby__distance : float const?;
                                var recreate_on_disappear_timer__createAt : float&)
  if act.curTime >= recreate_on_disappear_timer__createAt

    if if_there_no_heroes_nearby__distance != null
      let sphere = BSphere3(transform[3], *if_there_no_heroes_nearby__distance)
      let heroEid = find_entity_in_grid(ecs_hash("humans"),
                                        sphere,
                                        GridEntCheck.POS) <| $(human_eid : EntityId)
        var res = false
        query(human_eid) <| $ [es(REQUIRE=heroForPlayer)] ()
          res = true
        return res

      if heroEid != INVALID_ENTITY_ID
        recreate_on_disappear_timer__createAt = act.curTime + recreate_on_disappear_timer__delay
        return

    createEntity(recreate_on_disappear_timer__template) <| $(var init : ComponentsInitializer)
      init |> set("transform", transform)
      init |> set("recreate_on_disappear__delay", recreate_on_disappear_timer__delay)
    destroyEntity(eid)