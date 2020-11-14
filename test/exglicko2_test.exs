defmodule Exglicko2Test do
  use ExUnit.Case
  doctest Exglicko2

  test "example games" do
    player = {1500, 200, 0.06}
    system_constant = 0.5
    results = [
      {{1400, 30, 0}, 1},
      {{1550, 100, 0}, 0},
      {{1700, 300, 0}, 0}
    ]

    {rating, deviation, volatility} = Exglicko2.update_rating(player, results, system_constant)

    assert_in_delta 1464.06, rating, 0.01
    assert_in_delta 151.52, deviation, 0.01
    assert_in_delta 0.05999, volatility, 0.0001
  end
end
