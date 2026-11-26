# V5.8 sparse occupancy and shared computations

Baseline: `0231ce06d6302411225c6de9c1fb89124ecf17d2`.

- Retain current and previous local 4^3 brick occupancy bits in a disjoint tail of the existing R32UI image. Clear only previously occupied bricks on consecutive frames; initialize all bricks after invalid metadata. First successful atomic insertion publishes a brick bit, preserving the atomic maximum seed arbitration. Skip seed comparisons for two empty observations only with stationary integer camera and consecutive metadata. Movement retains full comparison; propagation, history and weather still consume current occupancy. Dispatch count is unchanged.
- Hi-Z uses identical native depth samples and min/max bounds, with full-interior tile fast path and invariant projected depth.
- Water skips bands whose existing coverage weight is mathematically zero and delays phase evaluation until necessary; retains the precise Fresnel model and visible band budgets.
- No profile, render scale, shadow resolution, image slot count or full-screen pass changes.

CPU regression covers atlas layout, 240 frames, deletion, repeated seed arbitration, camera movement, stale metadata, Hi-Z edges, zero wave thresholds and footprint algebra. GPU synchronization, dense geometry atomic contention and actual performance require real runtime verification. No true event-driven geometry feed, shadow scheduling/cache, full HDR fusion, compressed light-field migration or new LUT approximation is implemented in this increment.
