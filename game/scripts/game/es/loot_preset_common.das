module loot_preset_common shared
require ecs
require ecs.safe
require math.random
require game.es.inventory_item_common
require DagorRandom
require DagorSystem
require DagorMath


def get_loot_preset_item_num_copies(itemObj)
  let probablyInt = get_int(itemObj, "number")
  if probablyInt != null
    return *probablyInt

  let probablyInt2 = get_IPoint2(itemObj, "number")
  if probablyInt2 != null
    return rnd_int(*probablyInt2)

  return 1


def get_loot_preset_item_weight(itemObj)
  return itemObj?.weight ?? 1.0


def is_loot_preset(itemObj)
  return (itemObj?.sub_preset ?? "") != ""


def get_loot_preset_item_template(itemObj)
  return itemObj?.template_name ?? (itemObj?.sub_preset ?? "")


def get_sub_preset_template(itemObj)
  return itemObj?.template_sub_preset ?? ""


def get_loot_preset_total_weight(loot_preset : ecs::Array)
  var sum = 0.0
  for item in loot_preset
    let weight = get_loot_preset_item_weight(item as Object)
    sum += weight
  return sum


def loot_preset_choose_one_index(chances : ecs::Array; total_weight : float; allowed_indices : array<int>)
  if length(allowed_indices) == 0
    return -1

  let rand = gfrnd()
  var normalizedSum = 0.0
  for index in allowed_indices
    assume item = chances[index] as Object
    let weight = get_loot_preset_item_weight(item)
    let normalizedWeight = weight / total_weight
    normalizedSum += normalizedWeight
    if normalizedSum >= rand
      return index

  return allowed_indices[0]


def loot_preset_generate_items(chances : ecs::Array;
                               min_items : int;
                               max_items : int;
                               allow_repetition : bool;
                               var capacity_occupied : float&;
                               cb : block<(item : array<string>) : void>)
  let totalWeight = get_loot_preset_total_weight(chances)
  let numItemsToGen = rnd_int(min_items, max_items)

  var allowedIndices : array<int>
  reserve(allowedIndices, length(chances))
  for index in range(length(chances))
    allowedIndices |> push(index)

  for _i in range(0, numItemsToGen)
    let index = loot_preset_choose_one_index(chances, totalWeight, allowedIndices)
    if index < 0
      break
    if !allow_repetition
      let i_index = find_index(allowedIndices, index)
      allowedIndices |> erase(i_index)
    assume itemObj = chances[index] as Object
    let templateName = get_loot_preset_item_template(itemObj)
    if empty(templateName)
      logerr("[Loot Drop System] Item template and sub preset is empty!")
      return

    if is_loot_preset(itemObj)
      loot_preset_generate(templateName, capacity_occupied, cb)
    else
      var getItemTemplate = getTemplateByName(templateName)
      if getItemTemplate == null
        getItemTemplate = buildTemplateByName(templateName)
      if getItemTemplate == null
        logerr("[Loot Drop System] Undefined item template - {templateName}!")
        return

      let genItemVolume = get_item_template_volume(*getItemTemplate)

      let num_copies = get_loot_preset_item_num_copies(itemObj)
      for _j in range(num_copies)
        var result : array<string>
        capacity_occupied += genItemVolume
        result |> push(templateName)
        let templateSubPreset = get_sub_preset_template(itemObj)
        if !empty(templateSubPreset)
          var capacitySubTemplate_occupied = 0.0
          loot_preset_generate(templateSubPreset, capacitySubTemplate_occupied) <| $(itemsArray)
            for item in itemsArray
              result |> push(item)
          capacity_occupied += capacitySubTemplate_occupied
        invoke(cb, result)


def add_expected_value_to_possible_item(item_template : string;
                                        value_added : float;
                                        var possible_items : table<string; float>; dbg : string = "")

  var found = false
  get(possible_items, item_template) <| $(var expectedValue : float&)
    found = true
    expectedValue += value_added
  if !found
    possible_items |> insert(item_template, value_added)


def loot_preset_get_all_possible_items(template_name : string)
  var result : table<string; float> // EV

  let templateInfo = getTemplateByName(template_name)
  if templateInfo == null
    logerr("[Loot Drop System] Trying to get all possible items of unknown template: <{template_name}>")
    return <- result

  let chances = get_ecs_array(getTemplateComponent(*templateInfo, "loot_preset__chances"))
  let totalWeight = get_loot_preset_total_weight(*chances)
  let numSamplesPointer = get_IPoint2(getTemplateComponent(*templateInfo, "loot_preset__numSamples"))
  let numSamples = numSamplesPointer ?? int2(length(*chances))
  let avgPresetSamples = float(numSamples.x + numSamples.y) * 0.5

  for item in *chances
    assume itemObj = item as Object
    let templateName = get_loot_preset_item_template(itemObj)
    if empty(templateName)
      logerr("[Loot Drop System] Item template and sub preset is empty!")
      return <- result

    let weight = get_loot_preset_item_weight(itemObj)
    let normalizedWeight = weight / totalWeight

    if is_loot_preset(itemObj)
      let subPresetItems = loot_preset_get_all_possible_items(templateName)
      for subItem, subExpectedValue in keys(subPresetItems), values(subPresetItems)
        add_expected_value_to_possible_item(subItem, normalizedWeight * subExpectedValue, result, "{template_name}/{templateName}/")
      continue

    var numItemSamples = 1.0
    let probablyInt = get_int(itemObj, "number")
    if probablyInt != null
      numItemSamples = float(*probablyInt)
    else
      let probablyInt2 = get_IPoint2(itemObj, "number")
      if probablyInt2 != null
        numItemSamples = (float((*probablyInt2).x) + float((*probablyInt2).y)) * 0.5

    let avgCopies = numItemSamples * avgPresetSamples
    add_expected_value_to_possible_item(templateName, normalizedWeight * avgCopies, result, "{template_name}/")

    let templateSubPreset = get_sub_preset_template(itemObj)
    if !empty(templateSubPreset)
      let subPresetItems = loot_preset_get_all_possible_items(templateSubPreset)
      for subItem, subExpectedValue in keys(subPresetItems), values(subPresetItems)
        add_expected_value_to_possible_item(subItem, normalizedWeight * subExpectedValue, result, "{template_name}/{templateSubPreset}/")

  return <- result


def loot_preset_generate(template_name : string;
                         var capacity_occupied : float&;
                         cb : block<(item : array<string>) : void>)
  capacity_occupied += 0.0 // TODO: Workaround hack to disable daScript RW warning (recursion calls don't recognize RW argument?)

  let templateInfo = getTemplateByName(template_name)
  if templateInfo == null
    logerr("[Loot Drop System] Trying to generate loot preset of unknown template: <{template_name}>")
  else
    let chances = get_ecs_array(getTemplateComponent(*templateInfo, "loot_preset__chances"))
    if chances == null
      logerr("[Loot Drop System] Empty chances for: <{template_name}>. Add empty 'loot_preset__chances' component instead dropping it")
      return
    let numSamplesPointer = get_IPoint2(getTemplateComponent(*templateInfo, "loot_preset__numSamples"))
    let numSamples = numSamplesPointer ?? int2(length(*chances))

    var minItems, maxItems : int
    minItems = numSamples[0]
    maxItems = numSamples[1]

    if minItems > maxItems || minItems < 0 || maxItems < 0
      logerr("[Loot Drop System] Wrong max and min items for template: <{template_name}>; min <{minItems}> max <{maxItems}>")
    else
      let repeat = get_bool(getTemplateComponent(*templateInfo, "loot_preset__allowRepeat")) ?? false
      loot_preset_generate_items(*chances, minItems, maxItems, repeat, capacity_occupied, cb)


def loot_preset_generate(template_name : string;
                         cb : block<(item : array<string>) : void>) : float
  if template_name == ""
    return 0.0

  var capacityOccupied = 0.0
  loot_preset_generate(template_name, capacityOccupied, cb)
  return capacityOccupied