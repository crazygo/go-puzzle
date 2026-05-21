Place the local territory ONNX model files here as:

katago_territory_9x9.onnx
katago_territory_13x13.onnx
katago_territory_19x19.onnx

These files are downloaded by:

bash /home/runner/work/go-puzzle/go-puzzle/scripts/init-dev.sh

They are intentionally git-ignored and should not be committed to the repo.

The iOS native territory bridge looks for the board-size-specific asset first
and falls back to the Dart territory engine when the matching model is absent.
