from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { bodyParts, getDamageTypeStr } = require("%ui/hud/state/human_damage_model_state.nut")
let { round_by_value } = require("%sqstd/math.nut")
let { ceil } = require("math")


let dmTooltipNameColor = Color(200,200,200)
let dmTooltipStatColor = Color(225,180,140)
let dmTooltipBrokenTitleColor = Color(255,0,0)
let dmTooltipBrokenEffectColor = Color(255,90,30)


function buildDamageModelPartTooltip(part_name) {
  let partData = bodyParts.get()?[part_name]

  local tooltip = $"<color={dmTooltipNameColor}>{loc($"damage_model/{part_name}")}</color>\n"


  
  local statsTooltip = ""

  let maxHp = partData?.maxHp ?? -1.0
  let hp = partData?.hp ?? -1.0
  let isBrokenCondition = partData?.isInjured ?? false
  if (maxHp > 0.0) {
    if (hp >= 100000)
      statsTooltip = $"{statsTooltip}<color={dmTooltipStatColor}>{loc("desc/condition", "Condition:")}</color> {loc("damage_model/invulnerable", "Invulnerable")}\n"
    else {
      let hpText = isBrokenCondition ? $"<color={dmTooltipBrokenTitleColor}>{ceil(hp).tointeger()}</color>" : $"{ceil(hp).tointeger()}"
      statsTooltip = $"{statsTooltip}<color={dmTooltipStatColor}>{loc("desc/condition", "Condition:")}</color> {hpText}/{ceil(maxHp).tointeger()}\n"
    }
  }

  let protection = partData?.protection
  if (protection != null) {
    foreach (idx, value in protection) {
      if (value != 0.0)
        statsTooltip = $"{statsTooltip}<color={dmTooltipStatColor}>{loc($"desc/{getDamageTypeStr(idx)}_damage_protection", $"{getDamageTypeStr(idx)} damage protection:")}</color> {round_by_value(value * 100.0, 0.1)}%\n"
    }
  }

  
  if (statsTooltip != "")
    tooltip = $"{tooltip}\n{statsTooltip}"


  
  if (isBrokenCondition) {

    local criticalDamageTooltip = $"<color={dmTooltipBrokenTitleColor}>{loc($"damage_model/broken_condition")}</color>\n"

    criticalDamageTooltip = $"{criticalDamageTooltip}<color={dmTooltipBrokenEffectColor}>{loc($"damage_model/broken_condition/effects")}</color>\n"
    criticalDamageTooltip = $"{criticalDamageTooltip}<color={dmTooltipBrokenEffectColor}>{loc($"damage_model/broken_desc/{part_name}")}</color>\n"

    
    if (criticalDamageTooltip != "")
      tooltip = $"{tooltip}\n{criticalDamageTooltip}"
  }



  
  if (tooltip.len() > 0 && tooltip[tooltip.len() - 1] == '\n')
    tooltip = tooltip.slice(0, tooltip.len() - 1)

  return tooltip
}


return {
  buildDamageModelPartTooltip
}
