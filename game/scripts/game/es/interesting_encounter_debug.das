options no_aot
require ecs
require net
require DagorConsole
require game.es.server_debug_common


[console_cmd(name="am.create_encounter_on_nearest_gameobj")]
def console_create_encounter_on_nearest_gameobj(encounter_template : string; obj_eid = 0)
  var res = EntityId(uint(obj_eid))
  find_query() <| $ [es] (camera__active : bool; transform aka cam_transform : float3x4)
    if camera__active
      var bestScore = -1000.0
      let distanceCoeff = 0.05
      query() <| $ [es(REQUIRE=custom_game_object__name)] (eid : EntityId; transform aka obj_transform : float3x4)
        let dst = distance(obj_transform[3], cam_transform[3])
        let dt = dot(cam_transform[0], normalize(obj_transform[3] - cam_transform[3]))
        let score = dt - dst * distanceCoeff
        if score > bestScore
          bestScore = score
          res = eid
      if !is_server()
        exec_server_cmd("am.create_encounter_on_nearest_gameobj {encounter_template} {res}")
    return camera__active

  if is_server()
    query(res) <| $ [es] (transform : float3x4)
      createEntity(encounter_template) <| $(init)
        init |> set("transform", transform)