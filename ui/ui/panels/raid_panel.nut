from "%ui/ui_library.nut" import *

let { isOnboarding, onboardingQuery,
      onboardingStateMachineCurrentStateEid, onboardingStateMachineBaseFirstTimeStateEid, onboardingStateMachineBaseKeyInsertionStateEid } = require("%ui/hud/state/onboarding_state.nut")
let { matchingQueuesMap  } = require("%ui/matchingQueues.nut")
let { playerStats} = require("%ui/profile/profileState.nut")
let { isQueueHiddenBySchedule, doesZoneFitRequirements } = require("%ui/state/queueState.nut")
let { get_raid_description } = require("%ui/helpers/parseSceneBlk.nut")
let { mkFlashingInviteTextScreen, consoleFontSize, mkStdPanel, textColor, waitingCursor, inviteText } = require("%ui/panels/console_common.nut")
let { get_matching_utc_time } = require("%ui/state/matchingUtils.nut")

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
    let imgs = images.get() ?? const []
    let toShow = imageToShow.get()
    let imgsLen = imgs.len()
    let show = imgsLen > 0 && toShow > -1 && imgsLen > toShow
    return {
      watch = [imageToShow, images]
      children = show ? mkRaidConsoleImage(imgs[toShow], width) : null
      clipChildren = true
      animations = const [
        {prop=AnimProp.opacity from = 0, to = 3 duration = 1.0 play = true easing=InOutCubic}
      ]
    }
  }
}

function mkImageRoundabout(images, imageToShow, canvasSize) {
  let width = canvasSize[0]-hdpx(20)*2
  return @(){
    size = [ width, flex() ]
    clipChildren = true
    children = images.get().len() > 0 ? mkRaidConsoleImages(images, imageToShow, width) : null
  }
}

function isZoneUnlocked(queue_params, player_stats, matchingUTCTime) {
  return doesZoneFitRequirements(queue_params?.extraParams.requiresToSelect, player_stats)
    && doesZoneFitRequirements(queue_params?.extraParams.requiresToShow, player_stats)
    && queue_params?.enabled && !isQueueHiddenBySchedule(queue_params, matchingUTCTime.get())
}

function mkRaidConsoleMenuForPanel(canvasSize) {
  let actualMatchingQueuesMap = Computed(@() isOnboarding.get() ? onboardingQuery : matchingQueuesMap.get())
  let matchingUTCTime = Watched(0)
  gui_scene.setInterval(1, @() matchingUTCTime.set(get_matching_utc_time()))

  
  let availableZones = Computed(function(prev){
    let queues = actualMatchingQueuesMap.get()
    let stats = playerStats.get()

    function isZoneVisible(v) {
      let isNexus = v?.extraParams.nexus ?? false
      let unlocked = isZoneUnlocked(v, stats, matchingUTCTime)
      return !isNexus && unlocked
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
  let images = Computed(function(){
    let res = []
    foreach (v in availableZones.get()) {
      foreach ( scene in (v?.scenes ?? const []))
        if (scene?.fileName)
          res.extend(get_raid_description(scene?.fileName)?.images ?? const [])
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
  }))
  let raidsNum = Computed(@() availableZones.get().len())
  return function() {
    let onboarding = isOnboarding.get()
    let isFirstTimeBaseState = onboarding && onboardingStateMachineCurrentStateEid.get() == onboardingStateMachineBaseFirstTimeStateEid.get()
    let insertKey = onboarding && onboardingStateMachineCurrentStateEid.get() == onboardingStateMachineBaseKeyInsertionStateEid.get()
    return {
      flow = FLOW_VERTICAL
      watch = [isOnboarding, onboardingStateMachineCurrentStateEid, onboardingStateMachineBaseKeyInsertionStateEid]
      padding = const [ hdpx(10), hdpx(15) ]
      size = const flex()
      gap = const hdpx(2)
      children = isFirstTimeBaseState
        ? const mkFlashingInviteTextScreen("Tap Down the Rabbit Hole")
        : insertKey
          ? const mkFlashingInviteTextScreen("Insert Key")
          : {
            flow = FLOW_VERTICAL
            size = flex()
            valign = ALIGN_TOP
            children = [
              @() {
                flow = FLOW_HORIZONTAL
                watch = raidsNum
                gap = hdpx(10)
                children = raidsNum.get() > 0 ? [
                  {rendObj = ROBJ_TEXT text = "Raids Available:" color=textColor, fontSize = consoleFontSize}
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
}

return {
  mkRaidPanel = @(canvasSize, data) mkStdPanel(canvasSize, data, {children = mkRaidConsoleMenuForPanel(canvasSize)})
}
