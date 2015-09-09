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

  setup_all do
    {:ok, [:ecto_it]} = Application.ensure_all_started(:ecto_it)
    on_exit fn -> :application.stop(:ecto_it) end
  end

  test "export import" do
    insert_data

    assert {:ok, export_id} = Ecto.Export.create(Repo, @models, %{"export_uri" => "file://export.json"})

    assert :ok = wait_for_job(export_id)

    delete_all

    assert {:error, :not_found} == Ecto.Export.check(100)

    assert {:ok, import_id} = Ecto.Export.create(Repo, @models, %{"export_uri" => "file://export.json", "import" => true})

    assert :ok = wait_for_job(import_id)

    assert [%Species{name: "Dog", id: species_id}] = Repo.all(from s in Species, select: s)
    assert [%Animal{name: "Bello", species_id: ^species_id}] = Repo.all(from a in Animal, join: s in assoc(a, :species), select: a)

    delete_all
  end

  test "delete" do
    insert_data 

    assert {:ok, id} = Ecto.Export.create(Repo, @models, %{"export_uri" => "file://export.json"})
    assert :ok = Ecto.Export.stop(id)
    assert {:ok, :job_finished} == Ecto.Export.check(id)

    assert {:ok, id} = Ecto.Export.create(Repo, @models, %{"export_uri" => "file://export.json"})
    :timer.sleep(10)
    assert :ok = Ecto.Export.stop(id)
    assert {:ok, :job_finished} == Ecto.Export.check(id)

    delete_all
  end

  test "open file failed" do
    insert_data 

    filename = "./abc/export.json"

    # it will raise exception
    assert {:ok, id} = Ecto.Export.create(Repo, @models, %{"export_uri" => "file://" <> filename})
    assert :ok = wait_for_job(id)
    assert false == File.exists?(filename)
    assert :ok = Ecto.Export.stop(id)
    assert {:ok, :job_finished} == Ecto.Export.check(id)

    delete_all
  end

  defp insert_data() do
    for m <- @models, do: Ecto.Migration.Auto.migrate(Repo, m)

    assert %{id: species_id} = Repo.insert!(%Species{name: "Dog"})
    assert %{} = Repo.insert!(%Animal{name: "Bello", species_id: species_id})
  end

  defp delete_all(), do: assert [{1, nil} | _] = for model <- Enum.reverse(@models), do: Repo.delete_all(from a in model)

  defp wait_for_job(id) do
    case Ecto.Export.check(id) do
      {:ok, :job_finished} -> :ok
      {:ok, _} -> wait_for_job(id)
      e -> {:error, e}
    end
  end
end
