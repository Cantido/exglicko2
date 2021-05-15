defmodule Exglicko2Test do
  use ExUnit.Case
  doctest Exglicko2

  test "example game from the original paper" do
    player = Exglicko2.Player.from_glicko({1500, 200, 0.06})
    results = [
      {{1400, 30, 0}, 1},
      {{1550, 100, 0}, 0},
      {{1700, 300, 0}, 0}
    ]
    |> Enum.map(fn {opp, score} ->
      {Exglicko2.Player.from_glicko(opp), score}
    end)


    {rating, deviation, volatility} = Exglicko2.Player.update_rating(player, results) |> Exglicko2.Player.to_glicko()

    assert_in_delta 1464.06, rating, 0.01
    assert_in_delta 151.52, deviation, 0.01
    assert_in_delta 0.05999, volatility, 0.0001
  end
end
