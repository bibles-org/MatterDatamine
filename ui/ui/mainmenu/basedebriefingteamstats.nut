from "%dngscripts/platform.nut" import is_sony

from "%ui/fonts_style.nut" import h2_txt, body_txt
from "%ui/components/commonComponents.nut" import mkText, underlineComp
from "%ui/components/colors.nut" import InfoTextDescColor, InfoTextValueColor
from "%ui/helpers/remap_nick.nut" import remap_nick
import "%ui/components/faComp.nut" as faComp
from "%ui/components/cursors.nut" import setTooltip
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%ui/components/button.nut" import button
from "%ui/hud/menus/components/inventoryItemImages.nut" import inventoryItemImage
from "%ui/hud/menus/components/inventoryItem.nut" import inventoryItem
from "%ui/mainMenu/menus/options/player_interaction_option.nut" import isStreamerMode, playerRandName
from "%ui/mainMenu/clonesMenu/clonesMenuCommon.nut" import mkAlterIconParams

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { debriefingStatsCalculated } = require("%ui/mainMenu/debriefing/debriefing_stats_state.nut")
let { monolithTokensTextIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { INVITE_TO_PSN_FRIENDS, INVITE_TO_FRIENDS } = require("%ui/mainMenu/contacts/contactActions.nut")
let { userInfo } = require("%sqGlob/userInfoState.nut")

let playerIconHeight = hdpxi(120)

let mkStatsColumn = @(title, children) {
  flow = FLOW_VERTICAL
  size = FLEX_H
  gap = hdpx(5)
  children = [
    title == null ? null : mkText(loc(title), static {
      behavior = Behaviors.Marquee
      clipChildren = true
      size = FLEX_H
    }.__update(h2_txt))
    {
      gap = hdpx(2)
      flow = FLOW_VERTICAL
      size = FLEX_H
      children
    }
  ]
}

function mkStatString(statName, statValue, statUnit = "") {
  return {
    padding = hdpx(5)
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)
    children = [
      mkText(statName,{
        size = FLEX_H
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
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    gap = hdpx(20)
    padding = hdpx(10)
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
    size = FLEX_H
    maxWidth = pw(70)
    flow = FLOW_VERTICAL
    gap = hdpx(5)
    children = [
      static mkText(loc("debriefing/dailyStatRewards"), h2_txt)
      {
        size = FLEX_H
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
  let suitTemplate = data.suitTemplate
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(suitTemplate)
  let { attachments, alterIconParams } = mkAlterIconParams(suitTemplate, template)
  let item = mkFakeItem(suitTemplate, alterIconParams, attachments)
  let isAvailable = playerActions.mkIsVisible(data.userId.tostring())
  let name = mkText(data.name, {
    size = FLEX_H
    behavior = [Behaviors.Marquee,Behaviors.Button]
    halign = ALIGN_CENTER
    margin = hdpx(4)
    scrollOnHover = true
  })

  return function() {
    let isLocalPlayer = data.userId == userInfo.get().userId.tostring()
    let canInvite = !isLocalPlayer && isAvailable.get()
    let ad = iconHeight / 2 * 3
    return {
      watch = [userInfo, isAvailable]
      children = button({
        flow = FLOW_VERTICAL
        children = [
          {
            size = [iconHeight, iconHeight]
            clipChildren = true
            hplace = ALIGN_CENTER
            halign = ALIGN_CENTER
            children = [
              inventoryItemImage(item, {
                width = iconHeight
                height = ad
                slotSize = [iconHeight, ad]
              }, { vplace = ALIGN_TOP valign = ALIGN_TOP})
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

let mkTeamBlock = @(battle, iconHeight = playerIconHeight, txt_style = h2_txt) function() {
  let team = []
  foreach (mate in battle?.teamInfo ?? {}) {
    if (team.findvalue(@(v) v.userId == mate?.id) == null)
      team.append({
        name = isStreamerMode.get() && remap_nick(mate?.name) == userInfo.get().name
          ? playerRandName.get() : remap_nick(mate?.name)
        suitTemplate = (mate?.suitTemplate ?? "").split("+")[0]
        userId = mate?.id ?? 0
      })
  }
  if (team.len() <= 0)
    return static { size = FLEX_H }

  return {
    watch = [isStreamerMode, userInfo, playerRandName]
    size = FLEX_H
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      mkText(loc("baseDebriefing/team"), txt_style)
      {
        size = FLEX_H
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
