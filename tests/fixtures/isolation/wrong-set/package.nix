# Red fixture: a library declaring a set no family provides.
{
  buildPythonPackage,
  setuptools,
}:
buildPythonPackage {
  pname = "wrong-set";
  version = "0";
  pyproject = true;
  build-system = [setuptools];
  src = ./src;
  passthru = {
    kind = "library";
    set = "nodePackages";
  };
}
