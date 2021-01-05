# Exglicko2

An implementation of the [Glicko-2 rating system](https://en.wikipedia.org/wiki/Glicko_rating_system).

The Glicko-2 rating system is a way of measuring the skill of players in competitive games.
It is widely-used, and sees action in traditional games like chess and Go,
as well as in modern video games.

The Glicko-2 system is an improvement upon older methods like the Elo rating system and the Glicko rating system.
It uses three values--a *rating*, a *rating deviation*, and a *volatility*--to gain a statistical understanding of a player's "true" rating.
For example, if a player's rating is 0.1, and their rating deviation is 0.02,
then the player has a "true" strength somewhere between 0.08 and 0.12, with a 95% confidence.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `exglicko2` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exglicko2, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/exglicko2](https://hexdocs.pm/exglicko2).

## Usage

Players are represented by a tuple containing the player's rating, their rating deviation, and their volatility.
You can obtain a default tuple for new players with `Exglicko.new()`

```elixir
Exglicko2.new()
{0.0, 2.0, 0.06}
```

Ratings are updated with a list of game results passed to the `Exglicko2.update_rating/3` function.
Game results are batched into a list of tuples, with the first element being the opponent's rating tuple,
and the second being the resulting score.
This function also requires a system constant, which governs how much ratings are allowed to change.
This value must be between 0.4 and 1.2

```elixir
iex> player = {0.0, 1.2, 0.06}
iex> system_constant = 0.5
iex> results = [
...>   {{-0.6, 0.2, 0}, 1},
...>   {{0.3, 0.6, 0}, 0},
...>   {{1.2, 1.7, 0}, 0}
...> ]
iex> Exglicko2.update_rating(player, results, system_constant)
{-0.21522518921916625, 0.8943062104659615, 0.059995829968027437}
```

See [the docs](https://hexdocs.pm/exglicko2) for more information.

## License

The Glicko-2 algorithm itself is in the public domain.

This software is under the MIT License

Copyright 2020 Rosa Richter

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
