from "%ui/ui_library.nut" import *
from "%ui/components/colors.nut" import BtnBdNormal, BtnBdHover, BtnBdSelected, TextNormal

let { body_txt } = require("%ui/fonts_style.nut")
let { ConsoleFillColor, ConsoleBorderColor } = require("%ui/components/colors.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { arrayToColor, ribbonsChanged, indexToColor } = require("%ui/mainMenu/ribbons_colors_state.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")
let { itemHeight } = require("%ui/hud/menus/components/inventoryStyle.nut")
let { get_available_colors, get_color_name_by_index, get_primary_color_of_hero, get_secondary_color_of_hero, get_color_idx_of_hero } = require("das.ribbons_color")
let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let { isNexusWaveMode, isNexusRoundMode, nexusModeTeamColors } = require("%ui/hud/state/nexus_mode_state.nut")
let { mkTitleString } = require("%ui/components/commonComponents.nut")
let { teamColorIdxs, teamColorIdxsUpdate } = require("%ui/profile/profileState.nut")
let { currentMenuId } = require("%ui/hud/hud_menus_state.nut")
let { addModalPopup, removeModalPopup } = require("%ui/components/modalPopupWnd.nut")

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
  let stateFlags = Watched(0)
  let colorComp = @() {size = [hdpx(100), hdpx(25)] fillColor = index!=-1 ? indexToColor(index) : Color(178,178,178,255) rendObj = ROBJ_BOX borderColor = Color(70,70,70,120) borderWidth = 1}
  return function(){
    let sf = stateFlags.get()
    let isSelected = index == teamColorIdxs.get()[color_key]

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
      onClick = @() teamColorIdxsUpdate(teamColorIdxs.get().__merge({[color_key] = index}))
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
  if (currentMenuId.get() != "Inventory" && currentMenuId.get() != "Raid/PREPARATION_SUBMENU_ID") {
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
      padding = [0, hdpx(10), hdpx(10), hdpx(10)]
      transform = {}
      animations
      children = colorPickerModalContents
    }
  }
}



let stateFlags = Watched(0)

function ribbonsBackground() {
  let [primc=null, secc=null]= nexusModeTeamColors.get()
  let primRibonColor = primc ?? arrayToColor(get_primary_color_of_hero(watchedHeroEid.get()))
  let secondRibonColor = secc ?? arrayToColor(get_secondary_color_of_hero(watchedHeroEid.get()))
  return {
    watch = [ribbonsChanged, nexusModeTeamColors, watchedHeroEid]
    size = flex()
    rendObj = ROBJ_MASK
    image = Picture("ui/skin#ribbons_mask.svg:{0}:{0}:K".subst(hdpx(64)))
    margin = hdpx(1)
    children = {
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
  size = [ pw(50), ph(50) ]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
}

function ribbonsTooltip() {
  if (isInPlayerSession.get()) {
    let colors = get_color_idx_of_hero(watchedHeroEid.get())
    return loc("ribbonsColorTooltip", {primary=mkColorLoc(colors.x), secondary=mkColorLoc(colors.y)})
  }
  else
    return loc("pickRibbonsColorTooltip")
}

function onClick(event) {
  let {r,l,t} = event.targetRect
  addModalPopup([l+(r-l)/2, t], mkRibbonColorPickerWnd())
}

let colorPickerButton = @() {
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

return {
  colorPickerButton
  mkColorLoc
}

