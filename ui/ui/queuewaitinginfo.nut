from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

import "%ui/control/gui_buttons.nut" as JB
import "%ui/components/spinner.nut" as spinner

let { BtnPrimaryBgNormal } = require("%ui/components/colors.nut")
let { isInSquad, isSquadLeader, myExtSquadData, squadLeaderState } = require("%ui/squad/squadManager.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { secondsToStringLoc } = require("%ui/helpers/time.nut")
let { sub_txt, body_txt } = require("%ui/fonts_style.nut")
let { timeInQueue, queueInfo, isInQueue, leaveQueue, curQueueParam } = require("%ui/quickMatchQueue.nut")
let { tipContents } = require("%ui/hud/tips/tipComponent.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { areHudMenusOpened } = require("%ui/hud/hud_menus_state.nut")
let { matchingQueuesMap } = require("%ui/matchingQueues.nut")
let { isOnboarding, onboardingQuery } = require("%ui/hud/state/onboarding_state.nut")
let { textButton } = require("%ui/components/button.nut")
let { safeAreaVerPadding, safeAreaHorPadding } = require("%ui/options/safeArea.nut")
let { showMsgbox } = require("%ui/components/msgbox.nut")
let { rnd_int } = require("dagor.random")
let { startGame } = require("%ui/gameLauncher.nut")
let { CmdHideAllUiMenus } = require("dasevents")
let { useAgencyPreset } = require("%ui/equipPresets/presetsState.nut")
let { currentPrimaryContractIds } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { nestWatched } = require("%dngscripts/globalState.nut")

let faComp = require("%ui/components/faComp.nut")

let isInNebiewQueue = Watched(false)
let queueNebiewInfo = Watched(null)

const TIME_BEFORE_SHOW_QUEUE = 90

function leaveQueueAction() {
  sound_play("ui_sounds/button_leave_queue")
  leaveQueue()
  if (isInSquad.get() && !isSquadLeader.get())
    myExtSquadData.ready(false)
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
    size = const [SIZE_TO_CONTENT,closeBtnHgt]
    valign = ALIGN_CENTER
    children = const [
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
  size = [flex(), SIZE_TO_CONTENT]
}.__update(body_txt)))

function staleQueueAction() {
  if (isInQueue.get())
    leaveQueueAction()
  showMsgbox({ text = loc("raid/staleQueue") })
}

let randTime = rnd_int(22, 37)
let offlineScene = nestWatched("offlineScene", null)

function startNewbieGame(scene, queueNewbieInfo) {
  if (!isInNebiewQueue.get())
    return
  queueNebiewInfo.set(queueNewbieInfo)
  offlineScene.set(scene)
  eventbus_send("profile_server.get_battle_loadout", {
    session_id = "0",
    raid_name = queueNewbieInfo?.extraParams?.raidName ?? "",
    is_rented_equipment = useAgencyPreset.get(),
    primary_contract_ids = currentPrimaryContractIds.get()
  })
}

eventbus_subscribe("profile_server.get_battle_loadout.recieved", function(...){
  if (!isInNebiewQueue.get())
    return

  leaveQueue()
  ecs.g_entity_mgr.broadcastEvent(CmdHideAllUiMenus())
  startGame({ scene = offlineScene.get() ?? "" })
})

isInQueue.subscribe(function(v) {
  if (!v && isInNebiewQueue.get()) {
    gui_scene.clearTimer(startNewbieGame)
    isInNebiewQueue.set(false)
  }
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
    let scene = queue?.scenes[0].fileName.split("@")[0]
    let raidName = "locId" in queue ? loc(queue.locId) : ""
    
    

    return {
      watch = [queueInfo, isInSquad, isSquadLeader, squadLeaderState, curQueueParam]
      flow = FLOW_VERTICAL
      valign = ALIGN_CENTER
      gap = hdpx(5)
      padding = hdpx(5)
      onAttach = function() {
        if (canJoinOnlyNewbyRaid) {
          isInNebiewQueue.set(true)
          gui_scene.setTimeout(randTime, @() startNewbieGame(scene, queue))
        }
        else
          isQueueEnabled.subscribe(@(v) v ? null : staleQueueAction)
      }
      onDetach = @() isQueueEnabled.unsubscribe(staleQueueAction)
      children = [
        mkRaidName(raidName)
        function() {
          let duration = timeInQueue.get()
          local infoTextBlock = null
          if (matched > 1 && duration > TIME_BEFORE_SHOW_QUEUE && (info?.needed ?? 0) > 0)
            infoTextBlock = loc("queue/matchingStatus", { needed = info.needed - matched })
          else if (isWaitingForServer)
            infoTextBlock = loc("queue/watingForServer")
          return {
            watch = timeInQueue
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
let widgetPos = [sw(50) - size[0]/2, sh(45)]

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
  let width = calc_comp_size(mkQueueWaitingBody())[0]
  return {
    watch = areHudMenusOpened
    rendObj = ROBJ_WORLD_BLUR_PANEL
    size
    borderColor = BtnPrimaryBgNormal
    animations
    fillColor = Color(10, 10, 10, 200)
    borderWidth = const [hdpx(2), 0, 0, 0]
    padding = hdpx(10)
    transform = const {}
    flow = FLOW_VERTICAL
    eventHandlers = queueEventHandlers
    minWidth = SIZE_TO_CONTENT
    children = [
      {
        size = const [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = hdpx(8)
        valign = ALIGN_CENTER
        minWidth = width
        children = [
          spin
          title
          const faComp("arrows", { fontSize = sub_txt.fontSize })
        ]
      }
      const {size = [0, hdpx(20)]}
      mkQueueWaitingBody()
      const {size = [0, hdpx(10)]}
      areHudMenusOpened.get() ? closeBtn : hint
    ]
  }
}

function queueTip(){
  if (!isInQueue.get())
    return const { watch = isInQueue }
  let interactive = areHudMenusOpened.get()
  return {
    watch = const [isInQueue, areHudMenusOpened]
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
  queueNebiewInfo
}
