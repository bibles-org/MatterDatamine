module validation_common shared
require ecs
require math.base
require DagorMath


def is_client_value_valid(value : int;
                          min : int = -2147440000;
                          max : int = 2147440000)
  return value >= min && value <= max


def is_client_value_valid(value : float;
                          min : float = -VERY_BIG_NUMBER;
                          max : float = VERY_BIG_NUMBER)
  return !is_nan(value) && value >= min && value <= max


def is_client_value_valid(value : float2;
                          min : float = -VERY_BIG_NUMBER;
                          max : float = VERY_BIG_NUMBER)
  return is_client_value_valid(value.x, min, max) && is_client_value_valid(value.y, min, max)


def is_client_value_valid(value : float3;
                          min : float = -VERY_BIG_NUMBER;
                          max : float = VERY_BIG_NUMBER)
  return (is_client_value_valid(value.x, min, max) && is_client_value_valid(value.y, min, max) &&
          is_client_value_valid(value.z, min, max))


def is_client_value_valid(value : float4;
                          min : float = -VERY_BIG_NUMBER;
                          max : float = VERY_BIG_NUMBER)
  return (is_client_value_valid(value.x, min, max) && is_client_value_valid(value.y, min, max) &&
          is_client_value_valid(value.z, min, max) && is_client_value_valid(value.w, min, max))


def is_client_value_valid(value : float3x4;
                          min : float = -VERY_BIG_NUMBER;
                          max : float = VERY_BIG_NUMBER)
  return (is_client_value_valid(value[0], min, max) && is_client_value_valid(value[1], min, max) &&
          is_client_value_valid(value[2], min, max) && is_client_value_valid(value[3], min, max))


def is_client_value_in_distance(value : float;
                                required_value : float;
                                distance : float =  1e-3)
  return is_client_value_valid(value) && abs(value - required_value) <= distance


def is_client_value_in_distance(value : float3;
                                required_value : float3;
                                distance : float)
  return is_client_value_valid(value) && distance_sq(value, required_value) <= square(distance)


def is_client_value_length(value : float3;
                           min_length : float;
                           max_length : float)
  let lenSq = length_sq(value)
  return is_client_value_valid(value) && lenSq >= square(min_length) && lenSq <= square(max_length)


def is_client_value_normalized(value : float3)
  return is_client_value_length(value, 0.998, 1.002)