from "%ui/ui_library.nut" import *





let tiny_txt = freeze({
  font = Fonts.system
  fontSize = fsh(1.203)
})

let sub_txt = freeze({
  
  font = Fonts.system
  fontSize = fsh(1.481)
})

let body_txt = freeze({
  
  font = Fonts.system
  fontSize = fsh(2.037)
})
let h2_txt = freeze({
  
  font = Fonts.system
  fontSize = fsh(2.407)
})

let h1_txt = freeze({
  
  font = Fonts.system
  fontSize = fsh(3.2)
})

let giant_txt = freeze({
  font = Fonts.system
  fontSize = fsh(5.7)
})

let fontawesome = freeze({
  font = Fonts.fontawesome
  fontSize = fsh(1.944)
})

let basic_text_shadow = freeze({
  fontFx = FFT_BLUR 
  fontFxColor = Color(0,0,0,60)
  fontFxFactor = min(48, hdpx(48))
  fontFxOffsY = hdpx(0.7)
  fontFxOffsX = hdpx(0.3)
})
return {
  giant_txt,
  h1_txt,
  h2_txt,
  body_txt,
  sub_txt,
  tiny_txt,
  fontawesome,
  basic_text_shadow
}
