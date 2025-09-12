from "%sqstd/math.nut" import ceil, truncateToMultiple
from "%ui/components/colors.nut" import BtnBgActive, BtnBgDisabled, BtnTextNormal, MapIconEnable, MapIconHover, RedWarningColor, SelBgNormal, TextNormal, TextNormal, RedWarningColor, TextDisabled
from "%ui/components/cursors.nut" import setTooltip
import "%ui/components/tooltipBox.nut" as tooltipBox
from "%ui/components/commonComponents.nut" import fontIconButton, bluredPanel, mkTimeComp, mkText, mkTooltiped
from "%ui/components/mkSelection.nut" import mkTinySelection, tinyBtnHeight
from "%ui/components/modalWindows.nut" import addModalWindow, removeModalWindow
from "%ui/components/slider.nut" import Horiz
from "%ui/components/uiHotkeysHint.nut" import mkHintRow as uiHotkeysHint
from "%ui/fonts_style.nut" import tiny_txt, sub_txt, body_txt, h2_txt
from "%ui/helpers/timers.nut" import mkCountdownTimer
from "%ui/hud/map/map_ctors.nut" import getMapLayers
from "%ui/hud/map/map_extraction_points.nut" import extractionIcon
from "%ui/hud/map/map_user_points.nut" import user_points_order, user_points_icons, generic_user_points_order
from "%ui/hud/objectives/objectives_hud.nut" import setShowAllObjectives, stopAllObjectiveHudTimers
from "%ui/hud/state/interactive_state.nut" import removeInteractiveElement, switchInteractiveElement
from "%ui/hud/state/local_player.nut" import localPlayerEid
from "%ui/hud/state/user_points.nut" import teammatesPointsOpacity, playerPointsOpacity, user_points
from "%ui/hud/tips/tipComponent.nut" import tipContents, tipBack
from "dagor.math" import Point3, Point2
from "%ui/mainMenu/stdPanel.nut" import screenSize
from "dasevents" import EventSpawnSequenceEnd, CmdHideUiMenu, CmdShowUiMenu, CmdCreateMapPoint
from "%ui/hud/nexus_mode_loadout_selector_teammate_block.nut" import teammatesBlock, enemiesBlock
import "%ui/components/spinnerList.nut" as spinnerList
import "%ui/control/mouse_buttons.nut" as mouseButtons
import "%ui/hud/tips/nexus_round_mode_map_draw_counter.nut" as altNexusDrawTip
from "%ui/mainMenu/stdPanel.nut" import mkCloseStyleBtn
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "tiledMap.behaviors" import TiledMap, TiledMapInput
from "dasevents" import EventScanPointsOfInterest, RequestScanPointsOfInterest, sendNetEvent
from "%sqGlob/dasenums.nut" import HumanScanMode
from "net" import get_sync_time
from "%ui/hud/tips/tipComponent.nut" import mkInputHintBlock

let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let JB = require("%ui/control/gui_buttons.nut")
let formatInputBinding = require("%ui/control/formatInputBinding.nut")
let { mapSize, mapDefaultVisibleRadius, currentMapVisibleRadius } = require("%ui/hud/map/map_state.nut")
let { tiledMapContext, tiledMapContextData, tiledMapExist } = require("%ui/hud/map/tiled_map_ctx.nut")
let { currentLevelBlk } = require("%ui/state/appState.nut")
let { movingZoneInfo } = require("%ui/hud/state/hud_moving_zone_es.nut")
let { isNexus } = require("%ui/hud/state/nexus_mode_state.nut")
let { safeAreaHorPadding, safeAreaVerPadding } = require("%ui/options/safeArea.nut")

const BigMapId = "bigMap"

let NO_LOCATION_DATA_COLOR_1 = RedWarningColor
let NO_LOCATION_DATA_COLOR_2 = mul_color(RedWarningColor, 0.5)

let closeBigMap = @() ecs.g_entity_mgr.broadcastEvent(CmdHideUiMenu(static {menuName = BigMapId}))

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
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = [uiHotkeysHint(hotkeys,{textFunc=hintTextFunc})].append(hintTextFunc(text))
  }
}

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
  if (worldPos == null){
    alignMapToZone()
    return
  }
  if (tiledMapExist.get())
    tiledMapContext.setWorldPos(worldPos)
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
  halign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  children = [
    placePointsTipMouse
    mkMoveMapTipMouse()
  ]
}

let placePointsTipGamepad = {
  flow = FLOW_VERTICAL
  children = [
    makeHintRow("J:X", loc("map/place_marks/gamepad"))
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
      flow = FLOW_VERTICAL
      children = [
        makeHintRow(btn, loc("map/center_on_player"))
      ]
      hotkeys = [[ btn, { action = alignMapToHero }]]
    }
  }
}

let centerOnZoneHint = @(btn){
  flow = FLOW_VERTICAL
  children = [
    makeHintRow(btn, loc("map/center_on_zone"))
  ]
  hotkeys = [[ "L.Ctrl Space", { action = alignMapToZone }]]
}

let followPlayerToggleHint = @(btn){
  flow = FLOW_VERTICAL
  children = [
    makeHintRow(btn, loc("map/follow_player_toggle"))
  ]
  hotkeys = [[ "X", { action = followPlayerToggle }]]
}

let scanQuery = ecs.SqQuery("scanQuery", {comps_ro = [["human_scan_points_of_interest__enabled", ecs.TYPE_BOOL]], comps_rq=["human_input"]})
let requestScan = @() scanQuery.perform(function(eid, comp){
  if (comp["human_scan_points_of_interest__enabled"])
    sendNetEvent(eid, RequestScanPointsOfInterest({atTime = get_sync_time(), humanScanMode = HumanScanMode.MANUAL}))
  
})

let requestScanHint = @(btn){
  flow = FLOW_VERTICAL
  children = [
    makeHintRow(btn, loc("map/scan_points_of_interest"))
  ]
  hotkeys = [[ "K", { action = requestScan }]]
}

let zoomGamepadHints = @() {
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  children = formatInputBinding.buildElems(["J:LT", "J:RT"], { textFunc = hintTextFunc })
    .append(hintTextFunc(loc("map/zoom")))
}

let tipsHeight = sh(5)
let mkInteractiveModeTips = @() {
  watch = isGamepad
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  gap = hdpx(2)
  children = [
    isGamepad.get() ? zoomGamepadHints : null
    isGamepad.get() ? placePointsTipGamepad : mapMouseTips
    isGamepad.get() ? centerOnPlayerHint("J:RS") : centerOnPlayerHint("Space")
    isGamepad.get() ? {} : centerOnZoneHint("L.Ctrl Space")
    isGamepad.get() ? {} : followPlayerToggleHint("X")
    isGamepad.get() ? {} : requestScanHint("K")
  ]
}.__update(tipBack)

let mkInteractiveTips = @(internactiveTips, notInteractiveTips) @() {
  watch = hudIsInteractive
  size = [flex(), tipsHeight]
  flow = FLOW_VERTICAL
  padding = static [hdpx(5), 0]
  halign = ALIGN_CENTER
  children = hudIsInteractive.get() ? internactiveTips : notInteractiveTips
}

function interactiveFrame() {
  let res = { watch = hudIsInteractive }
  if (!hudIsInteractive.get())
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

let interactiveTips = mkInteractiveTips(mkInteractiveModeTips, modeHotkeyTip)

let durationOptions = [
  {locId = "map/user_points/duration/forever", cond = "forever"},
  {locId = "map/user_points/duration/1_min", cond = "1_min"},
  {locId = "map/user_points/duration/5_min", cond = "5_min"},
  {locId = "map/user_points/duration/10_min", cond = "10_min"},
]
let proximityOptions = [
  {locId = "map/user_points/proximity/never", cond = "never"},
  {locId = "map/user_points/proximity/near", cond = "near"},
  {locId = "map/user_points/proximity/teammate_near", cond = "teammate_near"},
]

let selectedUserPoint = Watched(user_points_order[0])
let selectedDuration = Watched(durationOptions[0])
let selectedProximity = Watched(proximityOptions[0])

function sendTiledMapMark(worldPos, icon){
  ecs.g_entity_mgr.sendEvent(
    localPlayerEid.get(), CmdCreateMapPoint({
      userPointType = icon,
      x = worldPos.x, z = worldPos.z,
      duration = selectedDuration.get().cond,
      proximity = selectedProximity.get().cond
    })
  )
}

let userMarkHeight = hdpxi(20)
let userMarkGap = hdpxi(2)
let userMarkCols = 10
let userMarkSelectorPadding = hdpx(4)
let markPos = Watched({x=0, y=0})
let isMarkPosEditing = Watched(false)

const USER_MARK_SELECTION = "USER_MARK_SELECTION"
function closeEditingPointer(){
  removeModalWindow(USER_MARK_SELECTION)
  isMarkPosEditing.set(false)
  markPos.set({x=0, y=0})
}
function closeAndSetPonter(pos, icon) {
  sendTiledMapMark(pos, icon)
  closeEditingPointer()
}

function mkMark(icon, idx=-1) {
  let sf = Watched(0)
  let iconDesc = user_points_icons[icon]
  let image = iconDesc.icon
  return @() {
    watch = sf
    onElemState = function(s){
      sf.set(s)
      if (s & S_HOVER)
        selectedUserPoint.set(icon)
    }
    behavior = Behaviors.Button
    rendObj = ROBJ_IMAGE
    image = Picture($"{image}:{userMarkHeight}:{userMarkHeight}:P")
    size = userMarkHeight
    onClick = @() closeAndSetPonter(markPos.get(), icon)
    color = (sf.get() & S_HOVER) ? MapIconHover : TextNormal
    onAttach = idx == 0 ? (@(elem) isGamepad.get() ? move_mouse_cursor(elem) : null) : null
    pos = idx < 0 ? iconDesc?.pos : null 
    children = iconDesc?.text ? mkText(iconDesc?.text, {
      color = sf.get() & S_HOVER ? MapIconHover : TextNormal
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      size = flex()
      pos = iconDesc?.textPos
    }) : null

  }
}

function calcUserMarkSelectSize() {
  let n = user_points_order.len()
  let rows = ceil(n.tofloat() / userMarkCols)
  let x = userMarkCols * userMarkHeight + (userMarkCols - 1) * userMarkGap + 2 * userMarkSelectorPadding
  let y = rows * userMarkHeight + (rows - 1) * userMarkGap +
    2 * userMarkSelectorPadding + 2 * tinyBtnHeight + hdpx(4) + userMarkHeight
  return Point2(x, y)
}

let defStyle = freeze({ color = BtnTextNormal }.__update(tiny_txt))

let hoverStyle = freeze({ color = BtnTextNormal }.__update(tiny_txt))

function getCurrentPoints() {
  let res = {}
  foreach( up in user_points.get()){
    let upt = up?.userPointType
    if (upt==null)
      continue
    res[upt] <- upt
  }
  return res
}
function userMarkSelect(e) {
  let sz = calcUserMarkSelectSize()
  let curPoints = getCurrentPoints()
  let availableUserPointTypes = generic_user_points_order.filter(@(v) v not in curPoints)
  if (availableUserPointTypes.len()!=0){
    selectedUserPoint.set(availableUserPointTypes[0])
  }

  let rb = Point2(e.screenX, e.screenY) + sz - Point2(sz.x / 2, 0)
  let lt = Point2(e.screenX, e.screenY) - Point2(sz.x / 2, 0)
  let rect = e.targetRect
  let offsetX = rb.x > rect.r
    ? rb.x - rect.r
    : lt.x < rect.l
      ? lt.x - rect.l : 0

  let flipY = rb.y > rect.b

  let children = user_points_order.reduce(function(acc, v, idx) {
    if (idx % userMarkCols == 0)
      acc.append({
        gap = userMarkGap
        flow = FLOW_HORIZONTAL
        children = [mkMark(v, idx)]
      })
    else
      acc.top().children.append(mkMark(v, idx))
    return acc
  }, [])

  let timeSelection = mkTinySelection(durationOptions, selectedDuration, {defTxtStyle=defStyle, hoverTxtStyle=hoverStyle})
  let proxymitySelection = mkTinySelection(proximityOptions, selectedProximity, {defTxtStyle=defStyle, hoverTxtStyle=hoverStyle})

  let lifetimeControls = {
    flow = FLOW_VERTICAL
    size = FLEX_H
    gap = hdpx(4)
    children = [
      mkText(loc("map/user_points/lifetime"), {size = [flex(), tinyBtnHeight]}.__merge(tiny_txt)),
      {
        flow = FLOW_HORIZONTAL
        size = FLEX_H
        gap = hdpx(4)
        children = [
          timeSelection,
          proxymitySelection
        ]
      }
    ]
  }

  children.append(lifetimeControls)
  if (flipY)
    children.reverse()

  return {
    pos = [e.screenX - sz.x / 2 - offsetX, e.screenY - (flipY ? sz.y : -userMarkHeight)]
    children = [
      mkCloseStyleBtn(closeEditingPointer, {
        hplace = ALIGN_RIGHT,
        size = static [userMarkHeight, userMarkHeight]
        pos = static [0, -userMarkHeight]
      })
      {
        rendObj = ROBJ_SOLID
        color = SelBgNormal
        padding = userMarkSelectorPadding
        flow = FLOW_VERTICAL
        gap = userMarkGap
        children
      }
    ]
  }
}

let closeAndSetCurPoint = @() closeAndSetPonter(markPos.get(), selectedUserPoint.get())
function onClickMap(e) {
  if (e.button == 1 || (isGamepad.get() && e.button == 1)) {
    isMarkPosEditing.set(true)
    let rect = e.targetRect
    let elemW = rect.r - rect.l
    let elemH = rect.b - rect.t
    let relX = (e.screenX - rect.l - elemW * 0.5)
    let relY = (e.screenY - rect.t - elemH * 0.5)
    let worldPos = tiledMapContext.mapToWorld(Point2(relX, relY))

    let previewPoint = @() {
      watch = selectedUserPoint
      pos = [e.screenX - userMarkHeight * 0.5, e.screenY - userMarkHeight * 0.5]
      children = mkMark(selectedUserPoint.get())
    }
    markPos.set(worldPos)
    addModalWindow({
      key = USER_MARK_SELECTION
      onClick = function(evt){
        if (evt.button == 0)
          closeAndSetCurPoint()
        else
          closeEditingPointer()
      }
      children = [
        previewPoint,
        userMarkSelect(e)
      ]
    })
  }
  else if (e.button == 0)
    closeEditingPointer()
}

let tiledMap = function() {
  return {
    watch = hudIsInteractive
    size = mapSize
    tiledMapContext = tiledMapContext
    rendObj = ROBJ_TILED_MAP
    transform = static {}
    panMouseButton = mouseButtons.LMB
    behavior = hudIsInteractive.get()
      ? [TiledMap, Behaviors.Button, TiledMapInput]
      : [TiledMap]
    color = Color(255, 255, 255, 255)
    skipDirPadNav = true

    halign = ALIGN_CENTER
    valign = ALIGN_CENTER

    clipChildren = true
    eventPassThrough = true
    children = getMapLayers().map(@(c) mkTiledMapLayer(c, mapSize))
      .append(hudIsInteractive.get() ? @() { size = null onDetach = function(){
        if (isMarkPosEditing.get())
          closeAndSetCurPoint()
      }
    } : null)

    onClick = onClickMap
  }
}

let mapLayers = function() {
  let isLocationDataAvailable = tiledMapExist.get()
  return {
    behavior = DngBhv.ActivateActionSet
    actionSet = "BigMap"
    size = mapSize
    watch = [tiledMapExist, tiledMapContextData]
    rendObj = ROBJ_SOLID
    color = tiledMapExist.get()
      ? tiledMapContextData.get().backgroundColor
      : BtnBgDisabled
    clipChildren = true
    children = [
      tiledMapExist.get() ? tiledMap : null,
      interactiveFrame,
      !isLocationDataAvailable ? {
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
        text = loc("map/noLocationData", "No location data")
        rendObj = ROBJ_TEXT
        fontSize = h2_txt.fontSize
        color = Color(180, 180, 180, 255)
        animations = static [{prop = AnimProp.color, from = NO_LOCATION_DATA_COLOR_1, to = NO_LOCATION_DATA_COLOR_2, duration = 1.5, loop = true, play = true, easing = CosineFull }]
      } : null
    ]
  }
}

let iconSize = hdpxi(20)
let zoneTimeIcon = freeze({
  rendObj = ROBJ_IMAGE
  image = Picture($"ui/skin#zone_collapse_time.svg:{iconSize}:{iconSize}:P")
  size = iconSize
  color = TextNormal
})

let zoneCollapseIcon = freeze({
  rendObj = ROBJ_IMAGE
  image = Picture($"ui/skin#zone_collapse.svg:{iconSize}:{iconSize}:P")
  size = iconSize
})

let closeBtn = fontIconButton(
  "icon_buttons/x_btn.svg",
  @() ecs.g_entity_mgr.broadcastEvent(CmdHideUiMenu({menuName = BigMapId})),
  {
    fontSize = hdpx(30)
    size = hdpx(32)
    skipDirPadNav = true
    hotkeys = [[$"^Esc | {JB.B}", {description = loc("mainmenu/btnClose")}]]
    sound = {
      click = null 
      hover = "ui_sounds/button_highlight"
    }
  }
)

let closeBtnHgt = calc_comp_size(closeBtn)[1]
let mapPadding = hdpx(10)
let timeLoc = static {rendObj = ROBJ_TEXT, text = loc("map/timeBeforeZoneCollapse"), color = TextNormal}
let finalExtractionNote = static {rendObj = ROBJ_TEXT, text = loc("map/finalExtractionNote"), color = TextNormal}
let warningLoc = static {rendObj = ROBJ_TEXT, text = loc("map/warning"), color = RedWarningColor}
let zoneCollapseLoc = static {rendObj = ROBJ_TEXT, text = loc("map/zoneCollapse"), color = TextNormal}
let hintsGap = hdpx(8)

let mapWndWidth = mapSize[0] - mapPadding*2
let wrapParams = static {hGap = hintsGap, vGap = hdpx(2), width = mapWndWidth}
let hintsWithTimer = @(time) {
  flow = FLOW_VERTICAL
  gap = hdpx(2)
  children = [
    wrap([ zoneTimeIcon, timeLoc, mkTimeComp(time)], wrapParams)
    wrap([extractionIcon, finalExtractionNote], wrapParams)
  ]
}


let mkZoneInfo = function(){
  let timerState = Computed(@() movingZoneInfo.get()?.endTime)
  let timer = mkCountdownTimer(timerState, "big_map:map_timer")

  return @() {
    valign = ALIGN_CENTER
    size = FLEX_H
    watch = timer
    flow = FLOW_VERTICAL
    minHeight = closeBtnHgt
    gap = hdpx(2)
    children = [altNexusDrawTip].append(timer.get() > 0
      ? hintsWithTimer(timer.get())
      : timerState.get() <= 0 ? null : wrap([zoneCollapseIcon, warningLoc, zoneCollapseLoc], wrapParams)
    )
  }
}

let statusWidth = hdpxi(30)
let iconWidth = (statusWidth / 1.2).tointeger()

let iconBackground = freeze({
  commands = [
    [VECTOR_FILL_COLOR, Color(0,0,0,80)],
    [VECTOR_COLOR, Color(0,0,0,0)],
    [VECTOR_WIDTH, 0],
    [VECTOR_ELLIPSE, 50, 50, 50, 50],
  ]
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
})

let scanPointsOfInterestCooldown = Watched(null)

ecs.register_es("track_scan_points_of_interest_cooldown_effect",
  {
    [[EventScanPointsOfInterest]] = function(evt, _eid, comp) {
      let startTime = get_sync_time()
      let duration = comp.human_scan_points_of_interest__useCooldowns[evt.humanScanMode]

      scanPointsOfInterestCooldown.set({duration, endTime = startTime + duration})
    }
    onDestroy = @() scanPointsOfInterestCooldown.set(null)
  },

  {
    comps_ro = [
      ["human_scan_points_of_interest__useTimer", ecs.TYPE_FLOAT],
      ["human_scan_points_of_interest__useCooldowns", ecs.TYPE_FLOAT_LIST],
    ],
    comps_rq = [["watchedByPlr", ecs.TYPE_EID]]
  }
)

let mkScanner = @() function() {
  let {endTime=0, duration=0} = scanPointsOfInterestCooldown.get()
  let countdown = mkCountdownTimer(Watched(endTime), $"inv_scanPointsOfInterestProto")
  return {
    size = statusWidth
    watch = scanPointsOfInterestCooldown
    behavior = Behaviors.Button
    onClick = requestScan
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    onHover = @(on) setTooltip(!on ? null : tooltipBox(@() {
      watch = [scanPointsOfInterestCooldown, countdown]
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      gap = hdpx(8)
      children = countdown.get() > 0
        ? mkText(loc("effects/scan_points_of_interest_cooldown", { duration = truncateToMultiple(countdown.get(), 1)}))
        : [ mkInputHintBlock("HUD.MapScanPointsOfInterest"), mkText(loc("hint/scan_points_of_interest"))]

     }))
    children = [
      iconBackground,
      @() {
        size = iconWidth
        rendObj = ROBJ_IMAGE
        image = Picture($"ui/skin#radar.svg:{iconWidth}:{iconWidth}:P")
      },
     duration > 0 ? function() {
        return {
          size = flex()
          watch = countdown
          rendObj = ROBJ_PROGRESS_CIRCULAR
          image = Picture($"ui/skin#round_border.svg:{statusWidth}:{statusWidth}:P")
          fgColor = mul_color(RedWarningColor, 0.7)
          bgColor = TextDisabled
          fValue = countdown.get() / duration
        }
      } : null
    ]
  }
}


let opacityBlock = @() {
  flow = FLOW_HORIZONTAL
  gap = hdpx(8)
  size = FLEX_H
  valign = ALIGN_CENTER
  children = [
    mkScanner()
    { size = [hdpx(10),0] }
    mkText(loc("map/player_points_opacity"), {margin = hdpx(2)})
    {
      size = flex(2)
      children = Horiz(playerPointsOpacity)
    }
    { size = flex(0.2) }
    mkText(loc("map/teammates_points_opacity"), {margin = hdpx(2)})
    {
      size = flex(2)
      children = Horiz(teammatesPointsOpacity)
    }
  ]
}

let framedMap = @() {
  children = [
    @() {watch = hudIsInteractive, halign = ALIGN_RIGHT, children = hudIsInteractive.get() ? closeBtn : null, size = FLEX_H}
    {
      flow = FLOW_VERTICAL
      padding = mapPadding
      gap = hdpx(5)
      children = [
        mkZoneInfo()
        mapLayers
        opacityBlock
      ]
    }
  ]
}.__update(bluredPanel)

let mapBlock = function(){
  return {
    watch = tiledMapExist
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
  let watch = static [isNexus]
  if (!isNexus.get())
    return static { watch }

  return {
    watch
    flow = FLOW_HORIZONTAL
    gap = static hdpx(10)
    children = [
      enemiesBlock
      teammatesBlock
    ]
  }
}

function bigMap() {
  if (isFirstTime) {
    alignMapToZone()
    isFirstTime = false
  }

  return {
    watch = [safeAreaHorPadding, safeAreaVerPadding]
    size = screenSize
    onAttach
    onDetach
    key = BigMapId
    gap = static hdpx(10)
    flow = FLOW_HORIZONTAL
    halign = ALIGN_RIGHT
    hplace = ALIGN_RIGHT
    padding = [fsh(1) + safeAreaVerPadding.get(), fsh(3), 0, safeAreaHorPadding.get()]
    children = [
      nexusMapBlock
      mapBlock
    ]

    animations = mapRootAnims
    hotkeys = static [
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
  openBigMap = @() ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu(static {menuName = BigMapId}))
}
