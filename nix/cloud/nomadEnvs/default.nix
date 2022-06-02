{
  inputs,
  cell,
}: {
  infra = {
    database = inputs.bitte-cells.mariadb.nomadJob.default cell.constants.infra;
  };

  prod = {
    matomo = import ./matomo {
      inherit inputs cell;
      inherit (cell.constants.prod) domain namespace;
    };
  };
}
