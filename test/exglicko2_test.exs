defmodule Exglicko2Test do
  use ExUnit.Case
  doctest Exglicko2

  test "example games" do
    player = {1500, 200, 0.06}
    system_constant = 0.5
    results = [
      {{1400, 30, 0}, :win},
      {{1550, 100, 0}, :lose},
      {{1700, 300, 0}, :lose}
    ]

    {rating, deviation, volatility} = Exglicko2.update_rating(player, results, system_constant)

    assert rating = 1464.06
    assert deviation = 151.52
    assert volatility = 0.05999
  end
end
