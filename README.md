# Advent of Code 2023 in LLVM IR

## Prerequisites

- `llc`
- `clang`
- `lld`
- `make`

Provided by `nix develop`.

## Usage

```console
$ make all
$ ./dayXX
```

## Challenge restrictions

The only "allowed" usage of libc is to read input files and write to standard outut and error.

## License

Solutions are licensed under GPL3 or later.
