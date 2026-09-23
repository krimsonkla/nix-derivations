"""Import every module of a package tree, so a missing dependency fails by name at build time.

The analogue of a namespace check: a dependency that is absent from the closure is found here,
naming the module that wanted it, rather than in a consumer's browser on the first page that
happens to reach it. Takes the directory holding the package and the package's name.
"""

import importlib
import pkgutil
import sys

root, package_name = sys.argv[1], sys.argv[2]
sys.path.insert(0, root)

package = importlib.import_module(package_name)
names = [package_name] + [
    found.name for found in pkgutil.walk_packages(package.__path__, package_name + ".")
]
for name in names:
    importlib.import_module(name)
print(f"{len(names)} modules import under this python")
