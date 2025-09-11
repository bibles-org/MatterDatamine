from "%dngscripts/sound_system.nut" import sound_play
from "%dngscripts/globalState.nut" import nestWatched
from "%ui/components/colors.nut" import BtnPrimaryBgNormal, InfoTextValueColor
from "%ui/components/commonComponents.nut" import mkText
from "%ui/helpers/time.nut" import secondsToStringLoc
from "%ui/fonts_style.nut" import sub_txt, body_txt
from "%ui/quickMatchQueue.nut" import leaveQueue
from "%ui/hud/tips/tipComponent.nut" import tipContents
from "%ui/hud/state/onboarding_state.nut" import onboardingQuery
from "%ui/components/button.nut" import textButton
from "%ui/components/msgbox.nut" import showMsgbox
from "dagor.random" import rnd_int
from "%ui/gameLauncher.nut" import startGame
from "dasevents" import CmdHideAllUiMenus, CmdStartMenuExtractionSequence, CmdConnectToOfflineRaid
from "eventbus" import eventbus_send, eventbus_subscribe
import "%ui/components/faComp.nut" as faComp
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
import "%ui/control/gui_buttons.nut" as JB
import "%ui/components/spinner.nut" as spinner
from "%ui/mainMenu/offline_raid_widget.nut" import isOfflineRaidSelected
from "%ui/profile/profileState.nut" import nextOfflineSessionId, playerProfileLoadout
from "app" import set_matching_invite_data
from "jwt" import decode as decode_jwt
from "%ui/state/matchingUtils.nut" import get_matching_utc_time


let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let { isInSquad, isSquadLeader, myExtSquadData, squadLeaderState } = require("%ui/squad/squadManager.nut")
let { timeInQueue, queueInfo, isInQueue, curQueueParam } = require("%ui/quickMatchQueue.nut")
let { areHudMenusOpened } = require("%ui/hud/hud_menus_state.nut")
let { matchingQueuesMap } = require("%ui/matchingQueues.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { safeAreaVerPadding, safeAreaHorPadding } = require("%ui/options/safeArea.nut")
let { useAgencyPreset } = require("%ui/equipPresets/presetsState.nut")
let { currentPrimaryContractIds } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { localPlayerUserId } = require("%ui/hud/state/local_player.nut")
let { profilePublicKey } = require("%ui/profile/profile_pubkey.nut")


let isInOfflineQueue = Watched(false)

const TIME_BEFORE_SHOW_QUEUE = 90

function leaveQueueAction() {
  sound_play("ui_sounds/button_leave_queue")
  leaveQueue()
  if (isInSquad.get() && !isSquadLeader.get())
    myExtSquadData.ready.set(false)
}

let queueEventHandlers = freeze({
  ["HUD.LeaveMatchingQueue"] = @(_event) leaveQueueAction()
})

let closeBtn = {hplace = ALIGN_CENTER children = textButton(loc("hintToLeaveQueue"), leaveQueueAction)}
let closeBtnHgt = calc_comp_size(closeBtn)[1]
function hint() {
  return {
    flow = FLOW_HORIZONTAL
    hplace = ALIGN_CENTER
    size = static [SIZE_TO_CONTENT,closeBtnHgt]
    valign = ALIGN_CENTER
    children = static [
      tipContents({
        text = loc("hintToLeaveQueue")
        inputId = "HUD.LeaveMatchingQueue"
        textStyle = {
          font = sub_txt.font
          fontSize = sub_txt.fontSize
        }
        style = { rendObj = null }
        needCharAnimation = false
      })
    ]
  }
}

let animations = freeze([
  { prop=AnimProp.translate,  from=[0, sh(9)], to=[0,0], duration=0.5, play=true, easing=OutBack onEnter = @() sound_play("ui_sounds/interface_open")}
  { prop=AnimProp.translate, from=[0,0], to=[0, sh(30)], duration=0.7, playFadeOut=true, easing=OutCubic }

  { prop=AnimProp.opacity, from=0, to=1, duration=0.3, play=true, easing=OutCubic }
  { prop=AnimProp.opacity, from=1, to=0, duration=0.3, playFadeOut=true, easing=OutCubic }
  { prop=AnimProp.fillColor, from=Color(10, 10, 10, 200), to=Color(10, 80, 100, 200), easing=CosineFull, duration=2.8, loop=true, play=true }
])

let mkRaidName = memoize(@(raidName) freeze(
    mkText(loc("queue/raid", {
      name = raidName
      primary_goal = ""
    }))
))

let titleText = loc("queue/searching")
let title = freeze(mkText(titleText, {
  behavior = Behaviors.Marquee
  scrollOnHover = false
  speed = hdpx(50)
  size = FLEX_H
}.__update(body_txt)))

function staleQueueAction() {
  if (isInQueue.get())
    leaveQueueAction()
  showMsgbox({ text = loc("missions/staleQueue") })
}

let randTime = Watched(0)
let newbyQueueTimeRange = [8, 17]
let offlineScene = nestWatched("offlineScene", null)


let startOfflineGameInfo = nestWatched("startOfflineGameInfo", {})
function startOfflineGame(scene, raid_name, queue_id) {
  if (!isInOfflineQueue.get())
    return

  startOfflineGameInfo.set({
    scene, raid_name, queue_id
  })

  ecs.g_entity_mgr.sendEvent(watchedHeroEid.get(), CmdStartMenuExtractionSequence({isOffline=true}))
}

function finishStartingOfflineGame() {
  let {scene, raid_name, queue_id} = startOfflineGameInfo.get()
  offlineScene.set(scene)
  eventbus_send("profile_server.get_battle_loadout", {
    session_id = nextOfflineSessionId.get(),
    raid_name,
    queue_id,
    is_rented_equipment = useAgencyPreset.get(),
    primary_contract_ids = currentPrimaryContractIds.get(),
    is_offline = true
  })
}

ecs.register_es("finish_starting_offline_game", {
  [CmdConnectToOfflineRaid] = @(...) finishStartingOfflineGame()
}, {comps_rq=["eid"]})

let generateOfflineMatchingInviteData = function(userid, scene, raidName, sessionId, needBotSpawn) {
  return {
    roomName = "active_matter",
    pmeta = {
        [userid] = {
            squadId = userid,
            appId = 1182,
            origSquadId = userid,
            reqTeamsNum = 1,
            mteam = 0
        }
    },
    teamsSlots = [
      2
    ],
    gameName = "active_matter",
    scene
    extraParams = {
      operatives = true,
      needBotSpawn,
      raidName
    },
    maxPlayersMult = 1.0,
    mode_info = {
        raidName
        gameName = "active_matter",
        scene
        maxPlayers = 1,
        teams = [
            {
                name = "operative_1",
                maxGroups = 3,
                maxGroupSize = 3,
                maxPlayers = 6,
                jipEnableTime = 10,
                jipOnly = false,
                minGroupSize = 1,
                startConditions = [
                    {
                        waitTime = 0,
                        teamFillToStart = 0.5,
                        groupsToStart = 1
                    },
                    {
                        waitTime = 30,
                        groupsToStart = 1
                    }
                ]
            }
        ],
        operatives = true
    },
    sessionId,
    startTimestamp = get_matching_utc_time().tointeger(),
    jipEnableTime = 0
  }
}

eventbus_subscribe("profile_server.get_battle_loadout.recieved", function(response){
  let scene = offlineScene.get() ?? ""
  if (scene.len() == 0) {
    log("[Offline Battle] Offline scene not set, not launching to offline")
    return
  }
  leaveQueue()
  offlineScene.set(null)

  let err = response?.error
  let res = response?.result
  let requestFailed = (err != null || res == null)
  if (requestFailed) {
    log("[Offline Battle] Profile sign request failed, not launching offline battle")
    return
  }
  let decodeRes = decode_jwt(playerProfileLoadout.get(), profilePublicKey)
  let raidName = decodeRes?.payload?.raidName ?? ""

  ecs.g_entity_mgr.broadcastEvent(CmdHideAllUiMenus())
  let sessionId = nextOfflineSessionId.get()
  let userid = $"{localPlayerUserId.get()}"
  let isNewby = decodeRes?.payload?.isNewby ?? false
  let needBotSpawn = isNewby

  let { queue_id } = startOfflineGameInfo.get()
  let isolatedVersion = matchingQueuesMap.get().findvalue(@(v) (v?.extraParams?.isolatedVersionOfQueue ?? "") == queue_id)
  let queueToParse = isolatedVersion ?? matchingQueuesMap.get().findvalue(@(v) (v?.queueId ?? "") == queue_id)
  let additionalImports = queueToParse?.imports
  let additionalImportsDbg = additionalImports != null ? ", ".join(additionalImports) : "null"

  log($"[Offline Battle] Starting offline battle: scene=\"{scene}\", imports={additionalImportsDbg}, raid name = \"{raidName}\", sessionId={sessionId}, needBotSpawn={needBotSpawn}")
  set_matching_invite_data(generateOfflineMatchingInviteData(userid, scene, raidName, sessionId, needBotSpawn))
  startGame({ scene, sessionId, additional_imports=additionalImports })
})

eventbus_subscribe("battle_loadout_sign_failed", function(...) {
  if (!isInOfflineQueue.get())
    return

  leaveQueue()
})

function mkQueueWaitingBody() {
  let isQueueEnabled = Computed(function() {
    let queueParam = isInSquad.get() && !isSquadLeader.get() ? squadLeaderState.get()?.curQueueParam : curQueueParam.get()
    let queue = (isOnboarding.get() ? onboardingQuery : matchingQueuesMap.get())?[queueParam?.queueId]
    return queue?.enabled ?? false
  })

  return function() {
    let info = isInSquad.get() && !isSquadLeader.get() ? squadLeaderState.get()?.queueInfo : queueInfo.get()
    let matched = info?.matched ?? 0
    let { isWaitingForServer = false } = info
    let queueParam = isInSquad.get() && !isSquadLeader.get() ? squadLeaderState.get()?.curQueueParam : curQueueParam.get()
    let queue = (isOnboarding.get() ? onboardingQuery : matchingQueuesMap.get())?[queueParam?.queueId]
    let canJoinOnlyNewbyRaid = !isInSquad.get() && (queue?.extraParams.isNewby ?? false)
    
    
    let shouldJoinOfflineRaid = !isInSquad.get() && isOfflineRaidSelected.get()
    let shouldShowOfflineRaidHint = isOfflineRaidSelected.get()
    let scene = queue?.scenes[0].fileName.split("@")[0]
    local raidName = ""
    if (queueParam?.waitingInfoLocId != null)
      raidName = loc(queueParam?.waitingInfoLocId)
    else if (queue?.locId != null)
      raidName = loc(queue.locId)
    
    
    return {
      watch = [queueInfo, isInSquad, isSquadLeader, squadLeaderState, curQueueParam, isOfflineRaidSelected]
      flow = FLOW_VERTICAL
      valign = ALIGN_CENTER
      gap = hdpx(5)
      padding = hdpx(5)
      onAttach = function() {
        if (canJoinOnlyNewbyRaid || shouldJoinOfflineRaid) {
          isInOfflineQueue.set(true)
          let waitTime = rnd_int(newbyQueueTimeRange[0], newbyQueueTimeRange[1])
          randTime.set(waitTime)
          gui_scene.resetTimeout(waitTime, @() startOfflineGame(scene, queue?.extraParams?.raidName ?? "", queueParam?.queueId ?? ""), "offline_raid_waiting_timout")
        }
        else
          isQueueEnabled.subscribe(@(v) v ? null : staleQueueAction)
      }
      onDetach = function() {
        if (canJoinOnlyNewbyRaid || shouldJoinOfflineRaid) {
          isInOfflineQueue.set(false)
          gui_scene.clearTimer("offline_raid_waiting_timout")
        }
        else
          isQueueEnabled.unsubscribe(staleQueueAction)
      }
      children = [
        mkRaidName(raidName)
        shouldShowOfflineRaidHint ? mkText(loc("queue/offline_raid"), { color = InfoTextValueColor }) : null
        function() {
          let duration = timeInQueue.get()
          local infoTextBlock = null
          if (matched > 1 && duration > TIME_BEFORE_SHOW_QUEUE && (info?.needed ?? 0) > 0)
            infoTextBlock = loc("queue/matchingStatus", { needed = info.needed - matched })
          else if (isWaitingForServer || randTime.get() - duration / 1000 <= 5)
            infoTextBlock = loc("queue/watingForServer")
          return {
            watch = [timeInQueue, randTime]
            children = mkText(loc("queue/searchingStatus", {
              wait_time = secondsToStringLoc(duration / 1000)
              status = infoTextBlock ?? ""
            }))
          }
        }
      ]
    }
  }
}

let size = [hdpx(400), SIZE_TO_CONTENT]
let widgetPos = [sw(85) - size[0]/2, sh(60)]

function onMoveResize(dx, dy, _dw, _dh) {
  let paddingX = safeAreaHorPadding.get()
  let paddingY = safeAreaVerPadding.get()

  widgetPos[0] = clamp(widgetPos[0] + dx, sw(0) + paddingX, sw(100) - paddingX - size[0])
  widgetPos[1] = clamp(widgetPos[1] + dy, sh(0) + paddingY, sh(100) - paddingY - size[1])
  return {pos = widgetPos, size}
}

function onMoveResizeStarted(_x, _y, bbox) {
  size[0] = bbox.w
  size[1] = bbox.h
}

let spin = spinner(hdpx(20))
function children() {
  size[1] = SIZE_TO_CONTENT
  let width = calc_comp_size(mkQueueWaitingBody())[0]
  return {
    watch = areHudMenusOpened
    rendObj = ROBJ_WORLD_BLUR_PANEL
    size
    borderColor = BtnPrimaryBgNormal
    animations
    fillColor = Color(10, 10, 10, 200)
    borderWidth = static [hdpx(2), 0, 0, 0]
    padding = hdpx(10)
    transform = static {}
    flow = FLOW_VERTICAL
    eventHandlers = queueEventHandlers
    minWidth = SIZE_TO_CONTENT
    children = [
      {
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        gap = hdpx(8)
        valign = ALIGN_CENTER
        minWidth = width
        children = [
          spin
          title
          static faComp("arrows", { fontSize = sub_txt.fontSize })
        ]
      }
      static {size = static [0, hdpx(20)]}
      mkQueueWaitingBody()
      static {size = static [0, hdpx(10)]}
      areHudMenusOpened.get() ? closeBtn : hint
    ]
  }
}

function queueTip(){
  if (!isInQueue.get())
    return static { watch = isInQueue }
  let interactive = areHudMenusOpened.get()
  return {
    watch = static [isInQueue, areHudMenusOpened]
    behavior = interactive ? Behaviors.MoveResize : null
    key = interactive
    onMoveResizeStarted
    onMoveResize
    stopMouse = true
    pos = widgetPos
    children
    eventHandlers = queueEventHandlers
  }
}

return {
  queueTip
}
