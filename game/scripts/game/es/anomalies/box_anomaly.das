require app
require ecs
require ecs.common
require math.base
require strings
require Grid
require DagorMath
require DagorSystem
require DngHuman
require game.events.events
require game.events.events_active_matter


[es(tag=server, on_appear)]
def box_anomaly_appear(evt : Event; eid : EntityId; box_anomaly__nextUpdateInterval : float;
                       var box_anomaly__nextUpdateAt : float&)
  box_anomaly__nextUpdateAt = get_sync_time() + box_anomaly__nextUpdateInterval * eid_frnd(eid)


[es(tag=server, no_order)]
def box_anomaly_update(act : ParallelUpdateFrameDelayed;
                       box_anomaly__affectTemplate : string;
                       box_anomaly__nextUpdateInterval : float;
                       eid aka anomaly_eid : EntityId;
                       transform : float3x4;
                       box_anomaly__targetsTag : string;
                       box_anomaly__globalAffectDestroyTemplates : StringList const?;
                       box_anomaly__globalAffectTemplates : StringList const?;
                       box_anomaly__accuracyCheck : Tag const?;
                       box_anomaly__checkBoxMin : float3 = float3(-0.5, -0.5, -0.5);
                       box_anomaly__checkBoxMax : float3 = float3(0.5, 0.5, 0.5);
                       box_anomaly__affectDestroyTemplate : das_string const?;
                       var box_anomaly__globalAffectEids : EidList?;
                       var box_anomaly__targetEids : EidList&;
                       var box_anomaly__nextUpdateAt : float&)

  if act.curTime < box_anomaly__nextUpdateAt
    return
  box_anomaly__nextUpdateAt = act.curTime + box_anomaly__nextUpdateInterval

  var effects : table< /*target*/uint; /*effect*/EntityId>
  query() <| $ [es] (eid, game_effect__attachedTo, anomaly_effect__ownerAnomalyEid : EntityId)
    if anomaly_effect__ownerAnomalyEid == anomaly_eid
      effects.insert(uint(game_effect__attachedTo), eid)

  var newTargets : table<uint>

  let targetTagHash = ecs_hash(box_anomaly__targetsTag)
  let check = box_anomaly__accuracyCheck != null ? GridEntCheck.BOUNDING : GridEntCheck.POS
  let checkBox = BBox3(box_anomaly__checkBoxMin, box_anomaly__checkBoxMax)
  for_each_entity_in_grid(ecs_hash("humans"), transform, checkBox, check) <| $(item_eid : EntityId)
    if has(item_eid, box_anomaly__targetsTag, targetTagHash)
      query(item_eid) <| $ [es(REQUIRE_NOT=deadEntity)] ()
        newTargets.insert(uint(item_eid))

  for target in box_anomaly__targetEids
    let targetId = uint(target)
    if !newTargets |> key_exists(targetId)
      effects |> get(targetId) <| $(effect)
        if box_anomaly__affectDestroyTemplate != null
          effect |> addSubTemplate(string(*box_anomaly__affectDestroyTemplate))
        else
          destroyEntity(effect)
      effects |> erase(targetId)
    elif !effects |> key_exists(targetId) && !empty(box_anomaly__affectTemplate)
      createEntity(box_anomaly__affectTemplate) <| $(init)
        init |> set("anomaly_effect__ownerAnomalyEid", eid)
        init |> set("game_effect__attachedTo", target)
        init |> set("game_effect__attachedAt", act.curTime)

  box_anomaly__targetEids |> clear()
  for target in keys(newTargets)
    box_anomaly__targetEids |> push(EntityId(target))

  if box_anomaly__globalAffectTemplates != null && box_anomaly__globalAffectEids != null
    if length(box_anomaly__targetEids) == 0
      if box_anomaly__globalAffectDestroyTemplates != null
        for effectEid, destroyTemplate in *box_anomaly__globalAffectEids, *box_anomaly__globalAffectDestroyTemplates
          effectEid |> addSubTemplate(string(destroyTemplate))
        for idx in range(length(*box_anomaly__globalAffectDestroyTemplates), length(*box_anomaly__globalAffectEids))
          (*box_anomaly__globalAffectEids)[idx] |> destroyEntity()
      else
        for effectEid in *box_anomaly__globalAffectEids
          effectEid |> destroyEntity()
      *box_anomaly__globalAffectEids |> clear()
    else
      *box_anomaly__globalAffectEids |> resize(length(*box_anomaly__globalAffectTemplates))
      for effectEid, templateName in *box_anomaly__globalAffectEids, *box_anomaly__globalAffectTemplates
        if effectEid == INVALID_ENTITY_ID
          effectEid = createEntity(string(templateName)) <| $(ini)
            ini |> set("transform", transform)
            ini |> set("anomaly_effect__ownerAnomalyEid", eid)
            ini |> set("game_effect__attachedAt", act.curTime)
