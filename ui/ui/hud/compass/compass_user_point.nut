from "%ui/ui_library.nut" import *

let { user_points } = require("%ui/hud/state/user_points.nut")
let { TeammateColor, TEAM0_TEXT_COLOR } = require("%ui/components/colors.nut")
let { orderedTeamNicks } = require("%ui/squad/squad_colors.nut")
let { nexusSelectedNames } = require("%ui/hud/state/nexus_mode_state.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { tiny_txt } = require("%ui/fonts_style.nut")

let pinSz = [fsh(1.4), fsh(1.8)]
let images = {
  main_user_point = {
    pic=Picture("ui/skin#map_pin.svg:{0}:{1}:P".subst(pinSz[0].tointeger(),pinSz[1].tointeger()))
    size=pinSz
  }
  activity_helper_point = {
    pic=Picture("ui/skin#eye.svg:{0}:{1}:P".subst(pinSz[1].tointeger(),pinSz[1].tointeger()))
    size=[pinSz[1], pinSz[1]]
    color=Color(250,250,50,250)
    behavior=DngBhv.OpacityByComponent
  }
}

let animations = [
  { prop=AnimProp.scale, from=[0, 0], to=[1, 1], duration=0.1, play=true, easing=InCubic }
  { prop=AnimProp.scale, from=[1, 1], to=[1.25, 1.25], duration=1, play=true, delay=0.1, easing=DoubleBlink }
]

let function makeUserPoint(eid, data, color) {
  let dataType = data.type
  let pin = {
      size = images?[dataType]?.size ?? pinSz
      rendObj = ROBJ_IMAGE
      color = images?[dataType]?.color ?? color
      pos = [0, -pinSz[1]]
      image = images?[dataType]?.pic
      behavior = images?[dataType]?.behavior
      halign = ALIGN_CENTER
      opacityComponentEntity = eid
      opacityComponentName = "hud_marker__opacity"
  }

  let blurPanel = {
    rendObj = ROBJ_WORLD_BLUR_PANEL
    pos = [1, -pinSz[1] - hdpx(1)]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    
    
    children = mkText(data?.name, tiny_txt.__merge({ fontFx = FFT_NONE }))
  }

  return {
    size = pinSz
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    transform = {}
    animations

    data = {
      eid = eid
      clampToBorder = true
    }

    children = [ blurPanel, pin ]
  }
}


let userPoints = Computed(function(){
  let components = []
  foreach (eid, data in user_points.get()) {
    let { playerNick = "" } = data
    let colorIdx = orderedTeamNicks.get().findindex(@(v) v == playerNick) ?? 0
    let color = playerNick in nexusSelectedNames.get() ? TEAM0_TEXT_COLOR : TeammateColor[colorIdx]
    components.append(makeUserPoint(eid, data, color))
  }

  return components
})

return userPoints
