options no_aot
require ecs
require math.base
require DagorConsole



[console_cmd(name="am.create_disorient_cloud")]
def create_disorient_cloud(target_eid = 0u)
  var resultEid = INVALID_ENTITY_ID
  if target_eid == 0u
    find_query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
      resultEid = eid
      return true
  else
    resultEid = EntityId(target_eid)
  query(resultEid) <| $ [es] (transform : float3x4)
    createEntity("disorient_trap_cloud") <| $(var init : ComponentsInitializer)
      var tm = IDENT_TM
      tm[3] = transform[3] + float3(0.0, 1.0, 0.0)
      init |> set("transform", tm)

