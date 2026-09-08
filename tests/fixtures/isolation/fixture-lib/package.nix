# Green fixture: a trivial python library, the witness for the library branch.
{
  buildPythonPackage,
  setuptools,
}:
buildPythonPackage {
  pname = "fixture-lib";
  version = "0";
  pyproject = true;
  build-system = [setuptools];
  src = ../fixture-lib/src;
  passthru = {
    kind = "library";
    set = "python3Packages";
  };
}
