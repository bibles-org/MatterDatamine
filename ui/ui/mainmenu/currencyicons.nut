from "%ui/ui_library.nut" import *

let { sub_txt } = require("%ui/fonts_style.nut")
let { itemIconNoBorder } = require("%ui/components/itemIconComponent.nut")

let creditsTextIcon = "₳"
let monolithTokensTextIcon = "࿋"
let amTextIcon = "҉"
let chronotraceTextIcon = "Ҁ"
let creditsColor = Color(180,200,220, 180)
let chronotracesColor = Color(180,220,200, 180)
let monolithTokensColor = Color(230, 210, 160, 190)

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

function activeMatterIcon(size = hdpx(200), override = {}){
  let amPic = Picture("!ui/skin#active_matter_balance_icon.svg:{0}:{1}".subst(size.tointeger(), size.tointeger()))
  return {
    rendObj = ROBJ_IMAGE
    image = amPic
    size
  }.__update(override)
}

function cronotracesIcon(size = hdpxi(16), override = {}) {
  return {
    rendObj = ROBJ_IMAGE
    size
    keepAspect = KEEP_ASPECT_FIT
    color = chronotracesColor
    image = Picture($"ui/skin#chronotrace_currency.svg:{size.tointeger()}:{size.tointeger()}:K")
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

return {
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


  currencyMap = freeze({
    ["MT"] = monolithTokensTextIcon,
    ["CREDITS"] = creditsTextIcon,
    ["AM"] = amTextIcon,
    ["CHRONOTRACE"] = chronotraceTextIcon,
  })
}