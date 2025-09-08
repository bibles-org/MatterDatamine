module poi_validation_common shared
require ecs
require ecs.common
require pathfinder
require DagorSystem
require DagorDataBlock
require DagorEditor
require math.maybe_pos
require active_matter.game.es.navmesh_nearest_pos_common
require danetlibs.imgui_daeditor.daEditor.daEditor_common
require daslib/sort_boost


let DEFAULT_POI_RADIUS = 2.0

def rebuild_all_bindings()
  delete_existing_nav_data()
  let onValidatorCreated <- @ <| (eid : EntityId) : void
    query(eid) <| $ [es] (var poi_validator__validPos : Point3List; var poi_validator__poiEids : EidList)
      add_respawn_bases_to_validator(poi_validator__validPos)
      add_all_bindings_to_validator(poi_validator__poiEids)
  createEntity("point_of_interest_validator", onValidatorCreated, $ [unused_argument(_)] (var _ : ComponentsInitializer) {})


def validate_existing_bindings()
  delete_existing_nav_data()
  let onValidatorCreated <- @ <| (eid : EntityId) : void
    query(eid) <| $ [es] (var poi_validator__validPos : Point3List; var poi_validator__poiEids : EidList)
      add_respawn_bases_to_validator(poi_validator__validPos)
      add_existing_bindings_to_validator(poi_validator__poiEids)
  createEntity("point_of_interest_validator", onValidatorCreated, $ [unused_argument(_)] (var _ : ComponentsInitializer) {})


def delete_existing_nav_data()
  query() <| $ [es(REQUIRE=poi_validator__total)] (eid : EntityId)
    destroyEntity(eid)
  query() <| $ [es(REQUIRE=pointOfInterestNavData)] (eid : EntityId)
    destroyEntity(eid)


def add_respawn_bases_to_validator(var poi_validator__validPos : Point3List)
  let navmeshSearchRadius = 1.0
  query() <| $ [es(REQUIRE=respbase)] (eid : EntityId; transform : float3x4)
    var navPos = transform[3]
    if !project_to_nearest_navmesh_point(navPos, navmeshSearchRadius)
      logerr("can't find navmesh near respbase {eid}<{getEntityTemplateName(eid)}> at {transform[3]}")
      return
    push(poi_validator__validPos, navPos)


def add_all_bindings_to_validator(var poi_validator__poiEids : EidList)
  query() <| $ [es(REQUIRE=nav_binding__navMeshPos, REQUIRE_NOT=nav_binding__entityPos)] (eid : EntityId;
                                                                                          transform : float3x4;
                                                                                          nav_binding__inaccessible : bool)
    let resultingEid = createEntity("point_of_interest_nav_data") <| $(init)
      set(init, "poi__eid", eid)
      set(init, "poi__pos", transform[3])
      set(init, "poi__radius", DEFAULT_POI_RADIUS)
      set(init, "poi__inaccessible", nav_binding__inaccessible)
      using() <| $(var list : Point3List)
        add_nearest_navmesh_points(eid, transform[3], DEFAULT_POI_RADIUS, list)
        set(init, "poi__navPos", list)
    push(poi_validator__poiEids, resultingEid)


def add_existing_bindings_to_validator(var poi_validator__poiEids : EidList)
  let zero = float3()
  query() <| $ [es(REQUIRE_NOT=nav_binding__entityPos)] (eid : EntityId;
                                                         transform : float3x4;
                                                         nav_binding__navMeshPos : float3;
                                                         nav_binding__inaccessible : bool)
    let resultingEid = createEntity("point_of_interest_nav_data") <| $(init)
      set(init, "poi__eid", eid)
      set(init, "poi__pos", transform[3])
      set(init, "poi__radius", DEFAULT_POI_RADIUS)
      set(init, "poi__inaccessible", nav_binding__inaccessible)
      using() <| $(var list : Point3List)
        if nav_binding__navMeshPos != zero
          push(list, nav_binding__navMeshPos)
        else
          add_nearest_navmesh_points(eid, transform[3], DEFAULT_POI_RADIUS, list)
        set(init, "poi__navPos", list)
    push(poi_validator__poiEids, resultingEid)


def add_nearest_navmesh_points(eid : EntityId; pos : float3; radius : float; var list : Point3List)
  query_navmesh_projections(pos, float3(radius), /*points num*/8) <| $(points)
    for p in points
      push(list, p)
    if length(list) > 0
      qsort(list) <| $(lhs : float3; rhs : float3)
        return distance_sq(pos, lhs) < distance_sq(pos, rhs)
    else
      logwarn("No navmesh points around {eid}:<{getEntityTemplateName(eid)}>")

def validate_single_poi(poi_eid : EntityId; pos : float3)
  query() <| $ [es(REQUIRE=poi_validator__total)] (eid : EntityId)
    destroyEntity(eid)
  let onValidatorCreated <- @ <| (eid : EntityId) : void
    query(eid) <| $ [es] (var poi_validator__validPos : Point3List; var poi_validator__poiEids : EidList)
      add_respawn_bases_to_validator(poi_validator__validPos)
      query() <| $ [es(REQUIRE=pointOfInterestNavData)] (eid : EntityId; poi__eid : EntityId; poi__isValid : bool; poi__navPos : Point3List)
        if poi__eid == poi_eid
          destroyEntity(eid)
        elif poi__isValid && length(poi__navPos) > 0
          push(poi_validator__validPos, poi__navPos[0])
      let newPoiData = createEntity("point_of_interest_nav_data") <| $(init)
        set(init, "poi__eid", poi_eid)
        set(init, "poi__pos", pos)
        set(init, "poi__radius", DEFAULT_POI_RADIUS)
        query(poi_eid) <| $ [es] (nav_binding__inaccessible : bool)
          set(init, "poi__inaccessible", nav_binding__inaccessible)
        using() <| $(var list : Point3List)
          add_nearest_navmesh_points(eid, pos, DEFAULT_POI_RADIUS, list)
          set(init, "poi__navPos", list)
      push(poi_validator__poiEids, newPoiData)
  createEntity("point_of_interest_validator", onValidatorCreated, $ [unused_argument(_)] (var _ : ComponentsInitializer) {})

def assign_valid_bindings()
  query() <| $ [es] (poi__eid : EntityId; poi__isValid : bool; poi__navPos : Point3List)
    if poi__isValid
      query(poi__eid) <| $ [es] (var nav_binding__navMeshPos : float3&)
        nav_binding__navMeshPos = poi__navPos[0]
        entity_obj_editor_saveComponent(poi__eid, "nav_binding.navMeshPos")

def save_poi_to_file()
  using() <| $(var blk : DataBlock)
    query() <| $ [es(REQUIRE=pointOfInterest)] (eid : EntityId)
      editor_save_entity(eid, blk)
    datablock_save_to_text_file(blk, "../prog/gameBase/content/active_matter/gamedata/scenes/_geisel_library_poi.blk")