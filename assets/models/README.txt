Place the local KataGo ONNX model file here as:

katago-kata1-b18c384nbt-batched-fp16.onnx

This file is downloaded by:

bash /home/runner/work/go-puzzle/go-puzzle/scripts/init-dev.sh

It is intentionally git-ignored and should not be committed to the repo.

The current Kaya/KataGo ONNX model uses dynamic board height and width axes, so
the same model asset is used for supported board sizes instead of maintaining
separate 9x9, 13x13, and 19x19 aliases.

The local Capture5 model files are:

capture5_13x13_11p_resnet_phase_h_hard010.onnx
capture5_13x13_11p_resnet_phase_h_hard010.metadata.json

It is a 13x13 capture-five policy model using feature schema
capture5_features_11p_ladder_v1 with 11 input planes. Expected ONNX SHA-256:

204f39d27b719a307be09bef96adfe61415e53bf26be4d2c87e4560bd0e629de

The Capture5 ONNX file is intentionally git-ignored and is provided as a GitHub
release asset:

https://github.com/crazygo/go-puzzle/releases/download/capture5-models-v1/capture5_13x13_11p_resnet_phase_h_hard010.onnx

To replace it from a local ML artifact, copy it from:

/Users/admin/Code/go-puzzle-ml/models/generated/capture5_13x13_11p_resnet_phase_h_hard010.onnx
