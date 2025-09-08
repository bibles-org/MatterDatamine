module anomaly_zones_common shared
require ecs
require ecs.safe


struct SpawnPresetItem
  templateName : string
  inflateBox : float3 const?
  targetScale : float3 const?
  minDistanceToWall : float const?
  projectToNavmesh : bool
  scaleToBox : bool
  alignToBottom : bool
  syncCreation : bool
  spawnOnLeafs : bool const?
  spawnIndoor : bool const?
  clientOnly : bool

struct SpawnPreset
  items : array<SpawnPresetItem>
  projectToNavmesh : bool
  minDistanceToWall : float const?

def parse_spawn_presets(data : Object; var presets : table<string; SpawnPreset>)
  for presetData in data
    let itemsData = presetData.value as Array
    var preset : SpawnPreset
    reserve(preset.items, length(*itemsData))
    for itemData in *itemsData
      let item = itemData |> get_ecs_object()
      var resItem = SpawnPresetItem(
        templateName = (*item)["template"] ?? "",
        inflateBox = (*item).inflateBox ?as float3,
        targetScale = (*item).targetScale ?as float3,
        projectToNavmesh = (*item).projectToNavmesh ?? false,
        minDistanceToWall = (*item).minDistanceToWall ?as float,
        scaleToBox = (*item).scaleToBox ?? false,
        alignToBottom = (*item).alignToBottom ?? false,
        syncCreation = (*item).syncCreation ?? false,
        spawnOnLeafs = (*item).spawnOnLeafs ?as bool,
        spawnIndoor = (*item).spawnIndoor ?as bool,
        clientOnly = (*item).clientOnly ?? false)
      preset.projectToNavmesh ||= resItem.projectToNavmesh
      if resItem.minDistanceToWall != null && (preset.minDistanceToWall == null || (*resItem.minDistanceToWall) > (*preset.minDistanceToWall))
        preset.minDistanceToWall = resItem.minDistanceToWall
      preset.items |> emplace(resItem)
    presets[presetData.key] <- preset

def cleanup_zone_children(zone_eid : EntityId)
  query() <| $ [es] (eid, anomaly_zone__ownerZoneEid : EntityId)
    if anomaly_zone__ownerZoneEid == zone_eid
      eid |> destroyEntity()