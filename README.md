# EctoExport # [![Coverage Status](https://coveralls.io/repos/xerions/ecto_export/badge.svg?branch=master&service=github)](https://coveralls.io/github/xerions/ecto_export?branch=master)

An elixir application for exporting/importing data from an [ecto][ecto] based application.

## Usage ##

### Dependency ###

Add ecto_export es dependeny to your applications mix.exs file:

```
  {:ecto_export, github: "xerions/ecto_export"}
```

### Export/Import data ###

Start an Export job by calling Ecto.Export.export, filename must currently be provided.
```
1> Ecto.Export.export(Repo, [MyModel1, MyModel2], %{"filename" => "export.json"})
{:ok, 1}
```
When exporting, dependencies between exported Models are handled by ecto_export.
The depending Model will only be contained in the output after the "parent" model.

Start an Import job by calling Ecto.Export.export, filename must currently be provided.
```
2> Ecto.Export.export(Repo, [MyModule1, MyModule2], %{"filename" => "export.json", "import" => true})
{:ok, 2}
```

Check for the status of a running job:
```
3> Ecto.Export.check_job([id: 1])
{:ok, {:read_file, 7}}
4> :timer.sleep(5000)
:ok
5> Ecto.Export.check_job([id: 1])
{:ok, :job_finished}
```
The jobs progress is the stage (:read_file/:write_file) and the number of objects/lines already processed (7).
When the job has finished {:ok, :job_finished} is returned.

For further information, use the documentation which is provided in the sourcecode and available through elixir introspection.

### Customized formatter ###

Which formatter to use for Export/Import is specified with the "formatter" option.
Default is Ecto.Export.Formatter.JSON.

To provide a customized formatter, a module must be implemented containing the following two functions:

* export(filehandle, object_stream)
* import(repo, string_stream)

The arguments object_stream and string_stream provide the objects/strings to be exported/imported.
A customized formatter should consume the streams while outputting strings through the filehandle or objects through the Ecto.Repo.
By consuming the streams the jobs progress will be updated.

[ecto]: https://github.com/elixir-lang/ecto
