defmodule EctoExportTest.Animal do
  use Ecto.Model
  schema "animal" do
    field :name
    belongs_to :species, EctoExportTest.Species
  end
end

defmodule EctoExportTest.Species do
  use Ecto.Model
  schema "species" do
    field :name
    has_many :animals, EctoExportTest.Animal
  end
end

defmodule EctoExportTest do
  use ExUnit.Case
  import Ecto.Query
  alias EctoIt.Repo
  alias EctoExportTest.Animal
  alias EctoExportTest.Species
  @models [Species, Animal]

  setup do
    {:ok, [:ecto_it]} = Application.ensure_all_started(:ecto_it)
    on_exit fn -> :application.stop(:ecto_it) end
  end

  test "export import" do

    for m <- @models, do: Ecto.Migration.Auto.migrate(Repo, m)

    assert %{id: species_id} = Repo.insert!(%Species{name: "Dog"})
    assert %{} = Repo.insert!(%Animal{name: "Bello", species_id: species_id})

    assert {:ok, export_id} = Ecto.Export.export(Repo, @models, %{"filename" => "export.json"})

    assert :ok = wait_for_job(export_id)

    assert [{1, nil} | _] = for model <- Enum.reverse(@models), do: Repo.delete_all(from a in model)

    assert {:ok, import_id} = Ecto.Export.export(Repo, @models, %{"filename" => "export.json", "import" => true})

    assert :ok = wait_for_job(import_id)

    assert [%Species{name: "Dog"}] = Repo.all(from s in Species, select: s)
    assert [%Animal{name: "Bello", species_id: species_id}] = Repo.all(from a in Animal, join: s in assoc(a, :species), select: a)
  end

  defp wait_for_job(id) do
    case Ecto.Export.check_job %{"id" => id} do
      {:ok, :job_finished} -> :ok
      {:ok, _} -> wait_for_job(id)
      e -> {:error, e}
    end
  end
end
