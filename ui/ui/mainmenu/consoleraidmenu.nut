import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "tiledMap.behaviors" import TiledMap
import "%ui/components/colors.nut" as colors

let { nestWatched } = require("%dngscripts/globalState.nut")
let { Point2, Point3 } = require("dagor.math")
let { stdBtnSize, stdBtnFontSize, mkCloseBtn, mkBackBtn, mkHelpButton, mkHeader, mkWndTitleComp, wrapButtons } = require("stdPanel.nut")
let { h1_txt, body_txt, h2_txt } = require("%ui/fonts_style.nut")
let { showMessageWithContent, showMsgbox } = require("%ui/components/msgbox.nut")
let { mkClustersUi } = require("clusters.nut")
let { consoleRaidAdditionalButton, onboardingRaidButton } = require("startButton.nut")
let { textButton } = require("%ui/components/button.nut")
let { mkSelectPanelItem, mkSelectPanelTextCtor, mkConsoleScreen, mkTitleString, fontIconButton, BD_LEFT, mkTextArea,
  mkInfoTxtArea, mkHelpConsoleScreen, mkText, mkTooltiped, VertSmallSelectPanelGap, mkMonospaceTimeComp } = require("%ui/components/commonComponents.nut")
let { textarea } = require("%ui/components/textarea.nut")
let { playerStats,
      playerProfileCurrentContracts } = require("%ui/profile/profileState.nut")
let { contractsPanel, mkRewardBlock, reportContract, contractReportIsInProgress } = require("contractWidget.nut")
let { mkPossibleLootBlock } = require("possibleLoot.nut")
let { matchingQueuesMap, matchingQueues, getNearestEnableTime, getNearestHideTime } = require("%ui/matchingQueues.nut")
let { selectedSpawn, selectedRaid } = require("%ui/gameModeState.nut")
let { autosquadWidget } = require("raidAutoSquad.nut")
let { squadLeaderState, isInSquad, isSquadLeader } = require("%ui/squad/squadState.nut")
let { mkContractsCompleted } = require("contractPanelCommon.nut")
let { isOnboarding, onboardingQuery, playerProfileOnboardingContracts } = require("%ui/hud/state/onboarding_state.nut")
let { get_matching_utc_time } = require("%ui/state/matchingUtils.nut")
let { mkZoneWidgets } = require("zoneTimeAndWetherWidget.nut")
let { tiledMapContext, tiledMapSetup, tiledMapDefaultConfig, normalizeSceneName } = require("%ui/hud/minimap/tiled_map_ctx.nut")
let { mkSmallSelection } = require("%ui/components/mkSelection.nut")
let { raidZoneInfo, raidZone } = require("%ui/hud/minimap/minimap_restr_zones_raid_menu.nut")
let { scalebar } = require("%ui/hud/minimap/map_scalebar.nut")
let { logerr } = require("dagor.debug")
let { currentMapVisibleRadius } = require("%ui/hud/minimap/map_state.nut")
let { isInQueue } = require("%ui/quickMatchQueue.nut")
let { doesZoneFitRequirements, isZoneUnlocked, isQueueHiddenBySchedule } = require("%ui/state/queueState.nut")
let { get_zone_info, get_tiled_map_info,
      get_spawns, get_extractions, get_raid_description, get_nexus_beacons,
      ensurePoint2, ensurePoint3 } = require("%ui/helpers/parseSceneBlk.nut")
let { ContractType } = require("%sqGlob/dasenums.nut")
let { mkNotificationMark } = require("%ui/mainMenu/notificationMark.nut")
let { accentButtonStyle } = require("%ui/components/accentButton.style.nut")
let { screenSize, wrapInStdPanel } = require("%ui/mainMenu/stdPanel.nut")
let { mkSpawns } = require("%ui/hud/minimap/map_spawn_points.nut")
let { mkExtractionPoints } = require("%ui/hud/minimap/map_extraction_points.nut")
let { mkNexusBeaconMarkers } = require("%ui/hud/minimap/minimap_nexus_beacons.nut")
let { preparationWindow } = require("%ui/mainMenu/raid_preparation_window.nut")
let { mintContent } = require("%ui/hud/menus/mintMenu/mintMenuContent.nut")
let { PREPARATION_SUBMENU_ID, PREPARATION_NEXUS_SUBMENU_ID, Raid_id,
      mintEditState } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { settings } = require("%ui/options/onlineSettings.nut")
let { isInBattleState, levelIsLoading } = require("%ui/state/appState.nut")
let { safeAreaHorPadding, safeAreaVerPadding, safeAreaAmount } = require("%ui/options/safeArea.nut")
let { openMenu, currentMenuId, convertMenuId } = require("%ui/hud/hud_menus_state.nut")
let faComp = require("%ui/components/faComp.nut")
let { doesLocTextExist } = require("dagor.localize")
let { setTooltip } = require("%ui/components/cursors.nut")

let keysWithHint = Watched([])
levelIsLoading.subscribe(@(v) v ? keysWithHint.set([]) : null)

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

let difficultyColors = const {
  dif_easy = Color(60, 200, 100, 160)
  dif_norm = Color(200, 200, 60, 160)
  dif_hard = Color(200, 60, 60, 160)
}

let difficultyDisabledColors = const {
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
    tiledMapSetup("Raid Menu", tiledMapDefaultConfig)
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
  }

  let restrZone = get_zone_info(scene)
  if (config.fogOfWarEnabled && !restrZone){
    logerr("Unable to parse zone parameters for fog of war. Possible reasons: zone entity not present in the scene or not parsed correctly.")
    return
  }

  if (config.fogOfWarEnabled) {
    let sceneName = normalizeSceneName(scene)
    let data = settings.get()?["fog_of_war"][sceneName]
    config.fogOfWarOldDataBase64 <- data?.b64
    config.fogOfWarOldLeftTop <- ensurePoint2(data?.leftTop)
    config.fogOfWarOldRightBottom <- ensurePoint2(data?.rightBottom)
    config.fogOfWarOldResolution <- data?.resolution
    config.fogOfWarLeftTop <- Point2(restrZone.sourcePos.x, restrZone.sourcePos.z) - Point2(restrZone.radius, restrZone.radius)
    config.fogOfWarRightBottom <- Point2(restrZone.sourcePos.x, restrZone.sourcePos.z) + Point2(restrZone.radius, restrZone.radius)
    config.fogOfWarResolution <- mapInfo.fogOfWarResolution
  }
  tiledMapSetup("Raid Menu", config)
  updateMapPos(scene)
}

let gameModeIcon = @(raid_type, text_color, size = hdpxi(20)) {
  rendObj = ROBJ_IMAGE
  size = [size, size]
  color = text_color
  image = Picture("!ui/skin#raid_info/{0}.svg:{1}:{1}:K".subst(raid_type, size))
}

let help_data = freeze({
  content = "raid/helpContent"
  footnotes = [
    "raid/helpFootnote1",
    "raid/helpFootnote2",
    "raid/helpFootnote3",
    "raid/helpFootnote4",
    "raid/helpFootnote5",
    "raid/helpFootnote6",
    "raid/helpFootnote7",
    "raid/helpFootnote8",
    "raid/helpFootnote9",
    "raid/helpFootnote10",
    "raid/helpFootnote11",
    "raid/helpFootnote12",
    "raid/helpFootnote13",
    "raid/helpFootnote14",
    "raid/helpFootnote15",
    "raid/helpFootnote16",
    "raid/helpFootnote17",
    "raid/helpFootnote18",
    "raid/helpFootnote19",
    "raid/helpFootnote20",
    "raid/helpFootnote21"
  ]
})

let raidMenuName = loc("Raid")
let raidWindowName = loc("raid/title")

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
let prevSelectedSpawnPerZone = persist("prevSelectedSpawnPerZone", @() {})

enum GameMode {
  Raid = "Raid"
  Nexus = "Nexus"
}

let PlayerGameModeOptions = freeze([GameMode.Raid, GameMode.Nexus])
let selectedPlayerGameModeOption = nestWatched("selectedPlayerGameModeOption", PlayerGameModeOptions[0])

function updateSelectedZone(availableZones){
  let curPGM = selectedPlayerGameModeOption.get()
  let prevZone = availableZones.findvalue(@(v) v.id == prevSelectedZonesPerGameMode?[curPGM].id)

  if (prevZone)
    selectedRaid.set(prevZone)
  else
    selectedRaid.set(availableZones?[0])
}

function updateSelectedSpawn(options){
  let prevSpawn = options.findvalue(@(v) isEqual(prevSelectedSpawnPerZone?[selectedRaid.get()?.id], v))

  if (prevSpawn)
    selectedSpawn.set(prevSpawn)
  else
    selectedSpawn.set(options?[0])
}

function getContent() {
  let actualMatchingQueuesMap = Computed(@() isOnboarding.get() ? onboardingQuery : matchingQueuesMap.get())
  let matchingUTCTime = Watched(0)
  gui_scene.setInterval(1, @() matchingUTCTime.set(get_matching_utc_time()))
  let {zoneWeatherWidget, zoneTimeWidget} = mkZoneWidgets(matchingUTCTime)

  let availableZones = Computed(function(prev){
    let queues = actualMatchingQueuesMap.get()
    let stats = playerStats.get()

    function isZoneVisible(v) {
      let isNexusSelected = selectedPlayerGameModeOption.get() == GameMode.Nexus
      let isNexus = v?.extraParams.nexus ?? false
      let requirements = doesZoneFitRequirements(v?.extraParams.requiresToShow, stats)
      return (isNexusSelected == isNexus) && requirements
    }

    let variants = queues
      .values()
      .filter(isZoneVisible) 
      .sort(@(a, b) isZoneUnlocked(b, stats, matchingUTCTime) <=> isZoneUnlocked(a, stats, matchingUTCTime)
                  || (queues[a.id]?.extraParams?.uiOrder ?? 9999) <=> (queues[b.id]?.extraParams?.uiOrder ?? 9999)
                  || a.id <=> b.id)
    if (isEqual(prev, variants))
      return prev
    return variants
  })
  let matchingTime = Watched(get_matching_utc_time())

  let nextRaidShiftTimestamp = Computed(function() {
    let mt = matchingTime.get()
    return matchingQueues.get().reduce(function(res, v) {
      let nearestEnableTime = getNearestEnableTime(v, mt)
      if (nearestEnableTime == -1)
        return res
      if (res == 0 || nearestEnableTime < res)
        return nearestEnableTime
      return res
    }, 0)
  })
  matchingQueues.subscribe(@(_v) matchingTime.set(get_matching_utc_time()))

  let nextRotation = Computed(@() (nextRaidShiftTimestamp.get() ?? 0) != 0 && (matchingUTCTime.get() > 0)
    ? nextRaidShiftTimestamp.get() - matchingUTCTime.get()
    : null)
  let needToUpdateList = Computed(@() nextRaidShiftTimestamp.get() != null
    && nextRaidShiftTimestamp.get() == matchingUTCTime.get())

  
  availableZones.subscribe(updateSelectedZone)
  updateSelectedZone(availableZones.get())

  let spawnOptions = Computed(function() {
    let q = selectedRaid.get()
    let numTeams = q?.teams.len()

    if (!numTeams || numTeams == 1){
      return []
    }

    let spawns = array(numTeams, 0).map(@(_, idx) idx)
    let randomSpawn = { locId = "zoneInfo/startPosRandom", mteams = spawns.reduce(@(acc, v) acc.append(v), []) }

    function calcLoc(v) {
      let locRaid = $"{q.extraParams.raidName}/spawn_name/{v}"
      let locZone = $"{q.extraParams.raidName?.split("+")?[0]}/spawn_name/{v}"
      return doesLocTextExist(locRaid) ? locRaid : locZone
    }
    let options = [randomSpawn].extend(spawns.map(@(v) { locId = calcLoc(v), mteams = [v] }))
    return options
  })

  
  spawnOptions.subscribe(updateSelectedSpawn)
  updateSelectedSpawn(spawnOptions.get())

  let raidDesc = Computed(function() {
    let scene = selectedRaid.get()?.scenes[0].fileName
    return get_raid_description(scene)
  })

  let spawns = Computed(function() {
    let q = selectedRaid.get()
    let isNexus  = q?.extraParams.nexus
    let scene = selectedRaid.get()?.scenes[0].fileName

    let allSpawns = get_spawns(scene) ?? []

    if (!isNexus){
      let defaultTeam = 0

      
      let offset = 1
      let spawnGroups = (selectedSpawn.get()?.mteams ?? [defaultTeam]).map(@(v) v + offset)

      let result = {}

      foreach (group in spawnGroups) {
        let locRaid = $"{q.extraParams.raidName}/spawn_name/{group - offset}"
        let locZone = $"{q.extraParams.raidName.split("+")?[0]}/spawn_name/{group - offset}"
        result[group] <- {
          spawns = allSpawns.filter(@(v) v.spawnGroupId == group)
          locId = doesLocTextExist(locRaid) ? locRaid : locZone
        }
      }
      return result
    } else {
      let result = {}
      result[1] <- {
        spawns = allSpawns
        locId = "hint/spawnPolygoneMinimapMarker"
      }
      return result
    }

    return []
  })

  let extracts = Computed(function() {
    let scene = selectedRaid.get()?.scenes[0].fileName

    let extractions = get_extractions(scene) ?? []
    let spawnGroups = (selectedSpawn.get()?.mteams ?? [0]).map(@(v) v + 1)

    return extractions
    .filter(
      @(v) v.spawnGroups.len() == 0 || v.spawnGroups.reduce(@(acc, g) acc || spawnGroups.contains(g), false)
    ) ?? []
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
  let selectedRaidBySquadLeader = Computed(@() squadLeaderState.get()?.selectedRaid)

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
          size = [ flex(), SIZE_TO_CONTENT ]
          children = [
            mkText(loc("raid/available_in"))
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

  function mkMissionImages(mapSize) {
    let imageSize = [flex(), (mapSize[1] - 2 * hdpx(10)) / 3]
    return function() {
      let images = raidDesc.get()?.images ?? ["ui/zone_thumbnails/no_info", "ui/zone_thumbnails/no_info", "ui/zone_thumbnails/no_info"]
      return {
        watch = raidDesc
        flow = FLOW_VERTICAL
        size = [flex(), SIZE_TO_CONTENT]
        gap = hdpx(10)
        children = images.map(@(v) {
          rendObj = ROBJ_IMAGE
          size = imageSize
          keepAspect = KEEP_ASPECT_FIT
          image = Picture(v)
        })
      }
    }
  }

  function preferredSpawnPoint(){
    let numTeams = selectedRaid.get()?.teams.len()

    if (!selectedRaid.get() || !numTeams || numTeams == 1 || spawnOptions.get().len() == 0)
      return { watch = [spawnOptions, selectedRaid] }

    return {
      watch = [spawnOptions, isInQueue, selectedRaid]
      flow = FLOW_VERTICAL
      size = [flex(), SIZE_TO_CONTENT]
      gap = hdpx(10)
      children = mkSmallSelection(spawnOptions.get(), selectedSpawn, {
        isEnabled = !isInQueue.get(),
        onClickCb = @(v) prevSelectedSpawnPerZone[selectedRaid.get().id] <- v
      })
    }
  }

  let mkRaidInfoIcon = @(icon_name, icon_size, icon_color) mkTooltiped({
    rendObj = ROBJ_IMAGE
    size = [icon_size, icon_size]
    color = icon_color
    image = Picture("!ui/skin#raid_info/{0}.svg:{1}:{1}:K".subst(icon_name, icon_size))
  }, loc($"raidInfo/{icon_name}"))

  let mkRaidInfoLine = @(icon_name, icon_size, icon_color, text_color = null) {
    flow = FLOW_HORIZONTAL
    gap = hdpx(5)
    halign = ALIGN_RIGHT
    children = [
      mkText(loc($"raidInfo/{icon_name}"), { color = text_color ?? icon_color })
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
      margin = [0, hdpx(2), 0, 0]
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
      size = [hdpxi(20), hdpxi(20)]
      image = Picture($"ui/skin#itemFilter/keys.svg:{hdpxi(20)}:{hdpxi(20)}:P")
      color = colors.TextHighlight
    }

    return {
      watch
      size = [flex(), SIZE_TO_CONTENT]
      children = mkTooltiped({
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        children = [ hintIcon, mkText(loc("raid/available_keys", { n = keyLocs.len() })) ]
      }, ", ".join(keyLocs))
    }
  }

  let raidDefinitionBlock = @() {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = hdpx(4)
    children = [
      keysWidget
      {
        flow = FLOW_VERTICAL
        gap = hdpx(8)
        children = [
          mkText(loc("contracts/enemies"))
          function() {
            let enemies = raidDesc.get()?.enemies ?? []
            return {
              watch = [raidDesc]
              size = [flex(), SIZE_TO_CONTENT]
              gap = hdpx(8)
              flow = FLOW_HORIZONTAL
              children = enemies.map(@(v) mkRaidInfoIcon(v, hdpx(30), colors.TextHighlight))
            }
          }
        ]
      }
    ]
  }

  let mkEnvironmentBlock = @(queueData) {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      mkText(loc("contracts/environment"))
      {
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
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = hdpx(8)
      children = [
        raidDefinitionBlock
        mkEnvironmentBlock(selectedRaid.get())
      ]
    }

    return {
      watch
      size = [flex(), SIZE_TO_CONTENT]
      gap = hdpx(10)
      flow = FLOW_VERTICAL
      children = zoneInfoblock
    }
  }
  let raidMenuCtor = mkSelectPanelTextCtor(loc("gameMode/raid"), body_txt)
  let nexusMenuCtor = mkSelectPanelTextCtor(loc("gameMode/nexus"), body_txt)
  let selectGameMode = @() {
    watch = playerProfileCurrentContracts
    flow = FLOW_HORIZONTAL
    size = [flex(), titleHeight]
    gap = hdpx(2)
    clipChildren = true
    children = PlayerGameModeOptions.map(function(pmode) {
      let isNexus = pmode == GameMode.Nexus
      let contractsToCheck = playerProfileCurrentContracts.get()
        .filter(@(v) isNexus ? v.raidName.startswith("nexus") : !v.raidName.startswith("nexus"))
      let completedCounter = contractsToCheck.reduce(@(res, v)
        v.currentValue >= v.requireValue && !v.isReported ? res + 1 : res, 0)
      let notifiaction = mkNotificationMark(Watched(completedCounter), const {
        hplace = ALIGN_RIGHT,
        vplace = ALIGN_TOP
        pos = [hdpx(6), -hdpx(6)]
      })
      return mkSelectPanelItem({
        children = @(params) isNexus ? [nexusMenuCtor(params), notifiaction] : [raidMenuCtor(params), notifiaction]
        idx = pmode
        disabled = isNexus && isOnboarding.get()
        state = selectedPlayerGameModeOption
        visual_params = {size = [flex(), titleHeight], padding=hdpx(10) halign = ALIGN_CENTER}
        onSelect = function(v) {
          if (v == selectedPlayerGameModeOption.get())
            return
          selectedPlayerGameModeOption.set(v)
        }
      })
    })
  }

  let zoneSound = const {
    click = "ui_sounds/zone_select"
    active = null
  }
  let lockColor = const Color(100,80,80)
  let mkZoneSelItem = function(opt) {
    let q = actualMatchingQueuesMap.get()?[opt.id]
    if (q == null)
      return null
    let isUnlocked = @() isZoneUnlocked(q, playerStats.get(), matchingUTCTime)
    let scene = q?.scenes[0].fileName
    let raid_description = get_raid_description(scene)

    let notification = mkContractsCompleted(q?.extraParams.raidName)
    let isDisabled = Computed(@() doesZoneFitRequirements(q?.extraParams.requiresToSelect, playerStats.get())
      && (!q.enabled || isQueueHiddenBySchedule(q, matchingUTCTime.get())))
    let visual_params = {
      style = !isDisabled.get() ? {} : { BtnBgNormal = colors.BtnBgDisabled }
      size = const [flex(), SIZE_TO_CONTENT]
      padding = const [hdpx(5), hdpx(10)]
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
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        size = const [flex(), SIZE_TO_CONTENT]
        gap = const hdpx(4)
        children = [
          {
            size = const [hdpxi(16), hdpxi(16)]
            children = mkNotificationMark(notification)
          }
          !isUnlocked() ? const faComp("lock", {color = lockColor, fontSize = hdpxi(14)}) : null
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
                behavior = const [Behaviors.Marquee, Behaviors.Button]
                speed = const [hdpx(40),hdpx(40)]
                delay = 0.3
                scrollOnHover = true
                size = const [flex(), SIZE_TO_CONTENT]
                eventPassThrough = true
              }
          }
          mkRaidInfoIcon(difficulty, hdpx(20), (isUnlocked() ? difficultyColors : difficultyDisabledColors)?[difficulty] ?? colors.TextNormal)
        ]
      }
      visual_params
      sound = zoneSound
      onSelect
      state = selectedRaid
      border_align = BD_LEFT
      idx = opt
    })
  }

  let mkZonesWithTitle = @(title, zones) {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = VertSmallSelectPanelGap
    padding = const [0,0, hdpx(10), 0]
    children = [title!=null && zones.len() > 0 ? mkText(title, const { padding = [0,0, hdpx(5), 0]}) : null].extend(zones)
  }
  let mkRotationComp = @(nextIn) {
    flow = FLOW_HORIZONTAL
    size = const [flex(), SIZE_TO_CONTENT]
    behavior = Behaviors.Button
    skipDirPadNav = true
    onHover = @(on) setTooltip(on ? loc("raid/rotationHint") : null)
    children = [
      const mkTextArea(loc("raid/available_in"))
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

  function zonesSelector() {
    local content = null
    if (selectedPlayerGameModeOption.get() == GameMode.Nexus){
      content = mkZonesWithTitle(const loc("gameType/agencyQualification"), availableZones.get().map(mkZoneSelItem))
    }
    else {
      content = mkZonesWithTitle(null, availableZones.get().map(mkZoneSelItem))
    }
    return {
      watch = [availableZones, selectedPlayerGameModeOption, needToUpdateList]
      size = const [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = hdpx(8)
      children = [
        nextRaidRotationTimer
        {
          size = const [flex(), SIZE_TO_CONTENT]
          flow = FLOW_VERTICAL
          children = content
        }
      ]
    }
  }

  let selectorsBlock = {
    size = flex(0.5)
    gap = hdpx(10)
    flow = FLOW_VERTICAL
    children = [
      selectGameMode
      zonesSelector
    ]
  }

  function autosquad(){
    return {
      watch = isOnboarding
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      size = [ flex(), SIZE_TO_CONTENT ]
      children = isOnboarding.get() ? null : [ autosquadWidget ]
    }
  }

  function mkLockMsgboxContent(){
    let txts = []
    let q = selectedRaid.get()

    if (doesZoneFitRequirements(q?.extraParams.requiresToSelect, playerStats.get())){
      txts.append(mkText(loc("requirement/temporarily_disabled"), {color = colors.InfoTextValueColor}.__update(body_txt)))
      txts.append({
        size = [ flex(), SIZE_TO_CONTENT ]
        halign = ALIGN_CENTER
        flow = FLOW_HORIZONTAL
        gap = hdpx(6)
        children = [
          
          
          mkText(loc("raid/available_in"))
          @() {
            watch = nextRotation
            children = mkMonospaceTimeComp(max(0, nextRotation.get()))
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
      size = const [sw(40), SIZE_TO_CONTENT]
      halign = ALIGN_CENTER
      gap = const sh(5)
      children = [
        const {rendObj = ROBJ_TEXT text = loc("zone_locked") }.__update(h1_txt)
      ].extend(txts)
    }
  }

  let raidButtonZoneLocked = textButton(
    loc("zone_locked"),
    @() showMessageWithContent({content = mkLockMsgboxContent()}),
    {size=[flex(), hdpx(70)], halign = ALIGN_CENTER}
  )

  let raidButtonContractsLocked = @(is_enabled) function() {
    let { raidName = null } = (selectedRaid.get()?.extraParams ?? {})
    let contractsToReport = playerProfileCurrentContracts.get().reduce(function(acc, v, k) {
      if (raidName != null && (v.raidName == raidName || (v.contractType == ContractType.STORY && raidName.split("+")?[0] == v.raidName)))
        if ((acc?.contractType ?? 9999) >= v.contractType && !v.isReported && v.currentValue >= v.requireValue)
          return acc.append({ contractType = v.contractType, id = k, name = v.name})
      return acc
    }, [])
    return {
      watch = [playerProfileCurrentContracts, selectedRaid]
      size = [flex(), SIZE_TO_CONTENT]
      children = textButton(
        contractsToReport.len() > 1
          ? loc("contract/multiReport", { num = contractsToReport.len() })
          : loc("contract/report"),
        function() {
          if (contractsToReport.len() > 0) {
            let contractsToReportIds = contractsToReport.reduce(function(acc, v) {
              if (v?.id != null)
                acc.append(v.id)
              return acc
            }, [])
            let contractName = contractsToReport.len() > 1 ? null : contractsToReport[0].name
            reportContract(contractsToReportIds, contractReportIsInProgress, contractName)
          }
        },
        {
          size=[flex(), hdpx(70)],
          halign = ALIGN_CENTER,
          isEnabled = is_enabled
        }.__update(accentButtonStyle)
      )
    }
  }

  function mkPrepareButton(menuId) {
    return {
      size = [ flex(), SIZE_TO_CONTENT ]
      children = textButton(loc("raid/loadoutCheck"),
        function() {
          openMenu(menuId)
        }
        {
          size = [flex(), hdpx(70)]
          halign = ALIGN_CENTER
          textParams = h2_txt
          textMargin = 0
        }.__update(accentButtonStyle)
      )
    }
  }

  function startRaidPanel(){
    let unavaliableIn = Computed(function(){
      let nearestHideTime = getNearestHideTime(selectedRaid.get(), matchingUTCTime.get())
      return nearestHideTime == - 1 ? null : nearestHideTime - matchingUTCTime.get()
    })
    let isNexus = selectedRaid.get()?.extraParams.nexus
    let isOperative = selectedRaid.get() != null && !isNexus
    function buttons() {
      let watch = [unavaliableIn, selectedRaid]
      if (unavaliableIn.get() != null && unavaliableIn.get() <= 0)
        return {
          watch
          size = const [flex(), SIZE_TO_CONTENT]
          children = raidButtonZoneLocked
        }
      if (isNexus)
        return {
          watch
          size = const [flex(), SIZE_TO_CONTENT]
          children = mkPrepareButton(const $"{Raid_id}/{PREPARATION_NEXUS_SUBMENU_ID}")
        }
      if (isOperative)
        return {
          watch
          size = const [flex(), SIZE_TO_CONTENT]
          flow = FLOW_VERTICAL
          gap = hdpx(4)
          children = [consoleRaidAdditionalButton, mkPrepareButton(const $"{Raid_id}/{PREPARATION_SUBMENU_ID}")]
        }
      return {watch}
    }

    return {
      watch = [selectedRaid, actualMatchingQueuesMap, contractReportIsInProgress]
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      valign = ALIGN_CENTER
      halign = ALIGN_RIGHT
      vplace = ALIGN_BOTTOM
      children = [
        preferredSpawnPoint,
        autosquad,
        buttons
      ]
    }
  }


  function mkNotAllowedToStartInfo(q){
    return @() {
      watch = [selectedRaid, matchingUTCTime]
      size = const [flex(), SIZE_TO_CONTENT]
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

  let reportContractsInfo = @() {
    watch = contractReportIsInProgress
    size = flex()
    flow = FLOW_VERTICAL
    gap
    children = [
      contractsPanel
      raidButtonContractsLocked(!contractReportIsInProgress.get())
    ]
  }

  let allowedToStartInfo = @() {
    watch = selectedRaid
    size = flex()
    flow = FLOW_VERTICAL
    gap
    children = [
      contractsPanel
      startRaidPanel
    ]
  }

  let notAllowedToStartInfo = @() {
    watch = selectedRaid
    size = flex()
    flow = FLOW_VERTICAL
    gap
    children = [
      contractsPanel
      mkNotAllowedToStartInfo(selectedRaid.get())
    ]
  }

  function raidMenuRightBlock(){
    let allContractsReported = Computed(function(){
      let contracts = playerProfileCurrentContracts.get()
      let { raidName = null } = (selectedRaid.get()?.extraParams ?? {})
      return contracts.reduce(function(acc, v) {
        if (raidName != null && (v.raidName == raidName || (v.contractType == ContractType.STORY && raidName.split("+")?[0] == v.raidName)))
          return acc && !(v.currentValue >= v.requireValue && !v.isReported)
        return acc
      }, true)
    })
    return function() {
      return {
        watch = [selectedRaid, playerStats, canChooseGameMode, isInSquad, allContractsReported, isOnboarding]
        size = flex()
        children = isOnboarding.get() ? onboardingContractsInfo
          : !allContractsReported.get() ? reportContractsInfo
          : !canChooseGameMode.get() ? allowedToStartInfo
          : isZoneUnlocked(selectedRaid.get(), playerStats.get(), matchingUTCTime) ? allowedToStartInfo
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
    let isUnlocked = isZoneUnlocked(selectedRaid.get(), playerStats.get(), matchingUTCTime)
    return {
      size = [flex(), titleHeight]
      watch = [currentPrimaryContract, raidDesc]
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

  let mkMapSector = @(mapSize) {
    rendObj = ROBJ_TILED_MAP
    behavior = TiledMap
    size = mapSize
    tiledMapContext = tiledMapContext
    children = [tiledFogOfWar, raidZone, scalebar, mkSpawnPoints(mapSize)(), extractionPoints, beaconMarkers]
      .map(@(c) mkTiledMapLayer(c, mapSize))
  }

  let mkMapContainer = @(mapSize) function() {
    let scene = selectedRaid.get()?.scenes[0].fileName
    setupMapContext(scene, mapSize)
    let mapInfo = get_tiled_map_info(scene)
    return {
      watch = selectedRaid
      size = mapSize
      rendObj = ROBJ_SOLID
      color = mapInfo?.tilesPath != null && mapInfo?.tilesPath != ""
        ? mapInfo.backgroundColor
        : colors.BtnBgDisabled
      clipChildren = true
      children = mkMapSector(mapSize)
    }
  }

  let mkOnboardingMapContainer = @(mapSize) {
    size = mapSize
    rendObj = ROBJ_IMAGE
    image = Picture("ui/zone_thumbnails/onboarding_map")
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

  let mkMissionDescriptionBlock = @(mapSize) @() {
    watch = [currentPrimaryContract, selectedRaid, raidDesc, safeAreaAmount]
    size = [mapSize[0], flex()]
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = !selectedRaid.get()?.extraParams.nexus
      ? mkPossibleLootBlock(selectedRaid.get()?.scenes[0].fileName, raidDesc.get(), {
          num_in_row = safeAreaAmount.get() == 1 ? 7 : 5
          total_items = safeAreaAmount.get() == 1 ? 14 : 10
        })
      : currentPrimaryContract.get() != null ? mkRewardBlock(currentPrimaryContract.get(), 7) : null

  }

  let mkFooterDescription = @(mapSize) {
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)
    children = [
      mkMissionDescriptionBlock(mapSize)
      selectedQueueInfo
    ]
  }

  function mkCentralBlock(horPadding, vertPadding) {
    let screenContentSize = [screenSize[0] - horPadding * 4, screenSize[1] - vertPadding * 4]
    let mapSize = [(screenContentSize[1] * 3 / 5).tointeger(), (screenContentSize[1] * 3 / 5).tointeger()]
    return {
      size = screenContentSize[1]
      flow = FLOW_VERTICAL
      gap
      children = [
        missionTitle
        mkMapAndImages(mapSize)
        mkFooterDescription(mapSize)
      ]
    }
  }


  let gameMode = @() {
    watch = const [safeAreaHorPadding, safeAreaVerPadding]
    key = const {}
    size = flex()
    flow = FLOW_HORIZONTAL
    gap
    clipChildren = true
    children = [
      selectorsBlock
      mkCentralBlock(safeAreaHorPadding.get(), safeAreaVerPadding.get())
      raidMenuRightBlock()
    ]
  }

  let showCloseMintEditMsgBox = @() showMsgbox({
    text = loc("mint/exitEditMsgbox"),
    buttons = [
      {
        text = loc("Yes")
        action = @() mintEditState.set(false)
        isCurrent = true
      },
      const {
        text = loc("No")
        isCancel = true
      }
    ]
  })

  let {clustersText, tryOpenMenu } = mkClustersUi({textStyle = {color = Color(70,70,70,30), vplace = ALIGN_CENTER padding = [0, hdpx(10)] behavior = Behaviors.Button }})
  let clusterBtn = fontIconButton("icon_buttons/sett_btn.svg", tryOpenMenu, { fontSize = stdBtnFontSize size = stdBtnSize sound = btnSound } )
  let helpBtn = mkHelpButton(mkHelpConsoleScreen(Picture("ui/build_icons/raid_portal.avif:{0}:{0}:P".subst(hdpx(600))), help_data), raidWindowName)
  let mkWindowHeader = @(isPreparation, isNexusPreparation) function() {
    local header = mkWndTitleComp(raidWindowName)
    let closeBtn = isPreparation || isNexusPreparation
      ? mkBackBtn(Raid_id, null, mintEditState.get() ? showCloseMintEditMsgBox : null)
      : mkCloseBtn(Raid_id)
    if (isPreparation || isNexusPreparation) {
      let raidType = raidDesc.get()?.raidType ?? "unknown"
      let icon = gameModeIcon(raidType, colors.TextNormal, hdpxi(23))
      let zoneName = selectedRaid.get()?.locId ?? ""
      header = @() {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = hdpx(4)
        valign = ALIGN_CENTER
        children = [
          mkTitleString(loc("raid/preparation")).__update({ margin = 0 })
          icon
          mkText(loc(zoneName), h2_txt)
        ]
      }
    }
    return {
      watch = [raidDesc, selectedRaid, mintEditState]
      size = [flex(), SIZE_TO_CONTENT]
      children = mkHeader(header, wrapButtons(clustersText, clusterBtn, helpBtn, closeBtn))
    }
  }

  return function() {
    let [_id, submenus] = convertMenuId(currentMenuId.get())
    let submenu = submenus?[0]
    let isPreparationOpened = submenu == PREPARATION_SUBMENU_ID
    let isNexusPreparation = submenu == PREPARATION_NEXUS_SUBMENU_ID
    let content = isPreparationOpened
      ? preparationWindow
      : isNexusPreparation
        ? mintContent
        : mkConsoleScreen(gameMode)
    return {
      watch = currentMenuId
      size = flex()
      onAttach = @() matchingUTCTime.set(get_matching_utc_time())
      children = wrapInStdPanel(Raid_id, content, raidMenuName, null,
        mkWindowHeader(isPreparationOpened, isNexusPreparation))
    }
  }
}

let mkBeaconScreen = @() {
  getContent
  name = raidMenuName
  notifications = mkContractsCompleted
}

return {
  raidMenuName
  Raid_id
  mkRaidScreen = mkBeaconScreen
  PREPARATION_SUBMENU_ID
}
