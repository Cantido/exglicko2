defmodule Exglicko2 do
  @moduledoc """
  Documentation for Exglicko2.
  """

  @e 2.71828182845904523536028747135266249775724709369995
  @conversion_factor 173.7178
  @convergence_tolerance 0.000001

  @unrated_rating 1500
  @unrated_deviation 350
  @unrated_volatility 0.06

  def update_rating(player, results, system_constant) do
    {rating, deviation, volatility} = converted_player = glicko_to_glicko2(player)
    converted_results = Enum.map(results, fn {player, result} ->
      {glicko_to_glicko2(player), score(result)}
    end)

    player_variance = variance(converted_player, converted_results)
    player_improvement = improvement(converted_player, converted_results)

    new_volatility = new_volatility(converted_player, player_variance, player_improvement, system_constant)
    new_pre_rating_deviation = :math.sqrt(square(deviation) + square(new_volatility))

    new_deviation = 1 / :math.sqrt((1/square(new_pre_rating_deviation)) + (1 / player_variance))

    new_rating = new_rating(converted_player, converted_results, new_deviation)

    glicko2_to_glicko({new_rating, new_deviation, new_volatility})
  end

  defp glicko2_to_glicko({rating, deviation, volatility}) do
    {
      @conversion_factor * rating + @unrated_rating,
      deviation * @conversion_factor,
      volatility
    }
  end

  defp glicko_to_glicko2({rating, deviation, volatility}) do
    {
      (rating - @unrated_rating)/@conversion_factor,
      deviation/@conversion_factor,
      volatility
    }
  end

  defp glicko_to_glicko2({rating, deviation}) do
    {
      (rating - @unrated_rating)/@conversion_factor,
      deviation/@conversion_factor,
    }
  end

  def score(:win), do: 1
  def score(:draw), do: 0.5
  def score(:lose), do: 0

  defp new_rating({rating, deviation, volatility}, results, new_deviation) do
    sum_term =
      results
      |> Enum.map(fn {{opponent_rating, opponent_deviation, _opponent_volatility}, score} ->
        g(opponent_deviation) * (score - e(rating, opponent_rating, opponent_deviation))
      end)
      |> Enum.sum()

    rating + square(new_deviation) * sum_term
  end

  defp new_volatility({rating, deviation, volatility} = player, player_variance, player_improvement, system_constant) do
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

  defp improvement({rating, deviation, volatility}, results) do
    sum = Enum.map(results, fn {{opponent_rating, opponent_deviation, _opponent_volatility}, score} ->
      g(opponent_deviation) * (score - e(rating, opponent_rating, opponent_deviation))
    end)
    |> Enum.sum()

    sum * variance({rating, deviation, volatility}, results)
  end

  defp variance({rating, deviation, volatility}, results) do
    sum = Enum.map(results, fn {{opponent_rating, opponent_deviation, _opponent_volatility}, _score} ->
      square(g(opponent_deviation)) *
        e(rating, opponent_rating, opponent_deviation) *
        (1 - e(rating, opponent_rating, opponent_deviation))
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
