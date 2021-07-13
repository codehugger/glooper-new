defmodule Glooper.Simulation do
  @moduledoc """
  The heart of Glooper is the simulation module.

  A simulation contains all agents and provides a mechanism for loading from
  config or adding them directly to the simulation.

  The simulation becomes a sandbox process environment through the means of
  process name prefixing. This means that all agents added to a simulation are
  started and linked to the simulation but prefixed with the name of the
  simulation.

  This prefixing is transparent to all the agents within the simulation as long
  as they communicate through the simulation module so the sandbox prefixing
  should not bleed into the labelling and reasoning about the agents involved.

  When a simulation has been set up it calls the contained agents in a grouped
  random burst fashion. The defined order of execution determines the groups of
  agents and the order in which they are run one by one. Then within each
  execution group the agents are run async in random order and then awaited
  according to a configured timeout. If time runs out before all agents have
  responded, they are halted and an error is returned.
  """
  use Agent

  alias Glooper.{Utils}

  alias Glooper.{
    Bank,
    BankInvestor,
    Borrower,
    Government,
    Factory,
    Market,
    Population,
    Recipe
  }

  @agent_registry Glooper.AgentRegistry

  defmodule State do
    @moduledoc false
    @enforce_keys [:sim_no]
    @optional_keys [
      title: "",
      description: "",
      eval: [],
      init: [],
      timestamp: 0,
      recipes: %{},
      agent_groups: %{},
      initialized: false
    ]
    defstruct @enforce_keys ++ @optional_keys
  end

  #############################################################################
  #### Initialization
  #############################################################################

  def start_link(fields \\ [], opts \\ []) when is_list(fields) and is_list(opts) do
    # Generate a unique identifier for this simulation to be used as prefix for
    # sandboxing all contained agents
    sim_no = Utils.gen_sim_no()

    opts =
      opts
      |> Keyword.put_new(:name, sim_no)
      # Change the name to a :via tuple to allow strings to be used as identifiers
      |> Keyword.put(:name, Glooper.via_tuple(sim_no, __MODULE__))

    fields =
      fields
      # It makes no sense to have a sim_no that differs from the assigned process name
      # so let's make absolutely sure it stays that way
      |> Keyword.put(:sim_no, sim_no)

    # Start the simulation as a linked process
    {:ok, pid} = Agent.start_link(fn -> struct!(State, fields) end, opts)

    # Return information about the started simulation agent
    {:ok, pid, sim_no}
  end

  @doc """
  Start a new simulation from a configuration.
  """
  def start_from_config(config) when is_map(config) do
    # Start the linked process as usual
    {:ok, pid, sim_no} = start_link()
    # Start the simulation agents from config
    load_config(pid, config)
    # For consistency we return the same tuple as start_link
    {:ok, pid, sim_no}
  end

  #############################################################################
  #### Lookup
  #############################################################################

  @doc """
  Returns the matching pid for the Simulation from `@agent_registry`.
  """
  def get_simulation(sim) when is_binary(sim) do
    Registry.lookup(@agent_registry, sim)
  end

  @doc """
  Returns the pid and module matching `agent_no` in the context of `sim` in
  the form of a `{:ok, {pid, module}}` tuple.
  """
  def get_agent(sim, agent_no) when is_pid(sim) and is_binary(agent_no) do
    Agent.get(sim, fn state -> get_agent(state.sim_no, agent_no) end)
  end

  def get_agent(sim, agent_no) when is_binary(sim) and is_binary(agent_no) do
    Registry.lookup(@agent_registry, "#{sim}_#{agent_no}")
  end

  @doc """
  Returns the pid of the agent matching `agent_no` in the context of `sim`.
  """
  def get_agent_pid(sim, agent_no) do
    case get_agent(sim, agent_no) do
      [{pid, _module}] -> pid
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Returns the agents matching `group`.
  """
  def get_agent_group(sim, name) when is_binary(sim) and is_binary(sim) do
    case Registry.lookup(@agent_registry, sim) do
      [{pid, _module}] -> get_agent_group(pid, name)
      _ -> {:error, :not_found}
    end
  end

  def get_agent_group(sim, name) when is_pid(sim) and is_binary(name) do
    Agent.get(sim, fn state ->
      Map.get(state.agent_groups, name)
    end)
  end

  #############################################################################
  #### Evaluation
  #############################################################################

  @doc """
  Initialize all agents in the simulation before evaluating.
  """
  def init(sim) when is_binary(sim) or is_pid(sim) do
    run(sim, :init)
  end

  @doc """
  Evaluate all execution `groups` within the simulation.
  """
  def eval(sim) when is_binary(sim) or is_pid(sim) do
    run(sim, :eval)
  end

  defp run(sim, action) when is_binary(sim) do
    [{pid, _module}] = get_simulation(sim)
    run(pid, action)
  end

  defp run(sim, action) when is_pid(sim) and action in [:init, :eval] do
    state = Agent.get(sim, & &1)

    # Force init action when simulation is not initialized and evaluate is run
    # similarly force evaluation if simulation is already initialized
    action =
      case state.initialized do
        true -> :eval
        false -> :init
      end

    agent_groups =
      case state.initialized do
        true -> state.eval
        false -> state.init
      end

    IO.puts("")

    case action do
      :init -> IO.puts("#{String.pad_trailing("=== Initialization =", 80, "=")}")
      :eval -> IO.puts("#{String.pad_trailing("=== Cycle #{state.timestamp} =", 80, "=")}")
    end

    Enum.reduce_while(agent_groups, :ok, fn group, :ok ->
      IO.puts("\n#{String.pad_trailing("--- #{String.capitalize(group)} -", 80, "-")}\n")

      # case action do
      #   :init -> IO.puts("\n==> Initializing #{group}")
      #   :eval -> IO.puts("\n==> Evaluating #{group} ...")
      # end

      # Get the execution module and agent ids for the group
      agents =
        get_agent_group(sim, group)
        |> Enum.map(fn agent -> get_agent(sim, agent) end)
        |> Enum.shuffle()

      # Generate tasks for agent evaluations
      tasks =
        Enum.map(agents, fn [{pid, module}] ->
          Task.async(fn -> apply(module, action, [pid, sim]) end)
        end)

      # Yield the results for each tasks
      tasks_with_results = Task.yield_many(tasks)

      # Collect the results and kill any agents that are hanging
      results =
        Enum.map(tasks_with_results, fn {task, res} ->
          # Shut down the tasks that did not reply nor exit
          case res || Task.shutdown(task, :brutal_kill) do
            nil -> {:error, :timeout}
            {:exit, reason} -> {:error, reason}
            {:ok, _value} = resp -> resp
          end
        end)

      # See if there were any errors among the results and halt if there were
      case Enum.count(results, fn {result, _reason} -> result == :error end) do
        0 -> {:cont, :ok}
        _ -> {:halt, results}
      end
    end)

    # Update the cycle counter for the next round
    Agent.update(sim, fn state -> %{state | timestamp: state.timestamp + 1, initialized: true} end)

    # case action do
    #   :init -> IO.puts("\n==> Initialization completed!")
    #   :eval -> IO.puts("\n==> Evaluation of cycle #{state.timestamp} completed!")
    # end

    IO.puts("\n================================================================================")
  end

  #############################################################################
  #### Internal clock
  #############################################################################

  @doc """
  Returns the current timestamp of the simulation.
  """
  def current_timestamp(sim) when is_binary(sim) do
    case get_simulation(sim) do
      [{pid, _module}] -> current_timestamp(pid)
      _ -> 0
    end
  end

  def current_timestamp(sim) when is_pid(sim) do
    Agent.get(sim, fn state -> state.timestamp end)
  end

  #############################################################################
  #### Config
  #############################################################################

  @doc """
  Loads a Glooper world into the simulation according to the specified content
  of the given config. Refer to the `Glooper.Config` module for details on the
  elements supported in a config.
  """
  def load_config(sim, config) when is_map(config) do
    Agent.get_and_update(sim, fn state ->
      state =
        state
        |> load_title(config)
        |> load_description(config)
        |> load_init(config)
        |> load_eval(config)
        |> load_recipes(config)
        |> load_agents(config)

      {state, state}
    end)
  end

  defp load_title(state, %{"title" => title}), do: %{state | title: title}
  defp load_title(state, _config), do: %{state | title: "No title"}

  defp load_description(state, %{"description" => desc}), do: %{state | description: desc}
  defp load_description(state, _config), do: %{state | description: "No description"}

  defp load_init(state, %{"init" => eval}), do: %{state | init: eval}
  defp load_init(state, _config), do: %{state | init: []}

  defp load_eval(state, %{"eval" => eval}), do: %{state | eval: eval}
  defp load_eval(state, _config), do: %{state | eval: []}

  defp load_recipes(state, %{"recipes" => recipes}) do
    %{
      state
      | recipes:
          Enum.map(recipes, fn {name, recipe} ->
            {name, Recipe.from_config(name, recipe)}
          end)
          |> Map.new()
    }
  end

  defp load_recipes(state, _config), do: %{state | recipes: %{}}

  defp load_agents(state, %{"agents" => agent_groups}) do
    groups =
      Enum.map(state.eval, fn eval_group ->
        # We use the evaluation group to load the agents to make sure we are
        # loading only and all agents belonging to the defined groups
        agents =
          Map.fetch!(agent_groups, eval_group)
          |> Enum.map(fn {agent_no, %{"module" => module} = config} ->
            result =
              case module do
                "bank" -> Bank.start_from_config(state.sim_no, agent_no, config)
                "bank_investor" -> BankInvestor.start_from_config(state.sim_no, agent_no, config)
                "borrower" -> Borrower.start_from_config(state.sim_no, agent_no, config)
                "factory" -> Factory.start_from_config(state.sim_no, agent_no, config)
                "government" -> Government.start_from_config(state.sim_no, agent_no, config)
                "market" -> Market.start_from_config(state.sim_no, agent_no, config)
                "population" -> Population.start_from_config(state.sim_no, agent_no, config)
                _ -> nil
              end

            case result do
              {:ok, _pid, _name} -> agent_no
              nil -> nil
            end
          end)
          |> Enum.filter(fn x -> x != nil end)

        {eval_group, agents}
      end)

    %{state | agent_groups: Map.new(groups)}
  end

  defp load_agents(state, _config), do: %{state | agent_groups: %{}}
end
