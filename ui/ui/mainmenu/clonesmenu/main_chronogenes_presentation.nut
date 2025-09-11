from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

enum ObtainWay {
  MONOLITH
  CONTRACT
  GAME_PACK
  MONOLITH_END
  PREPURCHASED
  T_DROPS
}

let mainChronogeneObtainWay = freeze({
  
  sm_reaper_item = {
    way = ObtainWay.GAME_PACK
    pack = "premium"
  }
  suit_militant_light_f_item = {}   
  
  sm_rebel_item = { way = ObtainWay.PREPURCHASED }
  suit_militant_light_b_prem_item = { way = ObtainWay.T_DROPS }   
  sm_liquidator_item = {
    way = ObtainWay.MONOLITH
    level = "prestige"
  }
  suit_militant_female_pulse_item = {
    way = ObtainWay.MONOLITH
    level = "prestige"
  }
  suit_militant_male_outlaw_item = {
    way = ObtainWay.MONOLITH_END
    level = "prestige"
  }
  suit_militant_female_enforcer_item = {
    way = ObtainWay.MONOLITH
    level = "prestige"
  }
  sm_phantom_item = {
    way = ObtainWay.MONOLITH
    level = 10
  }
  sm_hunter_item = {
    way = ObtainWay.MONOLITH
    level = 8
  }
  
  suit_militant_female_light_b_item = {   
    way = ObtainWay.MONOLITH
    level = 6
  }
  sm_mirage_item = {
    way = ObtainWay.MONOLITH
    level = 4
  }
  sm_beast_item = {}
  suit_militant_light_c_item = {}   
  sm_psychologist_item = {}
  sm_master_item = {}
  suit_militant_female_light_a_item = {   
    way = ObtainWay.CONTRACT
  }
})

return {
  mainChronogeneObtainWay
  ObtainWay
}