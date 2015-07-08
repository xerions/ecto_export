defmodule EctoExport.Mixfile do
  use Mix.Project

  def project do
    [app: :ecto_export,
     version: "0.0.1",
     elixir: "~> 1.1-dev",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :jsx],
     mod: {Ecto.Export, []}]
  end

  defp deps do
    [{:ecto, "~> 0.12.0-rc"},
     {:jsx, github: "talentdeficit/jsx", branch: "develop"}
    ]
  end
end
