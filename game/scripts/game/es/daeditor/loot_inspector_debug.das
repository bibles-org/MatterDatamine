options no_aot

require ecs
require ecs.common
require ecs.safe
require imgui/imgui_boost
require daslib/safe_addr
require daslib/strings_boost
require game.es.am_debug_draw_common
require active_matter.game.es.moving_zone_common
require DagorImgui
require math.base
require DngCamera
require danetlibs.imgui_daeditor.daEditor.daEditor_common
require active_matter.game.es.loot_preset_common


struct LootPresetInfo
  presetName : string
  entity : EntityId
  transform : float3x4


struct LootItemPerPresetInfo
  presetName : string
  itemExpectedValue : float


struct LootItemSceneInfo
  perPresetInfo : array<LootItemPerPresetInfo>
  totalExpectedValue : float


def get_template_rarity(item_template : string)
  let templateInfo = getTemplateByName(item_template)
  if templateInfo == null
    return "unknown"
  let rarity = getTemplateComponent(*templateInfo, "item__rarity") ?? "unknown"
  return string(rarity)


def get_rarity_color(rarity : string)
  if rarity == "epic"
    return IM_COL32(230, 110, 250, 255)
  if rarity == "rare"
    return IM_COL32(60, 100, 150, 255)
  if rarity == "uncommon"
    return IM_COL32(80, 130, 80, 255)
  return IM_COL32(101, 101, 101, 255)


def draw_item_rarity(item_template)
  let rarString = get_template_rarity(item_template)
  imgui::PushStyleColor(imgui::ImGuiCol.Text, get_rarity_color(rarString))
  imgui::Text("{rarString}")
  imgui::PopStyleColor()


def make_loot_preset_info(eid : EntityId; preset_name : string; transform : float3x4)
  return LootPresetInfo(presetName = preset_name, entity = eid, transform = transform)


def draw_loot_preset(tm : float3x4; color : E3DCOLOR; preset_name : string)
  draw_debug_tm_buffered(tm, color, 1)
  draw_debug_text_mark_buffered(tm[3], preset_name, 1, E3DCOLOR(0xffffffff))


def get_loot_inspector(cb : block<(eid : EntityId) : void>)
  let exists = find_query() <| $ [es(REQUIRE=loot_inspector__nearbyDistance)] (eid : EntityId)
    cb(eid)
    return true
  if !exists
    let eid = createEntitySync("loot_inspector")
    cb(eid)


def process_loot_inspector_params(var loot_inspector__nearbyDistance : float&)
  let step = 1f
  let fastStep = 10f
  var toEdit = loot_inspector__nearbyDistance

  imgui::PushItemWidth(100.0f)
  imgui::InputScalar("Nearby distance##LOOT_INSPECTOR_NEARBY_DISTANCE", ImGuiDataType.Float, safe_addr(toEdit), safe_addr(step), safe_addr(fastStep), "%.1f", ImGuiInputTextFlags.None)
  loot_inspector__nearbyDistance = toEdit


def select_preset_for_inspection(preset_name : string)
  find_query() <| $ [es] (var loot_inspector__inspectedPreset : das_string&;
                          var loot_inspector__lastGeneratedSample : StringList)
    loot_inspector__inspectedPreset := preset_name
    clear(loot_inspector__lastGeneratedSample)
    return true


def draw_preset_line(preset_name)
  if imgui::Button("Inspect##loot_inspector_select_preset_button{preset_name}")
    select_preset_for_inspection(preset_name)
  imgui::SameLine()
  imgui::Text("\"{preset_name}\"")


def gather_presets_data(loot_inspector__nearbyDistance : float;
                        camPos : float3;
                        movingZone : MovingZone;
                        var lootPresets : array<LootPresetInfo>;
                        var nearbyPresets : array<LootPresetInfo>;
                        var uniqueLootPresets : table<string; int>)
  let zoneRadiusSq = square(movingZone.radius)
  let processPresetEntity = $ <| (eid : EntityId; preset_name : string; transform : float3x4)
    if preset_name == ""
      return
    if distance_sq(transform[3], movingZone.pos) > zoneRadiusSq
      return
    if distance_sq(transform[3], camPos) < square(loot_inspector__nearbyDistance)
      draw_loot_preset(transform, ATBLUE, preset_name)
      push(nearbyPresets, make_loot_preset_info(eid, preset_name, transform))

    push(lootPresets, make_loot_preset_info(eid, preset_name, transform))
    if !key_exists(uniqueLootPresets, preset_name)
      insert(uniqueLootPresets, preset_name, 1)
    else
      get(uniqueLootPresets, preset_name) <| $(var cnt : int&)
        cnt += 1

  query() <| $ [es] (eid : EntityId; loot_drop_system__lootPreset : string; transform : float3x4)
    processPresetEntity(eid, loot_drop_system__lootPreset, transform)
  query() <| $ [es] (eid : EntityId; loot_generator__lootPreset : string; transform : float3x4)
    processPresetEntity(eid, loot_generator__lootPreset, transform)

  sort(nearbyPresets) <| $(a, b)
    return distance_sq(a.transform[3], camPos) < distance_sq(b.transform[3], camPos)


def draw_presets_data(lootPresets : array<LootPresetInfo>;
                      nearbyPresets : array<LootPresetInfo>;
                      uniqueLootPresets : table<string; int>)
  imgui::Text("Gathered {length(lootPresets)} loot preset entities with {length(uniqueLootPresets)} unique loot presets")
  if imgui::TreeNodeEx("Nearby loot presets ({length(nearbyPresets)})##NEARBYLOOTPRESETLIST", ImGuiTreeNodeFlags.None)
    for nearbyPreset in nearbyPresets
      if imgui::Button("{nearbyPreset.entity}##loot_inspector_select_eid_button{nearbyPreset.entity}")
        editor_select_eid(nearbyPreset.entity)
      imgui::SameLine()
      draw_preset_line(nearbyPreset.presetName)
    imgui::TreePop()

  if imgui::TreeNodeEx("All unique presets ({length(uniqueLootPresets)})##ALL_UNIQUE_LOOT_PRESETS", ImGuiTreeNodeFlags.None)
    find_query() <| $ [es] (var loot_inspector__presetNameFilter : das_string&)
      imgui::Text("Filter presets by name")
      imgui::SameLine()
      var nameFilterBuffer = new ImGuiInputTextBuffer(string(loot_inspector__presetNameFilter), 1024)
      imgui::PushItemWidth(100.0f)
      InputText("##LOOT_INSPECTOR_UNIQUE_PRESET_FILTER", *nameFilterBuffer)
      loot_inspector__presetNameFilter := to_string(*nameFilterBuffer)

      var sortedPresets : array<string>
      reserve(sortedPresets, length(uniqueLootPresets))
      for preset in keys(uniqueLootPresets)
        if length(loot_inspector__presetNameFilter) > 0 && find(preset, string(loot_inspector__presetNameFilter)) == -1
          continue
        push(sortedPresets, preset)
      sort(sortedPresets)
      for preset in sortedPresets
        draw_preset_line(preset)
      return true

    imgui::TreePop() // All unique presets


def gather_possible_items_data(uniqueLootPresets : table<string; int>;
                               var scenePossibleItemsData : table<string; LootItemSceneInfo>)
  for preset, presetCnt in keys(uniqueLootPresets), values(uniqueLootPresets)
    let possibleItems = loot_preset_get_all_possible_items(preset)
    for itemTemplate, itemExpectedValue in keys(possibleItems), values(possibleItems)
      let mainTemplate = (itemTemplate |> split("+"))[0]
      if !key_exists(scenePossibleItemsData, mainTemplate)
        scenePossibleItemsData[mainTemplate] = LootItemSceneInfo()

      get(scenePossibleItemsData, mainTemplate) <| $(var info : LootItemSceneInfo)
        push(info.perPresetInfo, LootItemPerPresetInfo(presetName = preset, itemExpectedValue = itemExpectedValue))
        info.totalExpectedValue += itemExpectedValue * float(presetCnt)


def draw_possible_items_data(scenePossibleItems : table<string; LootItemSceneInfo>;
                             uniqueLootPresets : table<string; int>;
                             var loot_inspector__selectedRarities : StringList;
                             var loot_inspector__itemTemplateFilter : das_string&)
  // TODO: filters by type
  if imgui::TreeNodeEx("All possible items ({length(scenePossibleItems)})##ALL_POSSIBLE_ITEMS_IN_LOOT_PRESETS", ImGuiTreeNodeFlags.None)
    imgui::Text("Filter items by name")
    imgui::SameLine()
    var templateNameFilterBuffer = new ImGuiInputTextBuffer(string(loot_inspector__itemTemplateFilter), 1024)
    imgui::PushItemWidth(100.0f)
    InputText("##LOOT_INSPECTOR_TEMPLATE_NAME_FILTER", *templateNameFilterBuffer)
    loot_inspector__itemTemplateFilter := to_string(*templateNameFilterBuffer)

    let allRarities = fixed_array("common", "uncommon", "rare", "epic")
    var allowedRarities : array<string>
    for rarity in allRarities
      let alreadyHas = has_value(loot_inspector__selectedRarities, rarity)
      var wantToHave = alreadyHas
      imgui::SameLine()
      imgui::Checkbox("{rarity}##LOOT_INSPECTOR_RARITY_FILTER{rarity}", safe_addr(wantToHave))
      if !alreadyHas && wantToHave
        push(loot_inspector__selectedRarities, rarity)
      if alreadyHas && !wantToHave
        let idx = find_index(loot_inspector__selectedRarities, rarity)
        if idx >= 0
          erase(loot_inspector__selectedRarities, idx)

      if wantToHave
        push(allowedRarities, rarity)

    var sortedTemplates : array<string>
    reserve(sortedTemplates, length(scenePossibleItems))
    for itemTemplate in keys(scenePossibleItems)
      push(sortedTemplates, itemTemplate)
    sort(sortedTemplates)
    var totalEv = 0.0
    for itemTemplate in sortedTemplates
      if length(loot_inspector__itemTemplateFilter) > 0 && find(itemTemplate, string(loot_inspector__itemTemplateFilter)) == -1
        continue
      if !empty(allowedRarities)
        let rarity = get_template_rarity(itemTemplate)
        if !has_value(allowedRarities, rarity)
          continue
      get(scenePossibleItems, itemTemplate) <| $(info : LootItemSceneInfo)
        totalEv += info.totalExpectedValue
        if imgui::TreeNodeEx("EV={fmt(":.3f", info.totalExpectedValue)}   \"{itemTemplate}\"##ALL_POSSIBLE_ITEMS_IN_LOOT_PRESETS{itemTemplate}")
          imgui::SameLine()
          draw_item_rarity(itemTemplate)
          for presetInfo in info.perPresetInfo
            get(uniqueLootPresets, presetInfo.presetName) <| $(presetCnt : int&)
              imgui::Text("{fmt(":.3f", presetInfo.itemExpectedValue)} * {presetCnt}")
              imgui::SameLine()
            draw_preset_line(presetInfo.presetName)
          imgui::TreePop() // concrete item
        else
          imgui::SameLine()
          draw_item_rarity(itemTemplate)
    imgui::Text("Total EV of shown items: {fmt(":.3f", totalEv)}")
    imgui::TreePop() // All possible items


def draw_preset_tree(preset : string; depth : int = 0; accumulated_prob : float = 1.0)
  let templateInfo = getTemplateByName(preset)
  if templateInfo == null
    imgui::Text("\"{preset}\" [!INCORRECT TEMPLATE]")
    return

  let chances = get_ecs_array(getTemplateComponent(*templateInfo, "loot_preset__chances"))
  if imgui::TreeNodeEx("\"{preset}\" ({length(*chances)})##DRAW_PRESET_TREE-{depth}-{preset}")
    let totalWeight = get_loot_preset_total_weight(*chances)
    let numSamplesPointer = get_IPoint2(getTemplateComponent(*templateInfo, "loot_preset__numSamples"))
    let numSamples = numSamplesPointer ?? int2(length(*chances))
    let avgPresetSamples = float(numSamples.x + numSamples.y) * 0.5
    let repeat = get_bool(getTemplateComponent(*templateInfo, "loot_preset__allowRepeat")) ?? false

    imgui::Text("samples: {numSamples.x} - {numSamples.y} (avg: {avgPresetSamples})")
    imgui::SameLine()
    imgui::Text("allow repeat: {repeat}")
    for item in *chances
      assume itemObj = item as Object
      let templateName = get_loot_preset_item_template(itemObj)
      if empty(templateName)
        continue
      let weight = get_loot_preset_item_weight(itemObj)
      let normalizedWeight = weight / totalWeight

      let accumulatedProb = depth == 0 ? "" : "[{fmt(":.2f", normalizedWeight * accumulated_prob)}]"
      let localProb = "[{fmt(":.2f", normalizedWeight)}]"
      if is_loot_preset(itemObj)
        imgui::Text("{accumulatedProb}{localProb}")
        imgui::SameLine()
        draw_preset_tree(templateName, depth + 1, normalizedWeight * accumulated_prob)
        continue
      imgui::Text("{accumulatedProb}{localProb} {templateName}")
      imgui::SameLine()
      draw_item_rarity(templateName)
      let probablyInt = get_int(itemObj, "number")
      if probablyInt != null
        imgui::SameLine()
        imgui::Text("x{*probablyInt}")
      else
        let probablyInt2 = get_IPoint2(itemObj, "number")
        if probablyInt2 != null
          imgui::SameLine()
          imgui::Text("x{(*probablyInt2).x} - {(*probablyInt2).y}")


      let templateSubPreset = get_sub_preset_template(itemObj)
      if !empty(templateSubPreset)
        imgui::Text("+ ")
        imgui::SameLine()
        draw_preset_tree(templateSubPreset, depth + 1, normalizedWeight * accumulated_prob)

    imgui::TreePop()


def draw_preset_loot_generator(preset : string)
  imgui::NewLine()
  imgui::Text("Loot sample generator")
  find_query() <| $ [es] (var loot_inspector__lastGeneratedSample : StringList)
    if imgui::Button("Generate sample")
      clear(loot_inspector__lastGeneratedSample)
      loot_preset_generate(preset) <| $(items)
        for item in items
          loot_inspector__lastGeneratedSample |> push(item)
    imgui::SameLine()
    if imgui::Button("Clear")
      clear(loot_inspector__lastGeneratedSample)

    var uniqueItems : table<string; int>
    for item in loot_inspector__lastGeneratedSample
      if !key_exists(uniqueItems, string(item))
        insert(uniqueItems, string(item), 1)
      else
        get(uniqueItems, string(item)) <| $(var cnt : int&)
          cnt += 1

    var sortedItems : array<string>
    reserve(sortedItems, length(uniqueItems))
    for item in keys(uniqueItems)
      push(sortedItems, item)
    sort(sortedItems)
    for item in sortedItems
      get(uniqueItems, string(item)) <| $(var cnt : int&)
        draw_item_rarity(item)
        imgui::SameLine()
        imgui::Text("{item} ({cnt})")

    return true


def draw_preset_entities(preset : string; lootPresets : array<LootPresetInfo>)
  imgui::NewLine()
  var entitiesWithPreset : array<EntityId>
  for lootPreset in lootPresets
    if lootPreset.presetName == preset
      push(entitiesWithPreset, lootPreset.entity)
  if imgui::TreeNodeEx("Entities with preset \"{preset}\" ({length(entitiesWithPreset)})##ENTITIES_WITH_PRESET{preset}", ImGuiTreeNodeFlags.None)
    sort(entitiesWithPreset) <| $(a, b)
      return uint(a) < uint(b)
    for eid in entitiesWithPreset
      if imgui::Button("{eid}##loot_inspector_select_eid_button{eid}")
        editor_select_eid(eid)
      imgui::SameLine()
      imgui::Text("{getEntityTemplateName(eid)}")
    imgui::TreePop()


def draw_preset_all_loot(preset : string)
  let possibleItems = loot_preset_get_all_possible_items(preset)
  imgui::NewLine()
  if imgui::TreeNodeEx("All possible items in \"{preset}\" ({length(possibleItems)})##ALL_POSSIBLE_ITEMS_IN_PRESET{preset}", ImGuiTreeNodeFlags.None)
    find_query() <| $ [es] (var loot_inspector__presetAllItemsFilter : das_string&)
      imgui::Text("Filter presets by name")
      imgui::SameLine()
      var nameFilterBuffer = new ImGuiInputTextBuffer(string(loot_inspector__presetAllItemsFilter), 1024)
      imgui::PushItemWidth(100.0f)
      InputText("##LOOT_INSPECTOR_UNIQUE_PRESET_FILTER", *nameFilterBuffer)
      loot_inspector__presetAllItemsFilter := to_string(*nameFilterBuffer)
      for itemTemplate, itemExpectedValue in keys(possibleItems), values(possibleItems)
        if length(loot_inspector__presetAllItemsFilter) > 0 && find(itemTemplate, string(loot_inspector__presetAllItemsFilter)) == -1
          continue
        draw_item_rarity(itemTemplate)
        imgui::SameLine()
        imgui::Text("{itemTemplate}: EV=({fmt(":.5f", itemExpectedValue)})")

      return true

    imgui::TreePop()



def draw_inspected_preset(preset : string; lootPresets : array<LootPresetInfo>)
  if preset == ""
    imgui::Text("No preset selected")
    return
  imgui::Text("Loot preset inspector for \"{preset}\"")

  draw_preset_tree(preset)
  draw_preset_all_loot(preset)
  draw_preset_entities(preset, lootPresets)
  draw_preset_loot_generator(preset)


[imgui_window(name="Loot inspector", group="AM")]
def loot_inspector_window()
  if IsWindowCollapsed()
    return

  let movingZone = get_target_moving_zone()

  get_loot_inspector() <| $(inspector : EntityId)
    var camPos = float3()
    query(get_cur_cam_entity()) <| $ [es] (transform : float3x4)
      camPos = transform[3]

    query(inspector) <| $ [es] (var loot_inspector__nearbyDistance : float&;
                                var loot_inspector__itemTemplateFilter : das_string&;
                                var loot_inspector__selectedRarities : StringList;
                                loot_inspector__inspectedPreset : string)
      ImGuiEx_BeginColumn()
      process_loot_inspector_params(loot_inspector__nearbyDistance)

      var lootPresets : array<LootPresetInfo>
      var nearbyPresets : array<LootPresetInfo>
      var uniqueLootPresets : table<string; int>
      gather_presets_data(loot_inspector__nearbyDistance, camPos, movingZone, lootPresets, nearbyPresets, uniqueLootPresets)
      draw_presets_data(lootPresets, nearbyPresets, uniqueLootPresets)

      var scenePossibleItemsData : table<string; LootItemSceneInfo>
      gather_possible_items_data(uniqueLootPresets, scenePossibleItemsData)
      draw_possible_items_data(scenePossibleItemsData, uniqueLootPresets, loot_inspector__selectedRarities, loot_inspector__itemTemplateFilter)

      ImGuiEx_NextColumn()

      draw_inspected_preset(loot_inspector__inspectedPreset, lootPresets)

      ImGuiEx_EndColumn()
