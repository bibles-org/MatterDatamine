require ecs
require ecs.safe
require ecs.common
require game.events.events
require math.base
require level
require DagorSystem
require RendInst
require Grid


[es(tag=server, on_event=EventLevelLoaded, on_appear)]
def composit_spawn_init(evt : Event;
                        eid : EntityId;
                        transform : float3x4;
                        composit_spawn__nodes : Array;
                        var composit_holder__childrenEids : EidList?)
  if !is_level_loaded()
    return

  for node in composit_spawn__nodes
    let nodeObj = node as Object
    if nodeObj == null
      logerr("{eid}<{getEntityTemplateName(eid)}>: invalid composit node!")
      continue
    let nodeType = get_string(nodeObj, "type", "")

    if nodeType == "riExtra"
      let rendinstName = (*nodeObj).name ?? ""

      if rendinstName == ""
        logerr("{eid}<{getEntityTemplateName(eid)}>: composit node rendinst name is empty!")
        continue

      var templName = get_string(nodeObj, "template", "placeable_rendinst")
      let localTm = (*nodeObj).tm ?? IDENT_TM

      if composit_holder__childrenEids != null
        templName += "+transform_attached"

      let childEid = createEntity(templName) <| $(var init : ComponentsInitializer)
        init |> set("ri_extra__name", rendinstName)
        init |> set("transform", transform * localTm)

        if composit_holder__childrenEids != null
          init |> set("transform_attached__entityEid", eid)
          init |> set("transform_attached__localTm", localTm)


      if composit_holder__childrenEids != null
        *composit_holder__childrenEids |> push(childEid)

    elif nodeType == "entity"
      var templName = get_string(nodeObj, "template", "")

      if templName == ""
        logerr("{eid}<{getEntityTemplateName(eid)}>: composit node entity template is empty!")
        continue

      let localTm = (*nodeObj).tm ?? IDENT_TM

      if composit_holder__childrenEids != null
        templName += "+transform_attached"

      let childEid = createEntity(templName) <| $(var init : ComponentsInitializer)
        init |> set("transform", transform * localTm)

        if composit_holder__childrenEids != null
          init |> set("transform_attached__entityEid", eid)
          init |> set("transform_attached__localTm", localTm)

      if composit_holder__childrenEids != null
        *composit_holder__childrenEids |> push(childEid)
    else
      logerr("{eid}<{getEntityTemplateName(eid)}>: invalid composit node type - `{nodeType}`!")


[es(track=transform)]
def composit_holder_track_transform(evt : Event;
                                    composit_holder__childrenEids : EidList;
                                    transform aka composit_transform : float3x4)
  for childEid in composit_holder__childrenEids
    query(childEid) <| $ [es] (transform_attached__localTm : float3x4;
                               grid_obj__gridType : das_string const?;
                               var transform aka child_transform : float3x4)
      child_transform = composit_transform * transform_attached__localTm

      if grid_obj__gridType != null
        sendEvent(childEid, CmdUpdateGrid())


[es(on_disappear)]
def composit_holder_disappear(evt : Event;
                              composit_holder__childrenEids : EidList)
  for childEid in composit_holder__childrenEids
    query(childEid) <| $ [es] (var transform_attached__entityEid : EntityId&)
      transform_attached__entityEid = INVALID_ENTITY_ID


[es(on_disappear)]
def composit_holder_child_disappear(evt : Event;
                                    eid aka child_eid : EntityId;
                                    transform_attached__entityEid : EntityId)
  query(transform_attached__entityEid) <| $ [es] (var composit_holder__childrenEids : EidList)
    let childIdx = composit_holder__childrenEids |> find_index(child_eid)
    if childIdx >= 0
      composit_holder__childrenEids |> erase(childIdx)