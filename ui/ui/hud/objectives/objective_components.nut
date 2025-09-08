from "%ui/ui_library.nut" import *

let { sub_txt } = require("%ui/fonts_style.nut")
let { TextHighlight } = require("%ui/components/colors.nut")
let { secondsToStringLoc } = require("%ui/helpers/time.nut")
let { getTemplateComponent } = require("%ui/profile/profile_functions.nut")

let color_common = TextHighlight

let idxMarkHeight = 1.11 * calc_str_box($"{1}", sub_txt)[1]
let idxMarkDefaultSize = const [idxMarkHeight, idxMarkHeight]

let mkPic = memoize(@(hgt) Picture("ui/skin#round.svg:{0}:{0}:K".subst(hgt.tointeger())))

let mkObjectiveIdxMark = function(text, size, color, progress=1.0) {
  let textSize = calc_str_box(text, sub_txt)
  let canFitText = size[0] > 1.1 * textSize[0] && size[1] > 1.1 * textSize[1]
  let needProgress = (progress ?? 1.0) < 1.0 && progress > 0
  let fillColor = mul_color(color, 0.4)
  return {
    size
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    color
    fillColor = !needProgress ? fillColor : 0
    rendObj = ROBJ_VECTOR_CANVAS
    commands = const [
      [VECTOR_WIDTH, hdpxi(2)],
      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
    children = [
      needProgress ? {
        rendObj = ROBJ_PROGRESS_CIRCULAR
        image = mkPic(size[1].tointeger())
        size = size[1]
        fgColor = mul_color(color, 0.25, 4)
        bgColor = fillColor
        fValue = progress
      } : null,
      (text != "" && !canFitText) ? null : {
        rendObj = ROBJ_TEXT
        size
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        text
        color = color_common
        fontFx = FFT_SHADOW
        fontFxColor = Color(0,0,0)
      }.__update(sub_txt)
    ]
  }
}

let ordinaryContractsProgression = function(contract, progress=true) {
  let r = loc($"contract/{contract.name}/progress")
  if (!progress)
    return r
  return "".concat(r, $": {contract.currentValue}/{contract.requireValue}")
}

let mkWeaponTypesLoc = function(weaponTypes) {
  if (weaponTypes == null)
    return null

  return ", ".join(weaponTypes.map(@(weaponType) loc($"items/types/{weaponType}")))
}

let killContractsProgression = function(contract, progress=true) {
  let r = loc($"contract/{contract.name}/progress", {
    regionName = loc($"region/{contract.params?.regionName[0]}")
    weaponType=mkWeaponTypesLoc(contract.params?.weaponType)
  })
  if (!progress)
    return r
  return "".concat(r, $": {contract.currentValue}/{contract.requireValue}")
}

let itemsContractsProgression = function(contract, progress=true) {
  let r = loc($"contract/{contract.name}/progress", {
    itemName = loc(getTemplateComponent(contract.params?.itemTemplate[0], "item__name") ?? "")
  })
  if (!progress)
    return r
  return "".concat(r, $": {contract.currentValue}/{contract.requireValue}")
}

let contractsProgressionFunc = {
  ["objective_stay_alive"] = function(contract, progress=true) {
    let r = loc($"contract/{contract.name}/progress")
    if (!progress)
      return r
    let currentValue = contract.currentValue > 0.0 ? secondsToStringLoc(contract.currentValue) : "0s"
    let requireValue = secondsToStringLoc(contract.requireValue)
    return "".concat(r, $": {currentValue}/{requireValue}")
  },
  ["objective_kill_with_tag"] = killContractsProgression,
  ["objective_kill_with_tag_and_zone"] = killContractsProgression,
  ["objective_kill_with_tag_pvp"] = killContractsProgression,
  ["objective_collect_item_with_name"] = itemsContractsProgression,
  ["objective_plant_item"] = itemsContractsProgression,
  ["objective_extract_item"] = itemsContractsProgression,
  ["objective_collect_item_with_tag"] = function(contract, progress=true) {
    let itemTags = contract.params?["itemTag"] ?? []
    if (itemTags.len() == 1 && type(itemTags[0]) == "string") {
      let r = loc($"contract/{contract.name}/progress", {
        itemType = loc(itemTags[0])
      })
      if (!progress)
        return r
      return "".concat(r, $": {contract.currentValue}/{contract.requireValue}")
    }
    else {
      let r = loc($"contract/{contract.name}/progress/generic")
      if (!progress)
        return r
      return "".concat(r, $": {contract.currentValue}/{contract.requireValue}")
    }
  }
}

let getContractProgressionText = @(contract, showprogress=true) contractsProgressionFunc?[contract.handledByGameTemplate](contract, showprogress) ?? ordinaryContractsProgression(contract, showprogress)

return {
  color_common
  mkObjectiveIdxMark
  idxMarkDefaultSize
  getContractProgressionText
  idxMarkHeight
}
