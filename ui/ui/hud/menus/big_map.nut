import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

import "%ui/hud/minimap/send_minimap_mark.nut" as sendMinimapMark
import "%ui/hud/minimap/send_tiled_map_mark.nut" as sendTiledMapMark
from "minimap.behaviors" import Minimap, MinimapInput
from "tiledMap.behaviors" import TiledMap, TiledMapInput

let { EventSpawnSequenceEnd, CmdHideUiMenu, CmdShowUiMenu } = require("dasevents")
let { Point3 } = require("dagor.math")
let {mkCountdownTimer} = require("%ui/helpers/timers.nut")
let { sub_txt, h2_txt } = require("%ui/fonts_style.nut")
let { mmContextData } = require("%ui/hud/minimap/minimap_ctx.nut")
let mouseButtons = require("%ui/control/mouse_buttons.nut")
let { removeInteractiveElement, hudIsInteractive, switchInteractiveElement
} = require("%ui/hud/state/interactive_state.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let { tipContents } = require("%ui/hud/tips/tipComponent.nut")
let { TextNormal, RedWarningColor, BtnBgActive, BtnBgDisabled
} = require("%ui/components/colors.nut")
let JB = require("%ui/control/gui_buttons.nut")
let uiHotkeysHint = require("%ui/components/uiHotkeysHint.nut").mkHintRow
let formatInputBinding = require("%ui/control/formatInputBinding.nut")
let { setShowAllObjectives, stopAllObjectiveHudTimers } = require("%ui/hud/objectives/objectives_hud.nut")
let { getMapLayers } = require("%ui/hud/minimap/mmCtors.nut")
let { mapDefaultVisibleRadius, currentMapVisibleRadius, minimapState } = require("%ui/hud/minimap/minimap_state.nut")
let { mapSize } = require("%ui/hud/minimap/map_state.nut")
let { tiledMapContext, tiledMapContextData,
      tiledMapExist } = require("%ui/hud/minimap/tiled_map_ctx.nut")
let {currentLevelBlk} = require("%ui/state/appState.nut")
let {movingZoneInfo} = require("%ui/hud/state/hud_moving_zone_es.nut")
let { isNexus } = require("%ui/hud/state/nexus_mode_state.nut")
let teammatesBlock = require("%ui/hud/nexus_mode_loadout_selector_teammate_block.nut")
let { fontIconButton, bluredPanel, mkMonospaceTimeComp } = require("%ui/components/commonComponents.nut")
let altNexusDrawTip = require("%ui/hud/tips/nexus_round_mode_minimap_draw_counter.nut")
let { extractionIcon } = require("%ui/hud/minimap/map_extraction_points.nut")

const BigMapId = "bigMap"

let NO_LOCATION_DATA_COLOR_1 = RedWarningColor
let NO_LOCATION_DATA_COLOR_2 = mul_color(RedWarningColor, 0.5)

let closeBigMap = @() ecs.g_entity_mgr.broadcastEvent(CmdHideUiMenu(const {menuName = BigMapId}))

let isBigMapOn = Watched(false)

function onDetach(){
  removeInteractiveElement(BigMapId)
  setShowAllObjectives(false)
  isBigMapOn.set(false)
}
function onAttach(){
  stopAllObjectiveHudTimers()
  setShowAllObjectives(true)
  isBigMapOn.set(true)
}

let mapRootAnims = [
  { prop=AnimProp.opacity, from=0, to=1, duration=0.1, play=true }
  { prop=AnimProp.opacity, from=1, to=0, duration=0.1, playFadeOut=true }
]


let hintTextFunc = @(text) {
  rendObj = ROBJ_TEXT
  text = text
  color = TextNormal
}.__update(sub_txt)

function makeHintRow(hotkeys, text) {
  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = [uiHotkeysHint(hotkeys,{textFunc=hintTextFunc})].append(hintTextFunc(text))
  }
}

let minimapTransform = { rotate = 90 }
let minimapMarkersTransform = { rotate = -90 }

let getWatchedPlrPosQ = ecs.SqQuery("getWatchedPlrPos", {
  comps_ro = [["transform", ecs.TYPE_MATRIX]],
  comps_rq = ["watchedByPlr"],
})

let getWatchedPlrPos = @() getWatchedPlrPosQ.perform(@(_, comp) comp["transform"].getcol(3))

function alignMapToZone(){
  tiledMapContext.setViewCentered(false);
  let radius = (movingZoneInfo.get()?.radius ?? mapDefaultVisibleRadius.get()) * 1.05
  let { leftTop, rightBottom } = tiledMapContextData.get()
  let mapCenter = Point3((leftTop.x + rightBottom.x) / 2, 0, (leftTop.y + rightBottom.y) / 2)

  let defaultWordPos = isNexus.get() ? mapCenter : (getWatchedPlrPos() ?? mapCenter)

  local actualRadius = radius
  if (tiledMapExist.get()){
    actualRadius = tiledMapContext.setVisibleRadius(radius)
    tiledMapContext.setWorldPos(movingZoneInfo.get()?.worldPos ?? defaultWordPos)
  } else {
    minimapState.isHeroCentered = false
    actualRadius = minimapState.setVisibleRadius(radius)
    minimapState.panWolrdPos = movingZoneInfo.get()?.worldPos ?? defaultWordPos
  }
  currentMapVisibleRadius.set(actualRadius)
}

function followPlayerToggle(){
  if (!tiledMapExist.get())
    return

  tiledMapContext.setViewCentered(!tiledMapContext.getViewCentered())
}

function alignMapToHero() {
  let worldPos = getWatchedPlrPos()
  if (worldPos != null)
    if (tiledMapExist.get())
      tiledMapContext.setWorldPos(worldPos)
    else
      minimapState.panWolrdPos = worldPos
  else
    alignMapToZone()
}

ecs.register_es("align_hero_on_spawn_es",
  {
    [EventSpawnSequenceEnd] = @(...) isNexus.get() ? null : alignMapToZone(),
  }, {comps_rq = ["spawn_sequence_controller__state", "hero"]}
)


let modeHotkeyTip = tipContents({
  text = loc("controls/HUD.Interactive")
  inputId = "HUD.Interactive"
  textStyle = {textColor = TextNormal}
  animations = []
  needCharAnimation = false
})

let placePointsTipMouse = {
  size = [flex(), SIZE_TO_CONTENT]
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  halign = ALIGN_CENTER
  color = TextNormal
  text = loc("map/place_marks")
  image = "Human.Aim"
}

function mkMoveMapTipMouse() {
  let needToShow = Computed(@() currentMapVisibleRadius.get() < tiledMapContext.getVisibleRadiusRange().y)
  return function () {
    let watch = needToShow
    if (!needToShow.get())
      return { watch }
    return {
      watch
      size = [flex(), SIZE_TO_CONTENT]
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      halign = ALIGN_CENTER
      color = TextNormal
      text = loc("map/move_tip")
      image = "Human.Aim"
    }
  }
}

let mapMouseTips = {
  size = [flex(), SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  children = [
    placePointsTipMouse
    mkMoveMapTipMouse()
  ]
}

let placePointsTipGamepad = {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  children = [
    makeHintRow(JB.A, loc("map/place_marks/gamepad"))
  ]
}

function centerOnPlayerHint(btn) {
  let needToShow = Computed(@() currentMapVisibleRadius.get() < tiledMapContext.getVisibleRadiusRange().y)
  return function() {
    let watch = needToShow
    if (!needToShow.get())
      return { watch }
    return {
      watch
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      children = [
        makeHintRow(btn, loc("map/center_on_player"))
      ]
      hotkeys = [[ "Space | J:X", { action = alignMapToHero }]]
    }
  }
}

let centerOnZoneHint = @(btn){
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  children = [
    makeHintRow(btn, loc("map/center_on_zone"))
  ]
  hotkeys = [[ "L.Ctrl Space", { action = alignMapToZone }]]
}

let followPlayerToggleHint = @(btn){
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  children = [
    makeHintRow(btn, loc("map/follow_player_toggle"))
  ]
  hotkeys = [[ "X", { action = followPlayerToggle }]]
}

let zoomGamepadHints = @() {
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  children = formatInputBinding.buildElems(["J:LT", "J:RT"], { textFunc = hintTextFunc })
    .append(hintTextFunc(loc("map/zoom")))
}

let tipsHeight = sh(5)
let mkInteractiveModeTips = @(sz) @() {
  watch = isGamepad
  size = [sz[0], tipsHeight]
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [
    isGamepad.value ? zoomGamepadHints : null
    isGamepad.value ? placePointsTipGamepad : mapMouseTips
    isGamepad.value ? centerOnPlayerHint("J.X") : centerOnPlayerHint("Space")
    isGamepad.value ? {} : centerOnZoneHint("L.Ctrl Space")
    isGamepad.value ? {} : followPlayerToggleHint("X")
  ]
}

let mkInteractiveTips = @(internactiveTips, notInteractiveTips) @() {
  watch = hudIsInteractive
  size = [flex(), tipsHeight]
  flow = FLOW_VERTICAL
  gap = fsh(0.5)
  padding = [fsh(1), 0]
  halign = ALIGN_CENTER
  children = hudIsInteractive.get() ? internactiveTips : notInteractiveTips
}

function interactiveFrame() {
  let res = { watch = hudIsInteractive }
  if (!hudIsInteractive.value)
    return res
  return res.__update({
    rendObj = ROBJ_FRAME
    size = flex()
    borderWidth = hdpx(2)
    color = BtnBgActive
  })
}

let bigMapEventHandlers = {
  ["HUD.Interactive"] = @(_event) switchInteractiveElement(BigMapId),
  ["HUD.Interactive:end"] = function onHudInteractiveEnd(event) {
    if (isBigMapOn.get() && ((event?.dur ?? 0) > 500 || event?.appActive == false))
      removeInteractiveElement(BigMapId)
  }
}

let closeMapDesc = {
  action = closeBigMap,
  description = loc("mainmenu/btnClose"),
  inputPassive = true
}

function mkMinimapLayer(ctorWatch, paramsWatch, map_size) {
  let watches = type(ctorWatch.watch) == "array" ? ctorWatch.watch : [ctorWatch.watch]
  return @() {
    watch = [paramsWatch].extend(watches)
    size = map_size
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    clipChildren = true
    eventPassThrough = true
    minimapState = minimapState
    transform = {}
    behavior = Minimap
    children = ctorWatch.ctor(paramsWatch.value)
  }
}

function mkTiledMapLayer(ctorWatch, map_size) {
  let watches = type(ctorWatch.watch) == "array" ? ctorWatch.watch : [ctorWatch.watch]
  return @() {
    watch = watches
    size = map_size
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    clipChildren = true
    eventPassThrough = true
    tiledMapContext = tiledMapContext
    transform = {}
    behavior = TiledMap
    children = ctorWatch.ctor({size=map_size, transform={}})
  }
}

let interactiveTips = mkInteractiveTips(mkInteractiveModeTips(mapSize), modeHotkeyTip)

function onClickMap(e){
  if (e.button == 1 || (isGamepad.value && e.button == 0))
    if (tiledMapExist.get()){
      sendTiledMapMark(e, tiledMapContext)
    }
    else
      sendMinimapMark(e, minimapState)
}

let markersParams = Computed(@() {
  state = minimapState
  size = mapSize
  transform = minimapMarkersTransform
  isInteractive = hudIsInteractive.value
  showHero = true
})

function isPosLocationDataAvailable(ctx) {
  let {left_top=const {x=0, y=0} right_bottom=const {x=0, y=0}} = ctx
  return ((left_top?.x ?? 0) < (right_bottom?.x ?? 0)) && ((left_top?.y ?? 0) < (right_bottom?.y ?? 0))
}

function baseMap() {
  let isLocationDataAvailable = isPosLocationDataAvailable(mmContextData.get())
  return {
    size = mapSize
    minimapState = minimapState
    rendObj = ROBJ_MINIMAP
    transform = minimapTransform
    panMouseButton = mouseButtons.LMB
    watch = [hudIsInteractive, mmContextData]
    behavior = hudIsInteractive.get() && isLocationDataAvailable
      ? [Minimap, Behaviors.Button, MinimapInput]
      : [Minimap]
    color = Color(255, 255, 255, 255)

    halign = ALIGN_CENTER
    valign = ALIGN_CENTER

    clipChildren = true
    eventPassThrough = true
    children = isLocationDataAvailable ? getMapLayers().map(@(c) mkMinimapLayer(c, markersParams, mapSize)) : null

    onClick = onClickMap
  }
}

let tiledMap = function() {
  return {
    size = mapSize
    tiledMapContext = tiledMapContext
    rendObj = ROBJ_TILED_MAP
    transform = {}
    panMouseButton = mouseButtons.LMB
    watch = hudIsInteractive
    behavior = hudIsInteractive.get()
      ? [TiledMap, Behaviors.Button, TiledMapInput]
      : [TiledMap]
    color = Color(255, 255, 255, 255)

    halign = ALIGN_CENTER
    valign = ALIGN_CENTER

    clipChildren = true
    eventPassThrough = true
    children = getMapLayers().map(@(c) mkTiledMapLayer(c, mapSize))

    onClick = onClickMap
  }
}

let mapLayers = function() {
  let isLocationDataAvailable = (mmContextData.get()?.mapTex ?? "") != "" || tiledMapExist.get()
  return {
    behavior = DngBhv.ActivateActionSet
    actionSet = "BigMap"
    size = mapSize
    watch = [mmContextData, tiledMapExist, tiledMapContextData]
    rendObj = ROBJ_SOLID
    color = tiledMapExist.get()
      ? tiledMapContextData.get().backgroundColor
      : BtnBgDisabled
    clipChildren = true
    children = [
      tiledMapExist.get() ? tiledMap : baseMap,
      interactiveFrame,
      !isLocationDataAvailable ? {
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
        text = loc("map/noLocationData", "No location data")
        rendObj = ROBJ_TEXT
        fontSize = h2_txt.fontSize
        color = Color(180, 180, 180, 255)
        animations = const [{prop = AnimProp.color, from = NO_LOCATION_DATA_COLOR_1, to = NO_LOCATION_DATA_COLOR_2, duration = 1.5, loop = true, play = true, easing = CosineFull }]
      } : null
    ]
  }
}

let iconSize = hdpxi(20)
let zoneTimeIcon = const {
  rendObj = ROBJ_IMAGE
  image = Picture($"ui/skin#zone_collapse_time.svg:{iconSize}:{iconSize}:P")
  size = iconSize
  color = TextNormal
}

let zoneCollapseIcon = const {
  rendObj = ROBJ_IMAGE
  image = Picture($"ui/skin#zone_collapse.svg:{iconSize}:{iconSize}:P")
  size = iconSize
}

let closeBtn = fontIconButton(
  "icon_buttons/x_btn.svg",
  @() ecs.g_entity_mgr.broadcastEvent(CmdHideUiMenu({menuName = BigMapId})),
  {
    fontSize = hdpx(30)
    size = [hdpx(32), hdpx(32)]
    hotkeys = [[$"^Esc | {JB.B}", {description = loc("mainmenu/btnClose")}]]
    sound = {
      click = null 
      hover = "ui_sounds/button_highlight"
    }
  }
)

let closeBtnHgt = calc_comp_size(closeBtn)[1]
let mapPadding = hdpx(10)
let timeLoc = const {rendObj = ROBJ_TEXT, text = loc("map/timeBeforeZoneCollapse"), color = TextNormal}
let finalExtractionNote = const {rendObj = ROBJ_TEXT, text = loc("map/finalExtractionNote"), color = TextNormal}
let warningLoc = const {rendObj = ROBJ_TEXT, text = loc("map/warning"), color = RedWarningColor}
let zoneCollapseLoc = const {rendObj = ROBJ_TEXT, text = loc("map/zoneCollapse"), color = TextNormal}
let hintsGap = hdpx(8)

let mapWndWidth = mapSize[0] - mapPadding*2
let wrapParams = const {hGap = hintsGap, vGap = hdpx(2), width = mapWndWidth}
let hintsWithTimer = @(time) {
  flow = FLOW_VERTICAL
  gap = hdpx(2)
  children = [
    wrap([ zoneTimeIcon, timeLoc, mkMonospaceTimeComp(time)], wrapParams)
    const wrap([extractionIcon, finalExtractionNote], wrapParams)
  ]
}


let mkZoneInfo = function(){
  let timerState = Computed(@() movingZoneInfo.get()?.endTime)
  let timer = mkCountdownTimer(timerState)

  return @() {
    valign = ALIGN_CENTER
    size = const [flex(), SIZE_TO_CONTENT]
    watch = timer
    flow = FLOW_VERTICAL
    minHeight = closeBtnHgt
    gap = hdpx(2)
    children = [altNexusDrawTip].append(timer.get() > 0
      ? hintsWithTimer(timer.get())
      : timerState.get() <= 0 ? null : const const wrap([zoneCollapseIcon, warningLoc, zoneCollapseLoc], wrapParams)
    )
  }
}

let framedMap = @() {
  children = [
    @() {watch = hudIsInteractive, halign = ALIGN_RIGHT, children = hudIsInteractive.get() ? closeBtn : null, size = const [flex(), SIZE_TO_CONTENT]}
    {
      flow = FLOW_VERTICAL
      padding = mapPadding
      gap = hdpx(5)
      children = [
        mkZoneInfo()
        mapLayers
      ]
    }
  ]
}.__update(bluredPanel)

let mapBlock = function(){
  return {
    watch = [mmContextData, tiledMapExist]
    flow = FLOW_VERTICAL
    hplace = ALIGN_RIGHT
    vplace = ALIGN_TOP

    children = [
      framedMap
      interactiveTips
    ]
  }
}

local isFirstTime = true
local prevLevelBlk = ""
currentLevelBlk.subscribe(function(v){
  if (v != prevLevelBlk) {
    isFirstTime = true
  }
  prevLevelBlk = v
})

function nexusMapBlock() {
  let watch = const [isNexus]
  if (!isNexus.get())
    return const { watch }

  return {
    watch
    children = teammatesBlock
  }
}

function bigMap() {
  if (isFirstTime) {
    alignMapToZone()
    isFirstTime = false
  }

  return {
    watch = mmContextData
    size = flex()
    onAttach
    onDetach
    padding = const [hdpx(80), fsh(2.5)]
    key = BigMapId
    gap = hdpx(10)
    flow = FLOW_HORIZONTAL
    children = [
      { size = flex() }
      nexusMapBlock
      mapBlock
    ]

    animations = mapRootAnims
    hotkeys = const [
      [$"J:RB | J:LB"], 
      [ "@HUD.BigMap", closeMapDesc ]
    ]
    eventHandlers = bigMapEventHandlers
  }
}


return {
  bigMap
  BigMapId
  closeBigMap
  openBigMap = @() ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu(const {menuName = BigMapId}))
}
