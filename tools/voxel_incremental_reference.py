"""Exact dirty-region reference for finite-iteration six-neighbor RGB voxel light.

World-space integer keys allow a scrolling grid to retain its overlap.
Each propagation stage is cached independently; a deletion is not a
monotone max-update and therefore dirty cells are recomputed from scratch.
"""
from itertools import product

BLACK = (0.0,0.0,0.0)
DIRECTIONS = ((-1,0,0),(1,0,0),(0,-1,0),(0,1,0),(0,0,-1),(0,0,1))
ATTENUATION = 0.73


def neighbors(cell):
    return (tuple(x+d for x,d in zip(cell,direction)) for direction in DIRECTIONS)


def grid(origin,size):
    return set(product(*(range(o,o+size) for o in origin)))


def source(cell,emitters,walls):
    return BLACK if cell in walls else emitters.get(cell,BLACK)


def evaluate(cell,previous,emitters,walls):
    if cell in walls:
        return BLACK
    light = list(emitters.get(cell,BLACK))
    for neighbor in neighbors(cell):
        incoming = previous.get(neighbor,BLACK)
        for c in range(3):
            light[c] = max(light[c],incoming[c]*ATTENUATION)
    return tuple(light)


def full_rebuild(origin,size,emitters,walls,passes):
    domain = grid(origin,size)
    stages = [{cell:source(cell,emitters,walls) for cell in domain}]
    for _ in range(passes):
        stages.append({cell:evaluate(cell,stages[-1],emitters,walls) for cell in domain})
    return stages


class IncrementalVoxelCache:
    def __init__(self,origin,size,emitters,walls,passes=4):
        self.size,self.passes = size,passes
        self.origin = origin
        self.emitters,self.walls = dict(emitters),set(walls)
        self.domain = grid(origin,size)
        self.stages = full_rebuild(origin,size,self.emitters,self.walls,passes)

    def update(self,origin,emitters,walls):
        emitters,walls = dict(emitters),set(walls)
        domain = grid(origin,self.size)
        entered,removed = domain-self.domain,self.domain-domain
        seed_dirty = entered | {cell for cell in domain & self.domain
                                if source(cell,emitters,walls) != source(cell,self.emitters,self.walls)
                                or (cell in walls) != (cell in self.walls)}
        old = self.stages
        first = {cell:old[0][cell] for cell in domain & self.domain}
        for cell in seed_dirty:
            first[cell] = source(cell,emitters,walls)
        stages = [first]
        changed = {cell for cell in seed_dirty if first[cell] != old[0].get(cell,BLACK)} | removed
        counts = [len(seed_dirty)]
        for iteration in range(1,self.passes+1):
            dirty = seed_dirty | {n for cell in changed for n in neighbors(cell) if n in domain}
            stage = {cell:old[iteration][cell] for cell in domain & self.domain if cell not in dirty}
            for cell in dirty:
                stage[cell] = evaluate(cell,stages[-1],emitters,walls)
            changed = {cell for cell in dirty if stage[cell] != old[iteration].get(cell,BLACK)} | removed
            stages.append(stage)
            counts.append(len(dirty))
        self.origin,self.domain = origin,domain
        self.emitters,self.walls = emitters,walls
        self.stages = stages
        return {"evaluations_by_stage":counts,"full_evaluations":len(domain)*(self.passes+1)}
