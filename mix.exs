defmodule Exglicko2.MixProject do
  use Mix.Project

  def project do
    [
      app: :exglicko2,
      description: "An implementation of the Glicko-2 rating system.",
      version: "0.2.1",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps()
    ]
  end

  defp package do
    [
      maintainers: ["Rosa Richter"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/Cantido/exglicko2"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.22.0", only: :dev, runtime: false}
    ]
  end
end
