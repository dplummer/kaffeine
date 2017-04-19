defmodule Kaffeine.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Registry, [:unique, Registry.Consumers], [id: Registry.Consumers]),
    ]

    opts = [strategy: :one_for_one, name: Kaffeine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
