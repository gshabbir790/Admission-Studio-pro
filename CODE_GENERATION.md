# Code generation / CI

This project commits the Hive TypeAdapter `.g.dart` files intentionally.
The application uses classic `hive`/`hive_flutter`, and there are no Riverpod,
Freezed, or JSON code-generation annotations in `lib/`.

GitHub Actions therefore does **not** run `build_runner`. This avoids CI
failures caused by an incompatible/stale generator toolchain and makes release
builds deterministic.

If a future developer changes a Hive model (fields or type IDs), regenerate the
adapters locally with a compatible `hive_generator`/`build_runner` setup and
commit the resulting `.g.dart` files before pushing.
