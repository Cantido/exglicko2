defmodule Exglicko2.GlickoConversion do
  @conversion_factor 173.7178

  @unrated_rating 1500

  def glicko2_to_glicko({rating, deviation, volatility}) do
    {
      @conversion_factor * rating + @unrated_rating,
      deviation * @conversion_factor,
      volatility
    }
  end

  def glicko_to_glicko2({rating, deviation, volatility}) do
    {
      (rating - @unrated_rating)/@conversion_factor,
      deviation/@conversion_factor,
      volatility
    }
  end
end
