from "%ui/ui_library.nut" import *

let { h2_txt } = require("%ui/fonts_style.nut")
let { mkText, underlineComp } = require("%ui/components/commonComponents.nut")
let { debriefingStatsCalculated } = require("%ui/mainMenu/debriefing/debriefing_stats_state.nut")
let { InfoTextDescColor, InfoTextValueColor } = require("%ui/components/colors.nut")
let { monolithTokensTextIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { remap_nick } = require("%ui/helpers/remap_nick.nut")
let { INVITE_TO_PSN_FRIENDS, INVITE_TO_FRIENDS } = require("%ui/mainMenu/contacts/contactActions.nut")
let faComp = require("%ui/components/faComp.nut")
let { is_sony } = require("%dngscripts/platform.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { userInfo } = require("%sqGlob/userInfoState.nut")
let { button } = require("%ui/components/button.nut")
let { inventoryItemImage } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { inventoryItem } = require("%ui/hud/menus/components/inventoryItem.nut")

let playerIconHeight = hdpxi(120)

let mkStatsColumn = @(title, children) {
  flow = FLOW_VERTICAL
  size = const [flex(), SIZE_TO_CONTENT]
  gap = hdpx(5)
  children = [
    title == null ? null : mkText(loc(title), const {
      behavior = Behaviors.Marquee
      clipChildren = true
      size = [ flex(), SIZE_TO_CONTENT ]
    }.__update(h2_txt))
    {
      gap = hdpx(2)
      flow = FLOW_VERTICAL
      size = const [flex(), SIZE_TO_CONTENT]
      children
    }
  ]
}

function mkStatString(statName, statValue, statUnit = "") {
  return {
    padding = hdpx(5)
    size = [ flex(), SIZE_TO_CONTENT ]
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)
    children = [
      mkText(statName,{
        size = [flex(), SIZE_TO_CONTENT]
        color = InfoTextDescColor
        clipChildren = true
        behavior = Behaviors.Marquee
      })
      mkText(statValue, { color = InfoTextValueColor })
      statUnit != "" ? mkText($" {statUnit}", {color = InfoTextDescColor}) : null
    ]
  }
}

let mkStatsEntry = @(name, units = "")
  underlineComp(mkStatString(loc($"debriefing/stats/{name}"), debriefingStatsCalculated.get()[name], units))

let mkDaily = @(dailyRewards)
  dailyRewards.map(@(v,k) underlineComp(mkStatString(loc($"stats/{k}"), $"{monolithTokensTextIcon}{v}"))).values()

function debriefingStats() {
  let watch = debriefingStatsCalculated
  if (debriefingStatsCalculated.get() == null)
    return { watch }
  return {
    watch
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = hdpx(20)
    children = [
      mkStatsColumn("debriefing/exploration", [
        mkStatsEntry("distance_traveled", loc("measureUnits/meters")),
        mkStatsEntry("max_height", loc("measureUnits/meters")),
        mkStatsEntry("points_of_interest_visited"),
        
        mkStatsEntry("containers_looted"),
        mkStatsEntry("bodies_looted"),
        mkStatsEntry("secret_stashes_found"),
      ]),

      mkStatsColumn("debriefing/battle", [
        mkStatsEntry("enemies_killed"),
        mkStatsEntry("damage_dealt"),
        mkStatsEntry("damage_taken"),
        mkStatsEntry("medicine_used"),
      ])
    ]
  }
}
let arrow = faComp("arrow-right", { fontSize = hdpx(25) })

let mkDailyRewardsStats = @(monolithCreditsCount) function() {
  let watch = debriefingStatsCalculated
  if ((debriefingStatsCalculated.get()?.daily_rewards ?? []).len() <= 0)
    return { watch }
  return {
    watch
    size = const [flex(), SIZE_TO_CONTENT]
    maxWidth = pw(60)
    flow = FLOW_VERTICAL
    gap = hdpx(5)
    children = [
      const mkText(loc("debriefing/dailyStatRewards"), h2_txt)
      {
        size = const [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        valign = ALIGN_CENTER
        children = [
          mkStatsColumn(null, mkDaily(debriefingStatsCalculated.get().daily_rewards))
          arrow
          inventoryItem(mkFakeItem("monolith_credit_coins_pile", { count = monolithCreditsCount }), null)
        ]
      }
    ]
  }
}

let playerActions = is_sony ? INVITE_TO_PSN_FRIENDS : INVITE_TO_FRIENDS

let addIcon = faComp("user-plus", {
  fontSize = hdpx(20)
  padding = hdpx(4)
  hplace = ALIGN_RIGHT
})

function mkPlayerData(data, iconHeight) {
  let item = mkFakeItem(data.suitTemplate)
  let isAvailable = playerActions.mkIsVisible(data.userId.tostring())
  let name = mkText(data.name, {
    size = [flex(), SIZE_TO_CONTENT]
    behavior = [Behaviors.Marquee,Behaviors.Button]
    halign = ALIGN_CENTER
    margin = hdpx(4)
    scrollOnHover = true
  })

  return function() {
    let isLocalPlayer = data.userId == userInfo.get().userId.tostring()
    let canInvite = !isLocalPlayer && isAvailable.get()
    return {
      watch = [userInfo, isAvailable]
      children = button({
        flow = FLOW_VERTICAL
        children = [
          {
            hplace = ALIGN_CENTER
            children = [
              inventoryItemImage(item, {
                width = iconHeight
                height = iconHeight
                slotSize = [iconHeight, iconHeight]
              })
              canInvite ? addIcon : null
            ]
          }
          name
        ]
      }, @() playerActions.action(data.userId), {
        valign = ALIGN_CENTER
        padding = hdpx(1)
        onHover = @(on) setTooltip(on ? loc("Add to friends") : null)
        isEnabled = canInvite
      })
    }
  }
}

function mkTeamBlock(battle, iconHeight = playerIconHeight) {
  let team = []
  foreach (mate in battle?.teamInfo ?? {}) {
    if (team.findvalue(@(v) v.userId == mate?.id) == null)
      team.append({
        name = remap_nick(mate?.name)
        suitTemplate = (mate?.suitTemplate ?? "").split("+")[0]
        userId = mate?.id ?? 0
      })
  }
  if (team.len() <= 0)
    return { size = [flex(), SIZE_TO_CONTENT] }

  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      mkText(loc("baseDebriefing/team"), h2_txt)
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = hdpx(20)
        children = team.map(@(data) mkPlayerData(data, iconHeight))
      }
    ]
  }
}

return {
  debriefingStats
  mkDailyRewardsStats
  mkTeamBlock
}
