defmodule Glooper.Ledger do
  @moduledoc """
  A ledger is a collection of accounts in which account transactions
  are recorded as either debit or credit and the closing balance.
  """

  alias __MODULE__, as: Ledger
  alias Glooper.Account

  @polarities Glooper.Finance.polarities()
  @account_types Glooper.Finance.account_types()
  @ledger_types Glooper.Finance.ledger_types()

  @enforce_keys [:name, :account_type, :ledger_type]
  @optional_keys [accounts: %{}, singular: true]

  defstruct @enforce_keys ++ @optional_keys

  @doc """
  Creates a new ledger of the specified account type and ledger type. Unless
  specified the ledger is singular and the underlying account is initialized
  with the same name as the ledger.
  """
  def create(name, account_type, ledger_type, singular \\ true)

  def create(name, account_type, ledger_type, true)
      when account_type in @account_types and ledger_type in @ledger_types do
    case create(name, account_type, ledger_type, false)
         |> add_account(name, "INTERNAL") do
      {:ok, l} -> l
    end
  end

  def create(name, account_type, ledger_type, singular) do
    %Ledger{name: name, account_type: account_type, ledger_type: ledger_type, singular: singular}
  end

  #############################################################################
  #### Accounts
  #############################################################################

  @doc """
  Returns the polarity of this ledger according to account type. If the account
  type is not recognized nil is returned.
  """
  def polarity(%Ledger{} = ledger), do: @polarities[ledger.account_type]

  @doc """
  Adds an account to the ledger. When the ledger is singular an account with the
  same name as the ledger is added. For singular-account ledgers an account
  number is generated using `generate_account_no` unless provided. Returns the
  ledger and the generated account number in a tuple.
  """
  def add_account(%Ledger{singular: true} = ledger), do: add_account(ledger, ledger.name, nil)

  def add_account(ledger, account_no, customer_no \\ nil)

  def add_account(%Ledger{accounts: accounts}, account_no, _customer_no)
      when is_map_key(accounts, account_no) do
    {:error, :duplicate_account_no}
  end

  def add_account(%Ledger{accounts: accounts} = ledger, account_no, customer_no)
      when not is_map_key(accounts, account_no) do
    account = Account.create(account_no, customer_no)
    {:ok, %{ledger | accounts: Map.put_new(accounts, account_no, account)}}
  end

  #############################################################################
  #### Accounts
  #############################################################################

  @doc """
  Debit the amount to the given account.
  """
  def debit(%Ledger{} = l, account_no, amount),
    do: post(l, account_no, amount * -1)

  @doc """
  Credit the amount to the given account.
  """
  def credit(%Ledger{} = l, account_no, amount),
    do: post(l, account_no, amount)

  defp post(%Ledger{accounts: accounts} = ledger, account_no, amount)
       when is_map_key(accounts, account_no) do
    case Account.post(accounts[account_no], amount * polarity(ledger)) do
      {:ok, account} -> {:ok, %{ledger | accounts: Map.put(ledger.accounts, account_no, account)}}
      {:error, _} = err -> err
    end
  end

  def total(%Ledger{accounts: accounts}) do
    accounts
    |> Enum.reduce(0, fn {_k, v}, acc -> acc + v.deposit end)
  end
end
