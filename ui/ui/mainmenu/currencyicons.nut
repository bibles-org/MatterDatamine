from "%ui/fonts_style.nut" import sub_txt
from "%ui/components/itemIconComponent.nut" import itemIconNoBorder
from "%ui/ui_library.nut" import *


let creditsTextIcon = "₳"
let monolithTokensTextIcon = "࿋"
let amTextIcon = "҉"
let chronotraceTextIcon = "Ҁ"
let premiumCreditsTextIcon = "₵"
let creditsColor = Color(180,200,220, 180)
let chronotracesColor = Color(180,220,200, 180)
let monolithTokensColor = Color(230, 210, 160, 190)
let premiumColor = Color(200, 150, 250, 180)

function creditsIcon(size = hdpx(120), override = {}) {
  
  let height = min(size, 255)
  return {
    rendObj = ROBJ_INSCRIPTION
    text = creditsTextIcon
  }.__update(sub_txt, {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    size = [ SIZE_TO_CONTENT, height ]
    fontSize = height * 0.548
  }, override)
}

function [pure] activeMatterIcon(size = hdpx(200), override = {}){
  let amPic = Picture("!ui/skin#active_matter_balance_icon.svg:{0}:{1}".subst(size.tointeger(), size.tointeger()))
  return {
    rendObj = ROBJ_IMAGE
    image = amPic
    size
  }.__update(override)
}

function [pure] cronotracesIcon(size = hdpxi(16), override = {}) {
  return {
    rendObj = ROBJ_IMAGE
    size
    keepAspect = KEEP_ASPECT_FIT
    color = chronotracesColor
    image = Picture($"ui/skin#chronotrace_currency.svg:{size.tointeger()}:{size.tointeger()}:K")
  }.__update(override)
}

function [pure] premiumCreditsIcon(size = hdpxi(16), override = {}) {
  return {
    rendObj = ROBJ_IMAGE
    size
    keepAspect = KEEP_ASPECT_FIT
    color = premiumColor
    image = Picture($"ui/skin#premium_credits.svg:{size.tointeger()}:{size.tointeger()}:K")
  }.__update(override)
}

let currencyPile = @(width = hdpxi(30), height = hdpxi(30), override = {}) {
  children = itemIconNoBorder("credit_coins_pile", { width, height })
}.__update(override)

let monolithTokensPile = @(width = hdpxi(30), height = hdpxi(30), override = {}) {
  children = itemIconNoBorder("monolith_credit_coins_pile", { width, height })
}.__update(override)

let chronotracesPile = @(width = hdpxi(30), height = hdpxi(30), override = {}) {
  children = itemIconNoBorder("chronotrace_coins_pile", { width, height })
}.__update(override)

let premiumCreditsPile = @(width = hdpxi(30), height = hdpxi(30), override = {}) {
  children = itemIconNoBorder("premium_credit_coins_pile", { width, height })
}.__update(override)

return freeze({
  amTextIcon
  activeMatterIcon

  creditsIcon
  creditsTextIcon
  currencyPile
  creditsColor

  monolithTokensPile
  monolithTokensColor
  monolithTokensTextIcon

  chronotracesPile
  cronotracesIcon
  chronotracesColor
  chronotraceTextIcon

  premiumCreditsPile
  premiumCreditsIcon
  premiumColor
  premiumCreditsTextIcon

  currencyMap = freeze({
    ["MT"] = monolithTokensTextIcon,
    ["CREDITS"] = creditsTextIcon,
    ["AM"] = amTextIcon,
    ["CHRONOTRACE"] = chronotraceTextIcon,
    ["PREMIUM_CREDITS"] = premiumCreditsTextIcon,
  })
})