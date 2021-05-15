defmodule Exglicko2.Rating do
  @enforce_keys [
    :rating,
    :deviation,
    :volatility
  ]
  defstruct [
    :rating,
    :deviation,
    :volatility
  ]
end
