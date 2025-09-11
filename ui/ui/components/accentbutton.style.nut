from "%ui/components/glareAnimation.nut" import glareAnimation, animChildren
from "%ui/ui_library.nut" import *
import "%ui/components/colors.nut" as colors

#allow-auto-freeze

let fgChild = animChildren(glareAnimation())

let accentButtonStyle = {
  style = {
    BtnBgNormal = colors.BtnPrimaryBgNormal
    BtnBdNormal = colors.BtnPrimaryBdNormal
    TextNormal = colors.BtnPrimaryTextNormal
  }
  fgChild
}

let accentSelectedButtonStyle = {
  style = {
    BtnBgNormal = colors.BtnPrimaryBgSelected
    BtnBdNormal = colors.BtnPrimaryBdNormal
    TextNormal = colors.BtnPrimaryTextNormal
  }
  fgChild
}

let successButtonStyle = {
  style = {
    BtnBgNormal = colors.BtnSuccessBgNormal
    BtnBdNormal = colors.BtnSuccessBdNormal
    TextNormal = colors.BtnPrimaryTextNormal
  }
  fgChild
}

let AlertButtonStyle = {
  style = {
    BtnBgNormal = colors.BtnAlertBgNormal

  }
}

let stopButtonStyle = {
  style = {
    TextNormal = colors.RedWarningColor
  }
}

return freeze({
  accentButtonStyle
  accentSelectedButtonStyle
  successButtonStyle
  stopButtonStyle
  AlertButtonStyle
})