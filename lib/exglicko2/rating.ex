defmodule Exglicko2.Rating do
  @moduledoc """
  A Glicko-2 rating.
  Ratings have a `:value`, `:deviation`, and `:volatility`.
  """

  @e 2.71828182845904523536028747135266249775724709369995
  @convergence_tolerance 0.000001
  @glicko_conversion_factor 173.7178
  @unrated_glicko_rating 1500

  @enforce_keys [
    :value,
    :deviation,
    :volatility
  ]
  defstruct [
    :value,
    :deviation,
    :volatility
  ]

  @doc """
  Returns a new `Exglicko2.Rating` suited to new players.
  """
  def new do
    %__MODULE__{
      value: 0.0,
      deviation: 2.0,
      volatility: 0.06
    }
  end

  @doc """
  Returns a new `Exglicko2.Rating` with the given values.
  """
  def new(rating, deviation, volatility) do
    %__MODULE__{
      value: rating,
      deviation: deviation,
      volatility: volatility
    }
  end

  @doc """
  Convert a rating to its first-generation Glicko equivalent.

  ## Examples

      iex> Exglicko2.Rating.new(0.0, 1.2, 0.06)
      ...> |> Exglicko2.Rating.to_glicko()
      {1500.0, 208.46136, 0.06}
  """
  def to_glicko(%__MODULE__{value: rating, deviation: deviation, volatility: volatility}) do
    {
      @glicko_conversion_factor * rating + @unrated_glicko_rating,
      deviation * @glicko_conversion_factor,
      volatility
    }
  end

  @doc """
  Build a new rating from first-generation Glicko rating values.

  ## Examples

      iex> Exglicko2.Rating.from_glicko({1500.0, 350, 0.06})
      %Exglicko2.Rating{value: 0.0, deviation: 2.014761872416068, volatility: 0.06}
  """
  def from_glicko({value, deviation, volatility}) do
    new(
      (value - @unrated_glicko_rating)/@glicko_conversion_factor,
      deviation/@glicko_conversion_factor,
      volatility
    )
  end

  @doc """
  Creates a rating with a value, deviation, and volatility that is the average of all given ratings.
  """
  def composite(ratings)

  def composite(ratings) when is_list(ratings) do
    %__MODULE__{
      value: Enum.map(ratings, & &1.value) |> mean(),
      deviation: Enum.map(ratings, & &1.deviation) |> mean(),
      volatility: Enum.map(ratings, & &1.volatility) |> mean()
    }
  end

  def composite(%__MODULE__{} = rating) do
    rating
  end

  defp mean(values) when is_list(values) do
    Enum.sum(values) / Enum.count(values)
  end

  def update_rating(%__MODULE__{deviation: deviation} = player, results, system_constant) do
    player_variance = variance(player, results)
    player_improvement = improvement(player, results)

    new_volatility = new_volatility(player, player_variance, player_improvement, system_constant)
    new_pre_rating_deviation = :math.sqrt(square(deviation) + square(new_volatility))

    new_deviation = 1 / :math.sqrt((1/square(new_pre_rating_deviation)) + (1 / player_variance))

    new_rating = new_rating(player, results, new_deviation)

    new(new_rating, new_deviation, new_volatility)
  end

  defp new_rating(%__MODULE__{value: rating}, results, new_deviation) do
    sum_term =
      results
      |> Enum.map(fn {opponent, score} ->
        g(opponent.deviation) * (score - e(rating, opponent.value, opponent.deviation))
      end)
      |> Enum.sum()

    rating + square(new_deviation) * sum_term
  end

  defp new_volatility(%__MODULE__{value: rating, deviation: deviation, volatility: volatility}, player_variance, player_improvement, system_constant) do
    f = &new_volatility_inner_template(&1, rating, deviation, player_variance, volatility, system_constant)

    starting_lower_bound = ln(square(volatility))
    starting_upper_bound =
      if square(player_improvement) > (square(volatility) + player_variance) do
        ln(square(player_improvement) - square(volatility) - player_variance)
      else
        k =
          Stream.iterate(1, &(&1 + 1))
          |> Stream.drop_while(&(f.(starting_lower_bound - &1 * system_constant) < 0))
          |> Enum.at(0)
        starting_lower_bound - k * system_constant
      end

    f_a = f.(starting_lower_bound)
    f_b = f.(starting_upper_bound)

    final_lower_bound =
      Stream.iterate(
        {starting_lower_bound, starting_upper_bound, f_a, f_b},
        fn {a, b, f_a, f_b} ->
          c = a + ((a - b) * f_a / (f_b - f_a))
          f_c = f.(c)

          if (f_c * f_b) < 0 do
            {b, c, f_b, f_c}
          else
            {a, c, f_a/2, f_c}
          end
        end
      )
      |> Stream.drop_while(fn {a, b, _f_a, _f_b} ->
        abs(b - a) > @convergence_tolerance
      end)
      |> Enum.at(0)
      |> elem(0)

    exp(final_lower_bound / 2)
  end

  defp new_volatility_inner_template(x, delta, phi, v, sigma, tau) do
    a = ln(square(sigma))
    numerator = exp(x) * (square(delta) - square(phi) - v - exp(x))
    denominator = 2 * square(square(phi) + v + exp(x))

    (numerator / denominator) - ((x - a) / square(tau))
  end

  defp improvement(player, results) do
    sum = Enum.map(results, fn {opponent, score} ->
      g(opponent.deviation) * (score - e(player.value, opponent.value, opponent.deviation))
    end)
    |> Enum.sum()

    sum * variance(player, results)
  end

  defp variance(%__MODULE__{value: rating}, results) do
    sum = Enum.map(results, fn {opponent, _score} ->
      square(g(opponent.deviation)) *
        e(rating, opponent.value, opponent.deviation) *
        (1 - e(rating, opponent.value, opponent.deviation))
    end)
    |> Enum.sum()

    1 / sum
  end

  defp e(mu, mu_j, phi_j) do
    1 / (1 + exp(-g(phi_j) * (mu - mu_j)))
  end

  defp g(phi) do
    1/:math.sqrt(1 + (3 * square(phi) / square(pi())))
  end

  defp ln(x) do
    :math.log(x)
  end

  defp pi do
    :math.pi()
  end

  defp square(n) do
    :math.pow(n, 2)
  end

  defp exp(n) do
    :math.pow(@e, n)
  end
end
