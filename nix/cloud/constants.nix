{
  inputs,
  cell,
}: let
  domain = "cw.iog.io";
in {
  infra = rec {
    inherit domain;
    WALG_S3_PREFIX = "s3://iog-clockworks-bitte/backups/${namespace}/walg";
    namespace = "infra";
    datacenters = ["eu-central-1"];
    nodeClass = namespace;
    scaling = 3;
    resources.cpu = 7000;
    resources.memory = 12 * 1024;
    # tempoMods.scaling = 1;
    # tempoMods.resources.cpu = 3000;
    # tempoMods.resources.memory = 3 * 1024;
    # tempoMods.storageS3Bucket = "iohk-cw-tempo";
    # tempoMods.storageS3Endpoint = "s3.eu-central-1.amazonaws.com";
  };
  prod = {
    inherit domain;
    namespace = "prod";
    datacenters = ["eu-central-1"];
  };
}
