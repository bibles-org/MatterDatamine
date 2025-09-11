from "%ui/fonts_style.nut" import sub_txt, tiny_txt
from "%ui/components/itemTypeIcon.nut" import mkItemTypeIco
from "%ui/components/controlHudHint.nut" import controlHudHint, mkHasBinding
from "das.inventory" import can_pickup_item, is_autoequip_cause_inventory_overflow
from "%ui/components/colors.nut" import HUD_TIPS_HOTKEY_FG, HudTipFillColor, InfoTextValueColor

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let { carriedVolume, maxVolume } = require("%ui/hud/state/inventory_common_es.nut")
let { rarityColorTable } = require("%ui/hud/menus/components/inventoryItemRarity.nut")

#allow-auto-freeze


let itemUnpickableByVolumeFontColor = Color(186,68,98,255)
let textDefColor                    = Color(255,255,255)



let itemUsefulMarkWidth = hdpx(4)

let defTransform = {}
let mkLabel = memoize(@(text, textColor) {
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    font = sub_txt.font
    fontSize = sub_txt.fontSize
    text
    color = textColor
  }
)

let itemTypeHeight = calc_str_box("F", tiny_txt)[1]

let mkIco = memoize(@(ico) ico!=null
  ? {image = ico, size = [itemTypeHeight, itemTypeHeight] rendObj = ROBJ_IMAGE, color=HUD_TIPS_HOTKEY_FG}
  : null
)

let mkItemInfo = function(text, text_color, item_type, item_weap_type_height, count) {
  let labelText = "{0}{1}".subst(text, (count ?? 0) > 1 ? $" {loc("ui/multiply")}{count}" : "")
  let label = mkLabel(labelText, text_color)
  let ico = mkItemTypeIco(item_type, item_weap_type_height)
  return {
    flow = FLOW_HORIZONTAL
    halign = ALIGN_CENTER
    children = [mkIco(ico), label]
    gap = hdpx(5)
  }
}

let pickupTip = @(promt) {
  id = "Human.Use",
  name = loc(promt != null && promt != "" ? promt : "hud/onlyPickup")
  text_params = tiny_txt
}

let searchTip = @(promt) {
  id = "Human.UseAlt",
  name = loc(promt)
  text_params = tiny_txt
}

function actionTip(params, textColor) {
  let hasBinding = mkHasBinding(params.id)
  let inputHint = controlHudHint(params)
  let name = {
    rendObj = ROBJ_TEXT
    text = params.name
    color = textColor
  }.__update(params.text_params)
  return @() {
    watch = hasBinding
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    gap = hdpx(5)
    children = hasBinding.get() ? [inputHint, name] : name
  }
}

let item_ctor = function(eid, marker) {
  local {maxDistance, volume, count, ammoCount, weapType, lootType, nickname, text, useActionPrompt, useAltActionPrompt, rarity} = marker
  text = count > 0 || (nickname ?? "") != "" ? loc(text, {count = count, nickname = nickname}) : loc(text)
  let watchedCanCarry = volume > 0 ? Computed(function() {
    return maxVolume.get() - carriedVolume.get() >= volume }) : null

  return function() {
    let heroEid = watchedHeroEid.get() ?? ecs.INVALID_ENTITY_ID
    let badgeColor = rarityColorTable?[rarity] ?? textDefColor
    let can_pickup = can_pickup_item(eid, heroEid) && !is_autoequip_cause_inventory_overflow(eid)
    let textColor = can_pickup ? InfoTextValueColor : itemUnpickableByVolumeFontColor
    let itemBlock = mkItemInfo(
      text,
      can_pickup ? textDefColor : itemUnpickableByVolumeFontColor,
      weapType ?? lootType,
      itemTypeHeight,
      ammoCount
    )

    let usefulMarker = {
      size = [itemUsefulMarkWidth, flex()]
      vplace = ALIGN_TOP
      hplace = ALIGN_LEFT
      rendObj = ROBJ_SOLID
      color = badgeColor
    }
    return {
      data = {
        eid
        minDistance = 0.1
        maxDistance
        clampToBorder = true
        yOffs = 0.07
      }
      rendObj = ROBJ_WORLD_BLUR_PANEL,
      fillColor = HudTipFillColor
      markerFlags = DngBhv.MARKER_SHOW_ONLY_IN_VIEWPORT
      gap = hdpx(5)
      flow = FLOW_HORIZONTAL
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      transform = defTransform
      pos = static [0, -fsh(2)]
      borderRadius = static [0, hdpx(4), hdpx(4), 0]
      key = eid
      watch = [watchedCanCarry, watchedHeroEid]
      children = [
        usefulMarker,
        {
          flow = FLOW_VERTICAL
          padding = static [hdpx(5), hdpx(10), hdpx(5), hdpx(5)]
          gap = hdpx(2)
          children = [
            itemBlock,
            actionTip(pickupTip(useActionPrompt), textColor),
            useAltActionPrompt != null && useAltActionPrompt.len() > 0 ? actionTip(searchTip(useAltActionPrompt), textDefColor) : null
          ]
        }
      ]
    }
  }
}

return {
  item_ctor = item_ctor
}
