require ecs
require DngNet


[es(tag=server, on_appear, track=possessedByPlr, REQUIRE=autorespawn)]
def autorespawn_point_init(evt : Event; possessedByPlr : EntityId)
  if possessedByPlr == INVALID_ENTITY_ID
    return

  let alredyHaveSavePoint = find_query() <| $ [es] (save_point__playerEid : EntityId)
    return save_point__playerEid == possessedByPlr
  if alredyHaveSavePoint
    return

  find_query() <| $ [es(REQUIRE=respbase)] (transform : float3x4)
    createEntity("save_point") <| $(init)
      init |> set("save_point__playerEid", possessedByPlr)
      init |> set("save_point__tm", transform)
    return true
