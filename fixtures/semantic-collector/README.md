# SDK-040 semantic collector fixture

This fixture compiles real Haxe declarations through the versioned build macro
collector. The collector emits only a canonical semantic plan and an
inspectable effective-input sidecar into a temporary test directory.

The positive program declares one plugin, one action, one resource, and one
public build environment input. Negative compile modes prove duplicate and
missing nodes, exact-profile rejection, callback typing, literal identities,
path containment, and required-environment handling. The JavaScript target is
used only to prove that the build API and collector do not survive full DCE.
