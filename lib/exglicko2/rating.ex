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

  @doc """
  Creates a "composite player" from the given enumerable of ratings.

  The resulting player will have a rating, deviation, and volatility that is the average of all given players.
  """
  def composite(players) when is_list(players) do
    %__MODULE__{
      rating: Enum.map(players, & &1.rating) |> mean(),
      deviation: Enum.map(players, & &1.deviation) |> mean(),
      volatility: Enum.map(players, & &1.volatility) |> mean()
    }
  end

  defp mean(values) when is_list(values) do
    Enum.sum(values) / Enum.count(values)
  end
end
