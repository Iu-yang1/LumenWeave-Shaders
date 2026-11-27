package io.lumenweave.renderer.core;

import java.util.IdentityHashMap;
import java.util.function.ToIntFunction;

public final class SeedPalette<State> {
    private final IdentityHashMap<State,Integer> values=new IdentityHashMap<>();
    private final ToIntFunction<State> decode;

    public SeedPalette(ToIntFunction<State> decode) {
        this.decode=decode;
    }

    public int seed(State state) {
        Integer existing=values.get(state);
        if(existing!=null)return existing;
        int decoded=decode.applyAsInt(state);
        values.put(state,decoded);
        return decoded;
    }

    public void clear() {
        values.clear();
    }

    public int size() {
        return values.size();
    }
}
