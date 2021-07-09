defmodule Glooper.Engine do
  use Supervisor

  @name __MODULE__

  def start_link(init_args \\ [], opts \\ []) when is_list(init_args) and is_list(opts) do
    opts = Keyword.put_new(opts, :name, @name)
    Supervisor.start_link(__MODULE__, init_args, opts)
  end

  def init(args) do
    children = [
      {Registry, keys: :unique, name: Glooper.AgentRegistry},
      {Glooper.AgentSupervisor, args}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
