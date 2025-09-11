from "%ui/ui_library.nut" import *
import "%ui/components/colors.nut" as colors

let factionsLogo = [
  {
    bg =    "central_horizontal_line"
    color = colors.colorblindPalette[0]
    fg =    "claws_with_granade"
  },
  {
    bg =    "checker"
    color = colors.colorblindPalette[1]
    fg =    "dinosaur"
  },
  {
    bg =    "horizontal_line"
    color = colors.colorblindPalette[2]
    fg =    "fire"
  },
  {
    bg =    "central_vertical_line"
    color = colors.colorblindPalette[3]
    fg =    "fortress"
  },
  {
    bg =    "solid"
    color = colors.colorblindPalette[4]
    fg =    "globe"
  },
  {
    bg =    "diagonal"
    color = colors.colorblindPalette[5]
    fg =    "shark"
  },
  {
    bg =    "central_vertical_line"
    color = colors.colorblindPalette[6]
    fg =    "skull"
  },
  {
    bg =    "diagonal"
    color = colors.colorblindPalette[7]
    fg =    "swords"
  },
  {
    bg =    "vertical_line"
    color = colors.colorblindPalette[8]
    fg =    "tiger_head"
  },
  {
    bg =    "checker"
    color = colors.colorblindPalette[9]
    fg =    "wind_rose"
  }
]

function mkFactionIcon(faction, size) {
  let idx = faction.replace("faction_", "").tointeger() - 1
  if (idx < 0 || idx >= factionsLogo.len())
    return null
  let bg = $"!ui/skin#logos/back/{factionsLogo[idx].bg}.svg:{size[0]}:{size[1]}:K"
  let fg = $"!ui/skin#logos/figure/{factionsLogo[idx].fg}.svg:{size[0]}:{size[1]}:K"

  return {
    size
    children = [
      {
        rendObj = ROBJ_IMAGE
        size
        color = factionsLogo[idx].color
        keepAspect = KEEP_ASPECT_FILL
        image = Picture(bg)
      }
      {
        rendObj = ROBJ_IMAGE
        size
        keepAspect = KEEP_ASPECT_FILL
        image = Picture(fg)
      }
    ]
  }
}

return {
  mkFactionIcon
}