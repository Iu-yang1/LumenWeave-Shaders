"""CPU reference for the P0 six-neighbor, componentwise-max propagation."""

NEIGHBORS = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
BLACK = (0.0, 0.0, 0.0)


def propagate(size, emitters, walls, passes):
    field = dict(emitters)
    for _ in range(passes):
        following = dict(emitters)
        for cell, light in field.items():
            attenuated = tuple(channel * 0.75 for channel in light)
            for offset in NEIGHBORS:
                neighbor = tuple(
                    coordinate + delta for coordinate, delta in zip(cell, offset)
                )
                if neighbor in walls or not all(
                    0 <= coordinate < size for coordinate in neighbor
                ):
                    continue
                following[neighbor] = tuple(
                    map(max, following.get(neighbor, BLACK), attenuated)
                )
        field = following
    return field
