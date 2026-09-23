"""The entry point the wrapper runs, beside the package it imports.

Python puts a script's own directory first on sys.path, so this file sitting next to the
knotview package is what makes the package importable without a PYTHONPATH the scrub would
have to make an exception for. The console entry point pyproject.toml declares is called
here rather than reimplemented: this file holds no behaviour of its own.
"""

import sys

from knotview.entry.console import main

sys.exit(main())
