{
  inputs,
  cell,
}: let
  inherit (inputs.bitte-cells) vector;
in {
  prod = {
    database = import ./mysql {
      inherit inputs cell;
      inherit (constants.args.prod) domain namespace;
    };

    matomo = import ./matomo {
      inherit inputs cell;
      inherit (constants.args.prod) domain namespace;
    };
  };
}
