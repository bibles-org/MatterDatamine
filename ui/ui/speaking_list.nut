from "%ui/ui_library.nut" import *

let {sub_txt} = require("%ui/fonts_style.nut")
let faComp = require("%ui/components/faComp.nut")
let {speakingPlayers} = require("%ui/voiceChat/voiceStateHandlers.nut")
let { remap_nick } = require("%ui/helpers/remap_nick.nut")
let {safeAreaHorPadding, safeAreaVerPadding} = require("%ui/options/safeArea.nut")

let speakingColor = Color(0, 255, 0)
let speakingIcon = faComp("volume-up", {
  vplace = ALIGN_BOTTOM
  color = speakingColor
  transform = {}
  animations = [
    { prop=AnimProp.scale, from=[1.2, 1.2], duration=0.1, play=true, easing=OutCubic }
    { prop=AnimProp.opacity, from=0, to=1, duration=0.1, play=true, easing=OutCubic }
    { prop=AnimProp.scale, to=[0, 0], duration=0.1, playFadeOut=true, easing=OutCubic }
    { prop=AnimProp.opacity, from=1, to=0, duration=0.1, playFadeOut=true, easing=OutCubic }
  ]
  fontSize = hdpx(12)
})

function mkSpeaker(name) {
  return {
    flow = FLOW_HORIZONTAL
    valing = ALIGN_BOTTOM
    gap = fsh(0.2)
    children = [
      speakingIcon
      {
        color = speakingColor
        text = name
        rendObj = ROBJ_TEXT
        fontFxFactor = min(24, hdpx(24))
        fontFxColor = Color(0,0,0)
        fontFx = FFT_BLUR
      }.__update(sub_txt, {fontSize = hdpx(12)})
    ]
  }
}

function mapTable(table, func= @(v) v){
  let ret = []
  foreach (k,_v in table)
    ret.append(func(k))
  return ret
}

return @() {
  flow = FLOW_VERTICAL
  gap = fsh(0.2)
  margin = [safeAreaVerPadding.value, hdpx(10) + safeAreaHorPadding.value]
  hplace = ALIGN_LEFT
  vplace = ALIGN_CENTER
  zOrder = Layers.Tooltip
  size = SIZE_TO_CONTENT
  watch = [speakingPlayers, safeAreaHorPadding]
  children = mapTable(speakingPlayers.value, @(name) mkSpeaker(remap_nick(name)))
}
