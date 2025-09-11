from "%ui/hud/state/onboarding_state.nut" import onboardingQuery
from "%ui/mainMenu/contractPanelCommon.nut" import mkContractsCompleted
from "%ui/state/queueState.nut" import isQueueHiddenBySchedule, doesZoneFitRequirements
from "%ui/helpers/parseSceneBlk.nut" import get_raid_description
from "%ui/panels/console_common.nut" import mkFlashingInviteTextScreen, consoleFontSize, mkStdPanel, textColor, waitingCursor, inviteText, mkInviteText
from "%ui/state/matchingUtils.nut" import get_matching_utc_time
from "%ui/ui_library.nut" import *

let { isOnboarding, onboardingStateMachineCurrentStateEid, onboardingStateMachineBaseFirstTimeStateEid, onboardingStateMachineBaseKeyInsertionStateEid, isKeyInserted } = require("%ui/hud/state/onboarding_state.nut")
let { matchingQueuesMap } = require("%ui/matchingQueues.nut")
let { playerStats } = require("%ui/profile/profileState.nut")
let { squadLeaderState, isInSquad, isSquadLeader } = require("%ui/squad/squadState.nut")

#allow-auto-freeze

let mkRaidConsoleImage = @(image, width) {
  rendObj = ROBJ_IMAGE
  size = [width, width/2.3]
  keepAspect = KEEP_ASPECT_FIT
  picSaturate = 0.0
  color = textColor
  image = image ? Picture(image) : null
}

function mkRaidConsoleImages(images, imageToShow, width) {
  return function() {
    let imgs = images.get() ?? static []
    let toShow = imageToShow.get()
    let imgsLen = imgs.len()
    let show = imgsLen > 0 && toShow > -1 && imgsLen > toShow
    return {
      watch = [imageToShow, images]
      children = show ? mkRaidConsoleImage(imgs[toShow], width) : null
      clipChildren = true
      animations = static [
        {prop=AnimProp.opacity from = 0, to = 3 duration = 1.0 play = true easing=InOutCubic}
      ]
    }
  }
}

function mkImageRoundabout(images, imageToShow, canvasSize) {
  let width = canvasSize[0]-40
  return @(){
    size = [ width, flex() ]
    clipChildren = true
    children = images.get().len() > 0 ? mkRaidConsoleImages(images, imageToShow, width) : null
  }
}

function isZoneUnlocked(queue_params, player_stats, matchingUTCTime,  inSquadState, isLeader, leaderRaid) {
  if (inSquadState && !isLeader)
    return leaderRaid?.extraParams.raidName != null
      && leaderRaid?.extraParams.raidName == queue_params?.extraParams.raidName
  return doesZoneFitRequirements(queue_params?.extraParams.requiresToSelect, player_stats)
    && doesZoneFitRequirements(queue_params?.extraParams.requiresToShow, player_stats)
    && queue_params?.enabled && !isQueueHiddenBySchedule(queue_params, matchingUTCTime.get())
}

function mkRaidConsoleMenuForPanel(canvasSize) {
  let actualMatchingQueuesMap = Computed(@() isOnboarding.get() ? onboardingQuery : matchingQueuesMap.get())
  let matchingUTCTime = Watched(0)
  gui_scene.clearTimer("missions_panel_matching_utc_time")
  gui_scene.clearTimer("missions_panel_image_to_show")
  gui_scene.setInterval(1, @() matchingUTCTime.set(get_matching_utc_time()), "missions_panel_matching_utc_time")

  
  let availableZones = Computed(function(prev){
    let queues = actualMatchingQueuesMap.get()
    let stats = playerStats.get()

    function isZoneVisible(v) {
      let isNexus = v?.extraParams.nexus ?? false
      let unlocked = isZoneUnlocked(v, stats, matchingUTCTime, isInSquad.get(),
        isSquadLeader.get(), squadLeaderState.get()?.leaderRaid)
      return !isNexus && unlocked
    }

    let variants = queues
      .values()
      .filter(isZoneVisible) 
      .sort(@(a, b) isZoneUnlocked(b, stats, matchingUTCTime, isInSquad.get(), isSquadLeader.get(), squadLeaderState.get()?.leaderRaid)
          <=> isZoneUnlocked(a, stats, matchingUTCTime, isInSquad.get(), isSquadLeader.get(), squadLeaderState.get()?.leaderRaid)
        || (queues[a.id]?.extraParams?.uiOrder ?? 9999) <=> (queues[b.id]?.extraParams?.uiOrder ?? 9999)
        || a.id <=> b.id)
    if (isEqual(prev, variants))
      return prev
    return variants
  })
  let images = Computed(function(){
    #forbid-auto-freeze
    let res = []
    foreach (v in availableZones.get()) {
      foreach ( scene in (v?.scenes ?? static []))
        if (scene?.fileName)
          res.extend(get_raid_description(scene?.fileName)?.images ?? static [])
    }
    return res
  })
  let imageToShow = Watched(images.get().len() > 0 ? 0 : -1)
  gui_scene.setInterval(4, @() imageToShow.modify(function(v) {
    if (images.get().len() == 0)
      return -1
    let next = (v+1)
    if (next >= images.get().len())
      return 0
    return next
  }), "missions_panel_image_to_show")
  let raidsNum = Computed(@() availableZones.get().len())
  return {
    size = flex()
    padding = static [ 10, 15 ]
    onDetach = function() {
      gui_scene.clearTimer("missions_panel_matching_utc_time")
      gui_scene.clearTimer("missions_panel_image_to_show")
    }
    children = [
      function() {
        let onboarding = isOnboarding.get()
        let isFirstTimeBaseState = onboarding && onboardingStateMachineCurrentStateEid.get() == onboardingStateMachineBaseFirstTimeStateEid.get()
        let isKeyInsertionPhase = onboarding && onboardingStateMachineCurrentStateEid.get() == onboardingStateMachineBaseKeyInsertionStateEid.get()
        let isKeyAlreadyInserted = onboarding && isKeyInserted.get()
        return {
          flow = FLOW_VERTICAL
          watch = [isOnboarding, onboardingStateMachineCurrentStateEid, onboardingStateMachineBaseKeyInsertionStateEid, isKeyInserted]
          size = flex()
          gap = 2
          children = isFirstTimeBaseState
            ? mkFlashingInviteTextScreen(loc("missions/console/first_raid"), "missions_panel")
            : isKeyInsertionPhase
              ? !isKeyAlreadyInserted ? mkFlashingInviteTextScreen(loc("missions/console/insert_key"), "missions_panel") : mkInviteText(loc("missions/console/key_accepted"))
              : {
                flow = FLOW_VERTICAL
                size = flex()
                valign = ALIGN_TOP
                children = [
                  @() {
                    flow = FLOW_HORIZONTAL
                    watch = raidsNum
                    gap = 10
                    children = raidsNum.get() > 0 ? [
                      {rendObj = ROBJ_TEXT text = loc("missions/console/raids_available", "Raids Available:") color=textColor, fontSize = consoleFontSize}
                      @() {watch = raidsNum rendObj = ROBJ_TEXT text = raidsNum.get() color=textColor, fontSize = consoleFontSize}
                    ] : null
                  }
                  mkImageRoundabout(images, imageToShow, canvasSize)
                  inviteText
                  waitingCursor
                ]
              }
        }
      }
    ]
  }
}

return {
  mkMissionsPanel = @(canvasSize, data, notifier=null) mkStdPanel(canvasSize, data, {children = [mkRaidConsoleMenuForPanel(canvasSize), notifier]})
  mkMissionsNotifications = mkContractsCompleted
}
