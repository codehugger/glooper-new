defmodule Glooper.TransactionLog do
  @moduledoc """
  The transaction log is responsible for recording transactions and associating
  them with the accounts involved. It uses duplicate entries for easier lookup
  one for debit and another for credit.
  """

  alias __MODULE__, as: TL
  alias Glooper.Transaction, as: T

  @type t :: %TL{}

  @enforce_keys []
  @optional_keys [transactions: %{}]

  defstruct @enforce_keys ++ @optional_keys

  @spec create :: TL.t()
  def create() do
    %TL{}
  end

  #############################################################################
  #### Transactions
  #############################################################################

  @doc """
  Add the given transaction to the underlying log associating it with both
  `debit_no` and `credit_no`.
  """
  def add(%TL{} = tl, %T{debit_no: debit_no, credit_no: credit_no} = t) do
    transactions =
      tl.transactions
      |> Map.update(debit_no, [t], fn x -> [t | x] end)
      |> Map.update(credit_no, [t], fn x -> [t | x] end)

    {:ok, %{tl | transactions: transactions}, t}
  end

  @doc """
  Add the given transaction to the underlying log by specifying its parts.
  """
  def add(%TL{} = tl, debit_no, credit_no, amount, text, timestamp),
    do: add(tl, T.create(debit_no, credit_no, amount, text, timestamp))

  @doc """
  Removes all entries from the underlying transactions log.
  """
  def clear(%TL{} = tl),
    do: {:ok, %{tl | transactions: %{}}}
end
