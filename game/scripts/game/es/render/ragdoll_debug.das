options no_aot
require ecs
require DagorConsole
require DagorDebug3D
require DngPhysObj
require GamePhys
require math.base
require game.es.grav_zones_common
require DagorSystem
require strings
require app


[console_cmd(name="ragdoll.debug_sync")]
def ragdoll_sync_debug()
  var needCreate = true
  query() <| $ [es(REQUIRE=ragdoll_phys_obj_debug)] (eid : EntityId)
    destroyEntity(eid)
    needCreate = false
  if needCreate
    createEntity("ragdoll_phys_obj_debug")


[es(tag=(render, dev), REQUIRE=ragdoll_phys_obj_debug, after=after_net_phys_sync)]
def ragdoll_sync_debug_act(info : UpdateStageInfoRenderDebug)
  query() <| $ [es] (ragdoll_phys_obj__links : Array;
                     phys_obj_net_phys : PhysObjActor;
                     ragdoll_phys_obj__attachedTo : EntityId)
    query(ragdoll_phys_obj__attachedTo) <| $ [es] (ragdoll__enabled : bool;
                                                   ragdoll__enabledAt : float;
                                                   ragdoll__timeBeforeFallingAsleep = 3f;
                                                   ragdoll__maxTimeInAwakenedState = 30f)
      var transform : float3x4
      phys_obj_net_phys.phys.currentState.location |> location_toTM(transform)
      if !ragdoll__enabled
        add_debug_text_mark(transform[3], "sleep", -1, -2f, E3DCOLOR(0xFFFF0000))
      else
        let curTime = get_sync_time()
        add_debug_text_mark(transform[3], "awake", -1, -2f, E3DCOLOR(0xFF11FF00))
        add_debug_text_mark(transform[3], "time before falling asleep: {fmt(":.1f", max(0f, ragdoll__enabledAt + ragdoll__timeBeforeFallingAsleep - curTime))}", -1, 0f, E3DCOLOR(0xFFFFFFFF))
        add_debug_text_mark(transform[3], "max time in awakened state: {fmt(":.1f", max(0f, ragdoll__enabledAt + ragdoll__maxTimeInAwakenedState - curTime))}", -1, 2f, E3DCOLOR(0xFFFFFFFF))
      for link in ragdoll_phys_obj__links
        let obj = get_ecs_object(link)
        if obj == null
          continue
        let offset = get_Point3(obj, "offset") ?? float3(0f)
        let nodeName = get_string(obj, "nodeName", "Unknown")
        var nodeTm = IDENT_TM
        nodeTm[3] = transform * offset
        draw_debug_sphere_buffered(nodeTm[3], 0.1, E3DCOLOR(0xFFFFFFFF), 12, 1)
        add_debug_text_mark(nodeTm[3], nodeName, -1, 0f, E3DCOLOR(0xFFFFFFFF))