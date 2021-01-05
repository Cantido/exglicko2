defmodule Exglicko2.Conversion do
  @moduledoc """
  Converts between Glicko and Glicko-2 ratings.
  """

  @conversion_factor 173.7178
  @unrated_rating 1500

  @doc """
  Converts a Glicko-2 rating tuple into a Glicko rating tuple.

  ## Examples

      iex> Exglicko2.Conversion.glicko2_to_glicko({0.0, 1.2, 0.06})
      {1500.0, 208.46136, 0.06}
  """
  def glicko2_to_glicko({rating, deviation, volatility}) do
    {
      @conversion_factor * rating + @unrated_rating,
      deviation * @conversion_factor,
      volatility
    }
  end

  @doc """
  Converts a Glicko rating tuple into a Glicko-2 rating tuple.

  ## Examples

      iex> Exglicko2.Conversion.glicko_to_glicko2({1500.0, 350, 0.06})
      {0.0, 2.014761872416068, 0.06}
  """
  def glicko_to_glicko2({rating, deviation, volatility}) do
    {
      (rating - @unrated_rating)/@conversion_factor,
      deviation/@conversion_factor,
      volatility
    }
  end
end
