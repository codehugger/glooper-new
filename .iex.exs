alias Glooper.{Bank, Borrower, Simulation}

# Government, Factory, Market, Population

###############################################################################
#### Borrower POC - Config Example
###############################################################################
borrower_config = Toml.decode_file!("#{__DIR__}/examples/borrower/borrower.toml")

###############################################################################
#### UBI 2 Products - Config Example
###############################################################################
ubi_config = Toml.decode_file!("#{__DIR__}/examples/surplus/ubi.toml")
