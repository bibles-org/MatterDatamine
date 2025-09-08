options no_aot
require app
require ecs
require ecs.common
require DagorConsole
require DagorSystem
require DagorDebug3DSolid
require game.es.net_console_macro

[net_console_cmd(name="am.lock_doors_around")]
def console_lock_doors_around(@net_hero eid : EntityId)
  query(eid) <| $ [es] (transform : float3x4)
    createEntity("adhock_locked_door_marker") <| $(init)
      init |> set("transform", transform)
      using() <| $(var list : StringList)
        list |> push("developer_key")
        init |> set("locked__keyTags", list)


[es(on_appear, before=adhock_mark_doors_locked)]
def scale_adhock_tm(evt : Event; locked_door_marker__scale : float; var transform : float3x4)
  transform[0] *= locked_door_marker__scale
  transform[1] *= locked_door_marker__scale
  transform[2] *= locked_door_marker__scale


[net_console_cmd(name="am.give_skeleton_key")]
def console_give_skeleton_key(@net_hero eid : EntityId)
  using() <| $(var tagList : StringList)
    tagList |> push("developer_key")
    query() <| $ [es] (locked__keyTags : StringList)
      for t in locked__keyTags
        if !has_value(tagList, string(t))
          tagList |> push(t)
    createEntity("base_key_item") <| $(init)
      init |> set("item__containerOwnerEid", eid)
      init |> set("key__tags", tagList)
      init |> set("item__amount", 10000)