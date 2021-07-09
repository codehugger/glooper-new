defmodule Glooper.Transaction do
  @moduledoc """
  A `Glooper.Transaction` defines the debit and credit of a monetary transaction
  and the time of occurrence within a double-entry bookkeeping system.
  """

  alias __MODULE__
  @enforce_keys [:debit_no, :credit_no, :amount]
  @optional_keys [timestamp: 0, text: "Unspecified transaction"]

  defstruct @enforce_keys ++ @optional_keys

  def create(init_arg \\ []) do
    struct!(Transaction, init_arg)
  end

  def create(debit_no, credit_no, amount, text, timestamp) do
    create(
      debit_no: debit_no,
      credit_no: credit_no,
      amount: amount,
      text: text,
      timestamp: timestamp
    )
  end
end
