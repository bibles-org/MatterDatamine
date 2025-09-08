from "%ui/ui_library.nut" import *

function colorize(color, text) {return "<color={0}>{1}</color>".subst(color, text.tostring())}
return colorize