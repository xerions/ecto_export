defmodule EctoExport.Mixfile do
  use Mix.Project

  def project do
    [app: :ecto_export,
     version: "0.0.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     test_coverage: [tool: Coverex.Task, coveralls: true]]
  end

  def application do
    [applications: [:logger, :jsx],
     mod: {Ecto.Export, []}]
  end

  defp deps do
    [{:postgrex, ">= 0.0.0", optional: true},
     {:mariaex, ">= 0.0.0", optional: true},
     {:ecto, ">= 0.16.0"},
     {:ecto_it, "~> 0.2.0", optional: true},
     {:ecto_migrate, "~> 0.6.1"},
     {:exrun, github: "liveforeverx/exrun"},
     {:jsx, "~> 2.6.2", [hex: :jsx]},

     {:coverex, "~> 1.4.1", only: :test}
    ]
  end
end
