defmodule Exglicko2.GlickoConversion do
  @moduledoc """
  Converts between Glicko and Glicko-2 ratings.
  """

  @conversion_factor 173.7178
  @unrated_rating 1500

  @doc """
  Converts a Glicko-2 rating tuple into a Glicko rating tuple.
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
  """
  def glicko_to_glicko2({rating, deviation, volatility}) do
    {
      (rating - @unrated_rating)/@conversion_factor,
      deviation/@conversion_factor,
      volatility
    }
  end
end
