Place the local KataGo ONNX model file here as:

katago-kata1-b18c384nbt-batched-fp16.onnx

This file is downloaded by:

bash /home/runner/work/go-puzzle/go-puzzle/scripts/init-dev.sh

It is intentionally git-ignored and should not be committed to the repo.

The current Kaya/KataGo ONNX model uses dynamic board height and width axes, so
the same model asset is used for supported board sizes instead of maintaining
separate 9x9, 13x13, and 19x19 aliases.
