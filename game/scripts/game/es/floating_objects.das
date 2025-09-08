require ecs
require ecs.common
require app
require game.es.bighead_common


[es(tag=server, on_appear, track=floating_objects__numObjects)]
def create_floating_objects(evt : Event;
                            eid : EntityId;
                            transform : float3x4;
                            floating_objects__numObjects : int;
                            floating_objects__creationRiList : StringList;
                            floating_objects__minMaxEllipseHeight : float2;
                            floating_objects__ellipseWidthHeightRatio : float;
                            floating_objects__minMaxSpeed : float2;
                            floating_objects__minMaxOscillationFrequency : float2;
                            floating_objects__minMaxOscillationAmplitude : float2;
                            floating_objects__minMaxOrbitAnglesDeg : float2;
                            floating_objects__objectTemplate : string;
                            floating_objects__anchorOffset : float3;
                            var floating_objects__anchorPosition : float3&;
                            var floating_objects__eids : EidList)
  floating_objects__anchorPosition = transform * floating_objects__anchorOffset
  var needToCreate = floating_objects__numObjects - length(floating_objects__eids)
  let curTime = get_sync_time()
  let salt = int(curTime)
  while needToCreate > 0
    let objectSeed = int(uint(eid)) + salt + needToCreate
    let newObject = create_floating_object(floating_objects__creationRiList, objectSeed,
                                           transform,
                                           eid, floating_objects__minMaxEllipseHeight,
                                           floating_objects__ellipseWidthHeightRatio,
                                           floating_objects__minMaxOrbitAnglesDeg,
                                           floating_objects__minMaxSpeed,
                                           floating_objects__minMaxOscillationAmplitude,
                                           floating_objects__minMaxOscillationFrequency,
                                           floating_objects__objectTemplate) <| $ [unused_argument(_)] (var _) {}
    push(floating_objects__eids, newObject)
    --needToCreate


[es(tag=netClient, on_appear, REQUIRE_NOT=floating_object__launched)]
def floating_object_register_in_owner_client(evt : Event;
                                             eid : EntityId;
                                             floating_object__owner : EntityId)
  query(floating_object__owner) <| $ [es] (var floating_objects__eids : EidList)
    print("[FLOATING OBJECT] Registering <{eid}> in <{floating_object__owner}> at idx {length(floating_objects__eids)}")
    push(floating_objects__eids, eid)


[es(tag=netClient, on_appear, REQUIRE=floating_object__launched)]
def floating_object_deregister_launched_client(evt : Event;
                                               eid : EntityId;
                                               floating_object__owner : EntityId)
  query(floating_object__owner) <| $ [es] (var floating_objects__eids : EidList)
    let idx = find_index(floating_objects__eids, eid)
    if idx >= 0
      print("[FLOATING OBJECT] Deregestering <{eid}> from <{floating_object__owner}> at idx {idx} (launched)")
      erase(floating_objects__eids, idx)


[es(on_disappear)]
def floating_object_deregister(evt : Event;
                               eid : EntityId;
                               floating_object__owner : EntityId)
  query(floating_object__owner) <| $ [es] (var floating_objects__eids : EidList)
    let idx = find_index(floating_objects__eids, eid)
    if idx >= 0
      print("[FLOATING OBJECT] Deregestering <{eid}> from <{floating_object__owner}> at idx {idx} (disappear)")
      erase(floating_objects__eids, idx)
