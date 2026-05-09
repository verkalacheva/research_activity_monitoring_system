"""Shared pytest fixtures and helpers for crawler_service tests."""
import sys
import os

# Ensure crawler_service root is on sys.path so imports work without installation
_crawler_root = os.path.dirname(os.path.dirname(__file__))
if _crawler_root not in sys.path:
    sys.path.insert(0, _crawler_root)
