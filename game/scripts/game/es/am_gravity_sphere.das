require app
require ecs
require ecs.common
require math.base
require Grid
require DagorMath
require PhysObj
require DngActor
require DngPhysObj
require DngHuman
require DngNet
require HumanPhys
require DagorSystem
require vehicle
require game.events.events_active_matter


[es(tag=server, on_appear)]
def am_gravity_sphere_init(evt : Event;
                           eid : EntityId;
                           am_gravity_sphere__updateInterval : float;
                           am_gravity_sphere__gridNames : StringList;
                           var am_gravity_sphere__updateAt : float&;
                           var am_gravity_sphere__gridEids : IntList)
  am_gravity_sphere__updateAt = get_sync_time() + am_gravity_sphere__updateInterval * eid_frnd(eid)

  am_gravity_sphere__gridEids |> resize(length(am_gravity_sphere__gridNames))
  for gridName, gridEid in am_gravity_sphere__gridNames, am_gravity_sphere__gridEids
    gridEid = int(ecs_hash(gridName |> string()))


[es(tag=server, before=before_net_phys_sync)]
def am_gravity_sphere_update(act : UpdateStageInfoAct;
                             transform : float3x4;
                             sphere_zone__radius : float;
                             am_gravity_sphere__active : bool;
                             am_gravity_sphere__updateInterval : float;
                             am_gravity_sphere__gridEids : IntList;
                             am_gravity_sphere__gravityMult : float;
                             am_gravity_sphere__affectInTemplate : string;
                             var am_gravity_sphere__updateAt : float&)
  if !am_gravity_sphere__active
    return

  if am_gravity_sphere__updateAt <= act.curTime
    am_gravity_sphere__updateAt += am_gravity_sphere__updateInterval

    for gridEid in am_gravity_sphere__gridEids
      for_each_entity_in_grid(uint(gridEid), BSphere3(transform[3], sphere_zone__radius), GridEntCheck.POS) <| $ [unused_argument(pos)] (entity_eid : EntityId;
                                                                                                                                         pos : float3)
        query(entity_eid) <| $ [es] (phys_obj_net_phys : PhysObjActor const?;
                                     human_net_phys : HumanActor const?;
                                     vehicle_net_phys : VehiclePhysActor const?)
          if phys_obj_net_phys == null && human_net_phys == null && vehicle_net_phys == null
            return

          find_query() <| $ [es(REQUIRE=am_gravity_sphere_affect_out)] (eid aka affect_eid : EntityId;
                                                                        game_effect__attachedTo : EntityId)
            if entity_eid != game_effect__attachedTo
              return false
            destroyEntity(affect_eid)
            return true

          let destroyAt = act.curTime + am_gravity_sphere__updateInterval * 1.5
          let exists = find_query() <| $ [es(REQUIRE=am_gravity_sphere_affect_in)] (game_effect__attachedTo : EntityId;
                                                                                    var am_gravity_sphere_affect__gravityMult : float&;
                                                                                    var game_effect__destroyAt : float&)
            if entity_eid != game_effect__attachedTo
              return false
            am_gravity_sphere_affect__gravityMult = am_gravity_sphere__gravityMult
            game_effect__destroyAt = destroyAt
            return true

          if !exists
            createEntity(am_gravity_sphere__affectInTemplate) <| $(var init : ComponentsInitializer)
              init |> set("game_effect__attachedTo", entity_eid)
              init |> set("am_gravity_sphere_affect__gravityMult", am_gravity_sphere__gravityMult)
              init |> set("game_effect__destroyAt", destroyAt)


[es(no_order)]
def am_gravity_sphere_affect_update(act : ParallelUpdateFrameDelayed;
                                    eid aka affect_eid : EntityId;
                                    am_gravity_sphere_affect__gravityMult : float;
                                    am_gravity_sphere_affect__gravityChangeSpeed : float;
                                    am_gravity_sphere_affect__selfDestroy : bool;
                                    game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var phys_obj_net_phys : PhysObjActor?;
                                            var human_net_phys : HumanActor?;
                                            var vehicle_net_phys : VehiclePhysActor?)
    var finished = false
    if human_net_phys != null
      human_net_phys.phys.currentState.gravMult = move_to(human_net_phys.phys.currentState.gravMult, am_gravity_sphere_affect__gravityMult,
                                                          act.dt, am_gravity_sphere_affect__gravityChangeSpeed)
      finished = is_equal_float(human_net_phys.phys.currentState.gravMult, am_gravity_sphere_affect__gravityMult)
    elif phys_obj_net_phys != null
      phys_obj_net_phys.phys.gravityMult = move_to(phys_obj_net_phys.phys.gravityMult, am_gravity_sphere_affect__gravityMult,
                                                  act.dt, am_gravity_sphere_affect__gravityChangeSpeed)
      finished = is_equal_float(phys_obj_net_phys.phys.gravityMult, am_gravity_sphere_affect__gravityMult)
    elif vehicle_net_phys != null
      vehicle_net_phys.phys.gravityMult = move_to(vehicle_net_phys.phys.gravityMult, am_gravity_sphere_affect__gravityMult,
                                                  act.dt, am_gravity_sphere_affect__gravityChangeSpeed)
      finished = is_equal_float(vehicle_net_phys.phys.gravityMult, am_gravity_sphere_affect__gravityMult)

    if finished && is_server() && am_gravity_sphere_affect__selfDestroy
      destroyEntity(affect_eid)


[es(tag=server, on_disappear)]
def am_gravity_sphere_affect_disappear(evt : Event;
                                       game_effect__attachedTo : EntityId;
                                       am_gravity_sphere_affect__resultAffect : string)
  if am_gravity_sphere_affect__resultAffect != ""
    createEntity(am_gravity_sphere_affect__resultAffect) <| $(var init : ComponentsInitializer)
      init |> set("game_effect__attachedTo", game_effect__attachedTo)