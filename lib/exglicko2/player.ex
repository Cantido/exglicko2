defmodule Exglicko2.Player do
  @moduledoc """
  A single entity that can take part in a game.
  Players have a `:rating`, `:deviation`, and `:volatility`.
  """

  @e 2.71828182845904523536028747135266249775724709369995
  @convergence_tolerance 0.000001

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

  @doc """
  Returns a new `Exglicko2.Player` suited to new players.
  """
  def new do
    %__MODULE__{
      rating: 0.0,
      deviation: 2.0,
      volatility: 0.06
    }
  end

  @doc """
  Returns a new `Exglicko2.Player` with the given values.
  """
  def new(rating, deviation, volatility) do
    %__MODULE__{
      rating: rating,
      deviation: deviation,
      volatility: volatility
    }
  end

  @doc """
  Update a player's rating based on game results.

  Each player is represented by a tuple of the player's rating, their rating deviation, and their rating volatility.
  Game results are batched into a list of tuples, with the first element being the opponent's values,
  and the second being the resulting score between zero and one.

  You can also specify a system constant, called `:tau`, which governs how much ratings are allowed to change.
  This value must be between 0.4 and 1.2, and the default is 0.5.

  ## Example

  A player with a rating of 0.0, a deviation of 1.2, and a volatility of 0.06 plays three games.
  - Against the first opponent, they win. Thus the score is 1.
  - Against the second opponent, they lose. Thus the score is 0.
  - Against the third opponent, they lose again. Thus the score is 0.

  The result is that the player's score drops to -0.2, their deviation drops to 0.9, and their volatility drops slightly.

      iex> player = Exglicko2.Player.new(0.0, 1.2, 0.06)
      iex> results = [
      ...>   {Exglicko2.Player.new(-0.6, 0.2, 0), 1},
      ...>   {Exglicko2.Player.new(0.3, 0.6, 0), 0},
      ...>   {Exglicko2.Player.new(1.2, 1.7, 0), 0}
      ...> ]
      iex> Exglicko2.Player.update_rating(player, results, tau: 0.5)
      %Exglicko2.Player{rating: -0.21522518921916625, deviation: 0.8943062104659615, volatility: 0.059995829968027437}
  """
  def update_rating(%__MODULE__{deviation: deviation} = player, results, opts \\ []) do
    system_constant = Keyword.get(opts, :tau, 0.5)

    player_variance = variance(player, results)
    player_improvement = improvement(player, results)

    new_volatility = new_volatility(player, player_variance, player_improvement, system_constant)
    new_pre_rating_deviation = :math.sqrt(square(deviation) + square(new_volatility))

    new_deviation = 1 / :math.sqrt((1/square(new_pre_rating_deviation)) + (1 / player_variance))

    new_rating = new_rating(player, results, new_deviation)

    new(new_rating, new_deviation, new_volatility)
  end

  defp new_rating(%__MODULE__{rating: rating}, results, new_deviation) do
    sum_term =
      results
      |> Enum.map(fn {opponent, score} ->
        g(opponent.deviation) * (score - e(rating, opponent.rating, opponent.deviation))
      end)
      |> Enum.sum()

    rating + square(new_deviation) * sum_term
  end

  defp new_volatility(%__MODULE__{rating: rating, deviation: deviation, volatility: volatility}, player_variance, player_improvement, system_constant) do
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
      g(opponent.deviation) * (score - e(player.rating, opponent.rating, opponent.deviation))
    end)
    |> Enum.sum()

    sum * variance(player, results)
  end

  defp variance(%__MODULE__{rating: rating}, results) do
    sum = Enum.map(results, fn {opponent, _score} ->
      square(g(opponent.deviation)) *
        e(rating, opponent.rating, opponent.deviation) *
        (1 - e(rating, opponent.rating, opponent.deviation))
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