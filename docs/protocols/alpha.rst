.. _alpha:

Protocol Alpha
==============

This page contains all the relevant information for protocol Alpha, a
development version of the Tezos protocol.

The code can be found in the ``src/proto_alpha`` directory of the
``master`` branch of Tezos.

This page documents the changes brought by protocol Alpha with respect
to Granada.

The main novelties in the Alpha protocol are:

- Context storage flattening for better context access performance.  Hex-nested
  directories like `/12/af/83/3d/` are removed from the context.  (MR :gl:`!2771`)
- Gas calculation fix based on the new flattend context layout (MR :gl:`!2771`)

.. contents:: Here is the complete list of changes:

New Environment Version (V3)
----------------------------

This protocol requires a different protocol environment than Granada.
It requires protocol environment V3, compared to V2 for Granada.

Bug fixes
---------

- A bug in Michelson comparison function has been fixed (MR :gl:`!3237`)

Minor changes
-------------

- Gas improvements for typechecking instruction ``CONTRACT`` (MR :gl:`!3241`)

- Other internal refactorings or documentation. (MRs :gl:`!2021` :gl:`!2984`
  :gl:`!3042` :gl:`!3049` :gl:`!3088` :gl:`!3075` :gl:`!3266`)

New Features
------------

- Expose timelock primitive to the Michelson interpreter.
  (MRs :gl:`!3160` :gl:`!2940` :gl:`!2950`) adds to michelson timelock
  related types and opcode. It's allows a smart contract to include a
  countermeasure against Block Producer Extractable Value.  More infos
  in docs/alpha/timelock.rst
