defmodule Glooper.GeneralLedger do
  @moduledoc """
  A general ledger represents the record-keeping system for a company's financial
  data with debit and credit account records validated by a trial balance i.e.
  `assets = liabilities + equity`. The general ledger provides record of each financial
  transaction that take place during a simulation of a bank or company.
  """

  alias __MODULE__, as: GL
  alias Glooper.Ledger

  @enforce_keys []
  @optional_keys [ledgers: %{}]

  defstruct @enforce_keys ++ @optional_keys

  @acc_types Glooper.Finance.account_types()
  @ldg_types Glooper.Finance.ledger_types()

  @doc """
  Creates a new general ledger and initializes with the default ledgers required
  for basic banking if the ledgers field is not set.
  """
  def create() do
    struct!(GL, [])
    |> init_bank_ledgers()
  end

  @doc """
  """
  def create(fields) do
    struct!(GL, fields)
  end

  #############################################################################
  #### Ledgers
  #############################################################################

  @doc """
  Adds a ledger to the general ledger.
  """
  def add_ledger(%GL{ledgers: ledgers} = gl, name, acc_type, ldg_type, singular)
      when acc_type in @acc_types and ldg_type in @ldg_types do
    ledger = Ledger.create(name, acc_type, ldg_type, singular)
    %{gl | ledgers: Map.put_new(ledgers, name, ledger)}
  end

  @doc """
  Gets the ledger where the account is found otherwise nil.
  """
  def get_account_ledger(%GL{ledgers: ledgers}, acc_no) do
    ledgers
    |> Map.values()
    |> Enum.find(fn x -> x.accounts[acc_no] != nil end)
  end

  @doc """
  Adds the minimum default ledgers and accounts for a fully functioning bank.
  All ledgers are singular (only one account) except deposit which contains
  customer deposits.

    * Deposit (liability, deposit)
    * Capital (equity, capital)
    * Cash (asset, cash)
    * Loan (asset, loan)
    * Interest income (liability, deposit)
    * Loss provision (liability, deposit)
    * Reserve (asset, deposit)
    * Retained Earnings (equity, deposit)
  """
  def init_bank_ledgers(%GL{} = gl) do
    gl
    # Deposit
    |> add_ledger("deposit", "liability", "deposit", false)
    # Capital
    |> add_ledger("capital", "equity", "capital", true)
    # Cash
    |> add_ledger("cash", "asset", "cash", true)
    # Non-Cash
    |> add_ledger("non_cash", "asset", "cash", true)
    # Loans
    |> add_ledger("loan", "asset", "loan", true)
    # Interest income
    |> add_ledger("interest_income", "liability", "deposit", true)
    # Loss reserve
    |> add_ledger("loss_reserve", "asset", "deposit", true)
    # Loss provision
    |> add_ledger("loss_provision", "liability", "deposit", true)
    # Reserve
    |> add_ledger("reserve", "asset", "deposit", true)
    # Retained earnings
    |> add_ledger("retained_earnings", "equity", "deposit", true)
  end

  #############################################################################
  #### Accounts
  #############################################################################

  @doc """
  Adds an account to the given ledger.
  """
  def add_account(%GL{ledgers: ledgers} = gl, ldg_name, acc_no, opts \\ [])
      when is_map_key(ledgers, ldg_name) do
    case Ledger.add_account(ledgers[ldg_name], acc_no, opts) do
      {:ok, ledger} -> {:ok, %{gl | ledgers: Map.put(ledgers, ldg_name, ledger)}}
      {:error, _} = err -> err
    end
  end

  @doc """
  Searches the all underlying ledgers and returns the account if found otherwise nil.
  """
  def get_account(%GL{} = gl, acc_no) do
    case get_account_ledger(gl, acc_no) do
      nil -> {:error, :not_found}
      ledger -> {:ok, ledger.accounts[acc_no]}
    end
  end

  @doc """
  Searches a specific ledger for the given account number.
  """
  def get_account(%GL{ledgers: ledgers} = gl, ldg_name, acc_no)
      when is_map_key(ledgers, ldg_name) do
    case gl.ledgers[ldg_name] do
      nil -> {:error, :not_found}
      ledger -> ledger.accounts[acc_no]
    end
  end

  @doc """
  Returns all the accounts owned by `customer_no`.
  """
  def get_accounts(%GL{ledgers: ledgers}, customer_no) do
    ledgers
    |> Enum.flat_map(fn l -> l.accounts end)
    |> Enum.filter(fn a -> a.customer_no == customer_no end)
  end

  #############################################################################
  #### Transfers
  #############################################################################

  @doc """
  Standard transfer of funds using debit and credit.
  """
  def transfer(%GL{} = gl, debit_no, credit_no, amount) when amount > 0 do
    with {:ok, gl} <- credit(gl, credit_no, amount),
         {:ok, gl} <- debit(gl, debit_no, amount) do
      {:ok, gl}
    else
      {:error, _} = err -> err
    end
  end

  defp debit(%GL{} = gl, acc_no, amount) do
    with ledger <- get_account_ledger(gl, acc_no),
         {:ok, ledger} <- Ledger.debit(ledger, acc_no, amount) do
      {:ok, %{gl | ledgers: Map.put(gl.ledgers, ledger.name, ledger)}}
    else
      err -> err
    end
  end

  defp credit(%GL{} = gl, acc_no, amount) do
    with ledger <- get_account_ledger(gl, acc_no),
         {:ok, ledger} <- Ledger.credit(ledger, acc_no, amount) do
      {:ok, %{gl | ledgers: Map.put(gl.ledgers, ledger.name, ledger)}}
    else
      err -> err
    end
  end

  #############################################################################
  #### Audit
  #############################################################################

  @doc """
  Total by `acc_type` or `name`.
  """
  def ledger_total(%GL{ledgers: ledgers}, acc_type) when acc_type in @acc_types do
    ledgers
    |> Enum.filter(fn {_k, v} -> v.account_type == acc_type end)
    |> Enum.reduce(0, fn {_k, v}, acc -> acc + Ledger.total(v) end)
  end

  def ledger_total(%GL{ledgers: ledgers}, name) when is_map_key(ledgers, name) do
    Ledger.total(ledgers[name])
  end

  @doc """
  Audits the entire ledger based on Assets = Liabilities + Equity.
  """
  def audit(%GL{} = gl) do
    ledger_total(gl, "asset") == ledger_total(gl, "liability") + ledger_total(gl, "equity")
  end
end
