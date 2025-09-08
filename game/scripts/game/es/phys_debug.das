options no_aot
require ecs
require ecs.safe
require DagorConsole
require DagorSystem
require RendInst
require game.utils.net_utils
require game.es.net_console_macro
require game.events.events_active_matter
require vehicle
require DngNet
require DngActor
require DngHuman
require DngPhysObj


def print_phys_debug_log(str : string)
  if !is_true_net_server()
    console_print(str)
  print(str)


[console_cmd(name="phys.print_actors")]
def console_phys_print_actors()
  print_phys_debug_log("human_net_phys:")
  var index = 0
  query() <| $ [es(REQUIRE=human_net_phys)] (eid : EntityId;
                                             transform : float3x4;
                                             disableUpdate : Tag const?;
                                             deadEntity : Tag const?;
                                             isAlive : bool = true)
    let updatable = (disableUpdate == null)
    let alive = isAlive && (deadEntity == null)
    print_phys_debug_log("\t{++index}. {eid}<{getEntityTemplateName(eid)}>: updatable={updatable} alive={alive} pos={transform[3]}")

  print_phys_debug_log("phys_obj_net_phys:")
  index = 0
  query() <| $ [es] (eid : EntityId;
                     transform : float3x4;
                     phys_obj_net_phys : PhysObjActor;
                     disableUpdate : Tag const?;
                     deadEntity : Tag const?;
                     isAlive : bool = true)
    let updatable = (disableUpdate == null)
    assume isSleep = phys_obj_net_phys.phys.currentState.isSleep
    let alive = isAlive && (deadEntity == null)
    print_phys_debug_log("\t{++index}. {eid}<{getEntityTemplateName(eid)}>: updatable={updatable} isSleep={isSleep} alive={alive} pos={transform[3]}")

  print_phys_debug_log("vehicle_net_phys:")
  index = 0
  query() <| $ [es] (eid : EntityId;
                     transform : float3x4;
                     vehicle_net_phys : VehiclePhysActor;
                     disableUpdate : Tag const?;
                     deadEntity : Tag const?;
                     isAlive : bool = true)
    let updatable = (disableUpdate == null)
    assume isSleep = vehicle_net_phys.isAsleep
    let alive = isAlive && (deadEntity == null)
    print_phys_debug_log("\t{++index}. {eid}<{getEntityTemplateName(eid)}>: updatable={updatable} isSleep={isSleep} alive={alive} pos={transform[3]} ")
