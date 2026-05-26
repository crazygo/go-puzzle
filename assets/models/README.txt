Place the local KataGo ONNX model file here as:

katago-kata1-b18c384nbt-batched-fp16.onnx

This file is downloaded by:

bash /home/runner/work/go-puzzle/go-puzzle/scripts/init-dev.sh

It is intentionally git-ignored and should not be committed to the repo.

The current Kaya/KataGo ONNX model uses dynamic board height and width axes, so
the same model asset is used for supported board sizes instead of maintaining
separate 9x9, 13x13, and 19x19 aliases.

The local Capture5 v8 model file is:

capture5_13x13_policy_only_v8.onnx

It is a 13x13 capture-five policy model. Expected SHA-256:

98441223424eef68eaeab35c715f56add24ff0207c0d59ab66a85fdaed4f48c6

This ONNX file is also intentionally git-ignored. Until it is published as a
release asset, copy it locally from:

/Users/admin/Code/go-puzzle-ml/models/released/capture5_13x13_policy_only_v8.onnx
