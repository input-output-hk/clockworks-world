{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (inputs.bitte-cells._writers.library) writeShellApplication;
  inherit (cell) packages;
in {
  matterbridge = writeShellApplication {
    name = "entrypoint";
    text = ''
      exec ${packages.matterbridge}/bin/matterbridge -debug -conf /secrets/config.toml
    '';
  };
}
