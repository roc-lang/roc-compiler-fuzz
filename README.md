# Roc Compiler Fuzz

A github repo that attempts to continually fuzz the roc compiler.
Inspiration loosely take from TigerBeetle's [Rocket science of simulation testing talk](https://www.hytradboi.com/2025/c222d11a-6f4d-4211-a243-f5b7fafc8d79-rocket-science-of-simulation-testing). 

## How it works?

Roc Compiler Fuzz loads the latest roc commit every few hours and starts running our various fuzz targets.
After fuzzing for a while, failures are minimized, and the results are logged in [data.json](data.json).
These results are then deployed to https://roc-lang.github.io/roc-compiler-fuzz/.

This makes it easy for Roc developers to periodically check for fuzzing failures and improve the compiler.
Only the most recent failures are kepts around. Old bugs are forgotten until the fuzzer finds them again.

To help the fuzzer explore better, the fuzzing corpus is cached between runs.
This enables the fuzzer to basically pickup where it left off.
