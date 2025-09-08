require ecs
require CollRes
require AnimV20
require GeomNodeTree
require DagorSystem

[es(on_appear)]
def init_human_bounding_sphere_es(evt : Event;
                                  eid : EntityId;
                                  animchar : AnimcharBaseComponent;
                                  collres__centerNode : string;
                                  var collres : CollisionResource)
  let bsphereCenterNode = *animchar.nodeTree |> geomtree_findNodeIndex(collres__centerNode)
  if bsphereCenterNode < 0
    logerr("can't find collres__centerNode <{collres__centerNode}> index, template={getEntityTemplateName(eid)}")
  else
    collres |> collres_setBsphereCenterNode(bsphereCenterNode)


[es(on_appear, REQUIRE=deadEntity)]
def human_net_phys_disable_collisions_on_death(evt : Event;
                                               var havePairCollision : bool&)
  // To disable HumanPhys collisions tracing (like torsoCollision)
  // @see grid_process_main_entities_collision_objects_on_ray
  havePairCollision = false