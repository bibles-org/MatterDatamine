import "%dngscripts/ecs.nut" as ecs

from "%ui/fonts_style.nut" import body_txt
from "%ui/components/colors.nut" import ConsoleFillColor, ConsoleBorderColor
from "%ui/mainMenu/ribbons_colors_state.nut" import arrayToColor, indexToColor
from "%ui/components/cursors.nut" import setTooltip
from "%ui/hud/menus/components/inventoryStyle.nut" import itemHeight
from "das.ribbons_color" import get_available_colors, get_color_name_by_index, get_primary_color_of_hero, get_secondary_color_of_hero, get_color_idx_of_player, get_color_idx_of_hero
from "%ui/components/commonComponents.nut" import mkTitleString
from "%ui/profile/profileState.nut" import teamColorIdxsUpdate, playerStats
from "%ui/components/modalPopupWnd.nut" import addModalPopup, removeModalPopup
from "%ui/components/msgbox.nut" import showMsgbox
from "%ui/profile/ribbonState.nut" import saveRibbons
import "%ui/components/faComp.nut" as faComp

from "%ui/ui_library.nut" import *
from "%ui/components/colors.nut" import BtnBdNormal, BtnBdHover, BtnBdSelected, TextNormal
from "%ui/components/button.nut" import button

let JB = require("%ui/control/gui_buttons.nut")
let { ribbonsChanged } = require("%ui/mainMenu/ribbons_colors_state.nut")
let { isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")
let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let { isNexusWaveMode, isNexusRoundMode, nexusModeTeamColors, isNexus } = require("%ui/hud/state/nexus_mode_state.nut")
let { teamColorIdxs } = require("%ui/profile/profileState.nut")
let { currentMenuId } = require("%ui/hud/hud_menus_state.nut")
let { mutationForbidenDueToInQueueState } = require("%ui/hud/state/inventory_state.nut")

const RibbonsMenuId = "RibbonsMenuId"
let close = @() removeModalPopup(RibbonsMenuId)

let colorRowSize = 4

let sound = freeze({
  click  = "ui_sounds/button_click"
  hover  = "ui_sounds/button_highlight"
  active = "ui_sounds/button_action"
})

function mkColorLoc(index) {
  return loc($"ribbon/{get_color_name_by_index(index)}")
}

function mkColorButton(index, color_key) {
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName("ribbon_colors")
  let countOfSimpleColors = template?.getCompValNullable("ribbon_colors__colors").getAll().len() ?? 0

  let stateFlags = Watched(0)
  let colorComp = @() {size = static [hdpx(100), hdpx(25)] fillColor = index!=-1 ? indexToColor(index) : Color(178,178,178,255) rendObj = ROBJ_BOX borderColor = Color(70,70,70,120) borderWidth = 1}
  return function(){
    let sf = stateFlags.get()
    local isSelected = index == teamColorIdxs.get()[color_key]

    if (teamColorIdxs.get()["primary"] >= countOfSimpleColors)
      isSelected = false

    return {
      watch = [stateFlags, teamColorIdxs]
      onElemState = @(s) stateFlags.set(s)
      behavior = Behaviors.Button
      padding = hdpx(5)
      rendObj = ROBJ_BOX
      children = colorComp
      fillColor = 0

      borderColor = sf & S_HOVER
        ? BtnBdHover
        : isSelected ? BtnBdSelected : BtnBdNormal
      onClick = function() {
        teamColorIdxsUpdate(teamColorIdxs.get().__merge({[color_key] = index}))
        saveRibbons()
      }
      onHover = @(on) setTooltip(on ? mkColorLoc(index) : null)
      borderWidth = isSelected || (sf & S_HOVER) ? hdpx(2) : 0
      sound
    }
  }
}

let mkColorChoices = @(color_key) {
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = get_available_colors()
    .map(@(_, i) i)
    .reduce(function(result, item) {
      if (result[result.len() - 1].len() < colorRowSize) {
          result[result.len() - 1].append(item)
      }
      else {
        result.append([item])
      }
      return result
    },
    [ [-1] ]
  ).map(@(row) {
    gap = hdpx(10)
    flow = FLOW_HORIZONTAL
    children = row.map(@(index) mkColorButton(index, color_key))
  })
}


function mkPatternChoice() {
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName("ribbon_colors")
  let patterns = template?.getCompValNullable("ribbon_colors__patterns").getAll() ?? []
  let countOfSimpleColors = template?.getCompValNullable("ribbon_colors__colors").getAll().len() ?? 0
  let neededUnlocks = template?.getCompValNullable("ribbon_colors__patternUnlocks").getAll() ?? []
  function mkPictureOfPattern(patternTextureName, idx) {
    let stateFlags = Watched(0)
    return function(){
      let playerUnlocks = playerStats.get()?.unlocks ?? []
      let hasPatterns = playerUnlocks.findindex(@(v) v == neededUnlocks[idx]) != null
      let pattern = {
        rendObj = ROBJ_IMAGE
        image = Picture($"!ui/uiskin/ribbon_patterns/{patternTextureName}.avif")
        size = [ hdpx(100), hdpx(25) ]
        picSaturate = hasPatterns ? 1 : 0.25
      }

      let sf = stateFlags.get()
      let index = countOfSimpleColors + idx
      let isSelected = index == teamColorIdxs.get()["primary"]

      return {
        watch = [stateFlags, teamColorIdxs, playerStats]
        onElemState = @(s) stateFlags.set(s)
        behavior = Behaviors.Button
        padding = hdpx(5)
        rendObj = ROBJ_BOX
        children = [
          pattern
          hasPatterns ? null : {
            hplace = ALIGN_CENTER
            vplace = ALIGN_CENTER
            children = faComp("lock")
            eventPassThrough = true
          }
        ]
        fillColor = 0

        borderColor = sf & S_HOVER
          ? BtnBdHover
          : isSelected ? BtnBdSelected : BtnBdNormal
        onClick = function() {
          if (!hasPatterns) {
            if (neededUnlocks[idx] == "unlock_extended_ribbons_color") {
              showMsgbox({ text = loc("ribbon/unavailablePattern/premiumEdition") })
            }
            else {
              showMsgbox({ text = loc("ribbon/unavailablePattern") })
            }
            return
          }
          teamColorIdxsUpdate(teamColorIdxs.get().__merge({["primary"] = index}))
          saveRibbons()
        }
        onHover = @(on) setTooltip(on ? loc("ribbon/pattern") : null)
        borderWidth = isSelected || (sf & S_HOVER) ? hdpx(2) : 0
        sound
      }
    }
  }

  local children = []
  let countPerRow = 4
  for (local i = 0; i < patterns.len(); i+=countPerRow) {
    children.append({
      flow = FLOW_HORIZONTAL
      gap = hdpx(10)
      hplace = ALIGN_CENTER
      children = patterns.slice(i, i+countPerRow).map(@(v, idx) mkPictureOfPattern(v, i + idx))
    })
  }
  return {
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children
  }
}


let mkColorPickerHeader = @(text) {
  rendObj = ROBJ_TEXT
  text
  hplace = ALIGN_CENTER
  color = TextNormal
}.__update(body_txt)

let colorPickerModalContents = {
  flow = FLOW_VERTICAL
  gap = hdpx(5)
  halign = ALIGN_CENTER
  children = [
    mkTitleString(loc("choseRibbonsColor"))
    mkColorPickerHeader(loc("choseRibbonsPattern"))
    mkPatternChoice()
    mkColorPickerHeader(loc("ribbonsPrimaryColor", "Primary"))
    mkColorChoices("primary")
    mkColorPickerHeader(loc("ribbonsSecondaryColor", "Secondary"))
    mkColorChoices("secondary")
  ]
}

let animations = freeze([
  { prop=AnimProp.scale, from=[1.2, 1.2], duration=0.1, play=true, easing=InCubic }
  { prop=AnimProp.opacity, from=0, to=1, duration=0.3, play=true, easing=OutCubic }
  { prop=AnimProp.scale, to=[0, 0], duration=0.3, playFadeOut=true, easing=OutCubic }
  { prop=AnimProp.opacity, from=1, to=0, duration=0.3, playFadeOut=true, easing=OutCubic }
])

function mkRibbonColorPickerWnd() {
  if (currentMenuId.get() != "Inventory" && currentMenuId.get() != "Missions/PREPARATION_SUBMENU_ID") {
    return null
  }

  return {
    uid = RibbonsMenuId
    behavior = Behaviors.Button
    onClick = close
    padding = hdpx(2)
    popupOffset = hdpx(4)
    hotkeys = [[$"^J:Start | {JB.B} | Esc", { action = close, description = loc("Cancel") }]]
    borderWidth = hdpx(2)
    borderColor =  mul_color(ConsoleBorderColor, 0.3)
    borderRadius = 0
    children = {
      rendObj = ROBJ_WORLD_BLUR_PANEL
      behavior = Behaviors.Button
      fillColor = ConsoleFillColor
      flow = FLOW_VERTICAL
      padding = static [0, hdpx(10), hdpx(10), hdpx(10)]
      transform = {}
      animations
      children = colorPickerModalContents
    }
  }
}



let stateFlags = Watched(0)

function ribbonsBackground() {
  let [primc = null, secc = null] = isNexus.get() ? nexusModeTeamColors.get() : []
  let primRibonColor = primc ?? arrayToColor(get_primary_color_of_hero(watchedHeroEid.get()))
  let secondRibonColor = secc ?? arrayToColor(get_secondary_color_of_hero(watchedHeroEid.get()))

  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName("ribbon_colors")
  let countOfSimpleColors = template?.getCompValNullable("ribbon_colors__colors").getAll().len() ?? 0
  let textureIdx = get_color_idx_of_hero(watchedHeroEid.get()).x - countOfSimpleColors

  local currentPattern = null
  if (textureIdx >= 0) {
    let patterns = template?.getCompValNullable("ribbon_colors__patterns").getAll() ?? {}
    currentPattern = patterns[textureIdx]
  }

  return {
    watch = [ribbonsChanged, nexusModeTeamColors, watchedHeroEid, isNexus]
    size = flex()
    rendObj = ROBJ_MASK
    image = Picture("ui/skin#ribbons_mask.svg:{0}:{0}:K".subst(hdpx(64)))
    margin = hdpx(1)
    children = currentPattern ? {
      size = flex()
      rendObj = ROBJ_IMAGE
      keepAspect = KEEP_ASPECT_FILL
      image = Picture($"!ui/uiskin/ribbon_patterns/{currentPattern}.avif")
    } : {
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      commands = [
        [ VECTOR_WIDTH, 0 ],
        [ VECTOR_COLOR, Color(0,0,0,0)],
        [ VECTOR_FILL_COLOR, primRibonColor ],
        [ VECTOR_POLY, 0,0, 100,0, 0,100 ],
        [ VECTOR_FILL_COLOR, secondRibonColor ],
        [ VECTOR_POLY, 100,0, 100,100, 0,100 ],
      ]
    }
  }
}

let ribbonsIcon = @() {
  watch = stateFlags
  rendObj = ROBJ_IMAGE
  image = stateFlags.get() & S_HOVER
    ? Picture("ui/skin#ribbon_icon_hover.svg:{0}:{0}:K".subst(hdpxi(64)))
    : Picture("ui/skin#ribbon_icon.svg:{0}:{0}:K".subst(hdpxi(64)))
  size = static [ pw(50), ph(50) ]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
}

function ribbonsTooltip() {
  if (isInPlayerSession.get()) {
    let colors = get_color_idx_of_player(watchedHeroEid.get()) 
    return loc("ribbonsColorTooltip", {primary=mkColorLoc(colors.x), secondary=mkColorLoc(colors.y)})
  }
  else
    return loc("pickRibbonsColorTooltip")
}

function onClick(event) {
  if (mutationForbidenDueToInQueueState.get()) {
    showMsgbox({ text = loc("playerPreset/cantChangePresetRightNow") })
    return
  }
  let {r,l,t} = event.targetRect
  addModalPopup([l+(r-l)/2, t], mkRibbonColorPickerWnd())
}

let colorPickerButton = function() {
  mutationForbidenDueToInQueueState.subscribe(function(state) {
    if (state) {
      removeModalPopup(RibbonsMenuId)
    }
  })
  return {
    watch = [isInPlayerSession, stateFlags, isNexusWaveMode, isNexusRoundMode]
    rendObj = isInPlayerSession.get() ? null : ROBJ_BOX
    size = [ itemHeight, itemHeight ]
    behavior = isInPlayerSession.get() || isNexusRoundMode.get() ? null : Behaviors.Button
    onClick
    onElemState = @(s) stateFlags.set(s)
    borderWidth = hdpx(2)
    borderColor = stateFlags.get() & S_HOVER ? Color(255, 255, 255, 255) : BtnBdHover
    borderRadius = hdpx(2)
    onHover = @(on) setTooltip(on ? ribbonsTooltip() : null)
    sound
    hplace = ALIGN_RIGHT

    children = [
      ribbonsBackground
      isInPlayerSession.get() && !isNexusRoundMode.get() ? null : ribbonsIcon
    ]
  }
}

return {
  colorPickerButton
  mkColorLoc
}
