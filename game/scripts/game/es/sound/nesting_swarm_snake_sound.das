require ecs
require app
require soundEvent
require soundSystem
require sound_utils.modules.sound_player_common
require sound_utils.modules.sound_control_common
require game.es.am_nesting_swarm_snake_common
require game.events.events_game
require math.base

// nest ------------

[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=(sound_begin_update_es, sound_control_update), before=sound_end_update_es)]
def nesting_swarm_snake_nest_sound(evt : Event;
                                   sound_control__state : int;
                                   nesting_swarm_nest__warriorEid : EntityId;

                                   transform aka nest_transform : float3x4;
                                   isAlive : bool;

                                   nesting_swarm_snake_nest_sound__path : string;
                                   var nesting_swarm_snake_nest_sound__event : SoundEvent&)

  assume event = nesting_swarm_snake_nest_sound__event

  if !have_sound(sound_control__state)
    event |> play_or_abandon(nesting_swarm_snake_nest_sound__path, nest_transform[3], false)
    return

  var state = int(NestingSwarmSnakeState.None)
  query(nesting_swarm_nest__warriorEid) <| $ [es] (nesting_swarm_snake__state : int)
    state = nesting_swarm_snake__state

  let shouldPlay = isAlive && (state != int(NestingSwarmSnakeState.None))

  if event |> play_or_abandon(nesting_swarm_snake_nest_sound__path, nest_transform[3], shouldPlay)

    let aggression = state == int(NestingSwarmSnakeState.Attack) ? 1. : 0.
    let isVisible = state == int(NestingSwarmSnakeState.Nest) ? 0. : 1.

    set_var(event, "agression", aggression)
    set_var(event, "is_visible", isVisible)


// snake ------------

[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=(sound_begin_update_es, sound_control_update), before=sound_end_update_es)]
def nesting_swarm_snake_sound(evt : Event;
                              sound_control__state : int;

                              nesting_swarm_snake__state : int;
                              nesting_swarm_snake__segmentEids : EidList;

                              transform aka snake_transform : float3x4;
                              isAlive : bool;

                              var nesting_swarm_snake_sound__event : SoundEvent&;
                              nesting_swarm_snake_sound__path : string;

                              // wiz (flyby)
                              nesting_swarm_snake_wiz_sound__path : string;
                              var nesting_swarm_snake_wiz_sound__pos : float3&;
                              nesting_swarm_snake_wiz_sound__cooldown : float;
                              var nesting_swarm_snake_wiz_sound__nextTimeAt : float&)

  assume event = nesting_swarm_snake_sound__event

  let shouldPlay = have_sound(sound_control__state) && isAlive && (nesting_swarm_snake__state >= int(NestingSwarmSnakeState.Fly)) && !empty(nesting_swarm_snake__segmentEids)

  if nesting_swarm_snake_sound__event |> play_or_abandon(nesting_swarm_snake_sound__path, snake_transform[3], shouldPlay)

    var center : float3
    var aa = float3(FLT_MAX, FLT_MAX, FLT_MAX)
    var bb = float3(-FLT_MAX, -FLT_MAX, -FLT_MAX)

    for segmentEid in nesting_swarm_snake__segmentEids
      query(segmentEid) <| $ [es] (transform aka segment_transform : float3x4)
        aa = min(aa, segment_transform[3])
        bb = max(bb, segment_transform[3])
        center += segment_transform[3]

    let count = length(nesting_swarm_snake__segmentEids)
    center /= float(count)
    let size = min(length(bb - center), length(aa - center))

    set_pos(event, center)
    set_var(event, "size", size)
    set_var(event, "count", float(count))

    // wiz (flyby) ------------
    assume prevPos = nesting_swarm_snake_wiz_sound__pos
    if length_sq(prevPos) == 0.
      prevPos = center
    else
      let pos = center
      let dir = normalize(pos - prevPos)
      let wizRange = 8.
      let listener = get_listener_pos()
      let closestPointOnDir = pos + dir * dot(listener - pos, dir)
      if dot(prevPos - closestPointOnDir, dir) <= 0. && dot(pos - closestPointOnDir, dir) > 0.
        if length_sq(closestPointOnDir - listener) < square(wizRange)
          if get_sync_time() >= nesting_swarm_snake_wiz_sound__nextTimeAt
            nesting_swarm_snake_wiz_sound__nextTimeAt = get_sync_time() + nesting_swarm_snake_wiz_sound__cooldown
            oneshot(nesting_swarm_snake_wiz_sound__path, closestPointOnDir)
      prevPos = pos
  else
    nesting_swarm_snake_wiz_sound__pos = float3(0., 0., 0.)

// snake attack oneshot ------------

[es(tag=sound, track=nesting_swarm_snake__state)]
def nesting_swarm_snake_sound_track_state(evt : Event;
                                          swarm_warrior__primaryNest : EntityId;
                                          nesting_swarm_snake__state : int)
  if nesting_swarm_snake__state == int(NestingSwarmSnakeState.Attack)
    query(swarm_warrior__primaryNest) <| $ [es] (transform aka nest_transform : float3x4;
                                                 nesting_swarm_snake_nest_aggression_sound__path : string;
                                                 nesting_swarm_snake_nest_aggression_sound__cooldown : float;
                                                 var nesting_swarm_snake_nest_aggression_sound__nextTimeAt : float&)
      if get_sync_time() >= nesting_swarm_snake_nest_aggression_sound__nextTimeAt
        nesting_swarm_snake_nest_aggression_sound__nextTimeAt = get_sync_time() + nesting_swarm_snake_nest_aggression_sound__cooldown
        oneshot(nesting_swarm_snake_nest_aggression_sound__path, nest_transform[3])


// snake segment hits human oneshot ------------

[es(tag=sound, REQUIRE=humanSound)]
def nesting_swarm_snake_segment_sound_hit_human(evt : EventOnEntityHit; eid : EntityId;
                                                transform : float3x4)
  if eid == evt.victim
    query(evt.offender) <| $ [es] (nesting_swarm_snake_segment_sound__humanHitPath : string)
      oneshot(nesting_swarm_snake_segment_sound__humanHitPath, transform[3])
