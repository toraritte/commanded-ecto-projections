defmodule Commanded.Projections.EctoProjectionTest do
  use ExUnit.Case

  import Commanded.Projections.ProjectionAssertions

  alias Commanded.Projections.Repo

  defmodule AnEvent do
    defstruct name: "AnEvent"
  end

  defmodule AnotherEvent do
    defstruct name: "AnotherEvent"
  end

  defmodule IgnoredEvent do
    defstruct name: "IgnoredEvent"
  end

  defmodule ErrorEvent do
    defstruct name: "ErrorEvent"
  end

  defmodule Projection do
    use Ecto.Schema

    schema "projections" do
      field(:name, :string)
    end
  end

  defmodule Projector do
    use Commanded.Projections.Ecto, name: "Projector"

    project %AnEvent{name: name}, _metadata, fn multi ->
      Ecto.Multi.insert(multi, :my_projection, %Projection{name: name})
    end

    project %AnotherEvent{name: name}, fn multi ->
      Ecto.Multi.insert(multi, :my_projection, %Projection{name: name})
    end

    project %ErrorEvent{}, fn multi ->
      Ecto.Multi.error(multi, :my_projection, :failure)
    end
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "should handle a projected event" do
    assert :ok == Projector.handle(%AnEvent{}, %{event_number: 1})

    assert_projections(Projection, ["AnEvent"])
    assert_seen_event("Projector", 1)
  end

  test "should handle two different types of projected events" do
    assert :ok == Projector.handle(%AnEvent{}, %{event_number: 1})
    assert :ok == Projector.handle(%AnotherEvent{}, %{event_number: 2})

    assert_projections(Projection, ["AnEvent", "AnotherEvent"])
    assert_seen_event("Projector", 2)
  end

  test "should ignore already projected event" do
    assert :ok == Projector.handle(%AnEvent{}, %{event_number: 1})
    assert :ok == Projector.handle(%AnEvent{}, %{event_number: 1})
    assert :ok == Projector.handle(%AnEvent{}, %{event_number: 1})

    assert_projections(Projection, ["AnEvent"])
    assert_seen_event("Projector", 1)
  end

  test "should ignore unprojected event" do
    assert :ok == Projector.handle(%IgnoredEvent{}, %{event_number: 1})

    assert_projections(Projection, [])
  end

  test "should ignore unprojected events amongst projections" do
    assert :ok == Projector.handle(%AnEvent{}, %{event_number: 1})
    assert :ok == Projector.handle(%IgnoredEvent{}, %{event_number: 2})
    assert :ok == Projector.handle(%AnotherEvent{}, %{event_number: 3})
    assert :ok == Projector.handle(%IgnoredEvent{}, %{event_number: 4})

    assert_projections(Projection, ["AnEvent", "AnotherEvent"])
    assert_seen_event("Projector", 3)
  end

  test "should return an error on failure" do
    assert {:error, :failure} == Projector.handle(%ErrorEvent{}, %{event_number: 1})

    assert_projections(Projection, [])
  end

  test "should ensure repo is configured" do
    repo = Application.get_env(:commanded_postgres_read_model_projector, :repo)

    try do
      Application.put_env(:commanded_postgres_read_model_projector, :repo, nil)

      assert_raise RuntimeError,
                   "Commanded Ecto projections expects :repo to be configured in environment",
                   fn ->
                     Code.eval_string("""
                     defmodule UnconfiguredProjector do
                       use Commanded.Projections.Ecto, name: "projector"
                     end
                     """)
                   end
    after
      Application.put_env(:commanded_postgres_read_model_projector, :repo, repo)
    end
  end

  test "should allow to set `:repo` as an option" do
    repo = Application.get_env(:commanded_postgres_read_model_projector, :repo)

    try do
      Application.put_env(:commanded_postgres_read_model_projector, :repo, nil)

      assert Code.eval_string("""
             defmodule ProjectorConfiguredViaOpts do
               use Commanded.Projections.Ecto,
                 name: "projector",
                 repo: Commanded.Projections.Repo
             end
             """)
    after
      Application.put_env(:commanded_postgres_read_model_projector, :repo, repo)
    end
  end

  test "should ensure projection name is present" do
    assert_raise RuntimeError, "UnnamedProjector expects :name to be given", fn ->
      Code.eval_string("""
      defmodule UnnamedProjector do
        use Commanded.Projections.Ecto
      end
      """)
    end
  end
end
