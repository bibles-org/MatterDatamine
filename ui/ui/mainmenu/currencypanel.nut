from "%ui/fonts_style.nut" import body_txt, h2_txt
from "%ui/components/colors.nut" import  CurrencyDefColor, CurrencyUseColor, BtnBdDisabled, BtnBdNormal,
  InfoTextValueColor, ControlBg, GreenSuccessColor
from "%ui/mainMenu/currencyIcons.nut" import monolithTokensColor, creditsColor, premiumCreditsIcon,
  premiumColor, premiumCreditsTextIcon
from "%ui/components/commonComponents.nut" import mkText, mkTextArea, mkDescTextarea
from "dasevents" import CmdShowUiMenu
from "%ui/components/cursors.nut" import setTooltip
from "%ui/components/msgbox.nut" import showMsgbox, showMessageWithContent
from "%ui/mainMenu/currencyIcons.nut" import creditsTextIcon, monolithTokensTextIcon
from "%ui/profile/profileState.nut" import playerProfileCreditsCount, playerProfileMonolithTokensCount,
  playerProfilePremiumCredits, playerBaseState
from "%ui/cursorState.nut" import showCursor
from "%ui/hud/state/onboarding_state.nut" import isOnboarding
from "%ui/components/button.nut" import defButtonStyle
from "%ui/components/openUrl.nut" import openUrl
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/httpPkg.nut" import getPlatformId, getLanguageId
from "%ui/components/mkFireParticles.nut" import mkFireParticles, mkAshes, mkSparks
import "%ui/components/faComp.nut" as faComp

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let defColor = CurrencyDefColor
let useColor = CurrencyUseColor
let alertColor = Color(255,205,80)

let PREMIUM_URL = $"https://store.gaijin.net/catalog.php?category=AMEditions&skin_lang={getLanguageId()}"

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
    skipDirPadNav = true
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
    transform = static {}
    animations = animations(icon)
  }
}

function showMsgboxDueToOnboarding() {
  showMsgbox(
    static {text=loc("notAvailableYet"),
    buttons = static [
      { text = loc("mainmenu/btnBack"), isCancel = true }
    ]
  })
}

let mkBgParticles = @(effectSize) {
  children = [
    mkFireParticles(8, effectSize, mkAshes)
    mkFireParticles(2, effectSize, mkSparks)
  ]
}

let packData = {
  standart = {
    color = 0xFF8A6959
    url = $"https://store.gaijin.net/story.php?skin_lang={getLanguageId()}&title=Active-Matter_Standard-Edition"
    purchaseIdx = 1
  }
  advanced = {
    color = 0xAA637A95
    url = $"https://store.gaijin.net/story.php?skin_lang={getLanguageId()}&title=Active-Matter_Advanced-Edition-1"
    purchaseIdx = 2
  }
  premium = {
    color = 0xAADF981C
    url = $"https://store.gaijin.net/story.php?skin_lang={getLanguageId()}&title=Active-Matter_Premium-Edition-1"
    purchaseIdx = 3
  }
}

let gamePackOrder = ["standart", "advanced", "premium"]
let packImageSize = static [hdpxi(450), hdpxi(300)]

let mkDescription = @(textBlock) {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  children = [
    mkText(loc("ui/bullet"), body_txt)
    textBlock
  ]
}

let purchasedFg = {
  rendObj = ROBJ_SOLID
  size = flex()
  color = ControlBg
  valign = ALIGN_BOTTOM
  halign = ALIGN_RIGHT
  padding = static hdpx(4)
  flow = FLOW_HORIZONTAL
  gap = static hdpx(2)
  children = [
    mkText(loc("alreadyBought"), { color = GreenSuccessColor }.__merge(body_txt))
    faComp("check", { color = GreenSuccessColor, fontSize = hdpxi(20), pos = [0, -hdpx(4)] })
  ]
}

function mkPremiumBox(grade) {
  let stateFlags = Watched(0)
  let isPurchased = Computed(@() packData[grade].purchaseIdx <= (playerBaseState.get()?.purchasedPacks ?? 0))
  return @() {
    watch = [stateFlags, isPurchased]
    rendObj = ROBJ_BOX
    behavior = Behaviors.Button
    onClick = @() isPurchased.get() ? null : openUrl(packData[grade].url)
    onElemState = @(sf) stateFlags.set(sf)
    padding = static hdpx(2)
    borderWidth = static hdpx(2)
    borderColor = stateFlags.get() & S_HOVER ? packData[grade].color : BtnBdDisabled
    clipChildren = true
    children = [
      {
        flow = FLOW_VERTICAL
        gap = static hdpx(4)
        children = [
          {
            size = packImageSize
            children = [
              {
                rendObj = ROBJ_IMAGE
                size = packImageSize
                keepAspect = KEEP_ASPECT_FILL
                transform = { scale = stateFlags.get() & S_HOVER ? [1.04, 1.04] : [1, 1] }
                transitions = [{ prop = AnimProp.scale, duration = 0.4, easing = OutQuintic }]
                image = Picture($"ui/uiskin/pack_{grade}.avif")
              }
              mkBgParticles(packImageSize)
            ]
          }
          {
            size = FLEX_H
            flow = FLOW_HORIZONTAL
            gap = static hdpx(4)
            padding = static hdpx(6)
            valign = ALIGN_CENTER
            children = [
              mkTextArea(loc($"shop/pack_{grade}"), body_txt)
              faComp("external-link", { fontSize = hdpx(20) })
            ]
          }
          {
            size = FLEX_H
            flow = FLOW_VERTICAL
            padding = static hdpx(6)
            children = [
              mkDescription(mkTextArea(loc($"shop/pack_{grade}/desc1"), { color = creditsColor }))
              mkDescription(mkTextArea(loc($"shop/pack_{grade}/desc2"), { color = premiumColor }))
              mkDescription(mkTextArea(loc($"shop/pack_{grade}/desc3"), { color = InfoTextValueColor }))
              mkDescription(mkTextArea(loc($"shop/pack_{grade}/desc4"), { color = InfoTextValueColor }))
              mkDescription(mkTextArea(loc("amClean/andMore")))
            ]
          }
        ]
      }
      isPurchased.get() ? purchasedFg : null
    ]
  }
}

function showNotEnoghPremiumMsgBox(header = null) {
  let buttons = [{
    text = loc("mainmenu/btnClose")
    isCurrent = true
  }]
  if ((playerBaseState.get()?.purchasedPacks ?? 0) < packData.len())
    buttons.insert(0, {
      customButton = {
        flow = FLOW_HORIZONTAL
        gap = static hdpx(10)
        valign = ALIGN_CENTER
        margin = defButtonStyle.textMargin
        children = [
          mkText(loc("shop/openLink"), body_txt)
          faComp("external-link", { fontSize = hdpx(20) })
        ]
      }
      isCurrent = true
      action = @() openUrl(PREMIUM_URL)
      customStyle = {
        textParams = { rendObj = ROBJ_TEXTAREA, behavior = Behaviors.TextArea }
      }.__merge(accentButtonStyle)
    })
  showMessageWithContent({
    content = {
      size = [sw(80), SIZE_TO_CONTENT]
      halign = ALIGN_CENTER
      children = [
        {
          hplace = ALIGN_RIGHT
          flow = FLOW_HORIZONTAL
          gap = static hdpx(12)
          children = mkCurrency(premiumCreditsTextIcon, playerProfilePremiumCredits,
            loc("premiumCredits"), @() null, premiumColor)
        }
        {
          size = FLEX_H
          flow = FLOW_VERTICAL
          gap = hdpx(50)
          halign = ALIGN_CENTER
          children = [
            header ?? mkDescTextarea(loc("premium/notEnoughPremiumCredits"), { halign = ALIGN_CENTER }.__merge(h2_txt)),
            {
              hplace = ALIGN_CENTER
              flow = FLOW_HORIZONTAL
              gap = hdpx(50)
              children = gamePackOrder.map(mkPremiumBox)
            }
          ]
        }
      ]
    }
    buttons
  })
}

let currencyPanel = [
  mkCurrency(creditsTextIcon, playerProfileCreditsCount, loc("credits"), function() {
    if (isOnboarding.get())
      showMsgboxDueToOnboarding()
    else
      ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu({menuName = "Market"}))
  }, creditsColor)
  mkCurrency(monolithTokensTextIcon, playerProfileMonolithTokensCount, loc("monolithTokens"), function() {
    if (isOnboarding.get())
      showMsgboxDueToOnboarding()
    else
      ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu({menuName = "monolithAccessWnd"}))
  }, monolithTokensColor)
  mkCurrency(premiumCreditsTextIcon, playerProfilePremiumCredits, loc("premiumCredits"), function() {
    if (isOnboarding.get())
      showMsgboxDueToOnboarding()
    else
      showNotEnoghPremiumMsgBox()
  }, premiumColor)
]

return freeze({
  currencyAnim = animations
  currencyPanel
  notEnoughMoneyAnim
  useCurrencyColor = useColor
  defCurrencyColor = defColor
  showNotEnoghPremiumMsgBox = showNotEnoghPremiumMsgBox
  packData
})