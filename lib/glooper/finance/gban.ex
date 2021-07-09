defmodule Glooper.GBAN do
  @moduledoc """
  A utility module for Glooper Bank Account Number (GBAN) references.

  The glooper bank account number is a case-insensitive sequence of alphanumeric
  characters made up of 2 parts separated by dash for routing bank and account.
  Below is an example of a full-length GBAN string.

  ```"1234-123456"```

  The example number above is be parsed as follows.

  * Bank: 1234
  * Account: 123456

  ## Examples

      iex> GBAN.parse("123456")
      [account: "123456", bank: ""]

      iex> GBAN.parse("1234-123456")
      [account: "123456", bank: "1234"]
  """

  @internal_accounts "(deposit|capital|cash|non_cash|loan|interest_income|loss_reserve|loss_provision|reserve|retained_earning)"
  @bank_regex ~s/(?<bank>[a-z0-9]+)/
  @account_regex ~s/(?<account>(#{@internal_accounts}|[a-z0-9]+))/

  @gban_regex ~r/^(((#{@bank_regex}\-)?#{@account_regex}))$/i

  @doc """
  Parse a standard GBAN number into parts.
  """
  def parse(number) do
    case Regex.named_captures(@gban_regex, number) do
      nil ->
        {:error, :invalid_gban}

      parts ->
        Map.new(parts, fn {k, v} -> {String.to_atom(k), v} end)
    end
  end

  @doc """
  Generates a GBAN number from keyword list.
  """
  def generate(args) when is_list(args) do
    generate(args[:bank], args[:account])
  end

  def generate(args) when is_map(args) do
    generate(args.bank, args.account)
  end

  @doc """
  Generate a GBAN number from explicit parts.
  """
  # account only
  def generate("", account), do: "#{account}"
  # account only
  def generate(nil, account), do: "#{account}"

  # bank and account
  def generate(bank, account), do: "#{bank}-#{account}"
end
