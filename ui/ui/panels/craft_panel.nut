from "%ui/panels/console_common.nut" import mkStdPanel, textColor, waitingCursor, inviteText, consoleFontSize, consoleTitleFontSize
from "net" import get_sync_time
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { mkCraftNotifications } = require("%ui/mainMenu/researchAndCraft.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { allCraftRecipes, playerProfileChronotracesCount, craftTasks, playerBaseState } = require("%ui/profile/profileState.nut")
let { levelLoaded } = require("%ui/state/appState.nut")

#allow-auto-freeze

let mkProgressBar = @(craftTime, timeLeftWatched) @() {
  watch = timeLeftWatched
  size = flex()
  color = textColor
  rendObj = ROBJ_SOLID
  transform = {
    scale = [(craftTime - timeLeftWatched.get()).tofloat() / craftTime, 1.0]
    pivot = static [0.0, 0.5]
  }
}

let craftSlotsData = Computed(function() {
  let maxReplicatorDevices = playerBaseState.get()?.maxReplicatorDevices ?? 0
  if (maxReplicatorDevices == 0)
    return []
  let ret = array(maxReplicatorDevices, { status = "unavailable" })

  foreach (task in craftTasks.get()) {
    ret[task.replicatorSlotIdx] = {
      status = task.craftCompleteAt > get_sync_time() ? "processing" :"done"
      task
    }
  }
  let openedReplicators = playerBaseState.get()?.openedReplicatorDevices ?? -1
  foreach (idx, replicator in ret) {
    if (replicator.status == "unavailable" && idx < openedReplicators)
      ret[idx] = { status = "empty" }
  }
  return ret
})

let defStyle = { fontFxColor = Color(0,0,0,120) color = textColor fontSize = consoleFontSize rendObj = ROBJ_TEXT fontFx = FFT_BLUR fontFxFactor=8 margin = static [0, 6] }
let mkTexts = memoize(@(status, idx) [
  defStyle.__merge({text = status  hplace = ALIGN_RIGHT })
  defStyle.__merge({text = $"#{idx+1}" vplace = ALIGN_CENTER})
])

function mkSlot(slot, idx, canvasSize){
  let isProcessing = slot.status == "processing"
  let craftCompleteAt = slot?.task.craftCompleteAt ?? 0
  let countdown = isProcessing ? Watched(craftCompleteAt-get_sync_time()) : Watched(0)
  gui_scene.clearTimer($"craft_panel_{idx}")
  function update() {
    let newTime = craftCompleteAt-get_sync_time()
    if (newTime > 0)
      countdown.set(newTime)
    else {
      countdown.set(0)
      gui_scene.clearTimer($"craft_panel_{idx}")
    }
  }
  let hasCountDown = Computed(@() isProcessing && countdown.get() != 0)
  return function() {
    let recipe = allCraftRecipes.get()?[slot?.task.craftRecipeId]
    let craftTime = slot?.task.startedBroken ? recipe?.brokenCraftTime : recipe?.craftTime
    let done = (slot.status == "done") || (isProcessing && countdown.get() <= 0.0)
    if (hasCountDown.get())
      gui_scene.setInterval(1, update, $"craft_panel_{idx}")
    return {
      size = [flex(), canvasSize[1]/8]
      padding = 4
      watch = hasCountDown
      children = [isProcessing && hasCountDown.get()
        ? mkProgressBar(craftTime, countdown)
        : done
          ? static {rendObj = ROBJ_SOLID size = flex() color = textColor animations = [{ prop=AnimProp.opacity, from=0.1, to=1, duration=2.0, easing=CosineFull, play=true, loop=true }]}
          : null
        ]
        .extend(mkTexts(done ? "done" : slot.status, idx))
    }
  }
}

let chrt = @() { watch = playerProfileChronotracesCount text = $"{loc("chronotraces")}: {playerProfileChronotracesCount.get()}" , hplace = ALIGN_RIGHT margin = static [2, 0]}.__update(defStyle)
let gap = static {size = static [flex(), 1] rendObj = ROBJ_SOLID color = textColor}
return {
  mkCraftNotifications
  mkCraftPanel = @(canvasSize, data, notifier=null) mkStdPanel(canvasSize, data, {
    children = [
      @() {
        watch = static [isOnboarding, levelLoaded]
        size = flex()
        flow = FLOW_VERTICAL
        padding = static [4, 8]
        children = isOnboarding.get() || !levelLoaded.get() ? null : [
            {
              size = FLEX_H
              children = [
                static {rendObj = ROBJ_TEXT text= loc("researchAndCraft") color = textColor fontSize = consoleTitleFontSize}
                chrt
              ]
            },
            @() {
              size = flex()
              watch = [craftSlotsData, allCraftRecipes]
              flow = FLOW_VERTICAL
              gap
              children = [static {size=static [0, 4]}]
                .extend(craftSlotsData.get().map(@(v, idx) mkSlot(v, idx, canvasSize)))
                .append(static {size=0})
            },
            static {size=flex()},
            inviteText,
            waitingCursor
          ]
    }, notifier]
  })
}
