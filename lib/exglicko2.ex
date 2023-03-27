defmodule Exglicko2 do
  @moduledoc """
  Tools for working with Glicko-2 ratings.

  Players are represented by a `Exglicko2.Rating` struct.
  You can get a new, default struct with the `new_player/0` function.

      iex> Exglicko2.new_player()
      %Exglicko2.Rating{value: 0.0, deviation: 2.014761872416068, volatility: 0.06}

      iex> Exglicko2.new_player() |> Exglicko2.Rating.to_glicko
      {1500.0, 350.0, 0.06}

  Once your players have ratings, the games can begin!
  Game results are represented by a number ranging from zero to one,
  with a one representing a win, and a zero representing a loss.

  Ratings are updated with a list of game results passed to the `update_rating/3` function.
  Game results are batched into a list of tuples, with the first element being the opponent's rating tuple,
  and the second being the resulting score.
  This function also accepts an optional system constant, which governs how much ratings are allowed to change.
  This value must be between 0.4 and 1.2, and is 0.5 by default.

      iex> player = Exglicko2.Rating.new(0.0, 1.2, 0.06)
      iex> results = [
      ...>   {Exglicko2.new_player(-0.6, 0.2, 0), 1},
      ...>   {Exglicko2.new_player(0.3, 0.6, 0), 0},
      ...>   {Exglicko2.new_player(1.2, 1.7, 0), 0}
      ...> ]
      iex> Exglicko2.update_player(player, results, tau: 0.5)
      %Exglicko2.Rating{value: -0.21522518921916625, deviation: 0.8943062104659615, volatility: 0.059995829968027437}

  Here is some guidance on the optimal number of games to pass into the `update_rating/3` function,
  directly from the original paper:

  > The Glicko-2 system works best when the number of games in a rating period is moderate to large,
  > say an average of at least 10-15 games per player in a rating period.
  > The length of time for a rating period is at the discretion of the administrator.

  If you use the older Glicko rating system,
  you can convert a player back-and-forth using the `Exglicko2.Rating.from_glicko/1` and `Exglicko2.Rating.to_glicko/1` functions.

      iex> Exglicko2.Rating.from_glicko({1500.0, 350, 0.06})
      %Exglicko2.Rating{value: 0.0, deviation: 2.014761872416068, volatility: 0.06}

  If a player has not played during the period, his deviation can be updated. This will indicate, that since he
  did not play, his score has become less reliable. This operation will increase the deviation without change the
  score value.

      iex(1)> player = Exglicko2.new_player()
      %Exglicko2.Rating{value: 0.0, deviation: 2.014761872416068, volatility: 0.06}
      iex(2)> player |> Exglicko2.update_player([])
      %Exglicko2.Rating{value: 0.0, deviation: 2.015655080250959, volatility: 0.06}
  """

  alias Exglicko2.Rating

  @doc """
  Create a new player with a default rating.
  """
  def new_player do
    Rating.new()
  end

  @doc """
  Create a new player with the given rating.
  """
  def new_player(rating, deviation, volatility) do
    Rating.new(rating, deviation, volatility)
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

      iex> player = Exglicko2.Rating.new(0.0, 1.2, 0.06)
      iex> results = [
      ...>   {Exglicko2.Rating.new(-0.6, 0.2, 0.06), 1},
      ...>   {Exglicko2.Rating.new(0.3, 0.6, 0.06), 0},
      ...>   {Exglicko2.Rating.new(1.2, 1.7, 0.06), 0}
      ...> ]
      iex> Exglicko2.update_player(player, results, tau: 0.5)
      %Exglicko2.Rating{value: -0.21522518921916625, deviation: 0.8943062104659615, volatility: 0.059995829968027437}
  """
  def update_player(%Rating{} = player, results, opts \\ []) do
    system_constant = Keyword.get(opts, :tau, 0.5)

    if not is_number(system_constant) or system_constant < 0.4 or system_constant > 1.2 do
      raise "System constant must be a number between 0.4 and 1.2, but it was #{inspect(system_constant)}"
    end

    Rating.update_rating(player, results, system_constant)
  end

  @doc """
  Updates a whole team of players with `update_rating/3`.

  Instead of individual player structs, pass in lists of players, like this:

      iex> team_one = [
      ...>   Exglicko2.new_player(-0.6, 0.2, 0.06),
      ...>   Exglicko2.new_player(0.3, 0.6, 0.06),
      ...>   Exglicko2.new_player(1.2, 1.7, 0.06)
      ...> ]
      ...> team_two = [
      ...>   Exglicko2.new_player(-0.6, 0.2, 0.06),
      ...>   Exglicko2.new_player(0.3, 0.6, 0.06),
      ...>   Exglicko2.new_player(1.2, 1.7, 0.06)
      ...> ]
      ...> results = [
      ...>   {team_two, 1}
      ...> ]
      ...> Exglicko2.update_team(team_one, results)
      [
        %Exglicko2.Rating{
          value: -0.5727225148150104,
          deviation: 0.20801152963424144,
          volatility: 0.05999777767142373
        },
        %Exglicko2.Rating{
          value: 0.45366492480429327,
          deviation: 0.581562104768686,
          volatility: 0.059997452826507966
        },
        %Exglicko2.Rating{
          value: 1.7340823171025699,
          deviation: 1.3854013493398154,
          volatility: 0.05999869242065375
        }
      ]
  """
  def update_team(team, results, opts \\ []) when is_list(team) do
    results =
      Enum.map(results, fn {opponents, result} ->
        {Rating.composite(opponents), result}
      end)

    Enum.map(team, fn player ->
      update_player(player, results, opts)
    end)
  end
end
