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
    [{:postgrex, ">= 0.0.0", optional: true},
     {:mariaex, ">= 0.0.0", optional: true},
     {:ecto, "~> 0.13.0"},
     {:ecto_it, "~> 0.1.0", optional: true},
     {:ecto_migrate, "~> 0.4.0"},
     {:exrun, github: "liveforeverx/exrun"},
     {:jsx, github: "talentdeficit/jsx", branch: "develop"}
    ]
  end
end
