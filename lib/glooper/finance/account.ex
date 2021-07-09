defmodule Glooper.Account do
  @moduledoc """
  The `Glooper.Account` is the foundation of the double-entry bookkeeping.

  It is fairly simple and defines the owning customer, account number, deposit,
  and the notion of whether the account is frozen or not.

  The account does not support overdrafts so posts to the account that would
  bring the deposit to negative are simply rejected with an error.
  """

  alias __MODULE__

  @enforce_keys [:account_no, :customer_no]
  @optional_keys [deposit: 0, frozen: false]
  defstruct @enforce_keys ++ @optional_keys

  @doc """
  Create a new account with desired `account_no` belonging to `customer_no`.
  """
  def create(account_no, customer_no) do
    %Account{account_no: account_no, customer_no: customer_no}
  end

  @doc """
  Post a transaction to the account. Returns an error if there are not enough
  funds to support the transaction.
  """
  def post(%Account{frozen: true}, _amount), do: {:error, :account_frozen}

  def post(%Account{deposit: deposit, frozen: false} = acc, amount) do
    case deposit + amount do
      x when x >= 0 -> {:ok, %{acc | deposit: acc.deposit + amount}}
      x when x < 0 -> {:error, :insufficient_funds}
    end
  end

  @doc """
  Freeze the account.
  """
  def freeze(%Account{} = acc), do: %Account{acc | frozen: true}

  @doc """
  Unfreeze the account.
  """
  def unfreeze(%Account{} = acc), do: %Account{acc | frozen: false}
end
