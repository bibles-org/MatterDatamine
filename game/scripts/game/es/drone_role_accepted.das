require ecs
require DngActor
require DngNet
require game.utils.hero


[es(tag=gameClient, on_appear, track=drone__owner, REQUIRE=isDrone)]
def drone_role_acept_on_client(evt : Event;
                               eid : EntityId;
                               drone__owner : EntityId;
                               var replication : NetObject&)
  var dronePhys : BasePhysActor? = get_phys_actor(eid)
  if dronePhys == null
    return
  if drone__owner == get_controlled_hero()
    base_phys_actor_setRoleAndTickrateType(*dronePhys, NetRole.ROLE_LOCALLY_CONTROLLED_SHADOW, dronePhys.tickrateType)
    let sconn : IConnection const? = get_server_conn()
    if sconn != null
      replication |> net_object_setControlledBy(connection_getId(*sconn))
  else
    base_phys_actor_setRoleAndTickrateType(*dronePhys, NetRole.ROLE_REMOTELY_CONTROLLED_SHADOW, dronePhys.tickrateType)
    replication |> net_object_setControlledBy(-1)


[es(tag=server, on_appear, track=drone__owner, REQUIRE=isDrone)]
def drone_role_acept_on_server(evt : Event;
                               eid : EntityId;
                               drone__owner : EntityId;
                               var replication : NetObject&)
  var dronePhys : BasePhysActor? = get_phys_actor(eid)
  if dronePhys == null
    return
  base_phys_actor_setRoleAndTickrateType(*dronePhys, NetRole.ROLE_REMOTELY_CONTROLLED_AUTHORITY, dronePhys.tickrateType)
  query(drone__owner) <| $ [es] (possessedByPlr : EntityId)
    query(possessedByPlr) <| $ [es] (connid : int)
      var clientConn : IConnection? = get_client_connection(connid)
      if clientConn != null
        replication |> net_object_setControlledBy(connection_getId(*clientConn))
