{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (inputs.bitte-cells._writers.library) writeShellApplication;
  inherit (cell) packages;
in {
  kroki = writeShellApplication {
    name = "entrypoint";
    text = ''
      exec ${packages.kroki}/bin/kroki-server
    '';
  };
}
