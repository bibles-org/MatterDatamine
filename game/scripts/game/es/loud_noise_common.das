module loud_noise_common shared
require app
require net
require ecs
require DngNet
require math.base
require Grid
require GridCollision
require DagorMath
require Dacoll
require DagorConsole
require game.events.events_active_matter


let meterUp = float3(0, 1, 0)//TODO gravity

def create_loud_noise_at(pos : float3; radius, amount : float; debug_name : string = "")
  create_loud_noise_at(pos, radius, amount, 0.0, 1.0, debug_name)

def private calc_noise_amount(origin_pos, receiver_pos : float3; radius, amount, muffled_multi : float)
  let dst = distance(receiver_pos, origin_pos)
  if dst < radius
    let p = origin_pos + meterUp
    let dir = normalize(receiver_pos - origin_pos - meterUp)
    let muffled : bool = rayhit_normalized(p, dir, dst, ETF_DEFAULT, -1)
    return cvt(dst, .0, radius, amount, .0) * (muffled ? muffled_multi : 1.0)
  return .0

def create_loud_noise_at(pos : float3; radius, amount, percent_amount, max_percent : float; debug_name : string = "")
  if amount == .0 && percent_amount == .0
    return
  if !is_true_net_server()
    create_loud_noise_for_client_meter(pos, radius, amount)
  if is_server()
    distribute_loud_noise(pos, radius, amount, percent_amount, max_percent, debug_name)


def distribute_loud_noise(pos : float3; radius, amount, percent_amount, max_percent : float; debug_name : string)
  var affectedEntities = 0
  var totalNoiseSpread = 0.0
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(pos, radius), GridEntCheck.POS) <| $(eid : EntityId)
    query(eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=sleeping_monster)] (transform : float3x4;
                                                                            eid : EntityId;
                                                                            changed_loud_noise__awakeThreshold : float;
                                                                            loud_noise__appendOnNoise : string = "";
                                                                            loud_noise__noiseMultiplier : float = 1.0;
                                                                            loud_noise__muffledMultiplier : float = 0.4;
                                                                            loud_noise__outsideOfTmMulti : float = 0.0;
                                                                            loud_noise__senseRadius : float = 100000.0;
                                                                            generated_monster__genEid : EntityId = INVALID_ENTITY_ID;
                                                                            var loud_noise__accumulatedNoise : float&;
                                                                            var loud_noise_reaction__wasDisturbed : bool?;
                                                                            var loud_noise__noiseVelocity : float&)
      if max_percent > .0 && loud_noise__accumulatedNoise > changed_loud_noise__awakeThreshold * max_percent
        return
      var mult = loud_noise__noiseMultiplier
      query(generated_monster__genEid) <| $ [es] (transform aka generator_transform : float3x4)
        if !is_inside_tm(pos, generator_transform)
          mult *= loud_noise__outsideOfTmMulti
      let effectiveRadius = min(radius, loud_noise__senseRadius)
      let dst = distance(transform[3], pos)
      if dst < effectiveRadius
        if amount > .0
          affectedEntities++
          if loud_noise_reaction__wasDisturbed != null
            *loud_noise_reaction__wasDisturbed = true
            loud_noise__noiseVelocity = max(.0, loud_noise__noiseVelocity)
          let delta = calc_noise_amount(pos, transform[3], radius, amount, loud_noise__muffledMultiplier) * mult
          totalNoiseSpread += delta
          loud_noise__noiseVelocity += delta

        if percent_amount > .0
          let targetAmount = changed_loud_noise__awakeThreshold * percent_amount
          if loud_noise__accumulatedNoise < targetAmount
            if loud_noise_reaction__wasDisturbed != null
              *loud_noise_reaction__wasDisturbed = true
            totalNoiseSpread += targetAmount - loud_noise__accumulatedNoise
            loud_noise__accumulatedNoise = targetAmount

        if loud_noise__noiseVelocity > .0 && loud_noise_reaction__wasDisturbed == null && !empty(loud_noise__appendOnNoise)
          send_net_event(eid, EventAddNoiseSubtemplate())
  if !empty(debug_name)
    find_query() <| $ [es(REQUIRE=loud_noise_debug)] ()
      visual_log("{debug_name}: {int(amount)} db in {int(radius)} meters. Affected: {affectedEntities} Distributed: {int(totalNoiseSpread)} db.")
      return true


def create_loud_noise_for_client_meter(pos : float3; radius, amount : float)
  query() <| $ [es(REQUIRE_NOT=deadEntity)] (var loud_noise_meter__value : float&; transform : float3x4; loud_noise_meter__muffledMultiplier : float)
    loud_noise_meter__value += calc_noise_amount(pos, transform[3], radius, amount, loud_noise_meter__muffledMultiplier)