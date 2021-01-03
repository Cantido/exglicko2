defmodule Exglicko2 do
  @moduledoc """
  Tools for working with Glicko-2 ratings.

  Ratings are represented by a tuple of the rating, the rating deviation, and the rating volatility.
  You can get a new, default tuple with the `new/0` function.

      iex> Exglicko2.new()
      {1500, 350, 0.06}

  Once your players have ratings, the games can begin!
  Game results are represented by a number ranging from zero to one,
  with a one representing a win, and a zero representing a loss.

  Ratings are updated with a list of game results passed to the `update_rating/3` function.
  Game results are batched into a list of tuples, with the first element being the opponent's rating tuple,
  and the second being the resulting score.
  This function also requires a system constant, which governs how much ratings are allowed to change.
  This value must be between 0.4 and 1.2

      iex> player = {1500, 200, 0.06}
      iex> system_constant = 0.5
      iex> results = [
      ...>   {{1400, 30, 0}, 1},
      ...>   {{1550, 100, 0}, 0},
      ...>   {{1700, 300, 0}, 0}
      ...> ]
      iex> Exglicko2.update_rating(player, results, system_constant)
      {1464.0506711471253, 151.51652284295207, 0.05999565709430874}
  """

  @e 2.71828182845904523536028747135266249775724709369995
  @convergence_tolerance 0.000001

  @doc """
  Returns a new `{rating, deviation, volatility}` tuple, suited to new players.
  """
  def new do
    {1500, 350, 0.06}
  end

  @doc """
  Update a player's rating based on game results.

  Each player is represented by a tuple of the player's rating, their rating deviation, and their rating volatility.
  Game results are batched into a list of tuples, with the first element being the opponent's values,
  and the second being the resulting score between zero and one.

  Also requires a system constant, which governs how much ratings are allowed to change.
  This value must be between 0.4 and 1.2

  ## Example

  A player with a rating of 1500, a deviation of 200, and a volatility of 0.06 plays three games.
  - Against the first opponent, with a rating of 1400, they win. Thus the score is 1.
  - Against the second opponent, with a rating of 1550, they lose. Thus the score is 0.
  - Against the third opponent, with a rating of 1700, they lose again. Thus the score is 0.

  The result is that the player's score drops to 1464, their deviation drops to 152, and their volatility drops slightly.

      iex> player = {1500, 200, 0.06}
      iex> system_constant = 0.5
      iex> results = [
      ...>   {{1400, 30, 0}, 1},
      ...>   {{1550, 100, 0}, 0},
      ...>   {{1700, 300, 0}, 0}
      ...> ]
      iex> Exglicko2.update_rating(player, results, system_constant)
      {1464.0506711471253, 151.51652284295207, 0.05999565709430874}
  """
  def update_rating(player, results, system_constant) do
    {_rating, deviation, _volatility} = converted_player = Exglicko2.GlickoConversion.glicko_to_glicko2(player)
    converted_results = Enum.map(results, fn {player, score} ->
      {Exglicko2.GlickoConversion.glicko_to_glicko2(player), score}
    end)

    player_variance = variance(converted_player, converted_results)
    player_improvement = improvement(converted_player, converted_results)

    new_volatility = new_volatility(converted_player, player_variance, player_improvement, system_constant)
    new_pre_rating_deviation = :math.sqrt(square(deviation) + square(new_volatility))

    new_deviation = 1 / :math.sqrt((1/square(new_pre_rating_deviation)) + (1 / player_variance))

    new_rating = new_rating(converted_player, converted_results, new_deviation)

    Exglicko2.GlickoConversion.glicko2_to_glicko({new_rating, new_deviation, new_volatility})
  end

  defp new_rating({rating, _deviation, _volatility}, results, new_deviation) do
    sum_term =
      results
      |> Enum.map(fn {{opponent_rating, opponent_deviation, _opponent_volatility}, score} ->
        g(opponent_deviation) * (score - e(rating, opponent_rating, opponent_deviation))
      end)
      |> Enum.sum()

    rating + square(new_deviation) * sum_term
  end

  defp new_volatility({rating, deviation, volatility}, player_variance, player_improvement, system_constant) do
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

  defp variance({rating, _deviation, _volatility}, results) do
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
