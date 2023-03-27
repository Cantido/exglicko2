defmodule Exglicko2Test do
  use ExUnit.Case
  doctest Exglicko2

  test "example game from the original paper" do
    player = Exglicko2.Rating.from_glicko({1500, 200, 0.06})

    results =
      [
        {{1400, 30, 0}, 1},
        {{1550, 100, 0}, 0},
        {{1700, 300, 0}, 0}
      ]
      |> Enum.map(fn {opp, score} ->
        {Exglicko2.Rating.from_glicko(opp), score}
      end)

    {rating, deviation, volatility} =
      Exglicko2.update_player(player, results) |> Exglicko2.Rating.to_glicko()

    assert_in_delta 1464.06, rating, 0.01
    assert_in_delta 151.52, deviation, 0.01
    assert_in_delta 0.05999, volatility, 0.0001
  end

  test "updating two teams from a single match" do
    team_one = [
      Exglicko2.new_player(0.6, 0.2, 0.06),
      Exglicko2.new_player(-0.3, 0.6, 0.06),
      Exglicko2.new_player(-1.2, 1.7, 0.06)
    ]

    team_two = [
      Exglicko2.new_player(-0.6, 0.2, 0.06),
      Exglicko2.new_player(0.3, 0.6, 0.06),
      Exglicko2.new_player(1.2, 1.7, 0.06)
    ]

    team_one_results = [
      {team_two, 1}
    ]

    team_two_results = [
      {team_one, 0}
    ]

    updated_team_one = Exglicko2.update_team(team_one, team_one_results)
    updated_team_two = Exglicko2.update_team(team_two, team_two_results)

    assert updated_team_one == [
             %Exglicko2.Rating{
               value: 0.616975738293235,
               deviation: 0.20788908025514855,
               volatility: 0.05999748464208987
             },
             %Exglicko2.Rating{
               value: -0.10448679338664246,
               deviation: 0.5830044120491541,
               volatility: 0.059997601601461156
             },
             %Exglicko2.Rating{
               value: 0.30879262132575813,
               deviation: 1.444054347059935,
               volatility: 0.05999888823648048
             }
           ]

    assert updated_team_two == [
             %Exglicko2.Rating{
               value: -0.616975738293235,
               deviation: 0.20788908025514855,
               volatility: 0.05999748464208987
             },
             %Exglicko2.Rating{
               value: 0.10448679338664249,
               deviation: 0.5830044120491541,
               volatility: 0.059997601601461156
             },
             %Exglicko2.Rating{
               value: -0.30879262132575813,
               deviation: 1.444054347059935,
               volatility: 0.05999888823648048
             }
           ]
  end
end
