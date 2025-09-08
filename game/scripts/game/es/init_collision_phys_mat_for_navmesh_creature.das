require ecs
require PhysMat


[es(on_appear)]
def init_collision_phys_mat_for_navmesh_creature(evt : Event;
                                                 collision_physMatName : string;
                                                 var collision_physMatId : int&)
  if collision_physMatId == PHYSMAT_INVALID
    collision_physMatId = get_material_id(collision_physMatName)