from "%dngscripts/globalState.nut" import nestWatched
from "%sqGlob/dasenums.nut" import ContractType
from "%ui/components/commonComponents.nut" import mkSelectPanelItem, mkTabs, mkConsoleScreen, mkTitleString,
  fontIconButton, BD_LEFT, mkTextArea, mkInfoTxtArea, mkHelpConsoleScreen, mkText, mkTooltiped,
  VertSmallSelectPanelGap, mkMonospaceTimeComp, getTextColorForSelectedPanelText, mkSelectPanelTextCtor, bluredPanel
from "%ui/helpers/parseSceneBlk.nut" import get_zone_info, get_tiled_map_info, get_spawns, get_extractions,
  get_raid_description, get_nexus_beacons, ensurePoint2, ensurePoint3
from "%ui/mainMenu/raid_preparation_window_state.nut" import closePreparationsScreens
from "dagor.math" import Point2, Point3, cvt
from "math" import cos, sin, fabs, sqrt, max, atan2, floor, PI, ceil
from "eventbus" import eventbus_send
from "%sqstd/rand.nut" import shuffle
from "%sqstd/string.nut" import utf8ToUpper, tostring_r
from "%ui/mainMenu/stdPanel.nut" import stdBtnFontSize, mkCloseBtn, mkBackBtn, mkHelpButton, mkHeader,
  mkWndTitleComp, wrapButtons, wrapInStdPanel, stdBtnSize, screenSize, mkCloseStyleBtn
from "%ui/fonts_style.nut" import h1_txt, body_txt, h2_txt, sub_txt
from "%ui/components/msgbox.nut" import showMessageWithContent, showMsgbox
from "%ui/components/scrollbar.nut" import makeVertScroll
from "%ui/mainMenu/clusters.nut" import mkClustersUi
from "%ui/mainMenu/startButton.nut" import consoleRaidAdditionalButton, onboardingRaidButton
from "%ui/components/button.nut" import textButton, button, buttonWithGamepadHotkey
from "%ui/components/textarea.nut" import textarea
from "%ui/mainMenu/contractWidget.nut" import contractsPanel, mkRewardBlock, reportContract, mkDifficultyBlock
from "%ui/mainMenu/possibleLoot.nut" import mkPossibleLootBlock
from "%ui/matchingQueues.nut" import getNearestEnableTime, getNextEnableTime, isQueueDisabledBySchedule
from "%ui/quickMatchQueue.nut" import leaveQueue
from "%ui/mainMenu/raidAutoSquad.nut" import autosquadWidget
from "%ui/mainMenu/offline_raid_widget.nut" import mkOfflineRaidCheckBox, wantOfflineRaid, mkOfflineRaidIcon, isOfflineRaidAvailable
from "%ui/mainMenu/contractPanelCommon.nut" import mkContractsCompleted, hasPremiumContracts
from "%ui/hud/state/onboarding_state.nut" import onboardingQuery
from "%ui/state/matchingUtils.nut" import get_matching_utc_time
from "%ui/mainMenu/zoneTimeAndWetherWidget.nut" import mkZoneWidgets
from "%ui/mainMenu/currencyIcons.nut" import premiumColor
from "%ui/hud/map/tiled_map_ctx.nut" import tiledMapSetup, getFogOfWarData
from "dagor.debug" import logerr
from "%ui/state/queueState.nut" import doesZoneFitRequirements, isZoneUnlocked, isQueueHiddenBySchedule
from "%ui/mainMenu/notificationMark.nut" import mkNotificationMark
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/hud/map/map_spawn_points.nut" import mkSpawns
from "%ui/hud/map/map_extraction_points.nut" import mkExtractionPoints
from "%ui/hud/map/map_nexus_beacons.nut" import mkNexusBeaconMarkers
from "%ui/mainMenu/raid_preparation_window.nut" import mkPreparationWindow
from "%ui/hud/menus/mintMenu/mintMenuContent.nut" import mkMintContent, resetMintMenuState
from "%ui/hud/hud_menus_state.nut" import openMenuInteractive, convertMenuId
import "%ui/components/tooltipBox.nut" as tooltipBox
import "%ui/components/faComp.nut" as faComp
import "%ui/components/spinnerList.nut" as spinnerList
from "dagor.localize" import doesLocTextExist
from "%ui/components/cursors.nut" import setTooltip
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "tiledMap.behaviors" import TiledMap
from "%ui/mainMenu/clonesMenu/clonesMenuCommon.nut" import ClonesMenuId, AlterSelectionSubMenuId
import "%ui/components/colors.nut" as colors
from "%ui/popup/player_event_log.nut" import addPlayerLog, mkPlayerLog, playerLogsColors
from "%ui/faction_presentation.nut" import mkFactionIcon
import "%ui/components/checkbox.nut" as checkBox
from "%ui/helpers/timers.nut" import mkCountdownTimerPerSec
from "%ui/components/modalWindows.nut" import addModalWindow, removeModalWindow
from "%ui/mainMenu/contractWidget.nut" import  contractReportIsInProgress, isRightRaidName
from "%ui/leaderboard/lb_state_base.nut" import curFactionLbData, curFactionLbPlayersCount, refreshFactionLb, updateRefreshTimer
from "%ui/profile/profileState.nut" import playerBaseState, playerStats, playerProfileCurrentContracts,
  nexusNodesState, currentContractsUpdateTimeleft, numOfflineRaidsAvailable, trialData
from "%ui/mainMenu/nexus_tutorial.nut" import checkShowNexusTutorial, mkNexusBriefingButton
from "%sqGlob/userInfoState.nut" import userInfo
from "%ui/mainMenu/currencyPanel.nut" import showNotEnoughPremiumMsgBox
from "%ui/mainMenu/trial_button.nut" import showEndDemoMsgBox

let { matchingQueuesMap, matchingQueues, matchingTime } = require("%ui/matchingQueues.nut")
let { selectedSpawn, selectedRaid, raidToFocus, leaderSelectedRaid, selectedNexusFaction,
  selectedNexusNode, showNexusFactions, selectedPlayerGameModeOption, GameMode, setShowNexusFactions, allowRaidsSelectInNexus } = require("%ui/gameModeState.nut")
let { squadLeaderState, isInSquad, isSquadLeader } = require("%ui/squad/squadState.nut")
let { isOnboarding, playerProfileOnboardingContracts } = require("%ui/hud/state/onboarding_state.nut")
let { tiledMapContext, tiledMapDefaultConfig } = require("%ui/hud/map/tiled_map_ctx.nut")
let { raidZoneInfo, raidZone } = require("%ui/hud/map/map_restr_zones_raid_menu.nut")
let { scalebar } = require("%ui/hud/map/map_scalebar.nut")
let { currentMapVisibleRadius } = require("%ui/hud/map/map_state.nut")
let { PREPARATION_SUBMENU_ID, Missions_id, isPreparationOpened,
  isNexusPreparationOpened, mintEditState } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { isInBattleState, levelIsLoading } = require("%ui/state/appState.nut")
let { currentMenuId } = require("%ui/hud/hud_menus_state.nut")
let { myExtSquadData } = require("%ui/squad/squadManager.nut")
let { PREPARATION_NEXUS_SUBMENU_ID } = require("%ui/hud/menus/mintMenu/mintState.nut")

const NODE_PREFIX = "nexus_node_"
const FACTION_PREFIX = "faction_"
const ANIM_DURATION = 1.8

let rowHeight = hdpx(40)
let contractsCountdown = mkCountdownTimerPerSec(currentContractsUpdateTimeleft, "nexusGraphContractsCountdown")

let keysWithHint = Watched([])
levelIsLoading.subscribe_with_nasty_disregard_of_frp_update(@(v) v ? keysWithHint.set([]) : null)

ecs.register_es("track_keys_with_hint",
  {
    onInit = function(eid, comp) {
      if (isInBattleState.get())
        return

      let name = comp.item__name
      let scenes = comp.key__scenes.getAll()
      keysWithHint.mutate(@(v) v.append({eid, name, scenes}))
    }
    onDestroy = function(eid, _comp) {
      keysWithHint.mutate(function(v){
        let idx = v.findindex(@(x) x.eid == eid)
        if (idx == null)
          return v

        v.remove(idx)
        return v
      })
    }
  },
  {
    comps_ro = [
      ["item__name", ecs.TYPE_STRING],
      ["key__scenes", ecs.TYPE_STRING_LIST],
    ]
  }
)

let difficultyColors = static {
  dif_easy = Color(60, 200, 100, 160)
  dif_norm = Color(200, 200, 60, 160)
  dif_hard = Color(200, 60, 60, 160)
}

let difficultyDisabledColors = static {
  dif_easy = Color(60, 200, 100, 60)
  dif_norm = Color(200, 200, 60, 60)
  dif_hard = Color(200, 60, 60, 60)
}
let btnSound = freeze({
  click = "ui_sounds/button_highlight"
  hover = "ui_sounds/button_highlight"
})




























let gap = hdpx(10)
let titleHeight = hdpx(50)

function updateMapPos(scene){
  let mapDesc = get_tiled_map_info(scene)
  if (mapDesc == null)
    return

  let restrZone = get_zone_info(scene)

  let lt = ensurePoint2(mapDesc.leftTop)
  let rb = ensurePoint2(mapDesc.rightBottom)

  let defaultCenter = Point3((lt.x + rb.x) / 2.0, 0, (lt.y + rb.y) / 2.0)
  let defaultRadius = (rb.x - lt.x) / 2.0

  let pos = ensurePoint3(restrZone?.sourcePos ?? defaultCenter)
  let visibleRadius = (restrZone?.radius ?? defaultRadius) * 1.05

  if (restrZone){
    raidZoneInfo.set({
      worldPos = pos
      radius = restrZone.radius
    })
  }
  else
    raidZoneInfo.set(null)

  currentMapVisibleRadius.set(visibleRadius)
  tiledMapContext.setVisibleRadius(visibleRadius)
  tiledMapContext.setWorldPos(pos)
}

function setupMapContext(scene, mapSize) {
  let mapInfo = get_tiled_map_info(scene)

  if (mapInfo == null){
    tiledMapSetup("Missions Menu", tiledMapDefaultConfig)
    return
  }

  let config = {
    leftTop = ensurePoint2(mapInfo.leftTop)
    rightBottom = ensurePoint2(mapInfo.rightBottom)
    visibleRange = ensurePoint2(mapInfo.visibleRange)
    tileWidth = mapInfo.tileWidth
    zlevels = mapInfo.zlevels
    northAngle = mapInfo.northAngle
    tilesPath = mapInfo.tilesPath
    viewportWidth = mapSize[0]
    viewportHeight = mapSize[1]
    backgroundColor = mapInfo.backgroundColor
    fogOfWarEnabled = mapInfo.fogOfWarEnabled
    fogOfWarSavePath = mapInfo.fogOfWarSavePath
  }

  let restrZone = get_zone_info(scene)
  if (config.fogOfWarEnabled && !restrZone){
    logerr("Unable to parse zone parameters for fog of war. Possible reasons: zone entity not present in the scene or not parsed correctly.")
    return
  }

  if (config.fogOfWarEnabled) {
    let data = getFogOfWarData(config.fogOfWarSavePath)
    config.fogOfWarOldDataBase64 <- data?.b64
    config.fogOfWarOldLeftTop <- ensurePoint2(data?.leftTop)
    config.fogOfWarOldRightBottom <- ensurePoint2(data?.rightBottom)
    config.fogOfWarOldResolution <- data?.resolution
    config.fogOfWarLeftTop <- Point2(restrZone.sourcePos.x, restrZone.sourcePos.z) - Point2(restrZone.radius, restrZone.radius)
    config.fogOfWarRightBottom <- Point2(restrZone.sourcePos.x, restrZone.sourcePos.z) + Point2(restrZone.radius, restrZone.radius)
    config.fogOfWarResolution <- mapInfo.fogOfWarResolution
  }
  tiledMapSetup("Missions Menu", config)
  updateMapPos(scene)
}

let gameModeIcon = @(raid_type, text_color, size = hdpxi(20)) {
  rendObj = ROBJ_IMAGE
  size = size
  color = text_color
  image = Picture("!ui/skin#raid_info/{0}.svg:{1}:{1}:K".subst(raid_type, size))
}

let help_data = freeze({
  content = "missions/helpContent"
  footnotes = [
    "missions/helpFootnote1",
    "missions/helpFootnote2",
    "missions/helpFootnote3",
    "missions/helpFootnote4",
    "missions/helpFootnote5",
    "missions/helpFootnote6",
    "missions/helpFootnote7",
    "missions/helpFootnote8",
    "missions/helpFootnote9",
    "missions/helpFootnote10",
    "missions/helpFootnote11",
    "missions/helpFootnote12",
    "missions/helpFootnote13",
    "missions/helpFootnote14",
    "missions/helpFootnote15",
    "missions/helpFootnote16",
    "missions/helpFootnote17",
    "missions/helpFootnote18",
    "missions/helpFootnote19",
    "missions/helpFootnote20",
    "missions/helpFootnote21"
  ]
})

let missionsMenuName = loc("Missions")
let raidWindowName = utf8ToUpper(loc("missions/title"))

function padWithZero(num) {
  return num < 10 ? $"0{num}" : $"{num}"
}

let nexusGraphDistSortOrder = ["inner", "medium", "outer"]
function getNexusNodeName(node) {
  let hour = padWithZero(node.nameParts.hours)
  let minutes = padWithZero(node.nameParts.minutes)
  let dist = $"nexus_graph/dist/{node.nameParts.dist}"

  return $"{hour}:{minutes} #{node.nameParts.idx+1} ({loc(dist)})"
}

let nexusUnavailablePanel = {
  behavior = Behaviors.Button
  size = flex()
  stopHover = true
  children = mkTextArea(loc("nexus/nexusUnavailablePanel"), {
    size = flex(), valign = ALIGN_CENTER, halign = ALIGN_CENTER
  }.__merge(body_txt))
}.__merge(bluredPanel)

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

let prevSelectedZonesPerGameMode = persist("prevSelectedZonesPerGameMode", @() {})


function updateSelectedZone(availableZones){
  let curPGM = selectedPlayerGameModeOption.get()
  let prevZone = availableZones.findvalue(@(v) v.id == prevSelectedZonesPerGameMode?[curPGM].id)

  if (prevZone)
    selectedRaid.set(prevZone)
  else
    selectedRaid.set(availableZones?[0])
}

local prevoisOfflineRaidStatus = null

function checkLeaderRaidChange(data) {
  let { raidData = null, isOffline = false } = data?.leaderRaid
  if (raidData == null)
    prevoisOfflineRaidStatus = null

  let leaderRaidName = raidData?.extraParams.raidName
  let currentRaidName = selectedRaid.get()?.extraParams.raidName
  if (leaderRaidName != null
    && leaderRaidName != currentRaidName
    && (isPreparationOpened.get() || isNexusPreparationOpened.get())
  ) {
    showMsgbox({ text = loc("missions/noLeaderRaid") })
    myExtSquadData.ready.set(false)
    leaveQueue()
    closePreparationsScreens()
    return
  }
  if (prevoisOfflineRaidStatus == null)
    prevoisOfflineRaidStatus = isOffline
  else if (prevoisOfflineRaidStatus != isOffline && !isSquadLeader.get()) {
    myExtSquadData.ready.set(false)
    addPlayerLog({
      id = $"{leaderRaidName}_{isOffline}"
      content = mkPlayerLog({
        titleText = loc("missions/leaderChangedStatus")
        titleFaIcon = "star"
        bodyText = loc("missions/currentRaidStatus",
          { status = isOffline ? loc("queue/offline_raid") : loc("queue/common_raid")})
        logColor = playerLogsColors.warningLog
      })
    })
    prevoisOfflineRaidStatus = isOffline
  }
}

let matchingUTCTime = Watched(0)
let updateTime = @() matchingUTCTime.set(get_matching_utc_time())

let premiumBg = {
  rendObj = ROBJ_SOLID
  size = flex()
  transform = {}
  opacity = 0.2
  color = premiumColor
  animations = [{prop = AnimProp.color, from = 0x00000000, to = premiumColor, duration = 3,
    play = true, loop = true, easing = CosineFull }]
}

let mkNexusFactionWindowKey = @(faction) $"{faction}_wnd"

let factionLbCategories = [
  {
    field = "idx"
    locId = "lb/index"
    width = hdpx(100)
    dataIdx = 0
    valueToShow = @(idx) idx + 1
  }
  {
    field = "name"
    locId = "lb/name"
    width = flex()
    dataIdx = 2
    valueToShow = @(name) name
  }
  {
    field = "score"
    locId = "lb/nexusScore"
    width = hdpx(150)
    dataIdx = 3
    override = {
      halign = ALIGN_RIGHT
    }
    valueToShow = @(score) score
  }
]

let mkLbTitle = @(locId, override = static {}) {
  rendObj = ROBJ_SOLID
  size = static [flex(), rowHeight]
  color = 0xF01C1C1C
  padding = static [0, hdpx(8)]
  valign = ALIGN_CENTER
  children = mkText(loc(locId), static { color = colors.InfoTextValueColor }.__update(sub_txt))
}.__update(override)

let mkDataRow = @(data, ctor, idx, override, isLocalPlayer) data == null ? null : function() {
  let textColor = isLocalPlayer ? colors.BtnBgActive : colors.TextNormal
  return {
    rendObj = ROBJ_SOLID
    size = static [flex(), rowHeight]
    color = idx == 0 || idx % 2 == 0 ? 0xDD0F0F0F : 0xDD1C1C1C
    valign = ALIGN_CENTER
    padding = static [0, hdpx(8)]
    children = mkText(ctor(data), { color = textColor }.__update(sub_txt))
  }.__update(override)
}

let lbSize = [hdpx(800), SIZE_TO_CONTENT]

function mkDataTable(dataToAdd, factionNum) {
  let pageCols = factionLbCategories.map(function(category) {
    let { locId, dataIdx, valueToShow, override = static {}, width } = category
    let title = mkLbTitle(locId, override)
    let mkData = @(data) dataIdx == 3 ? data?[factionNum.tointeger() + 4] : data?[dataIdx]
    let userId = userInfo.get()
    return @() {
      watch = userInfo
      size = [width, SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      children = [
        title
      ].extend(dataToAdd.map(function(v, idx) {
        let isLocalPlayer = v[1] == userId
        return mkDataRow(mkData(v), valueToShow, idx, override, isLocalPlayer)
      }))
    }
  })
  return pageCols
}

let emptyText = mkTextArea(loc("faction/lbEmpty"), {
  vplace = ALIGN_CENTER
  halign = ALIGN_CENTER
}.__update(h2_txt))

let mkLbList = @(factionNum) function() {
  if (curFactionLbData.get() == null || curFactionLbData.get().len() == 0)
    return {
      watch = curFactionLbData
      size = lbSize
      children = emptyText
    }

  let res = []
  let data = curFactionLbData.get()

  let dataToAdd = data.slice(0, min(data.len(), 100))
  let resData = dataToAdd.filter(@(d) (d?[factionNum.tointeger() + 4] ?? 0) > 0)
  foreach (i, _data in resData)
    data[0] = i

  res.append(mkDataTable(resData, factionNum))

  if (res.len() <= 0)
    return {
      watch = curFactionLbData
      size = lbSize
      children = emptyText
    }
  return {
    watch = [curFactionLbData, curFactionLbPlayersCount]
    size = flex()
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      mkTextArea(loc("faction/lbTitle"), { size = lbSize, hplace = ALIGN_CENTER }.__update(body_txt))
      makeVertScroll({
        halign = ALIGN_CENTER
        size = FLEX_H
        gap = hdpx(10)
        children = res.map(@(v) {
          size = lbSize
          flow = FLOW_HORIZONTAL
          children = v
        })
      })
    ]
  }
}

function openNexusFactionWindow(faction, factionActiveContracts, patchedNodes) {
  let factionNum = faction.slice(-1) == "0" ? "10" : faction.slice(-1)
  let key = mkNexusFactionWindowKey(faction)
  let headerBlock = {
    size = FLEX_H
    halign = ALIGN_RIGHT
    children = [
      {
        flow = FLOW_VERTICAL
        size = FLEX_H
        children = [
          mkText(loc("faction/infoTitle"), { hplace = ALIGN_CENTER }.__merge(h2_txt))
          mkText(loc("faction/infoTitle/desc"), { hplace = ALIGN_CENTER }.__merge(sub_txt))
        ]
      }
      mkCloseStyleBtn(@() removeModalWindow(key))
    ]
  }

  let infoHeader = {
    size = FLEX_H
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      mkTextArea(loc("faction/infoHeader"), body_txt)
      {
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        valign = ALIGN_CENTER
        children = [
          mkFactionIcon(faction, [hdpxi(100), hdpxi(100)])
          mkTextArea(loc(faction), { color = colors.InfoTextValueColor }.__merge(body_txt))
        ]
      }
    ]
  }
  
  let factionInfoBlock = @() {
    padding = hdpx(10)
    size = static [pw(30), flex()]
    flow = FLOW_VERTICAL
    children = [
      {
        size = FLEX_H
        flow = FLOW_VERTICAL
        gap = hdpx(20)
        padding = static [0, 0, hdpx(10), 0]
        vplace = ALIGN_TOP
        children = [
          infoHeader
          mkTextArea(loc($"{faction}/desc"))
        ]
      }
      {
        size = FLEX
        flow = FLOW_VERTICAL
        gap = hdpx(50)
        vplace = ALIGN_BOTTOM
        children = [
          function() {
            let contractIds = factionActiveContracts.get()?[faction] ?? []
            let activeNodes = contractIds.map(function(contractId) {
              let nodeId = playerProfileCurrentContracts.get()[contractId].params.nodeId[0]
              return mkText(getNexusNodeName(patchedNodes.get()[nodeId] ), static { color = colors.InfoTextValueColor })
            })
            let ownedNodesList = patchedNodes.get().filter(@(v) v?.owner == faction)
            let ownedNodes = ownedNodesList.values().map(function(node) {
              let factionIdx = node.owner.replace(FACTION_PREFIX, "").tointeger() - 1
              let nodeColor = colors.colorblindPalette[factionIdx % colors.colorblindPalette.len()]
              return mkText(getNexusNodeName(node), { color = nodeColor })
            })
            return {
              watch = [factionActiveContracts, playerProfileCurrentContracts, patchedNodes]
              flow = FLOW_VERTICAL
              gap = hdpx(20)
              size = FLEX
              children = [
                ownedNodes.len() <= 0 ? null : {
                  flow = FLOW_VERTICAL
                  size = FLEX
                  gap = hdpx(4)
                  children = [
                    mkText(loc("faction/ownedNodes", { nodes = ownedNodes.len()}), body_txt)
                  ].append(makeVertScroll({size = FLEX_H flow = FLOW_VERTICAL gap = VertSmallSelectPanelGap children = ownedNodes}))
                }
                activeNodes.len() <= 0 ? null : {
                  flow = FLOW_VERTICAL
                  size = FLEX
                  gap = hdpx(4)
                  children = [
                    mkText(loc("faction/activeNodes", { nodes = contractIds.len()}), body_txt)
                  ].append(makeVertScroll({size = FLEX_H flow = FLOW_VERTICAL gap = VertSmallSelectPanelGap children = activeNodes}))
                }
              ]
            }
          }
          textButton(loc("faction/join"), @() showMsgbox({ text = loc("faction/joinImpossible")}),
            {
              size = static [flex(), hdpx(70)]
              halign = ALIGN_CENTER
              vplace = ALIGN_BOTTOM
              fontSize = h2_txt.fontSize
            }.__merge(accentButtonStyle))
        ]
      }
    ]
  }.__update(bluredPanel)

  addModalWindow({
    rendObj = ROBJ_WORLD_BLUR_PANEL
    size = flex()
    key
    onDetach = @() updateRefreshTimer(false, @() refreshFactionLb(factionNum), faction)
    onAttach = function() {
      refreshFactionLb(factionNum)
      updateRefreshTimer(true, @() refreshFactionLb(factionNum), faction)
    }
    children = {
      rendObj = ROBJ_BOX
      size = screenSize
      fillColor = colors.ConsoleFillColor
      borderWidth = static [hdpx(1), 0]
      borderColor = colors.BtnBgDisabled
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      flow = FLOW_VERTICAL
      gap = hdpx(30)
      padding = static [hdpx(22), hdpx(10), hdpx(10), hdpx(10)]
      children = [
        headerBlock
        {
          size = flex()
          flow = FLOW_HORIZONTAL
          gap = hdpx(10)
          children = [
            mkLbList(factionNum)
            factionInfoBlock
          ]
        }
      ]
    }
  })
}

function getContent() {
  updateTime()
  let actualMatchingQueuesMap = Computed(@() isOnboarding.get() ? onboardingQuery : matchingQueuesMap.get())
  let {zoneWeatherWidget, zoneTimeWidget} = mkZoneWidgets(matchingUTCTime)
  let selectedRaidBySquadLeader = Computed(@() squadLeaderState.get()?.leaderRaid)

  let availableZones = Computed(function(prev) {
    let { raidData = null } = selectedRaidBySquadLeader.get()
    let queues = actualMatchingQueuesMap.get()
    let stats = playerStats.get()
    function isZoneVisible(v) {
      if (v?.extraParams?.neverShow ?? false) {
        return false
      }
      let isNexusSelected = selectedPlayerGameModeOption.get() == GameMode.Nexus
      let isNexus = v?.extraParams.nexus ?? false
      let requirements = doesZoneFitRequirements(v?.extraParams.requiresToShow, stats)
      return isEqual(prev, raidData) || ((isNexusSelected == isNexus) && requirements)
    }

    let variants = queues
      .values()
      .filter(isZoneVisible) 
      .sort(@(a, b) isZoneUnlocked(b, stats, matchingUTCTime, isInSquad.get(), isSquadLeader.get(), raidData)
          <=> isZoneUnlocked(a, stats, matchingUTCTime, isInSquad.get(), isSquadLeader.get(), raidData)
        || (queues[a.id]?.extraParams?.uiOrder ?? 9999) <=> (queues[b.id]?.extraParams?.uiOrder ?? 9999)
        || a.id <=> b.id)
    if (isEqual(prev, variants))
      return prev
    return variants
  })

  let nextRaidShiftTimestamp = Computed(function() {
    let mt = matchingTime.get()
    return matchingQueues.get().reduce(function(res, v) {
      let nextEnableTime = getNextEnableTime(v, mt)
      if (nextEnableTime == -1)
        return res
      if (res == 0 || nextEnableTime < res)
        return nextEnableTime
      return res
    }, 0)
  })

  let nextRotation = Computed(@() (nextRaidShiftTimestamp.get() ?? 0) != 0 && (matchingUTCTime.get() > 0)
    ? nextRaidShiftTimestamp.get() - matchingUTCTime.get()
    : null)

  
  if (raidToFocus.get()?.raid == null) {
    availableZones.subscribe_with_nasty_disregard_of_frp_update(updateSelectedZone)
    updateSelectedZone(availableZones.get())
  }
  else
    selectedRaid.set(raidToFocus.get().raid)

  let mkRaidDescFunc = @(sceneW) function() {
    let scene = sceneW.get()
    return get_raid_description(scene)
  }
  let selectedRaidScene = Computed(@() selectedRaid.get()?.scenes[0].fileName)
  let raidDesc = Computed(mkRaidDescFunc(selectedRaidScene))

  let spawns = Computed(function() {
    let q = selectedRaid.get()
    if (q == null)
      return {}

    let isNexus  = q?.extraParams.nexus
    let scene = q.scenes[0].fileName
    let allSpawns = get_spawns(scene) ?? []

    if (!isNexus) {
      
      let offset = 1

      let numTeams = q.teams.len()
      local result = allSpawns.reduce(function(acc, v) {
        let id = v.spawnGroupId

        
        if (numTeams < id - offset){
          return acc
        }
        if (acc?[id] == null) {
          let locRaid = $"{q.extraParams.raidName}/spawn_name/{id - offset}"
          let locZone = $"{q.extraParams.raidName.split("+")?[1]}/spawn_name/{id - offset}"
          acc[id] <- {
            spawnGroupId = id,
            mteams = [id - offset]
            spawns = [v],
            locId = doesLocTextExist(locRaid) ? locRaid : locZone
          }
        } else {
          acc[id].spawns.append(v)
        }
        return acc
      }, {})

      return result
    } else {
      let result = {}
      result[1] <- {
        spawns = allSpawns
        locId = "hint/spawnPolygoneMinimapMarker"
      }
      return result
    }

    return {}
  })

  let extracts = Computed(function() {
    let scene = selectedRaid.get()?.scenes[0].fileName

    let spawnGroupId = selectedSpawn.get()?.spawnGroupId
    let extractions = get_extractions(scene) ?? []
    return extractions.map(function(v){
      if (spawnGroupId != null && !v.spawnGroups.contains(spawnGroupId)){
        return {}.__merge(v, {showAsInactive = true})
      }
      return v
    })
  })

  let nexus_beacons = Computed(function() {
    let isNexus = selectedRaid.get()?.extraParams.nexus
    if (!isNexus)
      return []

    let scene = selectedRaid.get()?.scenes[0].fileName
    let beacons = get_nexus_beacons(scene) ?? []

    let res = beacons.map(@(v, idx) [$"{idx}", v]).totable()
    return res
  })

  let mkSpawnPoints = @(mapSize) @(){
    watch = spawns
    ctor = @(p) mkSpawns(
      spawns.get(),
      get_zone_info(selectedRaid.get()?.scenes[0].fileName),
      get_raid_description(selectedRaid.get()?.scenes[0].fileName),
      mapSize,
      p?.transform ?? {}
    )
  }

  let extractionPoints = {
    watch = extracts
    ctor = @(p) mkExtractionPoints(extracts.get(), p?.transform ?? {})
  }

  let beaconMarkers = {
    watch = nexus_beacons
    ctor = @(_) mkNexusBeaconMarkers(nexus_beacons.get()?.keys(), nexus_beacons)
  }

  let tiledFogOfWar = {
    watch = null
    ctor = @(_) {
      size = flex()
      tiledMapContext = tiledMapContext
      rendObj = ROBJ_TILED_MAP_FOG_OF_WAR
      behavior = TiledMap
    }
  }

  let canChooseGameMode = Computed(@() !isInSquad.get() || isSquadLeader.get())

  function mkRequireToUnlockZoneInfo(zoneInfo){
    let params = zoneInfo?.extraParams.requiresToSelect

    let ret = []
    if (doesZoneFitRequirements(params, playerStats.get())) {
      if (getNearestEnableTime(zoneInfo, matchingUTCTime.get()) == -1) {
        ret.append(mkText(loc("requirement/temporarily_disabled"), {halign = ALIGN_RIGHT}))
      }
      else {
        ret.append(@(){
          gap = hdpx(6)
          flow = FLOW_HORIZONTAL
          watch = nextRotation
          size = FLEX_H
          children = [
            mkText(loc("missions/available_in"))
            mkMonospaceTimeComp(max(nextRotation.get() ?? 0, 0))
          ]
        })
      }
    }
    else {
      foreach (req in (params ?? [])) {
        if (type(req) == "string") { 
          ret.append( mkInfoTxtArea(loc("requirement/require"), loc($"requirement/{req}")).__update( {halign = ALIGN_RIGHT}) )
        }
        else {
          foreach (stat_name, stat_val in req)
            if ((playerStats.get()?.statsCurrentSeason?[stat_name] ?? 0) < stat_val)
              ret.append(mkInfoTxtArea(loc("requirement/require"),
                "{0} {1}".subst(loc($"requirement/{stat_name}"), stat_val)).__update( {halign = ALIGN_RIGHT}) )
        }
      }
    }

    return ret
  }

  function mkMissionImages(mapSize, raidDescW = raidDesc, override={}) {
    let imageSize = [flex(), (mapSize[1] - 2 * hdpx(10)) / 3]
    return function() {
      let images = raidDescW.get()?.images ?? ["ui/zone_thumbnails/no_info", "ui/zone_thumbnails/no_info", "ui/zone_thumbnails/no_info"]
      return {
        watch = raidDescW
        key = raidDescW.get()
        size = FLEX_H
        flow = FLOW_VERTICAL
        gap = hdpx(10)
        children = images.map(@(v) {
          rendObj = ROBJ_IMAGE
          size = imageSize
          keepAspect = KEEP_ASPECT_FIT
          key = v
          image = Picture(v)
        }.__update(override))
      }.__update(override)
    }
  }

  let mkRaidInfoIcon = @(icon_name, icon_size, icon_color) mkTooltiped({
    rendObj = ROBJ_IMAGE
    size = icon_size
    color = icon_color
    image = Picture("!ui/skin#raid_info/{0}.svg:{1}:{1}:K".subst(icon_name, icon_size))
  }, loc($"missionInfo/{icon_name}"))

  let mkRaidInfoLine = @(icon_name, icon_size, icon_color, text_color = null) {
    flow = FLOW_HORIZONTAL
    gap = hdpx(5)
    halign = ALIGN_RIGHT
    children = [
      mkText(loc($"missionInfo/{icon_name}"), { color = text_color ?? icon_color })
      {
        rendObj = ROBJ_IMAGE
        size = [icon_size, icon_size]
        color = icon_color
        image = Picture("!ui/skin#raid_info/{0}.svg:{1}:{1}:K".subst(icon_name, icon_size))
      }
    ]
  }

  function raidGroupSizeBlock() {
    let maxGroupSize = min(4, selectedRaid.get()?.maxGroupSize ?? 1)
    return {
      watch = [selectedRaid, raidDesc]
      size = flex()
      gap = hdpx(5)
      margin = static [0, hdpx(2), 0, 0]
      flow = FLOW_VERTICAL
      halign = ALIGN_RIGHT
      valign = ALIGN_CENTER
      children = [
        mkRaidInfoLine($"squad_{maxGroupSize}", hdpx(20), colors.TextHighlight, colors.TextNormal)
      ]
    }
  }

  function keysWidget() {
    let watch = [selectedRaid, keysWithHint]
    if (selectedRaid.get() == null)
      return { watch }

    let qScenes = selectedRaid.get()?.scenes ?? []
    let fittingKeys = keysWithHint.get().filter(@(k) k.scenes.findindex(@(s) qScenes.findindex(@(qs) qs.fileName.startswith(s)) != null) != null)

    if (fittingKeys.len() == 0)
      return { watch }

    
    let keyLocs = fittingKeys.reduce(function(acc, k){
      let locName = loc(k.name)
      if (!acc.contains(locName))
        acc.append(locName)
      return acc
    }, []).sort()

    let hintIcon = {
      rendObj = ROBJ_IMAGE
      size = hdpxi(20)
      image = Picture($"ui/skin#itemFilter/keys.svg:{hdpxi(20)}:{hdpxi(20)}:P")
      color = colors.TextHighlight
    }

    return {
      watch
      size = FLEX_H
      children = mkTooltiped({
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        children = [ hintIcon, mkText(loc("missions/available_keys", { n = keyLocs.len() })) ]
      }, ", ".join(keyLocs))
    }
  }

  let raidDefinitionBlock = @() {
    size = FLEX_H
    flow = FLOW_VERTICAL
    gap = hdpx(4)
    children = [
      keysWidget
      {
        flow = FLOW_VERTICAL
        gap = hdpx(8)
        size = FLEX_H
        children = [
          mkText(loc("contracts/enemies"))
          function() {
            let enemies = raidDesc.get()?.enemies ?? []
            return {
              watch = raidDesc
              size = FLEX_H
              gap = hdpx(4)
              flow = FLOW_HORIZONTAL
              children = enemies.map(@(v) mkRaidInfoIcon(v, hdpx(30), colors.TextHighlight))
            }
          }
        ]
      }
    ]
  }

  let mkEnvironmentBlock = @(queueData) {
    size = FLEX_H
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      mkText(loc("contracts/environment"))
      {
        size = FLEX_H
        flow = FLOW_VERTICAL,
        gap = hdpx(10),
        children = [
          zoneTimeWidget(queueData),
          zoneWeatherWidget(queueData)
        ]
      }
    ]
  }

  function selectedQueueInfo() {
    let { id = null } = selectedRaid.get()
    let watch = selectedRaid
    if (id == null)
      return { watch }

    let zoneInfoblock = {
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(8)
      children = [
        raidDefinitionBlock
        mkEnvironmentBlock(selectedRaid.get())
      ]
    }

    return {
      watch
      size = FLEX_H
      gap = hdpx(10)
      flow = FLOW_VERTICAL
      children = zoneInfoblock
    }
  }

  let mkConsoleRaidTab = @(params, text, notifCount) @() {
    size = FLEX_H
    children = [
      {
        size = FLEX_H
        clipChildren = true
        children = {
          halign = ALIGN_CENTER
          behavior = Behaviors.Marquee
          group = params?.group
          size = FLEX_H
          children = { rendObj = ROBJ_TEXT text }.__update(sub_txt, params)
        }
      }
      {
        pos = static [-hdpx(4), -hdpx(1)], hplace = ALIGN_RIGHT, vplace = ALIGN_TOP, size = 0, children = mkNotificationMark(Watched(notifCount))
      }
    ]
  }
  function gameModeTabs() {
    let tabsList = GameMode.reduce(function(resList, pmode) {
      let isNexus = pmode == GameMode.Nexus
      let contractsToCheck = playerProfileCurrentContracts.get()
        .filter(@(v) isNexus ? v.raidName.startswith("nexus") : !v.raidName.startswith("nexus"))
      let completedCounter = contractsToCheck.reduce(@(res, v)
        v.currentValue >= v.requireValue && !v.isReported ? res + 1 : res, 0)
      return resList.append({
        id = isNexus ? GameMode.Nexus : GameMode.Raid
        isAvailable = isNexus && isOnboarding.get() ? Watched(false) : Watched(true)
        unavailableHoverHint = loc("nexus/nexusUnavailablePanel")
        childrenConstr = @(params) mkConsoleRaidTab(params,
          isNexus ? loc("gameMode/nexus") : loc("gameMode/raid"),
          completedCounter)
      })
    }, [])
    .sort(@(a, b) b.id <=> a.id)

    let tabsUi = mkTabs({
      tabs = tabsList
      currentTab = selectedPlayerGameModeOption.get()
      onChange = function(tab) {
        if (tab.id == selectedPlayerGameModeOption.get())
          return
        if (tab.id == "Nexus") {
          wantOfflineRaid.set(false)
          checkShowNexusTutorial()
        }
        selectedPlayerGameModeOption.set(tab.id)
      }
      override = static { size = FLEX_H tab_override = {padding=[fsh(1), fsh(0.5)] size = FLEX_H }}
    })
    return {
      watch = [playerProfileCurrentContracts, isOnboarding, selectedPlayerGameModeOption]
      size = static [flex(), titleHeight]
      flow = FLOW_HORIZONTAL
      gap = hdpx(2)
      children = tabsUi
    }
  }

  let zoneSound = static {
    click = "ui_sounds/zone_select"
    active = null
  }
  let lockColor = static Color(100,80,80)
  let mkZoneSelItem = function(opt) {
    let q = actualMatchingQueuesMap.get()?[opt.id]
    if (q == null)
      return null
    let isUnlocked = @() isZoneUnlocked(q, playerStats.get(), matchingUTCTime,
      isInSquad.get(), isSquadLeader.get(), selectedRaidBySquadLeader.get()?.raidData)
    let scene = q?.scenes[0].fileName
    let raid_description = get_raid_description(scene)

    let notification = mkContractsCompleted(q?.extraParams.raidName)
    let isDisabled = Computed(@() doesZoneFitRequirements(q?.extraParams.requiresToSelect, playerStats.get())
      && (!q.enabled || isQueueHiddenBySchedule(q, matchingUTCTime.get())))
    let visual_params = {
      style = !isDisabled.get() ? {} : static { BtnBgNormal = colors.BtnBgDisabled }
      size = FLEX_H
      onHover = function(on) {
        if (!on || !isInSquad.get()) {
          setTooltip(null)
          return
        }
        if (selectedRaidBySquadLeader.get()?.raidData == null) {
          if (isSquadLeader.get())
            setTooltip(loc("missions/makeLeaderSelection"))
          else
            setTooltip(loc("missions/waitingLeaderSelectionDesc"))
        }
        else
          setTooltip(loc("missions/anotherLeaderSelectionDesc"))
      }
      padding = 0
    }
    let onSelect = function(v) {
      selectedRaid.set(v)
      prevSelectedZonesPerGameMode[selectedPlayerGameModeOption.get()] <- v
    }
    let qName = loc(q.locId)
    let difficulty = raid_description?.difficulty ?? "unknown"
    return mkSelectPanelItem({
      children = @(params) @() {
        watch = [playerStats, selectedRaidBySquadLeader]
        size = FLEX_H
        children = [
          @() {
            watch = [playerProfileCurrentContracts, playerProfileOnboardingContracts, isOnboarding]
            size = flex()
            children = !hasPremiumContracts(playerProfileCurrentContracts.get(), playerProfileOnboardingContracts.get(),
              isOnboarding.get(), q?.extraParams.raidName) ? null : premiumBg
          }
          {
            size = FLEX_H
            flow = FLOW_HORIZONTAL
            gap = hdpx(4)
            valign = ALIGN_CENTER
            padding = static [hdpx(5), hdpx(10)]
            children = [
              mkRaidInfoIcon(difficulty, hdpx(20), (isUnlocked() ? difficultyColors : difficultyDisabledColors)?[difficulty] ?? colors.TextNormal)
              !isUnlocked() ? static faComp("lock", {color = lockColor, fontSize = hdpxi(14)}) : null
              function() {
                let isHover = (params.stateFlags.get() & S_HOVER)
                let textColor = isUnlocked()
                  ? (params.isSelected()
                      ? (isHover ? colors.BtnTextHover : colors.BtnTextActive)
                      : (isHover ? colors.BtnTextHighlight : colors.BtnTextNormal)
                    )
                  : lockColor
                return {
                    color = textColor, text = qName, watch = params.watch
                    rendObj = ROBJ_TEXT
                    behavior = static [Behaviors.Marquee, Behaviors.Button]
                    speed = static [hdpx(40),hdpx(40)]
                    delay = 0.3
                    scrollOnHover = true
                    size = FLEX_H
                    eventPassThrough = true
                  }
              }
              @() {
                watch = notification
                size = notification.get() <= 0 ? 0 : hdpxi(16)
                children = mkNotificationMark(notification)
              }
            ]
          }
        ]
      }
      visual_params = visual_params
      sound = zoneSound
      onSelect
      state = selectedRaid
      border_align = BD_LEFT
      idx = opt
    })
  }

  let mkZonesWithTitle = @(title, zones, footer = null) {
    size = flex()
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    xmbNode = XmbContainer({
      canFocus = true
      wrap = false
      scrollSpeed = 5.0
    })
    children = [
      makeVertScroll({
        size = FLEX_H
        flow = FLOW_VERTICAL
        gap = VertSmallSelectPanelGap
        padding = static [0,0, hdpx(10), 0]
        children = [title!=null && zones.len() > 0 ? mkText(title, static { padding = static [0,0, hdpx(5), 0]}) : null].extend(zones)
      })
      footer
    ]
  }

  let mkRotationComp = @(nextIn) {
    flow = FLOW_HORIZONTAL
    size = FLEX_H
    behavior = Behaviors.Button
    skipDirPadNav = true
    onHover = @(on) setTooltip(on ? loc("missions/rotationHint") : null)
    children = [
      static mkTextArea(loc("missions/available_in"))
      mkMonospaceTimeComp(nextIn)
    ]
  }
  let rotSize = calc_comp_size(mkRotationComp(1))

  function nextRaidRotationTimer() {
    if (nextRotation.get() == null || nextRotation.get() <= 0)
      return { watch = nextRotation }.__update({size = rotSize})
    return {
      watch = nextRotation
    }.__update(mkRotationComp(nextRotation.get()))
  }

  let waitingForLeaderRaid = mkTextArea(loc("missions/leaderSelectionRequired"), { color = colors.InfoTextValueColor })
  let chooseLeaderRaid = mkTextArea(loc("missions/makeLeaderSelection"), { color = colors.InfoTextValueColor })

  function squadLeaderRaid() {
    let watch = [selectedRaidBySquadLeader, isInSquad]
    if (!isInSquad.get())
      return { watch }
    let leaderRaid = selectedRaidBySquadLeader.get()?.raidData
    if (leaderRaid == null)
      return {
        watch = [selectedRaidBySquadLeader, isInSquad, isSquadLeader]
        size = FLEX_H
        children = isSquadLeader.get() ? chooseLeaderRaid : waitingForLeaderRaid
      }
    let isOffline = selectedRaidBySquadLeader.get()?.isOffline ?? false
    return {
      watch
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(4)
      children = [
        mkTextArea(loc("missions/squadLeaderRaid"))
        button({
          size = FLEX_H
          flow = FLOW_HORIZONTAL
          gap = hdpx(4)
          valign = ALIGN_CENTER
          children = [
            static faComp("star", {
              color = colors.ContactLeader
              fontSize = hdpxi(16)
            })
            mkText(loc(leaderRaid.locId), {
              size = FLEX_H
              scrollOnHover = true
              behavior = static [Behaviors.Marquee, Behaviors.Button]
              delay = 0.3
              eventPassThrough = true
            })
            isOffline ? mkOfflineRaidIcon({ fontSize = hdpxi(16), color = colors.ContactLeader }) : null
          ]
        }, function() {
          let isNexus = leaderRaid?.extraParams.nexus ?? false
          selectedPlayerGameModeOption.set(isNexus ? GameMode.Nexus : GameMode.Raid)
          selectedRaid.set(leaderRaid)
          prevSelectedZonesPerGameMode[selectedPlayerGameModeOption.get()] <- leaderRaid
        }, {
          size = static [flex(), hdpx(30)]
          padding = static [hdpx(5), hdpx(10)]
          onHover = @(on) setTooltip(on ? loc("missions/squadLeaderRaid") : null)
        })
      ]
    }
  }

  let nexusGraphBBox = Computed(function() {
    let randomNode = nexusNodesState.get().findvalue(@(_) true)
    if (randomNode == null)
      return [[0,0], [100, 100]]
    return nexusNodesState.get().reduce(function(acc, v) {
        let p = v.pos;
        if (acc[0][0] > p[0])
          acc[0][0] = p[0];
        if (acc[1][0] < p[0])
          acc[1][0] = p[0];
        if (acc[0][1] > p[1])
          acc[0][1] = p[1];
        if (acc[1][1] < p[1])
          acc[1][1] = p[1];
        return acc;
      },
      [
        [randomNode.pos[0], randomNode.pos[1]],
        [randomNode.pos[0], randomNode.pos[1]]
      ]
    )
  })

  let patchedNodes = Computed(function() {
    let [lt, rb] = nexusGraphBBox.get()
    let graphCenter = [(rb[0] + lt[0]) / 2, (rb[1] + lt[1]) / 2]
    let graphRadius = max((rb[0] - lt[0]) / 2, (rb[1] - lt[1]) / 2)

    let result = nexusNodesState.get().map(function(node, id) {
      let vec = [node.pos[0] - graphCenter[0], node.pos[1] - graphCenter[1]]
      let radius = sqrt(vec[0] * vec[0] + vec[1] * vec[1])
      local dist = "outer"
      
      if (radius < 0.5 * graphRadius)
        dist = "inner"
      else if (radius < 0.75 * graphRadius)
        dist = "medium"

      let angle = atan2(vec[1], vec[0])
      let time = angle / (2 * PI) * 12 + 12 + 3 
      let hours = floor(time) % 12
      let minutes = floor((time - floor(time)) * 60)
      let roundedMinutes = floor(minutes / 15) * 15

      node.nameParts <- { radius, dist, hours, angle, minutes = roundedMinutes }
      node.id <- id
      return node
    })

    let nodeClusters = result.reduce(function(acc, v, id) {
      let hour = v.nameParts.hours
      let dist = v.nameParts.dist
      let bucket = $"{hour}_{dist}"
      if (acc?[bucket] == null)
        acc[bucket] <- [id]
      else
        acc[bucket].append(id)
      return acc
    }, {}).map(function(bucket) {
      bucket.sort(function(a, b) {
        let nodeA = result[a]
        let nodeB = result[b]
        return nodeA.nameParts.radius <=> nodeB.nameParts.radius
          || nodeA.nameParts.angle <=> nodeB.nameParts.angle
          || a <=> b
      })
      return bucket
    })

    foreach (g in nodeClusters)
      g.each(@(id, idx) result[id].nameParts.idx <- idx)

    return result

  })

  let factionActiveContracts = Computed(function() {
    let contractsTable = playerProfileCurrentContracts.get().reduce(function(acc, v, id) {
      foreach (reward in v.rewards) {
        let faction = reward?.nexusFactionPoint
        if (faction == null)
          continue

        if (acc?[faction] == null) {
          acc[faction] <- [id]
        } else {
          acc[faction].append(id)
        }
      }

      return acc
    }, {}).map(@(v) v.sort(
      function(a, b) {
        let idA = playerProfileCurrentContracts.get()[a]?.params.nodeId[0]
        let idB = playerProfileCurrentContracts.get()[b]?.params.nodeId[0]
        let nodeA = patchedNodes.get()?[idA]
        let nodeB = patchedNodes.get()?[idB]
        if (nodeA == null || nodeB == null)
          return a <=> b
        return nodeA.nameParts.hours <=> nodeB.nameParts.hours
          || nodeA.nameParts.minutes <=> nodeB.nameParts.minutes
          || nexusGraphDistSortOrder.indexof(nodeA.nameParts.dist) <=> nexusGraphDistSortOrder.indexof(nodeB.nameParts.dist)
          || nodeA.nameParts.idx <=> nodeB.nameParts.idx
      }
    ))

    return contractsTable
  })

  let infoIcon = freeze(faComp("info", {
    fontSize = hdpxi(16)
    color = colors.InfoTextValueColor
  }))

  let mkInfoButton = @(faction) button(infoIcon,
    @() openNexusFactionWindow(faction, factionActiveContracts, patchedNodes),
    {
      key = faction
      size = static [hdpx(20), hdpx(20)]
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      stopHover = true
      skipDirPadNav = true
    })

  let activeNodes = Computed(@() playerProfileCurrentContracts.get().reduce(function(acc, v, contract_id){
    let connectedNodeId = v.params?.nodeId[0] ?? ""
    if (connectedNodeId != "")
      acc[connectedNodeId] <- contract_id
    return acc
  }, {}))

  let mkNodeInfo = function(node, id, size) {
    let owner = {
      flow = FLOW_HORIZONTAL
      gap = hdpx(2)
      children = [
        mkText(loc("nexus_graph/currentOwner")),
        node.owner != "" ? mkFactionIcon(node.owner, [hdpxi(24), hdpxi(24)]) : null,
        mkText(node.owner == "" ? loc("faction/noOwner") : loc(node.owner))
      ]
    }

    let isActive = Computed(@() activeNodes.get()?[id] != null)

    let nodeContract = playerProfileCurrentContracts.get()?[activeNodes.get()?[id]]
    let factions = nodeContract?.rewards.map(@(r) r?.nexusFactionPoint) ?? []

    
    let leader = node?.score.reduce(
      @(acc, _, idx, arr) ((arr?[acc] ?? 0) < arr[idx]) && arr[idx] >= (node?.minScoreToClaim ?? 0) ? idx : acc, null
    )
    let factionWithMostProgress = node?.score.reduce(
      @(acc, _, idx, arr) (arr?[acc] ?? 0) < arr[idx] ? idx : acc, null
    )

    let factionScore = function(faction) {
      let score = node?.score[faction] ?? 0
      return {
        flow = FLOW_HORIZONTAL
        gap = hdpx(2)
        valign = ALIGN_CENTER
        children = [
          mkFactionIcon(faction, [hdpxi(16), hdpxi(16)]),
          mkText(loc(faction)),
          mkText(": "),
          mkText($"{score}", { color = colors.InfoTextValueColor })
        ]
      }
    }

    let nodeContestedWidget = {
      flow = FLOW_VERTICAL
      children = [
          isActive.get() ? mkText(loc("node/contested")) : null
      ].extend(factions.map(factionScore))
    }

    let progressBarBelowLimit = function() {
      if (factionWithMostProgress == null)
        return null
      let factionIdx = factionWithMostProgress.replace(FACTION_PREFIX, "").tointeger() - 1
      let color = colors.colorblindPalette[factionIdx % colors.colorblindPalette.len()]
      let score = node?.score[factionWithMostProgress] ?? 0
      let minScore = node?.minScoreToClaim ?? 0
      return {
        flow = FLOW_HORIZONTAL
        size = static [flex(), hdpx(10)]
        children = [
          {
            rendObj = ROBJ_SOLID
            color
            size = flex(score)
          }
          {
            rendObj = ROBJ_SOLID
            color = Color(18, 18, 18)
            size = flex(minScore - score)
          }
        ]
      }
    }

    let progressBar = {
      flow = FLOW_HORIZONTAL
      size = static [flex(), hdpx(10)]
      rendObj = ROBJ_SOLID
      color = Color(18, 18, 18)
      children = factions.map(function(faction) {
        let factionIdx = faction.replace(FACTION_PREFIX, "").tointeger() - 1
        let color = colors.colorblindPalette[factionIdx % colors.colorblindPalette.len()]
        let score = node?.score[faction] ?? 0
        return {
          rendObj = ROBJ_SOLID
          color
          size = flex(score)
        }
      })
    }

    let newOwnerWidget = {
      flow = FLOW_VERTICAL
      children = leader ? [
        @() {
          watch = contractsCountdown
          flow = FLOW_HORIZONTAL
          children = [
            mkText(loc("nexus_graph/newOwnerIn"))
            mkMonospaceTimeComp(contractsCountdown.get())
          ]
        },
        {
          flow = FLOW_HORIZONTAL
          gap = hdpx(2)
          children = [
            mkText(loc("nexus_graph/nextOwner")),
            mkText(": "),
            mkFactionIcon(leader, static [hdpxi(24), hdpxi(24)]),
            mkText(loc(leader))
          ]
        }
      ] : null
    }

    return {
      flow = FLOW_VERTICAL
      gap = hdpx(2)
      size
      children = [
        {
          flow = FLOW_HORIZONTAL, gap  = hdpx(10) children = [
            mkText(getNexusNodeName(node), static { color = colors.InfoTextValueColor })
            owner
          ]
        },
        (node?.minScoreToClaim ?? 0) >= 100 ? mkTextArea(loc("nexus_graph/factionStartingPoint"), { color = colors.InfoTextValueColor }) : null,
        node?.minScoreToClaim ? mkTextArea(loc("nexus_graph/minScoreToClaim", {score=node.minScoreToClaim})) : null,
        factionWithMostProgress ? mkText(loc("nexus_graph/captureProgress")) : null,
        !factionWithMostProgress
          ? null
          : leader
            ? progressBar
            : progressBarBelowLimit(),
        nodeContestedWidget,
        newOwnerWidget,
        
      ]
    }
  }

  function mkActiveNexusNodeButton(contractId) {
    let notification = Computed(function() {
      let contract = playerProfileCurrentContracts.get()?[contractId]
      return contract && contract.requireValue <= contract.currentValue && !contract.isReported ? 1 : 0
    })
    let nodeId = playerProfileCurrentContracts.get()[contractId].params.nodeId[0]
    let group = ElemGroup()
    let selectItem = mkSelectPanelItem({
      children = @(params) {
        flow = FLOW_HORIZONTAL
        size = FLEX_H
        children = [
          mkSelectPanelTextCtor(getNexusNodeName(patchedNodes.get()[nodeId]), { size = FLEX_H, padding = [0, 0, 0, hdpx(10)] })(params),
          mkNotificationMark(notification)
        ]
      }
      state = selectedNexusNode
      onSelect = function(idx) {
        selectedNexusNode.set(idx)
      }
      idx = nodeId
      group
      visual_params = { size = FLEX_H, padding = hdpx(5), margin = [0, 0, 0, hdpx(8)], xmbNode = XmbNode() }
      border_align = BD_LEFT
    })

    let isSelected = Computed(@() selectedNexusNode.get() == nodeId)
    return @() {
      watch = isSelected
      size = FLEX_H
      children = selectItem
    }
  }

  let mkFactionLine = function(factionNum) {
    let factionKey = $"{FACTION_PREFIX}{factionNum}"

    let isSelected = Computed(@() selectedNexusFaction.get() == factionKey)
    let notifications = Computed(function(){
      let contracts = factionActiveContracts.get()?[factionKey] ?? []
      return contracts.filter(function(contractId) {
        let contract = playerProfileCurrentContracts.get()[contractId]
        return contract.requireValue <= contract.currentValue && !contract.isReported
      }).len()
    })
    let sf = Watched(0)

    let header = function() {
      let textColor = getTextColorForSelectedPanelText(isSelected.get(), sf.get() & S_HOVER)
      let isActiveFaction = (factionActiveContracts.get()?[factionKey] ?? []).len() > 0
      let textParams = {
        color = textColor
        fontFx = isSelected.get() ? null : FFT_GLOW
        fontFxColor = Color(0, 0, 0, 55)
      }
      return {
        watch = [sf, isSelected, factionActiveContracts]
        rendObj = ROBJ_BOX
        size = FLEX_H
        behavior = Behaviors.Button
        onClick = function(){
          if (isSelected.get()) {
            selectedNexusFaction.set(null)
          } else {
            selectedNexusFaction.set(factionKey)
            let firstFactionContract = factionActiveContracts.get()?[factionKey][0]
            let nodeId = playerProfileCurrentContracts.get()?[firstFactionContract].params.nodeId[0]
            selectedNexusNode.set(nodeId)
          }
        }
        flow = FLOW_HORIZONTAL
        gap = hdpx(8)
        valign = ALIGN_CENTER
        fillColor = sf.get() & S_HOVER ? colors.BtnBgHover
          : isSelected.get() ? colors.BtnBgSelected
          : !isActiveFaction ? colors.BtnBgDisabled
          : colors.SelBgNormal
        borderColor = sf.get() & S_HOVER ? colors.SelBdHover : isSelected.get() ? colors.SelBdSelected : colors.SelBdNormal
        borderWidth = static [0,0,0, hdpx(2)]
        padding = static [hdpx(2), hdpx(10)]
        xmbNode = XmbNode()
        onElemState = @(s) sf.set(s)
        clipChildren = true
        children = [
          mkFactionIcon(factionKey, [hdpxi(24), hdpxi(24)])
          {
            size = FLEX_H
            valign = ALIGN_CENTER
            children = [
              mkText(loc(factionKey), {
                size = FLEX_H
                behavior = Behaviors.Marquee
                speed = hdpx(50)
              }.__merge(textParams))
              !isActiveFaction ? { rendObj = ROBJ_SOLID, color=Color(255, 0, 0, 255), size=[flex(), hdpx(1)] } : null
            ]
          }
          mkNotificationMark(notifications)
          mkInfoButton(factionKey)
        ]
      }
    }
    let body = @() {
      watch = factionActiveContracts
      size = FLEX_H
      rendObj = ROBJ_SOLID
      color = colors.BtnBgNormal
      flow = FLOW_VERTICAL
      padding = hdpx(4)
      gap = hdpx(2)
      children = factionActiveContracts.get()?[factionKey].map(mkActiveNexusNodeButton)
    }
    return @() {
      watch = isSelected
      flow = FLOW_VERTICAL
      size = FLEX_H
      valign = ALIGN_CENTER
      children = [
        header
        isSelected.get() ? body : null
      ]
    }
  }

  function mkNexusRaidLine(zoneVariant) {
    let isSelected = Computed(@() selectedRaid.get() == zoneVariant)
    let sf = Watched(0)
    let raidNodes = Computed(function() {
      let raidName = selectedRaid.get()?.extraParams.raidName

      if (raidName == null)
        return []

      let contractIds = playerProfileCurrentContracts.get().reduce(function(acc, v, id) {
        if (raidName.startswith(v.raidName) && v?.params.nodeId[0] != null)
          acc.append(id)
        return acc
      }, []).sort(
        function(a, b) {
          let idA = playerProfileCurrentContracts.get()[a]?.params.nodeId[0]
          let idB = playerProfileCurrentContracts.get()[b]?.params.nodeId[0]
          let nodeA = patchedNodes.get()?[idA]
          let nodeB = patchedNodes.get()?[idB]
          if (nodeA == null || nodeB == null)
            return a <=> b
          return nodeA.nameParts.hours <=> nodeB.nameParts.hours
            || nodeA.nameParts.minutes <=> nodeB.nameParts.minutes
            || nexusGraphDistSortOrder.indexof(nodeA.nameParts.dist) <=> nexusGraphDistSortOrder.indexof(nodeB.nameParts.dist)
            || nodeA.nameParts.idx <=> nodeB.nameParts.idx
        }
      )
      return contractIds
    })

    let header = function() {
      let q = actualMatchingQueuesMap.get()?[zoneVariant.id]
      if (q == null)
        return null
      let isUnlocked = @() isZoneUnlocked(q, playerStats.get(), matchingUTCTime,
        isInSquad.get(), isSquadLeader.get(), selectedRaidBySquadLeader.get()?.raidData)
      let scene = q?.scenes[0].fileName
      let raid_description = get_raid_description(scene)

      let notification = mkContractsCompleted(q?.extraParams.raidName)

      let onClick = function() {
        if (isSelected.get()) {
          selectedRaid.set(null)
          selectedNexusNode.set(null)
          prevSelectedZonesPerGameMode.$rawdelete(selectedPlayerGameModeOption.get())
        } else {
          selectedRaid.set(zoneVariant) 

          let nodeId = playerProfileCurrentContracts.get()?[raidNodes.get()?[0]].params.nodeId[0]
          selectedNexusNode.set(nodeId)
          prevSelectedZonesPerGameMode[selectedPlayerGameModeOption.get()] <- zoneVariant
        }
      }

      let qName = loc(q.locId)
      let difficulty = raid_description?.difficulty ?? "unknown"

      return {
        watch = [sf, isSelected]
        rendObj = ROBJ_BOX
        size = FLEX_H
        behavior = Behaviors.Button
        onClick
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        valign = ALIGN_CENTER
        fillColor = sf.get() & S_HOVER ? colors.BtnBgHover : isSelected.get() ? colors.BtnBgSelected : colors.SelBgNormal
        borderColor = sf.get() & S_HOVER ? colors.SelBdHover : isSelected.get() ? colors.SelBdSelected : colors.SelBdNormal
        borderWidth = static [0,0,0, hdpx(2)]
        padding = static [hdpx(5), hdpx(10)]
        onElemState = @(s) sf.set(s)
        skipDirPadNav = true
        children = [
          {
            size = FLEX_H
            flow = FLOW_HORIZONTAL
            gap = hdpx(4)
            valign = ALIGN_CENTER
            children = [
              mkRaidInfoIcon(difficulty, hdpx(20), (isUnlocked() ? difficultyColors : difficultyDisabledColors)?[difficulty] ?? colors.TextNormal)
              !isUnlocked() ? static faComp("lock", {color = lockColor, fontSize = hdpxi(14)}) : null
              function() {
                let isHover = (sf.get() & S_HOVER)
                let textColor = isUnlocked()
                  ? (isSelected.get()
                      ? (isHover ? colors.BtnTextHover : colors.BtnTextActive)
                      : (isHover ? colors.BtnTextHighlight : colors.BtnTextNormal)
                    )
                  : lockColor
                return {
                    watch = [sf, isSelected]
                    color = textColor,
                    text = qName
                    rendObj = ROBJ_TEXT
                    behavior = static [Behaviors.Marquee, Behaviors.Button]
                    speed = static [hdpx(40),hdpx(40)]
                    delay = 0.3
                    xmbNode = XmbNode()
                    scrollOnHover = true
                    size = FLEX_H
                    eventPassThrough = true
                }
              }
              @() {
                watch = notification
                size = notification.get() <= 0 ? 0 : hdpxi(16)
                children = mkNotificationMark(notification)
              }
            ]
          }
        ]
      }
    }

    let body = @() {
      watch = raidNodes
      size = FLEX_H
      rendObj = ROBJ_SOLID
      color = colors.BtnBgNormal
      flow = FLOW_VERTICAL
      padding = hdpx(4)
      gap = hdpx(2)
      children = raidNodes.get().map(mkActiveNexusNodeButton)
    }

    return @() {
      watch = isSelected
      size = FLEX_H
      flow = FLOW_VERTICAL
      children = [
        header
        isSelected.get() ? body : null
      ]
    }
  }



  let createFactionButton = textButton(loc("faction/create"),
    @() showMsgbox({ text = loc("faction/createImpossible")}),
    {
      size = FLEX_H
      halign = ALIGN_CENTER
    })

  function zonesSelector() {
    local content = null
    if (selectedPlayerGameModeOption.get() == GameMode.Nexus) {
      if (showNexusFactions.get() == false) {
        content = mkZonesWithTitle(null, availableZones.get().map(mkNexusRaidLine))
        let contractId = activeNodes.get()?[selectedNexusNode.get()]
        let raidName = playerProfileCurrentContracts.get()?[contractId]?.raidName
        if (raidName != null) {
          let firstFittingZone = availableZones.get().findvalue(@(v) v?.extraParams.raidName.startswith(raidName))
          selectedRaid.set(firstFittingZone)
        }
      } else {
        content = mkZonesWithTitle(static loc("nexusFactionsList"), array(10, 0)
        .map(@(_, idx) idx + 1)
        .sort(@(a, b) ((factionActiveContracts.get()?[$"{FACTION_PREFIX}{b}"] ?? []).len()
            <=> (factionActiveContracts.get()?[$"{FACTION_PREFIX}{a}"] ?? []).len())
          || loc($"{FACTION_PREFIX}{a}") <=> loc($"{FACTION_PREFIX}{b}"))
        .map(mkFactionLine), {
          size = FLEX_H
          flow = FLOW_VERTICAL
          gap = hdpx(10)
          children = [
            mkNexusBriefingButton()
            createFactionButton
          ]
        })
        let contractId = activeNodes.get()?[selectedNexusNode.get()]
        let firstFittingFaction = playerProfileCurrentContracts.get()?[contractId].rewards.findvalue(
          @(v) v?.nexusFactionPoint != null
        ).nexusFactionPoint
        selectedNexusFaction.set(firstFittingFaction)
      }
    }
    else {
      content = mkZonesWithTitle(null, availableZones.get().map(mkZoneSelItem))
    }
    let valToString = function(v) {
      return v ? loc("nexus/factionsView") : loc("nexus/raidsView")
    }
    return {
      watch = [availableZones, selectedPlayerGameModeOption, showNexusFactions, factionActiveContracts]
      size = flex()
      flow = FLOW_VERTICAL
      gap = hdpx(8)
      children = [
        (selectedPlayerGameModeOption.get() == GameMode.Nexus && allowRaidsSelectInNexus)
          ? spinnerList({ curValue = showNexusFactions, allValues = [false, true], size = FLEX_H, valToString, setValue=setShowNexusFactions })
          : null
        selectedPlayerGameModeOption.get() == GameMode.Nexus && showNexusFactions.get() ? null : nextRaidRotationTimer
        squadLeaderRaid
        {
          size = flex()
          flow = FLOW_VERTICAL
          children = content
        }
      ]
    }
  }

  let isNexusDisabled = Computed(function() {
    return matchingQueuesMap.get().reduce(@(acc, q) acc && !q.extraParams?.nexus, true)
  })

  let selectorsBlock = {
    size = flex(0.42)
    gap = hdpx(10)
    flow = FLOW_VERTICAL
    children = [
      gameModeTabs
      @() {
        watch = [selectedPlayerGameModeOption, isNexusDisabled]
        size = flex()
        children = [
          zonesSelector
          selectedPlayerGameModeOption.get() == GameMode.Nexus && isNexusDisabled.get() ? nexusUnavailablePanel : null
        ]
      }
    ]
  }

  function autosquad(){
    return {
      watch = isOnboarding
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      children = isOnboarding.get() ? null : [ autosquadWidget ]
    }
  }

  function mkLockMsgboxContent(){
    let txts = []
    let q = selectedRaid.get()

    if (doesZoneFitRequirements(q?.extraParams.requiresToSelect, playerStats.get())){
      txts.append(mkText(loc("requirement/temporarily_disabled"), {color = colors.InfoTextValueColor}.__update(body_txt)))
      txts.append({
        flow = FLOW_VERTICAL
        size = FLEX_H
        halign = ALIGN_CENTER
        children = [
          mkText(loc("missions/rotationHint"), body_txt)
          {
            flow = FLOW_HORIZONTAL
            gap = hdpx(4)
            hplace = ALIGN_CENTER
            children = [
              mkText(loc("missions/available_in"), body_txt)
              @() {
                watch = nextRotation
                children = mkMonospaceTimeComp(nextRotation.get() != null ? max(0, nextRotation.get()) : "???", body_txt)
              }
            ]
          }
        ]
      })
    }
    else {
      let reqs = [].extend(q?.extraParams.requiresToSelect ?? [], q?.extraParams.requiresToSelectMC ?? [])
      if (reqs.len()==0)
        reqs.extend(q?.extraParams.requiresToShow)
      txts.append(textarea(loc("zone_requirements"), {color = Color(180,180,180)}))
      foreach (req in reqs) {
        if (type(req) == "string") { 
          txts.append( mkText(loc($"requirement/{req}"), {color = colors.InfoTextValueColor}.__update(body_txt)))
        }
        else {
          foreach (stat_name, stat_val in req)
            if ((playerStats.get()?.statsCurrentSeason?[stat_name] ?? 0) < stat_val)
              txts.append(mkText("{0} {1}".subst(loc($"requirement/{stat_name}"), stat_val),
                { color = colors.InfoTextValueColor}.__update( body_txt )))
        }
      }
    }

    return {
      flow = FLOW_VERTICAL
      size = static [sw(40), SIZE_TO_CONTENT]
      halign = ALIGN_CENTER
      gap = static sh(5)
      children = [
        static {rendObj = ROBJ_TEXT text = loc("zone_locked") }.__update(h1_txt)
      ].extend(txts)
    }
  }

  let raidButtonZoneLocked = buttonWithGamepadHotkey(
    mkText(utf8ToUpper(loc("zone_locked")), { hplace = ALIGN_CENTER }.__merge(h2_txt)),
    @() showMessageWithContent({content = mkLockMsgboxContent()}),
    {
      size = static [flex(), hdpx(70)]
      halign = ALIGN_CENTER
      hotkeys = [["J:Y", { description = { skip = true }}]]
    }
  )

  let raidButtonContractsLocked = @(is_enabled) function() {
    let { raidName = null } = (selectedRaid.get()?.extraParams ?? {})
    let contractsWithoutSelection = playerProfileCurrentContracts.get().reduce(function(acc, v, k) {
      if (isRightRaidName(raidName, v?.raidName)) {
        if (!v.isReported && v.currentValue >= v.requireValue && v.rewards.len() == 1)
          return acc.append({ contractType = v.contractType, id = k, name = v.name })
      }
      return acc
    }, [])

    let contractsWithSelection = playerProfileCurrentContracts.get().reduce(function(acc, v, k) {
      if (isRightRaidName(raidName, v?.raidName)) {
        if (!v.isReported && v.currentValue >= v.requireValue && v.rewards.len() > 1)
          return acc.append({ contractType = v.contractType, id = k, name = v.name })
      }
      return acc
    }, [])

    local text = ""
    if (contractsWithoutSelection.len() > 1)
      text = utf8ToUpper(loc("contract/multiReport", { num = contractsWithoutSelection.len() }))
    else if (contractsWithoutSelection.len() == 1)
      text = utf8ToUpper(loc("contract/report"))
    else if (contractsWithSelection)
      text = utf8ToUpper(loc("contract/reportWithSelection"))

    return {
      watch = [playerProfileCurrentContracts, selectedRaid]
      size = FLEX_H
      children = buttonWithGamepadHotkey(
        mkText(text, { hplace = ALIGN_CENTER }.__merge(h2_txt))
        function() {
          if (contractReportIsInProgress.get())
            return

          if (contractsWithoutSelection.len() > 0) {
            let contractsToReportIds = contractsWithoutSelection.reduce(function(acc, v) {
              if (v?.id != null)
                acc[v.id] <- 0
              return acc
            }, {})
            let contractName = contractsWithoutSelection.len() > 1 ? null : contractsWithoutSelection[0].name
            reportContract(contractsToReportIds, contractReportIsInProgress, contractName)
            return
          }
          if (contractsWithSelection.len() > 0) {
            
            let selectedNodeContract = activeNodes.get()?[selectedNexusNode.get()]
            if (contractsWithSelection.findindex(@(v) v.id == selectedNodeContract) == null) {
              selectedNexusNode.set(activeNodes.get().findindex(@(v) v == contractsWithSelection[0].id))
            }

            let newSelectedNodeContract = activeNodes.get()?[selectedNexusNode.get()]
            let contractId = contractsWithSelection.findvalue(@(v) v.id == newSelectedNodeContract)?.id

            if (contractId == null)
              return

            let nodeName = getNexusNodeName(patchedNodes.get()[selectedNexusNode.get()])
            let contract = playerProfileCurrentContracts.get()[contractId].__merge({ id = contractId })
            let uid = "consoleRaidMenu.nut/reportWithSelection/msgbox"
            showMessageWithContent({
              uid
              content = {
                size = sh(50)
                flow = FLOW_VERTICAL
                gap = hdpx(10)
                children = [
                  mkText(nodeName, h1_txt)
                  makeVertScroll(mkRewardBlock(contract, 10, uid))
                ]
              }
              buttons = [
                static {
                  text = loc("Cancel")
                  isCancel = true
                }
              ]
            })
          }
        },
        {
          size = static [flex(), hdpx(70)],
          halign = ALIGN_CENTER,
          isEnabled = is_enabled
          hotkeys = [["J:Y", { description = { skip = true } }]]
        }.__update(accentButtonStyle)
      )
    }
  }

  let selectLeaderRaidButton = {
    size = FLEX_H
    children = textButton(loc("missions/selectLeaderRaid"),
      function() {
        if (leaderSelectedRaid.get() == null)
          leaderSelectedRaid.set({
            raidData = selectedRaid.get()
            isOffline = wantOfflineRaid.get()
          })
        else {
          leaveQueue()
          leaderSelectedRaid.mutate(@(v) v.__update({
            raidData = selectedRaid.get()
            isOffline = wantOfflineRaid.get()
          }))
        }
      }
      {
        size = static [flex(), hdpx(70)]
        halign = ALIGN_CENTER
        textParams = h2_txt
        textMargin = 0
      }.__update(accentButtonStyle)
    )
  }

  function getRandomActiveNode() {
    let activeNodesData = shuffle(activeNodes.get().keys())
    let nodesWithNotCompletedContracts = activeNodesData.filter(function(n) {
      let contractId = activeNodes.get()[n]
      let contract = playerProfileCurrentContracts.get()[contractId]
      return contract.isReported || contract.currentValue >= contract.requireValue
    })
    if (nodesWithNotCompletedContracts.len() > 0)
      return nodesWithNotCompletedContracts[0]
    else if (activeNodesData.len() > 0)
      return activeNodesData[0]

    return null
  }


  let selectNexusNodeButton = buttonWithGamepadHotkey(
    mkText(utf8ToUpper(loc("nexus/select_node/button")), { hplace = ALIGN_CENTER }.__merge(h2_txt)),
    @() showMsgbox({ text = loc("nexus/select_node/msg"), buttons = [
        {text=loc("Ok"), customStyle={hotkeys=[["^Esc | Enter"]]}}
        {text=loc("nexus/select_node/select_random"), action = @() selectedNexusNode.set(getRandomActiveNode()) }
      ]
      }),
    {
      size = static [flex(), hdpx(70)]
      halign = ALIGN_CENTER
      hotkeys = [["J:Y", { description = { skip = true }}]]
    }
  )

  let blockedByDemoButton = buttonWithGamepadHotkey(
    mkText(utf8ToUpper(loc("nexus/select_node/button")), { hplace = ALIGN_CENTER }.__merge(h2_txt)),
    @() showMsgbox({ text = loc("market/disabledDueToDemoStatus"), buttons = [
        {text=loc("Ok"), customStyle={hotkeys=[["^Esc | Enter"]]}}
      ]
      }),
    {
      size = static [flex(), hdpx(70)]
      halign = ALIGN_CENTER
      hotkeys = [["J:Y", { description = { skip = true }}]]
    }
  )

  function mkPrepareButton(menuId) {
    return {
      size = FLEX_H
      children = buttonWithGamepadHotkey(mkText(loc("missions/loadoutCheck"), { hplace = ALIGN_CENTER }.__merge(h2_txt)),
        @() openMenuInteractive(menuId)
        {
          size = static [flex(), hdpx(70)]
          halign = ALIGN_CENTER
          hotkeys = [["J:Y", {description = { skip = true }}]]
        }.__update(accentButtonStyle)
      )
    }
  }

  let waitForLeaderRaidButton = {
    size = FLEX_H
    children = textButton(loc("missions/waitingLeaderSelection"),
      @() showMsgbox({ text = loc("missions/waitingLeaderSelectionDesc") })
      {
        size = static [flex(), hdpx(70)]
        halign = ALIGN_CENTER
        textParams = h2_txt
        textMargin = 0
      }
    )
  }

  let demoEndedButton = {
    size = FLEX_H
    children = textButton(loc("consoleRaid/demoExpiredButton"),
      showEndDemoMsgBox
      
      {
        size = static [flex(), hdpx(70)]
        halign = ALIGN_CENTER
        textParams = h2_txt
        textMargin = 0
      }
    )
  }

  let demoNeedsOnlineRaid = {
    size = FLEX_H
    children = textButton(loc("market/disabledDueToDemoStatus"),
      @() showNotEnoughPremiumMsgBox(mkText(loc("consoleRaid/demoNeedsOnlineRaid"), h2_txt))
      {
        size = static [flex(), hdpx(70)]
        halign = ALIGN_CENTER
        textParams = h2_txt
        textMargin = 0
      }
    )
  }

  let demoNeedsOflineRaid = {
    size = FLEX_H
    children = textButton(loc("market/disabledDueToDemoStatus"),
      @() showNotEnoughPremiumMsgBox(mkText(loc("consoleRaid/demoNeedsOfflineRaid"), h2_txt))
      {
        size = static [flex(), hdpx(70)]
        halign = ALIGN_CENTER
        textParams = h2_txt
        textMargin = 0
      }
    )
  }

  let noIsolatedTicketsButton = textButton(loc("queue/offline_raids/noTicketsShort"),
    @() showMsgbox({
      text = loc("queue/offline_raids/noTickets"),
      buttons = [
        {
          text = loc("Ok")
          isCurrent = true
        }
      ]
    }),
    {
      size = static [flex(), hdpx(70)]
      halign = ALIGN_CENTER
      textParams = body_txt
      textMargin = 0
    }
  )

  let anotherLeaderRaidButton = {
    size = FLEX_H
    children = textButton(loc("missions/anotherLeaderSelection"),
      @() showMsgbox({ text = loc("missions/anotherLeaderSelectionDesc") })
      {
        size = static [flex(), hdpx(70)]
        halign = ALIGN_CENTER
        textParams = h2_txt
        textMargin = 0
      }
    )
  }

  function startRaidPanel(){
    let isAvailable = Computed(function() {
      let raid = selectedRaid.get()
      let stat = playerStats.get()
      let utc = matchingUTCTime.get()
      let squad = isInSquad.get()
      let isLeader = isSquadLeader.get()
      let selectedByLeader = selectedRaidBySquadLeader.get()
      return isZoneUnlocked(raid, stat, utc, squad, isLeader, selectedByLeader?.raidData)
    })
    let isNexus = selectedPlayerGameModeOption.get() == GameMode.Nexus
    let isOperative = selectedRaid.get() != null && !isNexus
    function buttons() {
      let watch = [wantOfflineRaid, isOfflineRaidAvailable, isAvailable, selectedRaid, isInSquad, isSquadLeader, numOfflineRaidsAvailable,
        selectedRaidBySquadLeader, selectedNexusNode, activeNodes, squadLeaderState, trialData, playerStats]
      let { raidData = null } = selectedRaidBySquadLeader.get()
      let isLeaderSetOffline = squadLeaderState.get()?.leaderRaid.isOffline
      let isNewbyRaid = selectedRaid.get()?.extraParams.isNewby
      if (!isNewbyRaid && trialData.get()?.trialType) {
        let curStat = playerStats.get()?.stats ?? {}
        let maxStat = trialData.get()?.trialStatsLimit ?? {}

        local isOk = true

        foreach (tblKey, tblVal in maxStat) {
          foreach (statKey, statVal in tblVal) {
            let cur = curStat?[tblKey][statKey]
            if (cur == null)
              continue

            if (cur > statVal) {
              isOk = false
              break
            }
          }
        }

        if (!isOk) {
          return {
            watch
            size = FLEX_H
            children = demoEndedButton
          }
        }

        let demoType = trialData.get()?.trialType
        const DEMO_TYPE_OFFLINE_RAIDS = 1
        const DEMO_TYPE_ONLINE_RAIDS = 2
        if (demoType == DEMO_TYPE_OFFLINE_RAIDS && !wantOfflineRaid.get()) {
          return {
            watch
            size = FLEX_H
            children = demoNeedsOflineRaid
          }
        }
        else if (demoType == DEMO_TYPE_ONLINE_RAIDS && wantOfflineRaid.get()) {
          return {
            watch
            size = FLEX_H
            children = demoNeedsOnlineRaid
          }
        }
      }
      if ((wantOfflineRaid.get() && !isOfflineRaidAvailable.get() && !isNexus)
        || (isLeaderSetOffline && (raidData?.extraParams.raidName == selectedRaid.get()?.extraParams.raidName) && !isOfflineRaidAvailable.get())) {
        return {
          watch
          size = FLEX_H
          children = noIsolatedTicketsButton
        }
      }
      if (isInSquad.get() && !isSquadLeader.get() && raidData == null)
        return {
          watch
          size = FLEX_H
          children = waitForLeaderRaidButton
        }
      if (isInSquad.get() && !isSquadLeader.get() && raidData?.extraParams.raidName != null
        && raidData.extraParams.raidName != selectedRaid.get()?.extraParams.raidName)
        return {
          watch
          size = FLEX_H
          children = anotherLeaderRaidButton
        }
      if (!isAvailable.get())
        return {
          watch
          size = FLEX_H
          children = raidButtonZoneLocked
        }
      if (isNexus && trialData.get()?.trialType) {
        return {
          watch
          size = FLEX_H
          children = blockedByDemoButton
        }
      }
      if (isNexus && (selectedNexusNode.get() == null || activeNodes.get()?[selectedNexusNode.get()] == null))
        return {
          watch
          size = FLEX_H
          children = selectNexusNodeButton
        }
      if (isNexus)
        return {
          watch
          size = FLEX_H
          flow = FLOW_VERTICAL
          gap = hdpx(4)
          children = isSquadLeader.get() && (raidData?.extraParams.raidName == null
              || raidData.extraParams.raidName != selectedRaid.get()?.extraParams.raidName)
            ? selectLeaderRaidButton
            : [consoleRaidAdditionalButton(), mkPrepareButton(static $"{Missions_id}/{PREPARATION_NEXUS_SUBMENU_ID}")]
        }
      if (isOperative)
        return {
          watch
          size = FLEX_H
          flow = FLOW_VERTICAL
          gap = hdpx(4)
          children = isSquadLeader.get() && (raidData?.extraParams.raidName == null
              || raidData.extraParams.raidName != selectedRaid.get()?.extraParams.raidName)
            ? selectLeaderRaidButton
            : [consoleRaidAdditionalButton(), mkPrepareButton(static $"{Missions_id}/{PREPARATION_SUBMENU_ID}")]
        }
      return {watch}
    }

    return {
      watch = [selectedRaid, actualMatchingQueuesMap, contractReportIsInProgress, selectedPlayerGameModeOption]
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      valign = ALIGN_CENTER
      halign = ALIGN_RIGHT
      vplace = ALIGN_BOTTOM
      children = buttons
    }
  }

  let mkMapSector = @(mapSize) {
    rendObj = ROBJ_TILED_MAP
    behavior = TiledMap
    size = mapSize
    tiledMapContext = tiledMapContext
    children = [tiledFogOfWar, raidZone, scalebar, mkSpawnPoints(mapSize)(), extractionPoints, beaconMarkers]
      .map(@(c) mkTiledMapLayer(c, mapSize))
  }

  let mkMapContainer = @(mapSize, sceneW = selectedRaidScene) function() {
    let scene = sceneW.get()
    setupMapContext(scene, mapSize)
    let mapInfo = get_tiled_map_info(scene)
    return {
      watch = sceneW
      key = sceneW.get()
      rendObj = ROBJ_SOLID
      size = mapSize
      color = mapInfo?.tilesPath != null && mapInfo?.tilesPath != ""
        ? mapInfo.backgroundColor
        : colors.BtnBgDisabled
      clipChildren = true
      children = mkMapSector(mapSize)
    }
  }

  let mkNexusMapAndImages = @(sceneW = selectedRaidScene, raidDescW=raidDesc, override={}) @() {
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)
    halign = ALIGN_LEFT
    children = [
      mkMapContainer(static [hdpx(280), hdpx(280)], sceneW)
      mkMissionImages(static [hdpx(280), hdpx(280)], raidDescW, override)
    ]
  }

  function mkNotAllowedToStartInfo(q){
    return @() {
      watch = [selectedRaid, matchingUTCTime]
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      halign = ALIGN_RIGHT
      children = mkRequireToUnlockZoneInfo(q).append(raidButtonZoneLocked)
    }
  }

  let onboardingContractsInfo = @(){
    watch = contractReportIsInProgress
    size = flex()
    flow = FLOW_VERTICAL
    gap
    children = [
      contractsPanel
      onboardingRaidButton
    ]
  }
  let nexusFittingQueues = Computed(function() {
    if (!showNexusFactions.get())
      return []
    let selectedNNode = selectedNexusNode.get()
    let contractsForFaction = factionActiveContracts.get()?[selectedNexusFaction.get()] ?? []
    let mtime = matchingUTCTime.get()
    let ppcc = playerProfileCurrentContracts.get()
    let raidNames = (selectedNNode!= null ? [ppcc.findvalue(
      @(v) selectedNNode != null && v?.params.nodeId[0] == selectedNNode
    )?.raidName] : (contractsForFaction.map(@(v) ppcc?[v].raidName) ?? []))
      .filter(@(v) v!=null)
      .slice(0,5)

    if (raidNames.len() == 0)
      return []
    let qs = {}
    foreach (raidName in raidNames){
      qs.__update(matchingQueuesMap.get().filter(function(q) {
        let isFitting = q?.extraParams.raidName.startswith(raidName)
        let isDisabled = doesZoneFitRequirements(q?.extraParams.requiresToSelect, playerStats.get())
          && (q?.enabled == null || !q.enabled || isQueueDisabledBySchedule(q, mtime))
        return isFitting && !isDisabled
      }))
    }

    return qs.values().sort(@(a, b) (qs[a.id]?.extraParams?.uiOrder ?? 9999) <=> (qs[b.id]?.extraParams?.uiOrder ?? 9999) || a.id <=> b.id)
  })

  let nexusFittingScenes = Computed(function() {
    let qs = nexusFittingQueues.get()
    return qs.reduce(function(acc, v) {
      foreach (s in v.scenes) {
        if (!acc.contains(s.fileName))
          acc.append(s.fileName)
      }
      return acc
    }, [])
  })

  let nexusMapsName = function(s) {
    let name = s.split("/")?.top()
    let locId = name?.split(".")?[0] ?? ""
    return loc(locId)
  }

  let nexusMapAndImagesRaidView = mkNexusMapAndImages()
  let curSelectedSpinnerScene = Watched(nexusFittingScenes.get()?[0])
  let spinnerScene = Computed(function() {
    let cur = curSelectedSpinnerScene.get()
    if (nexusFittingScenes.get()?.contains(cur))
      return cur
    else
      return nexusFittingScenes.get()?[0]
  })
  local setNextSpinnerScene
  let setSpinnerTimer = function() {
    gui_scene.clearTimer(setNextSpinnerScene)
    gui_scene.setInterval(3, setNextSpinnerScene, setNextSpinnerScene)
  }
  setNextSpinnerScene = function() {
    let cur = curSelectedSpinnerScene.get()
    let nfs = nexusFittingScenes.get()
    let curidx = nfs.findindex(@(v) v == cur)
    if (curidx==null || curidx == nfs.len()-1)
      curSelectedSpinnerScene.set(nfs?[0])
    else {
      curSelectedSpinnerScene.set(nfs[curidx+1])
    }
    setSpinnerTimer()
  }
  let spinnerRaidDesc = Computed(mkRaidDescFunc(spinnerScene))
  let nexusMapAndImagesFactionView = mkNexusMapAndImages(spinnerScene, spinnerRaidDesc,
    static {animations = [
      { prop = AnimProp.opacity, from=0, to=1, duration=0.25, play=true, easing=InCubic }
      { prop = AnimProp.opacity, from=1, to=0, duration=0.2, playFadeOut=true, easing=OutCubic }
    ]})

  let gapLine = {
    rendObj = ROBJ_SOLID
    color = colors.ConsoleBorderColor
    margin = static [hdpx(4), 0]
    size = static[flex(), hdpx(1)]
  }
  function selectedNodeInfo() {
    let nodeId = selectedNexusNode.get()
    return {
      flow = FLOW_VERTICAL watch = selectedNexusNode size = FLEX_H children = nodeId!=null ? [gapLine, mkNodeInfo(patchedNodes.get()[nodeId], nodeId, FLEX_H), gapLine] : null
    }
  }
  function nexusRaidPreview(){
    let show_nexus_factions = showNexusFactions.get()
    let nexusFactionRaidsView = show_nexus_factions && nexusFittingQueues.get().len() > 0
    return {
      watch = [spinnerScene, nexusFittingQueues, showNexusFactions]
      flow = FLOW_VERTICAL
      size = FLEX_H
      gap = hdpx(2)
      onAttach = setSpinnerTimer
      onDetach = @() gui_scene.clearTimer(setNextSpinnerScene)
      children = nexusFactionRaidsView ? [
        mkTextArea(loc("nexus/factionsFittingRaids"))
        @(){color = colors.InfoTextValueColor size = FLEX_H watch = spinnerScene text = nexusMapsName(spinnerScene.get()) rendObj = ROBJ_TEXT behavior = Behaviors.Button onClick = setNextSpinnerScene skipDirPadNav=true}
        nexusMapAndImagesFactionView
        selectedNodeInfo
        
      ] : (
        show_nexus_factions ? selectedNodeInfo
         : [@() {watch = selectedRaid rendObj =ROBJ_TEXT text = nexusMapsName(selectedRaid.get()) color = colors.InfoTextValueColor size = FLEX_H }, nexusMapAndImagesRaidView, selectedNodeInfo]
      )
    }
  }

  let reportContractsInfo = function() {
    let is_nexus = !!selectedRaid.get()?.extraParams.nexus
    return {
      watch = selectedRaid
      size = flex()
      flow = FLOW_VERTICAL
      gap
      children = [
        is_nexus ? nexusRaidPreview : null
        contractsPanel
        raidButtonContractsLocked(!contractReportIsInProgress.get())
      ]
    }
  }

  let allowedToStartInfo = function() {
    let is_nexus = !!selectedRaid.get()?.extraParams.nexus
    return {
      watch = selectedRaid
      size = flex()
      flow = FLOW_VERTICAL
      gap
      children = [
        is_nexus ? nexusRaidPreview : null
        contractsPanel
        startRaidPanel
      ]
    }
  }

  let notAllowedToStartInfo = function() {
    let is_nexus = !!selectedRaid.get()?.extraParams.nexus
    return {
      watch = selectedRaid
      size = flex()
      flow = FLOW_VERTICAL
      gap
      children = [
        is_nexus ? nexusRaidPreview : null
        contractsPanel
        mkNotAllowedToStartInfo(selectedRaid.get())
      ]
    }
  }
  function raidMenuRightBlock(){
    let allContractsReported = Computed(function(){
      let contracts = playerProfileCurrentContracts.get()
      let { raidName = null } = (selectedRaid.get()?.extraParams ?? {})
      return contracts.reduce(function(acc, v) {
        if (raidName != null && (isRightRaidName(raidName, v.raidName) || (v.contractType == ContractType.STORY && raidName.split("+")?[1] == v.raidName))) {
          return acc && !(v.currentValue >= v.requireValue && !v.isReported)
        }
        return acc
      }, true)
    })
    return function() {
      return {
        watch = [selectedRaid, playerStats, canChooseGameMode, isInSquad, allContractsReported,
          isOnboarding, isSquadLeader, selectedRaidBySquadLeader]
        size = flex(0.8)
        children = isOnboarding.get()
          ? onboardingContractsInfo
          : !allContractsReported.get()
            ? reportContractsInfo
            : !canChooseGameMode.get()
              ? allowedToStartInfo
              : isZoneUnlocked(selectedRaid.get(), playerStats.get(), matchingUTCTime, isInSquad.get(), isSquadLeader.get(), selectedRaidBySquadLeader.get())
                ? allowedToStartInfo
                : notAllowedToStartInfo
      }
    }
  }

  let currentPrimaryContract = Computed(function(){
    let opt = selectedRaid.get()
    let fittingContracts = (isOnboarding.get() ? playerProfileOnboardingContracts.get() : playerProfileCurrentContracts.get())
      .filter(@(v) v?.contractType == ContractType.PRIMARY && v?.raidName!=null && v?.raidName == opt?.extraParams.raidName)
      .topairs()
    return fittingContracts?[0][1]
  })

  let missionTitle = function(){
    let zoneName = selectedRaid.get()?.locId ?? ""
    let title = loc(zoneName)
    let raid_description = raidDesc.get()

    let difficulty = raid_description?.difficulty ?? "unknown"
    let isUnlocked = isZoneUnlocked(selectedRaid.get(), playerStats.get(), matchingUTCTime, isInSquad.get(),
      isSquadLeader.get(), selectedRaidBySquadLeader.get())
    return {
      size = [flex(), titleHeight]
      watch = [currentPrimaryContract, raidDesc, selectedRaid]
      valign = ALIGN_CENTER
      children = [
        {
          flow = FLOW_HORIZONTAL
          size = SIZE_TO_CONTENT
          gap = hdpx(10)
          valign = ALIGN_CENTER
          children = [
            mkRaidInfoIcon(difficulty, hdpx(20), (isUnlocked ? difficultyColors : difficultyDisabledColors)?[difficulty] ?? colors.TextNormal)
            mkTitleString(title).__update({ margin = 0 })
          ]
        }
        raidGroupSizeBlock
      ]
    }
  }

  let mkOnboardingMapSector = @(mapSize) {
    rendObj = ROBJ_TILED_MAP
    behavior = TiledMap
    size = mapSize
    tiledMapContext = tiledMapContext
    children = [tiledFogOfWar, raidZone, scalebar]
      .map(@(c) mkTiledMapLayer(c, mapSize))
  }

  let mkOnboardingMapContainer = @(mapSize) function() {
    let scene = "gamedata/scenes/_onboarding_raid_debriefing_description.blk"
    setupMapContext(scene, mapSize)
    let mapInfo = get_tiled_map_info(scene)
    return {
      watch = selectedRaid
      rendObj = ROBJ_SOLID
      size = mapSize
      color = mapInfo?.tilesPath != null && mapInfo?.tilesPath != ""
        ? mapInfo.backgroundColor
        : colors.BtnBgDisabled
      clipChildren = true
      children = mkOnboardingMapSector(mapSize)
    }
  }

  let mkMapAndImages = @(mapSize) @() {
    watch = isOnboarding
    flow = FLOW_HORIZONTAL
    size = [flex(), mapSize[1]]
    gap = hdpx(10)
    children = [
      isOnboarding.get() ? mkOnboardingMapContainer(mapSize) : mkMapContainer(mapSize),
      mkMissionImages(mapSize)
    ]
  }

  let mkMissionDescriptionBlock = @(mapSize) function() {
    let isNexus = selectedRaid.get()?.extraParams.nexus ?? false
    return {
      watch = [currentPrimaryContract, selectedRaid, raidDesc]
      size = [mapSize[0], flex()]
      flow = FLOW_VERTICAL
      gap = hdpx(4)
      children = []
        .append(!selectedRaid.get()?.extraParams.nexus
          ? mkPossibleLootBlock(selectedRaid.get()?.scenes[0].fileName, raidDesc.get(), { num_in_row = 6 total_items = 11})
          : currentPrimaryContract.get() != null ? mkRewardBlock(currentPrimaryContract.get(), 7) : null)
        .append(isNexus ? null : mkOfflineRaidCheckBox({ halign = ALIGN_LEFT }), isNexus ? null : autosquad)
    }
  }

  let mkFooterDescription = @(mapSize) {
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = hdpx(20)
    children = [
      mkMissionDescriptionBlock(mapSize)
      selectedQueueInfo
    ]
  }

  let viewportSize = Watched(null)

  let nexusGraph = function() {
    let viewportOffset = Watched([0, 0])
    let mousePos = Watched([0, 0])
    let scale = Watched(0.8)
    let maxScale = 4.0
    let minScale = 0.8
    let scaleStep = 0.1
    let [lt, rb] = nexusGraphBBox.get()
    let graphCenter = [(rb[0] + lt[0]) / 2, (rb[1] + lt[1]) / 2]
    let graphRadius = max((rb[0] - lt[0]) / 2, (rb[1] - lt[1]) / 2)

    function graphToScreen(pos) {
      let mult = scale.get() * min(viewportSize.get()[0], viewportSize.get()[1])
      let offset = viewportOffset.get()
      let screenCenter = [viewportSize.get()[0] / 2, viewportSize.get()[1] / 2]
      return [
        (pos[0] - graphCenter[0]) / (rb[0] - lt[0]) * mult + offset[0] + screenCenter[0],
        (pos[1] - graphCenter[1]) / (rb[1] - lt[1]) * mult + offset[1] + screenCenter[1]
      ]
    }

    function screenToGraph(pos) {
      let mult = scale.get() * min(viewportSize.get()[0], viewportSize.get()[1])
      let offset = viewportOffset.get()
      let screenCenter = [viewportSize.get()[0] / 2, viewportSize.get()[1] / 2]
      return [
        (pos[0] - screenCenter[0] - offset[0]) * (rb[0] - lt[0]) / mult + graphCenter[0],
        (pos[1] - screenCenter[1] - offset[1]) * (rb[1] - lt[1]) / mult + graphCenter[1]
      ]
    }

    function setViewportOffset(offset) {
      viewportOffset.set(offset)

      let viewport_lt = screenToGraph(viewportSize.get().map(@(v) 0.3 * v))
      let viewport_rb = screenToGraph(viewportSize.get().map(@(v) 0.7 * v))

      local diff = [0, 0]
      if (lt[0] > viewport_rb[0])
        diff[0] = lt[0] - viewport_rb[0]
      if (lt[1] > viewport_rb[1])
        diff[1] = lt[1] - viewport_rb[1]
      if (rb[0] < viewport_lt[0])
        diff[0] = rb[0] - viewport_lt[0]
      if (rb[1] < viewport_lt[1])
        diff[1] = rb[1] - viewport_lt[1]

      let currentOffset = screenToGraph(offset)
      let correctedOffset = graphToScreen([currentOffset[0] - diff[0], currentOffset[1] - diff[1]])
      viewportOffset.set(correctedOffset)
    }

    let graphSectors = function() {
      let r3 = 1.05 * graphRadius
      let r2 = 0.75 * graphRadius
      let r1 = 0.5 * graphRadius
      let r0 = 0.2 * graphRadius

      let wh = viewportSize.get()
      let sx = 100.0 / wh[0]
      let sy = 100.0 / wh[1]
      let center = graphToScreen(graphCenter)
      let radius3 = graphToScreen([graphCenter[0] + r3, graphCenter[1]])[0] - center[0]
      let radius2 = graphToScreen([graphCenter[0] + r2, graphCenter[1]])[0] - center[0]
      let radius1 = graphToScreen([graphCenter[0] + r1, graphCenter[1]])[0] - center[0]
      let radius0 = graphToScreen([graphCenter[0] + r0, graphCenter[1]])[0] - center[0]

      let color0 = Color(10, 10, 10, 60)
      let color1 = Color(15, 15, 15, 60)

      local commands = [[VECTOR_WIDTH, radius3 - radius2], [VECTOR_INNER_LINE]]
      for (local i = 0; i < 12; i++) {
        let angle0 = i * 360.0 / 12.0
        let angle1 = (i + 1) * 360.0 / 12.0
        commands.append([VECTOR_COLOR, (i % 2) ? color0 : color1])
        commands.append([VECTOR_SECTOR, center[0] * sx, center[1] * sy, radius3 * sx, radius3 * sy, angle0, angle1])
      }
      commands.append([VECTOR_WIDTH, radius2 - radius1])
      for (local i = 0; i < 12; i++) {
        let angle0 = i * 360.0 / 12.0
        let angle1 = (i + 1) * 360.0 / 12.0
        commands.append([VECTOR_COLOR, (i % 2) ? color1 : color0])
        commands.append([VECTOR_SECTOR, center[0] * sx, center[1] * sy, radius2 * sx, radius2 * sy, angle0, angle1])
      }
      commands.append([VECTOR_WIDTH, radius1 - radius0])
      for (local i = 0; i < 12; i++) {
        let angle0 = i * 360.0 / 12.0
        let angle1 = (i + 1) * 360.0 / 12.0
        commands.append([VECTOR_COLOR, (i % 2) ? color0 : color1])
        commands.append([VECTOR_SECTOR, center[0] * sx, center[1] * sy, radius1 * sx, radius1 * sy, angle0, angle1])
      }

      return {
        watch = [scale, viewportSize, viewportOffset, nexusGraphBBox]
        size = viewportSize.get()
        rendObj = ROBJ_VECTOR_CANVAS
        fillColor = 0
        commands
      }
    }

    let clockLables = function() {
      local children = []
      for (local i = 0; i < 12; i++) {
        let angle = (i - 3) * PI / 6
        let r = 1.1 * graphRadius
        let v = [r * cos(angle), r * sin(angle)]
        let pos = graphToScreen([graphCenter[0] + v[0], graphCenter[1] + v[1]])
        
        pos[0] -= hdpx(50)
        pos[1] -= hdpx(50)

        let rotatePhase = [90, 90, 90, 90, 270, 270, 270, 270, 270, 90, 90, 90]
        children.append(mkText($"{padWithZero(i)}:00", {
          transform = { rotate = angle * 180.0 / PI + rotatePhase[i] }
          pos
          size = hdpx(100)
          color = colors.TextDisabled
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
        }))
      }
      return {
        watch = [scale, viewportSize, viewportOffset, nexusGraphBBox]
        size = viewportSize.get()
        children
      }
    }

    local edges = []
    for (local i = 0; i < patchedNodes.get().len(); i++) {
      let curId = $"{NODE_PREFIX}{i}"
      let curNode = patchedNodes.get()[curId]
      foreach (neighborId in curNode.neighbors) {
        if (i < neighborId.replace(NODE_PREFIX, "").tointeger())
          edges.append([curId, neighborId])
      }
    }

    let mkEdges = @(edgesList) function() {
      local commands = [[VECTOR_WIDTH, max(1.1, hdpx(1.2))]]

      let wh = viewportSize.get()
      let sx = 100.0 / wh[0]
      let sy = 100.0 / wh[1]
      foreach (edge in edgesList) {
        let p0 = graphToScreen(patchedNodes.get()[edge[0]].pos)
        let p1 = graphToScreen(patchedNodes.get()[edge[1]].pos)

        let x0 = sx * p0[0]
        let x1 = sx * p1[0]
        let y0 = sy * p0[1]
        let y1 = sy * p1[1]

        commands.append([VECTOR_LINE, x0, y0, x1, y1])
      }
      return {
        watch = [scale, viewportSize, viewportOffset]
        size = viewportSize.get()
        rendObj = ROBJ_VECTOR_CANVAS
        color = Color(60, 60, 60, 50)
        commands
      }
    }

    function mkNode(node, id) {
      let sf = Watched(0)
      let isActive = Computed(@() activeNodes.get()?[id] != null)
      let isSelected = Computed(@() selectedNexusNode.get() == id)

      return function() {
        local nodeColor = 0xFF1C1C1C
        local nodeSize = hdpx(8)
        local transform = {}
        if (isSelected.get()) {
          nodeSize = hdpx(10)
        }
        if (isActive.get()) {
          nodeColor = Color(220, 220, 220, 220)
          nodeSize = hdpx(12)
          transform = { rotate = 45 }
        }
        if (node.owner != "") {
          let factionIdx = node.owner.replace(FACTION_PREFIX, "").tointeger() - 1
          nodeColor = colors.colorblindPalette[factionIdx % colors.colorblindPalette.len()]
          nodeSize = nodeSize > hdpx(10) ? nodeSize : hdpx(10)
        }
        nodeSize *= cvt(scale.get(), minScale, maxScale, 1, 0.5 * maxScale)

        let getNodeTooltip = @() tooltipBox(mkNodeInfo(node, id, SIZE_TO_CONTENT))

        return {
          watch = [sf, scale, activeNodes, playerProfileCurrentContracts, isActive, isSelected]
          behavior = Behaviors.Button
          onElemState = @(s) sf.set(s)
          onClick = function() {
            if (id == selectedNexusNode.get()) {
              selectedNexusNode.set(null)
            } else {
              selectedNexusNode.set(id)
            }

            
            if (showNexusFactions.get() == false) {
              let contractId = activeNodes.get()?[selectedNexusNode.get()]
              let raidName = playerProfileCurrentContracts.get()?[contractId]?.raidName
              if (raidName != null) {
                let firstFittingZone = availableZones.get().findvalue(@(v) v?.extraParams.raidName.startswith(raidName))
                selectedRaid.set(firstFittingZone)
              }
            } else {
              let contractId = activeNodes.get()?[selectedNexusNode.get()]
              let firstFittingFaction = playerProfileCurrentContracts.get()?[contractId].rewards.findvalue(
                @(v) v?.nexusFactionPoint != null
              ).nexusFactionPoint
              selectedNexusFaction.set(firstFittingFaction)
            }
          }
          onHover = @(on) setTooltip(on ? getNodeTooltip : null)
          size = nodeSize
          pos = graphToScreen(node.pos).map(@(v, idx) v - nodeSize / 2.0 - viewportOffset.get()[idx])
          valign = ALIGN_CENTER
          halign = ALIGN_CENTER
          transform
          children = [
            isActive.get() ? {
              rendObj = ROBJ_VECTOR_CANVAS
              size = nodeSize * 3
              fillColor = 0
              color = Color(200, 200, 200)
              opacity = 0
              transform = {scale = [0, 0]}
              animations = [
                { prop = AnimProp.opacity, from=0, to=0.4, duration=ANIM_DURATION, trigger=id, easing=OutCubic },
                { prop = AnimProp.scale, from=[1,1], to=[0,0], duration=ANIM_DURATION, trigger=id, easing=InCubic },
              ]
              commands = [
                [VECTOR_ELLIPSE, 50, 50, 50, 50]
              ]
            } : null,
            isSelected.get() ? {
              rendObj = ROBJ_VECTOR_CANVAS
              size = nodeSize * 2
              color = Color(200, 200, 200, 200)
              commands = [
                [VECTOR_WIDTH, max(1.1, hdpx(1.2))],
                [VECTOR_LINE, 0,30, 0,0, 30,0],
                [VECTOR_LINE, 70,0, 100,0, 100,30],
                [VECTOR_LINE, 100,70, 100,100, 70,100],
                [VECTOR_LINE, 30,100, 0,100, 0,70],
              ]
            } : null,
            {
              rendObj = ROBJ_BOX
              size = nodeSize
              borderWidth = hdpxi(1)
              borderColor = sf.get() & S_HOVER ? colors.BtnTextHover : Color(60, 60, 60, 60)
              fillColor = nodeColor
            },
            (node?.minScoreToClaim ?? 0) >= 100 ? {
              rendObj = ROBJ_VECTOR_CANVAS
              size = 2 * nodeSize
              fillColor = nodeColor
              color = sf.get() & S_HOVER ? colors.BtnTextHover : Color(60, 60, 60, 60)
              commands = [
                [VECTOR_WIDTH, max(1.1, hdpx(1.2))],
                [VECTOR_POLY, 50,0, 60,40, 100,50, 60,60, 50,100, 40,60, 0,50, 40,40]
              ]
            } : null,
            isActive.get() && (node?.owner ?? "") != "" ? {
              rendObj = ROBJ_VECTOR_CANVAS
              size = nodeSize * 0.4
              color = 0x0
              fillColor = 0xFFFFFFFF
              animations = [
                { prop = AnimProp.fillColor, from=0xFFFFFFFF, to=0xFF000000, duration=ANIM_DURATION, play=true, loop=true, easing=InOutCubic }
              ]
              commands = [
                [VECTOR_WIDTH, 0],
                [VECTOR_ELLIPSE, 50, 50, 50, 50]
              ]
            } : null
          ]
        }
      }
    }

    function mkNodes() {
      let nodes = patchedNodes.get().map(mkNode).values()
      return {
        watch = patchedNodes
        children = @() {
          watch = viewportOffset
          pos = viewportOffset.get()
          transform = {}
          children = nodes
        }
      }
    }


    local anim_idx = 0
    let animNodesOrder = Computed(@() shuffle(activeNodes.get().keys()))
    function playRandomAnim() {
      let N = animNodesOrder.get().len()
      if (N == 0)
        return

      anim_idx = anim_idx % N
      anim_start(animNodesOrder.get()[anim_idx])
      anim_idx++
    }
    gui_scene.clearTimer("nexusGraph:animTimer")
    gui_scene.setInterval(0.4 * animNodesOrder.get().len() > ANIM_DURATION ? 0.4 : ANIM_DURATION, playRandomAnim, "nexusGraph:animTimer")

    return {
      watch = patchedNodes
      size = flex(7)
      clipChildren = true
      onAttach = function(elem) {
        viewportSize.set([elem.getWidth(), elem.getHeight()])
        gui_scene.resetTimeout(60, @() eventbus_send("profile.get_nexus_state"), "profile.get_nexus_state")
        if (selectedNexusNode.get() == null) {
          selectedNexusNode.set(getRandomActiveNode())
        }
      }
      onDetach = function(_) {
        viewportSize.set(null)
        gui_scene.clearTimer("nexusGraph:animTimer")
        gui_scene.clearTimer("profile.get_nexus_state")
      }
      behavior = [Behaviors.MoveResize, Behaviors.WheelScroll, Behaviors.TrackMouse]
      onMoveResize = function(dx, dy, _dw, _dh) {
        let curPos = viewportOffset.get()
        setViewportOffset([curPos[0] + dx, curPos[1] + dy])
        return {}
      }
      onMouseMove = function(event) {
        let rect = event.targetRect
        let elemW = rect.r - rect.l
        let elemH = rect.b - rect.t
        let relX = (event.screenX - rect.l - elemW*0.5)
        let relY = (event.screenY - rect.t - elemH*0.5)
        mousePos.set([relX, relY])
      }
      onWheelScroll = function(value) {
        let oldScale = scale.get()
        if (value > 0)
          scale.set(clamp(oldScale * (1 + scaleStep), minScale, maxScale))
        else
          scale.set(clamp(oldScale * (1 - scaleStep), minScale, maxScale))

        let mouseGraphPos = screenToGraph(mousePos.get())
        let centerPos = screenToGraph([0, 0])
        let oldDelta = [centerPos[0] - mouseGraphPos[0], centerPos[1] - mouseGraphPos[1]]

        let scaleRatio = (scale.get() / oldScale)

        let delta = [oldDelta[0] * scaleRatio, oldDelta[1] * scaleRatio]
        let screenDelta = graphToScreen([mouseGraphPos[0] + delta[0], mouseGraphPos[1] + delta[1]])
        setViewportOffset([viewportOffset.get()[0] * scaleRatio + screenDelta[0], viewportOffset.get()[1] * scaleRatio + screenDelta[1]])
      }
      children =  @() {
        watch = [viewportSize, patchedNodes]
        rendObj = ROBJ_SOLID
        color = Color(18, 18, 18, 200)
        children = viewportSize.get() == null
          ? null
          : [graphSectors, clockLables, mkEdges(edges), mkNodes]
      }
    }
  }

  function mkCentralBlock() {
    let screenContentSize = [screenSize[0] / 2, screenSize[1] ]
    let mapHgt = (screenContentSize[1] * 3 / 5*0.89).tointeger()
    let mapSize = [mapHgt, mapHgt]
    return @() {
      watch = selectedPlayerGameModeOption
      size = [screenContentSize[0], flex()]
      flow = FLOW_VERTICAL
      gap
      children = selectedPlayerGameModeOption.get() == GameMode.Nexus ? nexusGraph : [
        missionTitle
        mkMapAndImages(mapSize)
        mkFooterDescription(mapSize)
      ]
    }
  }


  let gameMode = @() {
    key = static {}
    size = flex()
    flow = FLOW_HORIZONTAL
    gap
    children = [
      selectorsBlock
      mkCentralBlock()
      @() {
        watch = [selectedPlayerGameModeOption, isNexusDisabled]
        size = flex()
        children = [
          raidMenuRightBlock()
          selectedPlayerGameModeOption.get() == GameMode.Nexus && isNexusDisabled.get() ? nexusUnavailablePanel : null
        ]
      }

    ]
  }

  let showCloseMintEditMsgBox = @() showMsgbox({
    text = loc("mint/exitEditMsgbox"),
    buttons = [
      {
        text = loc("Yes")
        action = resetMintMenuState
        isCurrent = true
      },
      static {
        text = loc("No")
        isCancel = true
      }
    ]
  })

  let {clustersText, tryOpenMenu } = mkClustersUi({textStyle = {color = Color(70,70,70,30), vplace = ALIGN_CENTER padding = static [0, hdpx(10)] behavior = Behaviors.Button }})
  let clusterBtn = fontIconButton("icon_buttons/sett_btn.svg", tryOpenMenu, {
    fontSize = stdBtnFontSize
    size = stdBtnSize
    sound = btnSound
    skipDirPadNav = true
  } )
  let helpBtn = mkHelpButton(mkHelpConsoleScreen(Picture("ui/build_icons/raid_portal.avif:{0}:{0}:P".subst(hdpx(600))), help_data), raidWindowName)
  let mkWindowHeader = @(isPreparation, isNexusPreparation) function() {
    local header = mkWndTitleComp(raidWindowName)
    let closeBtn = raidToFocus.get()?.backWay != null ? mkBackBtn(raidToFocus.get().backWay)
      : isPreparation || isNexusPreparation ? mkBackBtn(Missions_id, null, mintEditState.get() ? showCloseMintEditMsgBox : null)
      : mkCloseBtn(Missions_id)
    if (isPreparation || isNexusPreparation) {
      let raidType = raidDesc.get()?.raidType ?? "unknown"
      let icon = gameModeIcon(raidType, colors.TextNormal, hdpxi(23))
      let zoneName = selectedRaid.get()?.locId ?? ""
      header = @() {
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        gap = hdpx(4)
        valign = ALIGN_CENTER
        children = [
          mkTitleString(loc("missions/preparation")).__update(static { margin = 0 })
          icon
          mkText(loc(zoneName), h2_txt)
        ]
      }
    }
    return {
      watch = [raidDesc, selectedRaid, mintEditState]
      size = FLEX_H
      children = mkHeader(header, wrapButtons(clustersText, clusterBtn, helpBtn, closeBtn))
    }
  }

  return function() {
    let [_id, submenus] = convertMenuId(currentMenuId.get())
    let submenu = submenus?[0]
    let isPreparation = submenu == PREPARATION_SUBMENU_ID
    let isNexusPreparation = submenu == PREPARATION_NEXUS_SUBMENU_ID
    let content = isPreparation
      ? mkPreparationWindow(nextRaidRotationTimer)
      : isNexusPreparation
        ? mkMintContent(nextRaidRotationTimer)
        : mkConsoleScreen(gameMode)
    return {
      watch = [currentMenuId, raidToFocus]
      size = flex()
      onAttach = function() {
        matchingUTCTime.set(get_matching_utc_time())
        gui_scene.clearTimer(updateTime)
        gui_scene.setInterval(1, updateTime)
        squadLeaderState.subscribe_with_nasty_disregard_of_frp_update(@(v) checkLeaderRaidChange(v))
      }
      onDetach = function() {
        gui_scene.clearTimer(updateTime)
        squadLeaderState.unsubscribe(checkLeaderRaidChange)
        raidToFocus.set(null)
      }
      children = wrapInStdPanel(Missions_id, content, missionsMenuName, null,
        mkWindowHeader(isPreparation, isNexusPreparation))
    }
  }
}

let mkBeaconScreen = @() {
  getContent
  name = missionsMenuName
  notifications = mkContractsCompleted
}

return {
  missionsMenuName
  Missions_id
  mkMissionsScreen = mkBeaconScreen
  PREPARATION_SUBMENU_ID
  selectedPlayerGameModeOption
  prevSelectedZonesPerGameMode
  GameMode
}
