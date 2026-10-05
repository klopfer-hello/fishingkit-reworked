Run from the repository root with Lua 5.1 or 5.2:

```sh
lua tests/run.lua
lua tests/run.lua fishing
```

The tests load the actual addon modules with isolated game API fixtures and
deferred timers. They cover loot and cast ordering, auction scan callbacks,
backup independence, pool route targets, and sound restoration at logout.

Set `FISHINGKIT_SOURCE` to another checkout to run the same cases against it.
The loader strips UTF-8 BOMs for compatibility with standalone Lua 5.1.
