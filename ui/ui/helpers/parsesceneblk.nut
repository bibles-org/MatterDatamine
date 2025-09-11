from "%sqGlob/dasenums.nut" import ExtractionStatusForHero

from "dagor.math" import Point2, Point3, TMatrix, E3DCOLOR
from "das.loot_preset" import loot_preset_get_all_possible_items
from "math" import rand

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
import "DataBlock" as DataBlock
from "dagor.debug" import logerr


let memoizedGetAllPresetItems = memoize(@(preset) loot_preset_get_all_possible_items(preset))



function extractLootFromPresetTemplates(all_preset_items, accumulator) {
  foreach (presetTemplate in all_preset_items.keys()) {
    let curTemplName = presetTemplate.split("+")[0]
    let curTempl = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(curTemplName)
    let extractedTemplName = curTempl?.getCompValNullable("item__extractionTemplateOverride") ?? curTemplName
    accumulator.rawset(extractedTemplName, true)
    let innerGenerator = curTempl?.getCompValNullable("loot_drop_system__lootPreset")
    if (innerGenerator != null) {
      let innerPresetItems = memoizedGetAllPresetItems(innerGenerator)
      foreach(innerK in innerPresetItems.keys()) {
        let curInnerTemplName = innerK.split("+")[0]
        let curInnterTempl = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(curInnerTemplName)
        let extractedInnerTemplName = curInnterTempl?.getCompValNullable("item__extractionTemplateOverride") ?? curInnerTemplName
        accumulator.rawset(extractedInnerTemplName, true)
      }
    }
  }
}

function parse_tiled_map_info_from_scene_entity(entityBlk){
  let fittingTemplates = [
    "tiled_map",
    "onboarding_tiled_map"
  ]

  let templateName = entityBlk.getStr("_template", "")
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  if (!fittingTemplates.contains(templateName) || !template)
    return null

  let result = {
    transform = template.getCompValNullable("tiled_map__tilesPath") ?? ""
    spawnGroupId = template.getCompValNullable("tiled_map__northAngle") ?? 0.0
    zlevels = template.getCompValNullable("tiled_map__zlevels") ?? 1
    tileWidth = template.getCompValNullable("tiled_map__tileWidth") ?? 1
    visibleRange = template.getCompValNullable("tiled_map__visibleRange") ?? Point2(0, 0)
    leftTop = template.getCompValNullable("tiled_map__leftTop") ?? Point2(0, 0)
    rightBottom = template.getCompValNullable("tiled_map__rightBottom") ?? Point2(0, 0)
    leftTopBorder = template.getCompValNullable("tiled_map__leftTopBorder") ?? Point2(0, 0)
    rightBottomBorder = template.getCompValNullable("tiled_map__rightBottomBorder") ?? Point2(0, 0)
    backgroundColor = template.getCompValNullable("tiled_map__backgroundColor") ?? E3DCOLOR(0, 0, 0, 140)
    fogOfWarEnabled = template.getCompValNullable("fog_of_war__enabled") ?? false
    fogOfWarSavePath = template.getCompValNullable("fog_of_war__onlineSettingsPath") ?? ""
    fogOfWarResolution = template.getCompValNullable("fog_of_war__resolution") ?? 5.0
  }

  if (entityBlk.paramExists("tiled_map__tilesPath"))
    result.tilesPath <- entityBlk.getStr("tiled_map__tilesPath", "")
  if (entityBlk.paramExists("tiled_map__northAngle"))
    result.northAngle <- entityBlk.getReal("tiled_map__northAngle", 0.0)
  if (entityBlk.paramExists("tiled_map__zlevels"))
    result.zlevels <- entityBlk.getInt("tiled_map__zlevels", 1)
  if (entityBlk.paramExists("tiled_map__tileWidth"))
    result.tileWidth <- entityBlk.getInt("tiled_map__tileWidth", 1)
  if (entityBlk.paramExists("tiled_map__visibleRange"))
    result.visibleRange <- entityBlk.getPoint2("tiled_map__visibleRange", Point2(0, 0))
  if (entityBlk.paramExists("tiled_map__leftTop"))
    result.leftTop <- entityBlk.getPoint2("tiled_map__leftTop", Point2(0, 0))
  if (entityBlk.paramExists("tiled_map__rightBottom"))
    result.rightBottom <- entityBlk.getPoint2("tiled_map__rightBottom", Point2(0, 0))
  if (entityBlk.paramExists("tiled_map__leftTopBorder"))
    result.leftTopBorder <- entityBlk.getPoint2("tiled_map__leftTopBorder", Point2(0, 0))
  if (entityBlk.paramExists("tiled_map__rightBottomBorder"))
    result.rightBottomBorder <- entityBlk.getPoint2("tiled_map__rightBottomBorder", Point2(0, 0))
  if (entityBlk.paramExists("tiled_map__backgroundColor"))
    result.backgroundColor <- entityBlk.getE3dcolor("tiled_map__backgroundColor", E3DCOLOR(0, 0, 0, 140))
  if (entityBlk.paramExists("fog_of_war__enabled"))
    result.fogOfWarEnabled <- entityBlk.getBool("fog_of_war__enabled", false)
  if (entityBlk.paramExists("fog_of_war__onlineSettingsPath"))
    result.fogOfWarSavePath <- entityBlk.getStr("fog_of_war__onlineSettingsPath", "")
  if (entityBlk.paramExists("fog_of_war__resolution"))
    result.fogOfWarResolution <- entityBlk.getReal("fog_of_war__resolution", 5.0)

  
  result.backgroundColor <- result.backgroundColor.u
  return result
}

function parse_zone_info_from_scene_entity(entityBlk){
  let requiredParams = [
    "sphere_zone__radius",
    "moving_zone__sourcePos"
  ]

  foreach (_, param in requiredParams)
    if (!entityBlk.paramExists(param))
      return null

  let result = {
    radius = entityBlk.getReal("sphere_zone__radius", 0.0)
    sourcePos = entityBlk.getPoint3("moving_zone__sourcePos", Point3(0, 0, 0))
  }

  return result
}


function parse_list_from_scene(entityBlk, listName){
  let listBlk = entityBlk.getBlockByName(listName)
  if (!listBlk)
    return null

  let result = []
  for(local idx = 0; idx < listBlk.paramCount(); idx++){
    let val = listBlk.getParamValue(idx)
    result.append(val)
  }
  return result
}

function parse_raid_description_from_scene_entity(entityBlk){
  let requiredParams = [
    "raid_description__raidType",
    "raid_description__difficulty",
  ]

  let requiredBlocks = [
    "raid_description__enemies:list<t>",
    "raid_description__images:list<t>",
    "raid_description__mcImages:list<t>",
  ]

  foreach (_, param in requiredParams)
    if (!entityBlk.paramExists(param))
      return null

  foreach (_, block in requiredBlocks)
    if (!entityBlk.getBlockByName(block))
      return null

  let result = {
    raidType = entityBlk.getStr("raid_description__raidType", "")
    difficulty = entityBlk.getStr("raid_description__difficulty", "")
    drawSpawnsAsPoints = entityBlk.getBool("raid_description__drawSpawnsAsPoints", false)
    drawSpawnsAsPoly = entityBlk.getBool("raid_description__drawSpawnsAsPoly", false)
    drawSpawnsAlpha = entityBlk.getReal("raid_description__drawSpawnsAlpha", 100.0)
    drawSpawnsRadius = entityBlk.getReal("raid_description__drawSpawnsRadius", 20.0)
    drawSpawnsClampParam = entityBlk.getPoint2("raid_description__drawSpawnsClampParam", Point2(0, 0))
    enemies = parse_list_from_scene(entityBlk, "raid_description__enemies:list<t>")
    images = parse_list_from_scene(entityBlk, "raid_description__images:list<t>")
    mcImages = parse_list_from_scene(entityBlk, "raid_description__mcImages:list<t>")
    possibleLoot = parse_list_from_scene(entityBlk, "raid_description__possibleLoot:list<t>")
    overrideMoreLootNum = entityBlk.getInt("raid_description__overrideMoreLootNum", -1)
  }

  
  foreach (key, val in result)
    if (isEqual(val, "") || isEqual(val, []))
      result[key] = null

  return result
}

let possiblePresetComponents = [
  "loot_drop_system__lootPreset",
  "loot_generator__lootPreset"
]
function parse_loot_presets_from_scene(entityBlk) {
  foreach(componentName in possiblePresetComponents) {
    let preset = entityBlk.getStr(componentName, "")
    if (preset != "") {
      return preset
    }
  }
  return null
}

function parse_spawn_from_scene(entityBlk){
  let fittingTemplates = [
    "am_respawn_group_0",
    "am_respawn_group_1",
    "am_respawn_group_2",
    "am_respawn_group_3",
    "am_respawn_group_4",
    "am_respawn_group_5",
    "am_mindcontrolled_spawn",
    "spawnBase"
  ]

  let templateName = entityBlk.getStr("_template", "").split("+")[0]
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)

  if (!fittingTemplates.contains(templateName) || !template)
    return null

  let result = {
    transform = template.getCompValNullable("transform") ?? TMatrix()
    spawnGroupId = template.getCompValNullable("spawnBase__spawnGroupId") ?? -1
  }

  if (entityBlk.paramExists("transform"))
    result.transform <- entityBlk.getTm("transform", TMatrix())
  if (entityBlk.paramExists("spawnBase__spawnGroupId"))
    result.spawnGroupId <- entityBlk.getInt("spawnBase__spawnGroupId", -1)

  return result
}

function parse_extraction_from_scene(entityBlk){
  let fittingTemplates = [
    "militant_extraction",
    "extraction_point",
    "mindcontrolled_extraction",
    "am_extraction_group_0",
    "am_extraction_group_1",
    "am_extraction_group_2"
  ]

  let templateName = entityBlk.getStr("_template", "")
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  if (!fittingTemplates.contains(templateName) || !template)
    return null

  let result = {
    statusForHero = ExtractionStatusForHero.OK
    transform = template.getCompValNullable("transform") ?? TMatrix()
    enableTime = template.getCompValNullable("extraction_enable_time__defaultTime") ?? 0.0
    spawnGroups = template.getCompValNullable("extraction__connectedSpawnGroups")?.getAll() ?? []
  }

  if (entityBlk.paramExists("transform"))
    result.transform = entityBlk.getTm("transform", TMatrix())
  if (entityBlk.paramExists("extraction_enable_time__defaultTime"))
    result.enableTime = entityBlk.getReal("extraction_enable_time__defaultTime", 0.0)
  let extractionBlk = entityBlk?.getBlockByName("extraction__connectedSpawnGroups:list<i>")
  if (extractionBlk){
    let spawnGroups = []
    for (local idx = 0; idx < extractionBlk.paramCount(); idx++){
      spawnGroups.append(extractionBlk.getParamValue(idx))
    }
    result.spawnGroups = spawnGroups
  }

  return result
}

function parse_nexus_beacons(entityBlk){
  let fittingTemplates = [
    "nexus_beacon"
  ]

  let templateNames = entityBlk.getStr("_template", "").split("+")
  foreach (templateName in templateNames) {
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
    if (!fittingTemplates.contains(templateName) || !template)
      continue


    let result = {
      transform = template.getCompValNullable("transform")
      name = template.getCompValNullable("nexus_beacon__name")
      symbol = template.getCompValNullable("nexus_beacon__symbol")
      activationProgress = template.getCompValNullable("nexus_beacon__progress")
      state = template.getCompValNullable("nexus_beacon__state")
      controllingTeam = template.getCompValNullable("nexus_beacon__controllingTeam")
    }

    if (entityBlk.paramExists("transform"))
      result.transform <- entityBlk.getTm("transform", TMatrix())
    if (entityBlk.paramExists("nexus_beacon__name"))
      result.name <- entityBlk.getStr("nexus_beacon__name", "")
    if (entityBlk.paramExists("nexus_beacon__symbol"))
      result.symbol <- entityBlk.getStr("nexus_beacon__symbol", "")
    if (entityBlk.paramExists("nexus_beacon__progress"))
      result.activationProgress <- entityBlk.getReal("nexus_beacon__progress", 0.0)
    if (entityBlk.paramExists("nexus_beacon__state"))
      result.state <- entityBlk.getInt("nexus_beacon__state", 0)
    if (entityBlk.paramExists("nexus_beacon__controllingTeam"))
      result.controllingTeam <- entityBlk.getInt("nexus_beacon__controllingTeam", -1)

    result.pos <- result.transform.getcol(3)
    result.eid <- rand() 
    return result
  }
  return null
}


function get_entity_info_from_scene(scene, parser){
  let blk = DataBlock()
  if (!scene || scene == "")
    return null
  if (type(scene)!="string"){
    log("incorrect scene name:", scene)
    logerr("incorrect scene name")
    return null
  }
  if (!blk.tryLoad(scene))
    return null
  for (local idx = 0; idx < blk.blockCount(); idx++){
    let b = blk.getBlock(idx)
    if (b.getBlockName() == "import"){
      let scenePath = b.getStr("scene", "")
      if (scenePath != "") {
        let res = get_entity_info_from_scene(scenePath, parser)
        if (res != null)
          return res
      }
    }
    else if (b.getBlockName() != "entity")
      continue
    let res = parser(b)
    if (res != null)
      return res
  }
  return null
}

function get_entities_info_array_from_scene(scene, parser){
  let blk = DataBlock()
  let result = []
  if (!scene || scene == "" || !blk.tryLoad(scene))
    return null
  for (local idx = 0; idx < blk.blockCount(); idx++){
    let b = blk.getBlock(idx)
    if (b.getBlockName() == "import"){
      let scenePath = b.getStr("scene", "")
      if (scenePath != "")
        result.extend(get_entities_info_array_from_scene(scenePath, parser))
    }
    else if (b.getBlockName() != "entity")
      continue
    let res = parser(b)
    if (res != null)
      result.append(res)
  }
  return result.filter(@(x) x != null)
}

function ensurePoint2(pointOrTable) {
  if (type(pointOrTable) == "table") {
    return Point2(pointOrTable.x, pointOrTable.y)
  }
  return pointOrTable
}

function ensurePoint3(pointOrTable) {
  if (type(pointOrTable) == "table") {
    return Point3(pointOrTable.x, pointOrTable.y, pointOrTable.z)
  }
  return pointOrTable
}

function vectorToTable(vec) {
  return {
    x = vec.x
    y = vec.y
  }.__update(vec?.z != null ? { z = vec.z } : {})
}

function get_possible_loot_impl(scene) {
  let presetsArr = get_entities_info_array_from_scene(scene, parse_loot_presets_from_scene) ?? []
  let lootFromPresets = presetsArr.reduce(function(accumulator, presetTemplate) {
    let presetItems = memoizedGetAllPresetItems(presetTemplate)
    extractLootFromPresetTemplates(presetItems, accumulator)
    return accumulator
  }, {})

  return lootFromPresets
}

return {
  ensurePoint2
  ensurePoint3
  vectorToTable
  get_possible_loot = memoize(@(scene) get_possible_loot_impl(scene))
  get_tiled_map_info = memoize(@(scene) get_entity_info_from_scene(scene, parse_tiled_map_info_from_scene_entity))
  get_zone_info = memoize(@(scene) get_entity_info_from_scene(scene, parse_zone_info_from_scene_entity))
  get_raid_description = memoize(@(scene) get_entity_info_from_scene(scene, parse_raid_description_from_scene_entity))
  get_spawns = memoize(@(scene) get_entities_info_array_from_scene(scene, parse_spawn_from_scene))
  get_extractions = memoize(@(scene) get_entities_info_array_from_scene(scene, parse_extraction_from_scene))
  get_nexus_beacons = memoize(@(scene) get_entities_info_array_from_scene(scene, parse_nexus_beacons))
}
