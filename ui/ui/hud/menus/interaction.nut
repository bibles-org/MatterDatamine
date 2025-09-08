import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let JB = require("%ui/control/gui_buttons.nut")
let { selectedObjectEid, useActionKey } = require("%ui/hud/state/actions_state.nut")
let { addInteractiveElement, removeInteractiveElement } = require("%ui/hud/state/interactive_state.nut")
let { body_txt } = require("%ui/fonts_style.nut")
let { TextNormal } = require("%ui/components/colors.nut")
let { controlHudHint, mkHasBinding } = require("%ui/components/controlHudHint.nut")
let { RequestInteractionMenuAction, sendNetEvent, CmdHideUiMenu } = require("dasevents")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { interactionMenuState } = require("%ui/hud/state/actions_markers.nut")

const InteractionMenuId = "Interaction"

let showInteraction = Watched(false)

let closeInteraction = @() ecs.g_entity_mgr.broadcastEvent(CmdHideUiMenu({menuName = InteractionMenuId}))

function onAttach() {
  addInteractiveElement(InteractionMenuId)
  showInteraction.set(true)
}
function onDetach() {
  removeInteractiveElement(InteractionMenuId)
  showInteraction.set(false)
}

selectedObjectEid.subscribe(@(v) v == ecs.INVALID_ENTITY_ID ? closeInteraction() : null)

function actionBlurColor(sf){
  if (sf & S_ACTIVE)   return Color(100,100,100)
  if (sf & S_HOVER)    return Color(200,200,200)
  return Color(255,255,255)
}

function actionTextColor(sf){
  if (sf & S_ACTIVE)   return Color(240, 240, 240, 220)
  if (sf & S_HOVER)    return Color(220, 220, 220, 160)
  return TextNormal
}

let headerBlurColor = Color(200,200,200)
let headerTextColor = Color(170, 235, 255)


let appearTime = 0.1
function mkAppearAnim(idx){
  let delay = appearTime * idx / 2.0
  return [
    { prop=AnimProp.opacity, from=0, to=0, duration=delay, play=true, easing=Linear },
    { prop=AnimProp.opacity, from=0, to=1, duration=appearTime, delay=delay, play=true, easing=InCubic },
    { prop=AnimProp.opacity, from=1, to=0, duration=appearTime*2, delay=delay, playFadeOut=true, easing=InCubic },
  ]
}

function closeInput(inputId) {
  if (inputId == null)
    return null
  let hasBinding = mkHasBinding(inputId)
  let inputHint = controlHudHint({ id = inputId })
  return @() {
    watch = hasBinding
    flow = FLOW_HORIZONTAL
    children = hasBinding.value ? inputHint : null
  }
}

let closeText = @(sf){
  rendObj = ROBJ_TEXT
  margin = hdpx(2)
  text = loc("mainmenu/btnClose")
  color = actionTextColor(sf)
  font = body_txt?.font
  fontSize = body_txt.fontSize
}

let closeTip = watchElemState(@(sf){
  rendObj = ROBJ_WORLD_BLUR
  behavior = Behaviors.Button
  onClick = closeInteraction
  padding = hdpx(2)
  valign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  color = actionBlurColor(sf)
  children = [
    closeInput(useActionKey.get()),
    { size = [fsh(1), 0] },
    closeText(sf)
  ]
})

let closeTipSize = calc_comp_size(closeTip)


function mkHeaderLine(data, idx, arr){
  let text = data?.locParam ? loc(data.loc, data?.locParam) : loc(data.loc)
  let l = arr.len() - 1
  let animations = mkAppearAnim(l-idx)
  return {
    rendObj = ROBJ_WORLD_BLUR
    color = headerBlurColor
    animations
    padding = hdpx(2)
    children = {
      rendObj = ROBJ_TEXT
      text
      color = headerTextColor
      fontSize = body_txt.fontSize
      font = body_txt.font
    }
  }
}


function mkActionLine(eid, data, idx, arr){
  let text = data?.locParam ? loc(data.loc, data?.locParam) : loc(data.loc)
  function action() {
    let actionParamCompObject = ecs.CompObject()
    let actionParam = data?.actionParam
    if (actionParam != null) {
      foreach (key, val in actionParam)
        actionParamCompObject[key] <- val
    }
    sendNetEvent(eid, RequestInteractionMenuAction({heroEid = controlledHeroEid.get(), action=data.action, actionParam=actionParamCompObject}))
    if (data?.closeInteraction ?? true)
      closeInteraction()
  }
  let l = arr.len() - 1
  let animations = mkAppearAnim(l-idx)
  return watchElemState(@(sf) {
    rendObj = ROBJ_WORLD_BLUR
    behavior = Behaviors.Button
    color = actionBlurColor(sf)
    onClick = action
    animations
    padding = hdpx(2)
    children = {
      rendObj = ROBJ_TEXT
      text
      color = actionTextColor(sf)
      fontSize = body_txt.fontSize
      font = body_txt.font
    }
  })
}


function interactionMenu() {
  let {menu = null, menu_header = null, eid=null} = interactionMenuState.get()
  if (!menu?.len())
    return {}

  let children = []

  if (menu_header != null)
    children.extend(menu_header.map(@(data, idx, arr) mkHeaderLine(data, idx, arr)))

  children.extend(menu.map(@(data, idx, arr) mkActionLine(eid, data, idx, arr)))
  children.append(closeTip)

  let duration = children.len() * appearTime
  let animations = [
    { prop=AnimProp.scale, from=[1, 0], to=[1, 1], duration=duration/2, play=true, easing=InCubic },
    { prop=AnimProp.scale, from=[1, 1], to=[1, 0], duration, playFadeOut=true, easing=InCubic }
  ]
  let background = {
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    children
    animations
    hotkeys = [
      [ "Esc", closeInteraction],
      [ $"^{JB.B}", closeInteraction]
    ]
  }

  let backgroundSize = calc_comp_size(background)

  let offset = -backgroundSize[1] / 2.0 - closeTipSize[1] / 2.0
  background.transform <- { translate=[0, offset], pivot=[0, 1] }

  return {
    size = flex()
    onAttach
    onDetach
    watch = interactionMenuState
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = background
  }
}

return {
  interactionMenu
  InteractionMenuId
  showInteraction
}