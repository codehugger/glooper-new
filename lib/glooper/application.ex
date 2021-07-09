defmodule Glooper.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Glooper.Repo,
      # Start the Telemetry supervisor
      GlooperWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Glooper.PubSub},
      # Start the Endpoint (http/https)
      GlooperWeb.Endpoint,
      # Start a worker by calling: Glooper.Worker.start_link(arg)
      # {Glooper.Worker, arg}

      # Start a Glooper Simulations Supervisor
      Glooper.Engine
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Glooper.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GlooperWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
