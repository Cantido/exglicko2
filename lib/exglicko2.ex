defmodule Exglicko2 do
  @moduledoc """
  Tools for working with Glicko-2 ratings.

  Ratings are represented by a tuple of the rating, the rating deviation, and the rating volatility.
  You can get a new, default tuple with the `new/0` function.

      iex> Exglicko2.new()
      {0.0, 2.0, 0.06}

  Once your players have ratings, the games can begin!
  Game results are represented by a number ranging from zero to one,
  with a one representing a win, and a zero representing a loss.

  Ratings are updated with a list of game results passed to the `update_rating/3` function.
  Game results are batched into a list of tuples, with the first element being the opponent's rating tuple,
  and the second being the resulting score.
  This function also requires a system constant, which governs how much ratings are allowed to change.
  This value must be between 0.4 and 1.2

      iex> player = {0.0, 1.2, 0.06}
      iex> system_constant = 0.5
      iex> results = [
      ...>   {{-0.6, 0.2, 0}, 1},
      ...>   {{0.3, 0.6, 0}, 0},
      ...>   {{1.2, 1.7, 0}, 0}
      ...> ]
      iex> Exglicko2.update_rating(player, results, system_constant)
      {-0.21522518921916625, 0.8943062104659615, 0.059995829968027437}

  Here is some guidance on the optimal number of games to pass into the `update_rating/3` function,
  directly from the original paper:

  > The Glicko-2 system works best when the number of games in a rating period is moderate to large,
  > say an average of at least 10-15 games per player in a rating period.
  > The length of time for a rating period is at the discretion of the administrator.

  Some convenience functions are also present in this module.
  The functions `rating/1`, `deviation/1`, and `volatility/1` access the corresponding value of a rating tuple,
  so you don't have to keep accessing a "magic tuple position" in your code.

  If you use the older Glicko rating system,
  use the `Exglicko2.Conversion` module to convert between the old and new systems.

      iex> Exglicko2.Conversion.glicko_to_glicko2({1500.0, 350, 0.06})
      {0.0, 2.014761872416068, 0.06}
  """

  @e 2.71828182845904523536028747135266249775724709369995
  @convergence_tolerance 0.000001

  @doc """
  Returns a new `{rating, deviation, volatility}` tuple, suited to new players.
  """
  def new do
    {0.0, 2.0, 0.06}
  end

  @doc """
  Returns the rating value of a rating tuple.

  ## Examples

      iex> Exglicko2.rating({0.0, 2.0, 0.06})
      0.0
  """
  def rating({r, _d, _v}), do: r

  @doc """
  Returns the deviation value of a rating tuple.

  ## Examples

      iex> Exglicko2.deviation({0.0, 2.0, 0.06})
      2.0
  """
  def deviation({_r, d, _v}), do: d

  @doc """
  Returns the volatility value of a rating tuple.

  ## Examples

      iex> Exglicko2.volatility({0.0, 2.0, 0.06})
      0.06
  """
  def volatility({_r, _d, v}), do: v

  @doc """
  Update a player's rating based on game results.

  Each player is represented by a tuple of the player's rating, their rating deviation, and their rating volatility.
  Game results are batched into a list of tuples, with the first element being the opponent's values,
  and the second being the resulting score between zero and one.

  Also requires a system constant, which governs how much ratings are allowed to change.
  This value must be between 0.4 and 1.2

  ## Example

  A player with a rating of 0.0, a deviation of 1.2, and a volatility of 0.06 plays three games.
  - Against the first opponent, they win. Thus the score is 1.
  - Against the second opponent, they lose. Thus the score is 0.
  - Against the third opponent, they lose again. Thus the score is 0.

  The result is that the player's score drops to -0.2, their deviation drops to 0.9, and their volatility drops slightly.

      iex> player = {0.0, 1.2, 0.06}
      iex> system_constant = 0.5
      iex> results = [
      ...>   {{-0.6, 0.2, 0}, 1},
      ...>   {{0.3, 0.6, 0}, 0},
      ...>   {{1.2, 1.7, 0}, 0}
      ...> ]
      iex> Exglicko2.update_rating(player, results, system_constant)
      {-0.21522518921916625, 0.8943062104659615, 0.059995829968027437}
  """
  def update_rating({_r, deviation, _v} = player, results, system_constant) do
    player_variance = variance(player, results)
    player_improvement = improvement(player, results)

    new_volatility = new_volatility(player, player_variance, player_improvement, system_constant)
    new_pre_rating_deviation = :math.sqrt(square(deviation) + square(new_volatility))

    new_deviation = 1 / :math.sqrt((1/square(new_pre_rating_deviation)) + (1 / player_variance))

    new_rating = new_rating(player, results, new_deviation)

    {new_rating, new_deviation, new_volatility}
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
