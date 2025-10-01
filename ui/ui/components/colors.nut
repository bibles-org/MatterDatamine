from "%sqstd/string.nut" import hexStringToInt

from "%ui/ui_library.nut" import *
from "string" import format

#allow-auto-freeze

let ActionBgColor = Color(217,193, 127)
let ActionBgHoverColor = Color(227, 109, 0, 255)

let ActionBdHoverColor = Color(220, 220, 220, 120)
let MajorBdColor = Color(20, 220, 253)
let SuccessBdColor = Color(20, 253, 180)
let ItemListBgColor = Color(69,90,100)
let TabTextColor = Color(217, 193, 127)
let BtnBdNormal = mul_color(ActionBgColor, 0.8, 2)
let BtnBgNormal            = mul_color(ActionBgColor, 0.11, 6)
let OptionRowBgHover = mul_color(ActionBgHoverColor, 0.3)
let OptionRowBdHover =  BtnBdNormal

#forbid-auto-freeze
let colors = {
  CurrencyDefColor = Color(255,255,255)
  CurrencyUseColor = Color(200,200,200)

  ItemIconBlocked        = [0, 0, 0, 255]
  ItemDelayedMove        = Color(210, 140, 60, 80)
  ItemBgColor            = Color(10,10,10,180)
  ItemBdColor            = Color(71, 71, 71, 255)
  corruptedItemColor     = Color(0, 154, 154)

  SelBdNormal            = mul_color(ActionBgColor, 0.6, 1)
  SelBdSelected          = ActionBdHoverColor
  SelBdHover             = ActionBgHoverColor
  SelBdDisabled          = Color(20, 20, 20, 20)
  SelBgNormal            = mul_color(ItemListBgColor, 0.2, 3.6)
  SelBgDisabled          = Color(18, 18, 18, 230)

  BtnBdActive            = mul_color(ActionBgHoverColor, 0.5,2)
  BtnBdDisabled          = Color(20, 20, 20, 20)
  BtnBdFocused           = Color(160, 160, 160, 120)
  BtnBdHover             = ActionBdHoverColor
  BtnBdNormal
  BtnBdSelected          = Color(230, 200, 90, 195)
  BtnBdTransparent       = Color(67, 67, 67)

  BtnBgActive            = Color(255, 180, 100, 255)
  BtnBgDisabled          = Color(60, 60, 60)
  BtnBgFocused           = Color(40, 40, 40, 120)
  BtnBgHover             = ActionBgHoverColor
  BtnBgNormal
  BtnBgSelected          = mul_color(TabTextColor, 0.5, 0.4)
  BtnBgTransparent       = Color(0, 0, 0, 50)

  BtnPrimaryBgNormal     = mul_color(MajorBdColor, 0.3, 0.7)
  BtnPrimaryBdNormal     = mul_color(MajorBdColor, 1, 0.95)
  BtnPrimaryBgSelected   = Color(25, 160, 240)
  BtnPrimaryTextNormal   = Color(210, 210, 210, 205)
  BtnSuccessBgNormal     = mul_color(SuccessBdColor, 0.3, 0.7)
  BtnSuccessBdNormal     = mul_color(SuccessBdColor, 1, 0.95)
  BtnSuccessBgSelected   = Color(25, 240, 150)
  BtnAlertBgNormal       = mul_color(Color(255, 180, 80), 0.3, 0.7)
  NotificationBg = MajorBdColor

  BtnTextActive          = Color(0, 0, 0)
  BtnTextFocused         = Color(0, 0, 0, 100)
  BtnTextHighlight       = Color(160, 160, 160, 120)
  BtnTextHover           = Color(220, 220, 220, 160)
  BtnTextNormal          = Color(160, 160, 160, 120)
  BtnTextVisualDisabled  = Color(160, 160, 160, 80)

  ContactInBattle        = Color(90, 30, 30, 60)
  ContactLeader          = Color(170, 170, 50, 205)
  ContactNotReady        = Color(90, 30, 30, 60)
  ContactOffline         = Color(50, 50, 50, 50)
  ContactReady           = Color(50, 90, 50, 50)

  UserNameColor = Color(150, 255, 160, 120)

  inactiveBackgroundMenuColor = mul_color(Color(69, 90, 100), 127.0/255.0)
  ComboboxBorderColor    = Color(60, 60, 60, 255)
  ConsoleBorderColor     = Color(50, 50, 65, 25)
  ConsoleFillColor       = Color(1, 8, 16, 102)
  ConsoleHeaderFillColor = Color(0, 0, 0, 140)
  ControlBg              = Color(28, 28, 28, 150)
  ControlBgOpaque        = Color(28, 28, 28, 240)

  HudTipFillColor        = Color(0,0,0,102)
  DropBdActive           = Color(255, 225, 105, 105)
  DropBdDisabled         = Color(75, 5, 5, 15)
  DropBdNormal           = Color(105, 65, 15, 75)
  DropBgDisabled         = Color(20, 5, 5, 15)
  DropBgNormal           = Color(25, 25, 15, 15)

  KnobNormal             = mul_color(ActionBgColor, 0.18, 2)
  KnobActive             = Color(255, 180, 100, 255)
  KnobHover              = ActionBgHoverColor
  ScrollBarBgColor       = Color(3, 3, 3, 30)

  HUD_TIPS_HOTKEY_FG     = Color(120, 120, 50, 20)
  InfoTextDescColor      = Color(160, 160, 160, 120)
  DangerTextValueColor   = Color(255, 110, 100, 250)
  InfoTextValueColor     = Color(250, 220, 170, 200)
  ModalBgTint            = Color(10, 10, 10, 120)
  panelRowColor          = Color(15, 15, 15, 170)
  OptionRowBgHover
  OptionRowBdHover
  MenuRowBgOdd           = Color(20, 20, 20, 20)
  MenuRowBgEven          = Color(0, 0, 0, 20)
  progressBarBg          = Color(0, 0, 0, 200)

  TEAM0_TEXT_COLOR       = Color(150, 160, 255, 120)
  TEAM1_TEXT_COLOR       = Color(255, 160, 160, 120)

  TextActive             = Color(0, 0, 0)
  TextHighlight          = Color(220, 220, 220, 160)
  TextHover              = Color(220, 220, 220, 160)
  TextDisabled           = Color(100, 100, 100, 100)
  TextNormal             = Color(160, 160, 160, 120)

  TextInputBdNormal      = Color(60, 60, 60, 255)
  TextInputBdActive      = Color(180, 180, 180, 180)
  TextInputBgNormal      = Color(30, 30, 30, 255)
  TextInputBgActive      = Color(40, 40, 40, 255)

  MapIconEnable  = Color(150, 240, 140)
  MapIconDisable = Color(255, 105, 105)
  MapIconInactive  = Color(105, 105, 105)
  MapIconInner   = Color(0, 0, 0, 255)
  MapIconHover   = Color(255, 255, 0)

  TooltipBackground      = Color(30, 30, 30, 0)

  VictoryColor           = Color(0, 177, 131, 220)
  GreenSuccessColor      = Color(72, 228, 68)
  RedWarningColor        = Color(228, 72, 68)
  RedFailColor           = Color(228, 49, 45, 140)
  OrangeHighlightColor   = Color(248, 148, 68)


  NexusPlayerPointsColor    = Color(170, 123, 0)

  noItemContainerBg      = Color(120, 20, 20, 170)

  negativeTextButtonStyle = {
    BtnBgNormal = Color(150, 50, 50, 120)
    BtnBgDisabled = Color(0, 0, 0, 120)
    BtnBgActive = Color(120, 40, 40, 255)
    BtnBgHover = Color(150, 150, 150)
  }

  RarityCommon = Color(101, 101, 101)
  RarityUncommon = Color(80, 130, 80)
  RarityRare = Color(60, 100, 150)
  RarityEpic = Color(160, 100, 160)

  TeammateColor = [Color(243, 190, 32, 200), Color(62, 181, 255, 200), Color(146, 81, 249, 200), Color(196, 181, 209, 200)]

  PlayerInfoVeryLow = Color(200, 100, 100, 200)
  PlayerInfoLow = Color(220, 180, 80, 200)
  PlayerInfoMedium = Color(200, 200, 80, 200)
  PlayerInfoNormal = Color(192, 192, 192, 200)

  
  Active   = Color(255, 255, 255)
  Inactive = Color(165, 165, 165, 150)
  Alert    = Color(255, 205, 80, 220)

  WindowBg          = Color(0, 0, 0, 220)
  WindowBd          = Color(80, 80, 80, 20)
  WindowTransparent = Color(10, 10, 10, 220)
  WindowOpaque      = Color(18, 18, 18, 255)
  WindowBlur        = Color(100, 100, 100, 255)
  WindowContacts    = Color(18, 18, 18, 50)
  WindowHeader      = Color(30, 30, 30, 150)

  

  
  
  colorblindPalette = [
    
    
    0xffebce2b, 
    0xff702c8c, 
    0xffdb6917, 
    0xff96cde6, 
    0xffba1c30, 
    0xffc0bd7f, 
    
    
    0xff5fa641, 
    0xffd485b2, 
    0xff4277b6, 
    0xff463397, 
    0xffe1a11a, 
    0xff91218c, 
    0xffe8e948, 
    0xff7e1510, 
    0xff92ae31, 
    0xff6f340d, 
    0xffd32b1e, 
    0xff2b3514, 
    0xffdf8461, 
  ]
}

#allow-auto-freeze

colors.__update({
  textColor = function(sf, isEqupped, defColor = colors.BtnTextNormal) {
    if (isEqupped || (sf & S_ACTIVE))  return colors.BtnTextActive
    if (sf & S_HOVER)                  return colors.BtnTextHover
    if (sf & S_KB_FOCUS)               return colors.BtnTextFocused
    return defColor
  }

  borderColor = function(sf, isEqupped, defColor = colors.BtnBdNormal) {
    if (isEqupped || (sf & S_ACTIVE))  return colors.BtnBdActive
    if (sf & S_HOVER)                  return colors.BtnBdHover
    if (sf & S_KB_FOCUS)               return colors.BtnBdFocused
    return defColor
  }

  fillColor = function(sf, isEqupped, defColor = colors.BtnBgNormal) {
    if (isEqupped || (sf & S_ACTIVE))  return colors.BtnBgActive
    if (sf & S_HOVER)                  return colors.BtnBgHover
    if (sf & S_KB_FOCUS)               return colors.BtnBgFocused
    return defColor
  }

})

console_register_command(function(colorStr, multiplier) {
  if (typeof colorStr != "string" || (colorStr.len() != 8 && colorStr.len() != 6))
    return console_print("first param must be string with len 6 or 8")
  if ((typeof multiplier != "float" && typeof multiplier != "integer") || multiplier < 0)
    return console_print("second param must be numeric > 0")

  let colorInt = hexStringToInt(colorStr)
  let a = min(multiplier * (colorStr.len() == 8 ? ((colorInt & 0xFF000000) >> 24) : 255), 255).tointeger()
  let r = min(multiplier * ((colorInt & 0xFF0000) >> 16), 255).tointeger()
  let g = min(multiplier * ((colorInt & 0xFF00) >> 8), 255).tointeger()
  let b = min(multiplier * (colorInt & 0xFF), 255).tointeger()
  let resColor = (a << 24) + (r << 16) + (g << 8) + b
  console_print(format("color = 0x%X, Color(%d, %d, %d, %d)", resColor, r, g, b, a))
}, "debug.multiply_color")

return freeze(colors)
