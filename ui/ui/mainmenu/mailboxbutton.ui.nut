from "%dngscripts/sound_system.nut" import sound_play

from "%ui/fonts_style.nut" import sub_txt
from "%ui/components/colors.nut" import Alert, Inactive
from "%ui/components/button.nut" import squareIconButton
import "%ui/mainMenu/mailboxBlock.nut" as mailboxWndOpen

from "%ui/ui_library.nut" import *

let { isMailboxVisible, unreadNum, hasUnread } = require("%ui/mainMenu/mailboxState.nut")
let { showCursor } = require("%ui/cursorState.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")

let soundNewMail = "ui_sounds/notification"

function readNumCounter(){
  let num = unreadNum.get()
  return {
    watch = unreadNum
    rendObj = ROBJ_TEXT
    text = num < 1 ? "" : num
    hplace = ALIGN_RIGHT
    vplace = ALIGN_TOP
    pos = static  [hdpx(5), -hdpx(2)]
    fontFx = FFT_GLOW
    transform = static { pivot = [0.5,0.5] }
    fontFxColor = static Color(0, 0, 0, 255)
    animations = static [{prop = AnimProp.scale from =[3.0, 3.0] to = [1.0,1.0]  duration = 0.5 trigger="new_mail" easing = OutCubic}]
  }.__update(sub_txt)
}

local prevUnread = unreadNum.get()
unreadNum.subscribe(function(v) {
  if (isInPlayerSession.get())
    return
  if (v > prevUnread) {
    sound_play(soundNewMail)
    anim_start("new_mail")
  } else
    anim_request_stop("new_mail")
  prevUnread = v
})

return function() {
  return {
    watch = [hasUnread, isMailboxVisible, isOnboarding]
    children = !isOnboarding.get() ? [
      squareIconButton({
        onClick = mailboxWndOpen
        tooltipText = static loc("tooltips/mailboxButton")
        iconId = "envelope"
        key = hasUnread.get()
        seletect = isMailboxVisible
        animations = hasUnread.get()
          ? static [{prop = AnimProp.scale, from =[1.0, 1.0], to = [1.1, 1.1], duration = 1.3, loop = true, play = true, easing = CosineFull }]
          : null
        isEnable = showCursor
      }, {
        animations = hasUnread.get()
          ? static [{prop = AnimProp.color, from = Inactive, to = Alert, duration = 1.3, loop = true, play = true, easing = CosineFull }]
          : null
      })
      readNumCounter
    ] : null
  }
}
