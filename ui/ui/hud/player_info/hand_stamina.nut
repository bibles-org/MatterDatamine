from "%ui/components/colors.nut" import PlayerInfoVeryLow, PlayerInfoLow, PlayerInfoMedium, PlayerInfoNormal

from "%ui/hud/player_info/style.nut" import indicatorsFontStyle, indicatorsFontSize, indicatorsIcoSize, indicatorsGap

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { vitalParameterSize } = require("%ui/hud/player_info/vital_info_common.nut")


let handStamina = Watched(1)

ecs.register_es("hud_hand_stamina_state_es",
  {
    onUpdate = function(_eid, comp){ handStamina.set(comp.human_hand_stamina__stamina / comp.human_hand_stamina__maxStamina * 100.0) }
  },
  {
    comps_ro = [
      ["human_hand_stamina__maxStamina", ecs.TYPE_FLOAT],
      ["human_hand_stamina__stamina", ecs.TYPE_FLOAT]
    ]
    comps_rq = ["watchedByPlr"]
  },
  { updateInterval = 1.0, before="*", after="*" }
)


function handStaminaToColor(val) {
  if (val < 25)
    return PlayerInfoVeryLow
  else if (val < 50)
    return PlayerInfoLow
  else if (val < 75)
    return PlayerInfoMedium
  else
    return PlayerInfoNormal
}

let ico = @(size, color) @() {
  rendObj = ROBJ_IMAGE
  image = Picture($"!ui/skin#hand_watch.svg:{size}:{size}:P")
  color
  size = [ size, size ]
  vplace = ALIGN_CENTER
  hplace = ALIGN_LEFT
}

let visibleHandStamina = Computed(@() handStamina.get() != null && handStamina.get() < 100)

function mkHandStaminaComp(customHdpxi = hdpxi, override = {}) {
  return @() {
    watch = handStamina
    size = [ customHdpxi(vitalParameterSize[0]), customHdpxi(vitalParameterSize[1]) ]
    vplace = ALIGN_CENTER
    valign = ALIGN_CENTER
    gap = customHdpxi(indicatorsGap)
    children = [
      ico(customHdpxi(indicatorsIcoSize), handStaminaToColor(handStamina.get()))
      indicatorsFontStyle.__merge({
        fontSize = customHdpxi(indicatorsFontSize)
        color = handStaminaToColor(handStamina.get())
        text = $"{handStamina.get().tointeger()}%"
      })
    ]
  }.__update(override)
}

let handStaminaPanel = freeze({
  panel = mkHandStaminaComp
  visibleWatched = visibleHandStamina
})

return freeze({ handStaminaPanel, mkHandStaminaComp, visibleHandStamina })