"""Spack-backed assertions used by the ReFrame concretization tests."""

import argparse
from collections import Counter
from pathlib import Path


def check_concretization(path):
    import spack.environment as ev

    environment = ev.Environment(str(path))
    pairs = list(environment.concretized_specs())
    if not environment.user_specs:
        raise AssertionError("Environment has no requested roots: " + str(path))
    if Counter(str(spec) for spec in environment.user_specs) != Counter(
            str(abstract) for abstract, _ in pairs):
        raise AssertionError("Not every requested root has a concrete result: " + str(path))
    if not all(spec.concrete for spec in environment.all_specs()):
        raise AssertionError("Environment contains abstract packages: " + str(path))
    for abstract, concrete in pairs:
        if not concrete.satisfies(abstract):
            raise AssertionError("Concrete root does not satisfy {}: {}".format(abstract, concrete))
    print("Concretization verified: {} ({} roots)".format(path, len(pairs)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("environment", type=Path)
    check_concretization(parser.parse_args().environment)
