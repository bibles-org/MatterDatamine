from "%ui/ui_library.nut" import *
from "%ui/fonts_style.nut" import body_txt, h2_txt
from "%ui/components/colors.nut" import InfoTextValueColor, TextDisabled, RedWarningColor
import "%ui/components/checkbox.nut" as checkBox
from "%ui/components/commonComponents.nut" import mkText, mkTimeComp, mkTextArea, mkDescTextarea
from "%ui/profile/profileState.nut" import numOfflineRaidsAvailable, offlineFreeTicketAt, freeTicketsLimit,
  freeTicketsPerDay, alwaysIsolatedQueues, neverIsolatedQueues, playerStats
from "%ui/helpers/timers.nut" import mkCountdownTimerPerSec
import "%ui/components/tooltipBox.nut" as tooltipBox
from "%ui/components/cursors.nut" import setTooltip
import "%ui/components/colorize.nut" as colorize
import "%ui/components/faComp.nut" as faComp
from "%ui/components/msgbox.nut" import showMsgbox, showMessageWithContent
from "%ui/squad/squadState.nut" import isInSquad, isSquadLeader, squadLeaderState
from "%ui/gameModeState.nut" import selectedRaid, leaderSelectedRaid
from "%ui/state/queueState.nut" import isInQueue
from "%ui/mainMenu/raid_preparation_window_state.nut" import isPreparationOpened, closePreparationsScreens
from "%ui/squad/squadManager.nut" import myExtSquadData
from "%ui/matchingQueues.nut" import matchingQueuesMap
from "%ui/hud/state/onboarding_state.nut" import isOnboarding


let wantOfflineRaid = Watched(false)
let offlineRaidCachseList = Watched({})

let isOfflineRaidAvailableForQueue = Computed(function() {
  if (isOnboarding.get()) {
    return false
  }
  let params = selectedRaid.get()?.extraParams
  let isNexus = params?.nexus ?? false
  if (isNexus)
    return false

  let isNewby = params?.isNewby ?? false
  if (isNewby) {
    return false
  }

  let queueId = selectedRaid.get()?.queueId ?? ""
  let isNeverIsolated = (queueId in neverIsolatedQueues.get())

  if (isNeverIsolated)
    return false

  return true
})

let isQueueOfflineOnly = Computed(function() {
  let queueId = selectedRaid.get()?.queueId ?? ""
  return (queueId in alwaysIsolatedQueues.get())
})

let isOfflineRaidAvailable = Computed(@() numOfflineRaidsAvailable.get() > 0 && isOfflineRaidAvailableForQueue.get())
let isOfflineRaidSelected = Computed(@() wantOfflineRaid.get() && isOfflineRaidAvailable.get())


let mkNextTicketTimer = function() {
  let timer = mkCountdownTimerPerSec(offlineFreeTicketAt, "offline_raid_widget.nut:mkNoOfflineTicketsLeft")
  return @() {
    watch = [freeTicketsPerDay, offlineFreeTicketAt]
    flow = FLOW_HORIZONTAL
    gap = static hdpx(4)
    children = [
      mkText(loc("queue/offline_raids/next_ticket_in", {
        amount = colorize(InfoTextValueColor, freeTicketsPerDay.get())
        amounts = freeTicketsPerDay.get()
      }),
        {
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
        })
      @() {
        watch = timer
        children = mkTimeComp(max(timer.get() ?? 0, 0))
      }
    ]
  }
}

let mkOfflineRaidUnavailableReason = function() {
  let reason = Computed(function() {
    if (isOfflineRaidAvailable.get()) {
      return null
    }
    if (isOnboarding.get()) {
      return loc("queue/offline_raids/unavailable")
    }
    if (numOfflineRaidsAvailable.get() <= 0) {
      return loc("queue/offline_raids/noTicketsShort")
    }
    if (!isOfflineRaidAvailableForQueue.get()) {
      return loc("queue/offline_raids/unavailable_raid")
    }
    return loc("queue/offline_raids/unavailable")
  })
  return @(){
    watch = reason
    children = mkText(reason.get(), {color=RedWarningColor})
  }
}

let mkOfflineRaidIcon = @(override = {}) faComp("isolated_raid.svg", {
  fontSize = static hdpxi(19),
  color = InfoTextValueColor
}.__merge(override))

function mkOfflineRaidCheckBox(override = {}, isDisabled = false) {
  let leaderRaidStatus = Computed(function() {
    if (!isInSquad.get() || isSquadLeader.get())
      return null
    let leaderRaid = squadLeaderState.get()?.leaderRaid
    if (leaderRaid?.raidData != null
      && selectedRaid.get()?.extraParams.raidName == leaderRaid?.raidData.extraParams.raidName
    )
      return squadLeaderState.get()?.leaderRaid.isOffline
  })

  return function() {
    if (leaderRaidStatus.get() != null) {
      if (leaderRaidStatus.get() && numOfflineRaidsAvailable.get() <= 0) {
        myExtSquadData.ready.set(false)
        if (isPreparationOpened.get()) {
          closePreparationsScreens()
          showMsgbox({ text = $"{loc("queue/offline_raids/leaderSetIsolated")}\n\n{loc("queue/offline_raids/noTickets")}" })
        }
      }
      else
        wantOfflineRaid.set(leaderRaidStatus.get())
    }
    else if (isQueueOfflineOnly.get())
      wantOfflineRaid.set(true)
    else if (!isOfflineRaidAvailable.get())
      wantOfflineRaid.set(false)
    else if (selectedRaid.get()?.extraParams.raidName in offlineRaidCachseList.get())
      wantOfflineRaid.set(offlineRaidCachseList.get()[selectedRaid.get().extraParams.raidName])
    else
      wantOfflineRaid.set(false)

    let color = !isOfflineRaidAvailableForQueue.get() || isQueueOfflineOnly.get() || isDisabled
      ? TextDisabled : InfoTextValueColor
    return {
      watch = [numOfflineRaidsAvailable, freeTicketsLimit, isOfflineRaidAvailableForQueue, isOfflineRaidAvailable,
        isQueueOfflineOnly, selectedRaid, leaderRaidStatus, isPreparationOpened]
      size = FLEX_H
      halign = ALIGN_RIGHT
      valign = ALIGN_CENTER
      flow = FLOW_HORIZONTAL
      children = [
        checkBox(wantOfflineRaid,
          {
            flow = FLOW_HORIZONTAL
            gap = hdpx(4)
            valign = ALIGN_CENTER
            children = [
              mkOfflineRaidIcon({ color })
              mkText($"{loc("queue/offline_raids/left")} {numOfflineRaidsAvailable.get()}", {
                color })
            ]
          }
          {
            setValue = function(v) {
              if (isOnboarding.get()) {
                showMsgbox({ text = loc("closedDoor/accessDenied") })
                return
              }
              if (isInQueue.get()) {
                showMsgbox({ text = loc("queue/offline_raids/forbidden") })
                return
              }
              if (isInSquad.get() && !isSquadLeader.get()) {
                showMsgbox({ text = loc("queue/offline_raids/only_leader") })
                return
              }
              if (isDisabled) {
                showMsgbox({ text = loc("queue/offline_raids/impossibleToChangeInPreparation") })
                return
              }
              if (!v && isQueueOfflineOnly.get()) {
                showMsgbox({ text = loc("queue/offline_raids/only_offline") })
                return
              }
              if (v && numOfflineRaidsAvailable.get() <= 0) {
                showMsgbox({ text = loc("queue/offline_raids/noTickets") })
                return
              }
              if (v && !isOfflineRaidAvailableForQueue.get()) {
                let isNewby = selectedRaid.get()?.extraParams?.isNewby ?? false
                let raidName = selectedRaid.get()?.extraParams?.raidName
                let nonNewbyVersion = (isNewby && raidName != null)
                  ? matchingQueuesMap.get().findvalue(@(queue) (!(queue?.extraParams?.isNewby ?? false)) && (queue?.extraParams?.raidName ?? "") == raidName)
                  : null
                let unlockParams = nonNewbyVersion != null
                  ? nonNewbyVersion?.extraParams.requiresToShow ?? []
                  : selectedRaid.get()?.extraParams.requiresToShow ?? []
                if (unlockParams.len() > 0) {
                  let txts = [mkTextArea(loc("queue/offline_raids/unlockReqs"), { halign = ALIGN_CENTER }.__merge(h2_txt))]
                  foreach (req in unlockParams) {
                    if (type(req) == "string") { 
                      txts.append(mkTextArea(loc($"requirement/{req}".replace("<", ">=")), {
                        halign = ALIGN_CENTER
                        color = InfoTextValueColor
                      }.__merge(h2_txt)))
                    }
                    else {
                      foreach (stat_name, stat_val in req)
                        if ((playerStats.get()?.statsCurrentSeason?[stat_name] ?? 0) < stat_val)
                          txts.append(mkTextArea("{0} {1}".subst(loc($"requirement/{stat_name}"), stat_val),
                            {
                              halign = ALIGN_CENTER
                              color = InfoTextValueColor
                            }.__merge(h2_txt)))
                    }
                  }
                  showMessageWithContent({ content = {
                    size = static [sw(80), SIZE_TO_CONTENT]
                    flow = FLOW_VERTICAL
                    gap = static hdpx(4)
                    children = txts
                  }})
                }
                else
                  showMsgbox({ text = loc("queue/offline_raids/only_online") })
                return
              }
              offlineRaidCachseList.mutate(@(data) data[selectedRaid.get().extraParams.raidName] <- v)
              if (isInSquad.get() && isSquadLeader.get() && (leaderSelectedRaid.get() != null))
                leaderSelectedRaid.mutate(@(data) data.__update({isOffline = v}))
              wantOfflineRaid.set(v)
            }
            textOnTheLeft = true
            override = { padding = hdpx(4) }
            tooltip = tooltipBox(@() {
              watch = [isOfflineRaidAvailable, numOfflineRaidsAvailable, freeTicketsLimit, wantOfflineRaid]
              flow = FLOW_VERTICAL
              gap = static hdpx(4)
              minWidth = static hdpx(500)
              children = [
                isOfflineRaidAvailable.get() ? null : mkOfflineRaidUnavailableReason()
                wantOfflineRaid.get() ? mkTextArea(loc("queue/offline_raids/active")) : null
                {
                  flow = FLOW_VERTICAL
                  gap = static hdpx(4)
                  minWidth = static hdpx(500)
                  children = [
                    numOfflineRaidsAvailable.get() < freeTicketsLimit.get() ? mkNextTicketTimer() : null
                    mkDescTextarea(loc("queue/offline_raids/free_tickets_limit_reached", {maxAmount=freeTicketsLimit.get()}))
                    mkDescTextarea(loc("queue/offline_raids/desc"))
                  ]
                }
              ]
            })
          })
      ]
    }.__merge(override)
  }
}

return {
  mkOfflineRaidCheckBox,
  isOfflineRaidSelected,
  isOfflineRaidAvailable,
  isQueueOfflineOnly,
  wantOfflineRaid,
  mkOfflineRaidIcon
}
