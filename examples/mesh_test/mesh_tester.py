"""Ensure the scenes have a cube mesh."""

import unittest

import bpy


class BlenderTests(unittest.TestCase):
    """Test cases for a `.blend` file"""

    def test_cube_exists(self) -> None:
        """Test that the current blend file has a cube mesh."""

        for obj in bpy.data.objects:
            if obj.type == "MESH" and obj.name == "Cube":
                print("Cube mesh found!")
                return

        raise AssertionError("No cube mesh detected")


if __name__ == "__main__":
    unittest.main(argv=[__file__])
