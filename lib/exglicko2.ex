defmodule Exglicko2 do
  @moduledoc """
  Tools for working with Glicko-2 ratings.

  Players are represented by a `Exglicko2.Player` struct.
  You can get a new, default struct with the `new/0` function.

      iex> Exglicko2.Player.new()
      %Exglicko2.Player{rating: 0.0, deviation: 2.0, volatility: 0.06}

  Once your players have ratings, the games can begin!
  Game results are represented by a number ranging from zero to one,
  with a one representing a win, and a zero representing a loss.

  Ratings are updated with a list of game results passed to the `update_rating/3` function.
  Game results are batched into a list of tuples, with the first element being the opponent's rating tuple,
  and the second being the resulting score.
  This function also accepts an optional system constant, which governs how much ratings are allowed to change.
  This value must be between 0.4 and 1.2, and is 0.5 by default.

      iex> player = Exglicko2.Player.new(0.0, 1.2, 0.06)
      iex> results = [
      ...>   {Exglicko2.Player.new(-0.6, 0.2, 0), 1},
      ...>   {Exglicko2.Player.new(0.3, 0.6, 0), 0},
      ...>   {Exglicko2.Player.new(1.2, 1.7, 0), 0}
      ...> ]
      iex> Exglicko2.Player.update_rating(player, results, tau: 0.5)
      %Exglicko2.Player{rating: -0.21522518921916625, deviation: 0.8943062104659615, volatility: 0.059995829968027437}

  Here is some guidance on the optimal number of games to pass into the `update_rating/3` function,
  directly from the original paper:

  > The Glicko-2 system works best when the number of games in a rating period is moderate to large,
  > say an average of at least 10-15 games per player in a rating period.
  > The length of time for a rating period is at the discretion of the administrator.

  If you use the older Glicko rating system,
  use the `Exglicko2.Conversion` module to convert between the old and new systems.

      iex> Exglicko2.Conversion.glicko_to_glicko2({1500.0, 350, 0.06})
      %Exglicko2.Player{rating: 0.0, deviation: 2.014761872416068, volatility: 0.06}
  """
end
