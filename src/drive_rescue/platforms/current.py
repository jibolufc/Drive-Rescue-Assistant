from __future__ import annotations

import platform


def platform_adapter():
    system = platform.system().lower()
    if system == "darwin":
        from . import macos as adapter
    elif system == "windows":
        from . import windows as adapter
    elif system == "linux":
        from . import linux as adapter
    else:
        from . import base as adapter
    return adapter

