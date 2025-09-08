from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "%ui/components/colors.nut" import  CurrencyDefColor, CurrencyUseColor

let { creditsTextIcon, monolithTokensTextIcon, monolithTokensColor, creditsColor, cronotracesIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { playerProfileCreditsCount, playerProfileMonolithTokensCount, playerProfileChronotracesCount
} = require("%ui/profile/profileState.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { showCursor } = require("%ui/cursorState.nut")
let { CmdShowUiMenu } = require("dasevents")
let { setTooltip } = require("%ui/components/cursors.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { showMsgbox } = require("%ui/components/msgbox.nut")


let defColor = CurrencyDefColor
let useColor = CurrencyUseColor
let alertColor = Color(255,205,80)

let animations = @(icon) freeze([
  { prop=AnimProp.scale, from = [1, 1], to = [1.1, 1.1], duration=0.3, trigger=$"currency_panel_{icon}", easing=CosineFull }
])
let notEnoughMoneyAnim = @(icon) freeze([
  { prop=AnimProp.color, from=defColor, to=alertColor, duration=0.3, trigger=$"currency_panel_{icon}", easing=CosineFull }
])

function mkCurrency(icon, textWatch, hover_msg, cb, defIconColor=defColor, svgIcon = null) {
  let sf = Watched(0)
  return @() {
    key = icon
    onElemState = @(s) sf.set(s)
    flow = FLOW_HORIZONTAL
    size = SIZE_TO_CONTENT
    watch = [ textWatch, sf, showCursor ]
    gap = hdpx(1)
    behavior = showCursor.get() ? Behaviors.Button : null
    onClick = cb
    onHover = @(on) setTooltip(on ? hover_msg : null)
    vplace = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      svgIcon != null ? svgIcon : mkText(icon, {
        color = sf.get() ? useColor : defIconColor
        fontSize = hdpx(20)
        animations = notEnoughMoneyAnim(icon)
      })
      mkText(textWatch.get(), {
        color = sf.get() ? defColor : useColor
        animations = notEnoughMoneyAnim(icon)
      })
    ]
    transform = const {}
    animations = animations(icon)
  }
}

function showMsgboxDueToOnboarding() {
  showMsgbox(
    const {text=loc("notAvailableYet"),
    buttons = const [
      { text = loc("mainmenu/btnBack"), isCancel = true }
    ]
  })
}

let currencyPanel = [
  mkCurrency(monolithTokensTextIcon, playerProfileMonolithTokensCount, loc("monolithTokens"), function() {
    if (isOnboarding.get())
      showMsgboxDueToOnboarding()
    else
      ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu({menuName = "monolithAccessWnd"}))
  }, monolithTokensColor)
  mkCurrency(creditsTextIcon, playerProfileCreditsCount, loc("credits"), function() {
    if (isOnboarding.get())
      showMsgboxDueToOnboarding()
    else
      ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu({menuName = "Market"}))
  }, creditsColor)
  mkCurrency("chronotraces", playerProfileChronotracesCount, loc("chronotraces"), function() {
    if (isOnboarding.get())
      showMsgboxDueToOnboarding()
    else
      ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu({menuName = "craftWindow"}))
  }, creditsColor, cronotracesIcon)
]

return {
  currencyPanel
  useCurrencyColor = useColor
  defCurrencyColor = defColor
}