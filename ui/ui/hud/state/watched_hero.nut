import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
let { get_watched_hero } = require("%dngscripts/common_queries.nut")







let watchedHeroEid = Watched(ecs.INVALID_ENTITY_ID)
let watchedHeroMainAnimcharRes = Watched("")
let watchedHeroPlayerEid = Watched(ecs.INVALID_ENTITY_ID)
let watchedHeroAnimcharEid = Watched(ecs.INVALID_ENTITY_ID)
let watchedHeroAnimcharRes = Watched("")
let watchedHeroDefaultStubMeleeWeapon = Watched(null)

wlog(watchedHeroEid, "watched:")

ecs.register_es("watched_hero_player_eid_es", {
  onInit = function(_eid,comp){ watchedHeroPlayerEid.set(comp["possessedByPlr"] ?? ecs.INVALID_ENTITY_ID); }
  onChange = function(_eid,comp){ watchedHeroPlayerEid.set(comp["possessedByPlr"] ?? ecs.INVALID_ENTITY_ID);}
  onDestroy = function(_eid,comp){ watchedHeroPlayerEid.set(comp["possessedByPlr"] == watchedHeroPlayerEid.get() ? ecs.INVALID_ENTITY_ID : watchedHeroPlayerEid.get()); }
}, {comps_track=[["possessedByPlr", ecs.TYPE_EID]],comps_rq=[["watchedByPlr", ecs.TYPE_EID]]})


ecs.register_es("watched_hero_eid_es", {
  onInit = function (eid, comp){
    watchedHeroEid.set(eid)
    watchedHeroMainAnimcharRes.set(comp.animchar__res)
    watchedHeroDefaultStubMeleeWeapon.set(comp.default_stub_melee_controller__meleeTemplate)
  }
  onDestroy = function(eid, _comp){
    if (eid == watchedHeroEid.get()) {
      watchedHeroEid.set(ecs.INVALID_ENTITY_ID)
      watchedHeroMainAnimcharRes.set("")
      watchedHeroDefaultStubMeleeWeapon.set(null)
    }
  }
},
{
  comps_rq=[["watchedByPlr", ecs.TYPE_EID]]
  comps_ro=[
    ["animchar__res", ecs.TYPE_STRING],
    ["default_stub_melee_controller__meleeTemplate", ecs.TYPE_STRING]
  ]
},
{
  before="watched_hero_player_eid_es"
})


ecs.register_es("watched_hero_animchar_with_builtin_suit_es", {
  onInit = function (eid, comp){
    watchedHeroAnimcharEid.set(eid)
    watchedHeroAnimcharRes.set(comp.animchar__res)
  }
  onDestroy = function(...){
    watchedHeroAnimcharEid.set(ecs.INVALID_ENTITY_ID)
    watchedHeroAnimcharRes.set("")
  }
},
{
  comps_rq=[["watchedByPlr", ecs.TYPE_EID]]
  comps_ro=[["animchar__res", ecs.TYPE_STRING]]
  comps_no=[["attachable_suit_controller__suitAnimcharEid", ecs.TYPE_EID]]
})


ecs.register_es("watched_hero_animchar_with_attachable_suit_es", {
  onInit = function (eid, comp) {
    watchedHeroAnimcharEid.set(eid)
    watchedHeroAnimcharRes.set(comp.animchar__res)
  }
  onDestroy = function(...){
    watchedHeroAnimcharEid.set(ecs.INVALID_ENTITY_ID)
    watchedHeroAnimcharRes.set("")
  }
},
{
  comps_rq=[
    ["suit_militant_attachable_animchar", ecs.TYPE_TAG],
    ["watchedPlayerItem", ecs.TYPE_TAG]
  ]
  comps_ro=[["animchar__res", ecs.TYPE_STRING]]
})

let watchedHeroPos = Watched(null)
ecs.register_es("watched_hero_track_pos_es", {
    [["onInit", "onUpdate"]] = function(_eid, comp) {
      watchedHeroPos.set(comp.transform.getcol(3))
    },
    onDestroy = function(...){
      watchedHeroPos.set(null)
    }
  }, {
    comps_rq=[["watchedByPlr", ecs.TYPE_EID]]
    comps_ro=[["transform", ecs.TYPE_MATRIX]]
  },
  { tags="gameClient", updateInterval = 1.0, before="*", after="*" }
)




let watchedHeroSex = Watched(0)
ecs.register_es("watched_hero_track_sex_es", {
    [["onInit", "onChange"]] = function(_eid, comp) {
      if (comp.item__humanOwnerEid == get_watched_hero())
        watchedHeroSex.set(comp.suit__suitType)
    }
  }, {
    comps_rq=[
      ["watchedPlayerItem", ecs.TYPE_TAG],
      ["suit_attachable_item_in_equipment", ecs.TYPE_TAG]
    ]
    comps_ro=[
      ["suit__suitType", ecs.TYPE_INT]
    ]
    comps_track=[
      ["item__humanOwnerEid", ecs.TYPE_EID],
    ]
  }
)

let watchedHeroSneaking = Watched(false)
ecs.register_es("watched_hero_track_sneaking_es", {
    [["onInit", "onChange"]] = function(_eid, comp) {
      watchedHeroSneaking.set(comp.human__sneaking)
    }
  }, {
    comps_rq=["watchedByPlr"]
    comps_track=[
      ["human__sneaking", ecs.TYPE_BOOL]
    ]
  }
)


return {
  watchedHeroEid,
  watchedHeroMainAnimcharRes,
  watchedHeroPlayerEid,
  watchedHeroAnimcharEid,
  watchedHeroAnimcharRes,
  watchedHeroPos,
  watchedHeroSex,
  watchedHeroSneaking,
  watchedHeroDefaultStubMeleeWeapon
}